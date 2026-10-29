// ================================================================
// HALO — 系统数据光环 | KDE Plasma 6 Widget
// version v0.11 (Plasma 6 port)
// ================================================================

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "halo2139.js" as Halo

// ================================================================
// 1. ROOT — Plasmoid shell
// ================================================================

PlasmoidItem {
    id: root
    width:  400
    height: 400

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // ============================================================
    // 2. fullRepresentation — main widget surface
    // ============================================================

    fullRepresentation: Item {
        id: w
        anchors.fill: parent

        // ─── 2a. layout constants ───────────────────────────────
        readonly property string version: "v1.0 (Halo #2139)"

        // ─── 2b. halo state（Halo #2139，IL 原样移植）─────────────
        // 状态机在 halo2139.js 里，与 tools/halo2139_sim.py 逐函数对应。
        // 规格书：docs/HALO_2139_SPEC.md
        property var halo: null

        // 缩放：把「游戏单位」映射到屏幕像素，组件任意尺寸都成立。
        //   Halo.GAME_EXTENT = 57 = 常态外沿（外圈 bit 环半径 55 + 径向半厚 2）
        //   inscribe = 1.0 → 常态外沿【正好内接】于组件矩形
        //   inscribe > 1.0 → 整体缩小，为 IL 自身的大脉冲（expand 可达 2.0，
        //                  每约 32 秒一次）留出余量，避免被 Canvas 边界切平
        readonly property real inscribe: 1.0
        readonly property real haloScale: {
            var d = Math.min(width, height);
            return d > 0 ? (d / 2) / (Halo.GAME_EXTENT * inscribe) : 1;
        }

        // ─── 数据调制槽位（computeModulation 写入；1/0 = 原版行为）───
        // 每个槽位都对应 Halo 里一个【真实存在】的自由度，不新增几何。
        property real modSizeGain:   1.0        // ← CPU  ：整体尺寸倍率 0.80..1.00
        property real modRing1Thick: 3.0        // ← 内存：环 1 粗细（游戏单位，3 = 原版）
        property real modWhiteForce: 0.0        // ← 温度：0..1 强制环 0 变实心墨盘
        property var  modBitGain:    [1.0, 1.0, 1.0]  // ← 磁盘/GPU/网络：三环活跃度
        property real modRotSpeed:   1.0        // ← 负载：旋转急促度

        // ─── 2b2. system data (polled from /proc) ──────────────
        property real sysCpu:   0       // 0..100
        property real sysMem:   0       // 0..100
        property real sysLoad:  0       // per‑core load 0..1+
        property real sysTemp:  40      // celsius
        property real sysNetDown: 0     // bytes/s (delta)
        property real sysNetUp:  0     // bytes/s (delta)
        property var  _netPrev: ({ d: 0, u: 0 })
        property var  _netTime: 0
        // modulation factors (computed from system data at each poll)
        // modulation factors (computed from system data at each poll)
        property int   paintTick: 0   // incremented after every data poll → forces Canvas+Text refresh
        property real cpuMix:   0     // 0‑1  CPU% → colour mix
        property real cpuPulse: 1     // 0.5‑3  temp → pulse amplitude
        property real cpuRotSpd:1     // 0.3‑3  loadavg → rotation speed
        property real memMix:   0     // 0‑1  Mem% → colour mix
        property real memBright:1     // 0.2‑1.5  flicker brightness
        property real netMix:   0     // 0‑1  Net↓ → colour mix
        property real netPulse: 1     // 0.5‑3  Net↑ → burst amplitude
        property real netRotSpd:1     // 0.5‑3  total throughput → rotation speed
        // disk I/O (cumulative sectors → delta)
        property real sysDiskRead: 0    // sectors/s
        property real sysDiskWrite: 0   // sectors/s
        property var  _diskPrev: ({ r: 0, w: 0 })
        property var  _diskTime: 0
        // GPU (显存占用百分比 + 温度, 来自 nvidia-smi)
        property real sysGpu:   0       // 0..100 VRAM%
        property real sysGpuTemp: 50    // celsius

        // Disk (layer 0) — color by total throughput
        property real diskColorMix: 0   // 0‑1  total I/O → colour mix
        // GPU (layer 3) — VRAM%
        property real gpuColorMix: 0    // 0‑1  vram% → colour
        property real gpuPulse: 1       // 0.5‑3  vram% → pulse amplitude
        property real gpuRotSpd:1       // 0.3‑3  vram% → rotation speed

        // ─── 2c. color config (persistent) ──────────────────────
        // color config (continued) ──────────────────────────────
        readonly property var defaultColors: [
            "#8fb3a6", "#cfe7df", "#bfe0d6", "#d6ece4", "#c4e0d8"
        ]

        property string _c0: defaultColors[0]
        property string _c1: defaultColors[1]
        property string _c2: defaultColors[2]
        property string _c3: defaultColors[3]
        property string _c4: defaultColors[4]

        // dual‑color (start / end) for data‑driven layers (all)
        property string _c0s: "#5a8a7a"
        property string _c0e: "#c0a050"
        property string _c1s: "#2a6e7e"
        property string _c1e: "#c04040"
        property string _c2s: "#3a9a6a"
        property string _c2e: "#b058d0"
        property string _c3s: "#6ab0c0"
        property string _c3e: "#d05030"
        property string _c4s: "#4a8a7a"
        property string _c4e: "#d0a050"

        function getColor(i) {
            if (i === 0) return lerpColor(_c0s, _c0e, diskColorMix);
            if (i === 1) return lerpColor(_c1s, _c1e, cpuMix);
            if (i === 2) return lerpColor(_c2s, _c2e, memMix);
            if (i === 3) return lerpColor(_c3s, _c3e, gpuColorMix);
            if (i === 4) return lerpColor(_c4s, _c4e, netMix);
            return "#000000";
        }

        function syncColors() {
            var v;
            v = Plasmoid.configuration.color0Start; _c0s = (v && v.length) ? v : "#5a8a7a";
            v = Plasmoid.configuration.color0End;   _c0e = (v && v.length) ? v : "#c0a050";
            v = Plasmoid.configuration.color1Start; _c1s = (v && v.length) ? v : "#2a6e7e";
            v = Plasmoid.configuration.color1End;   _c1e = (v && v.length) ? v : "#c04040";
            v = Plasmoid.configuration.color2Start; _c2s = (v && v.length) ? v : "#3a9a6a";
            v = Plasmoid.configuration.color2End;   _c2e = (v && v.length) ? v : "#b058d0";
            v = Plasmoid.configuration.color3Start; _c3s = (v && v.length) ? v : "#6ab0c0";
            v = Plasmoid.configuration.color3End;   _c3e = (v && v.length) ? v : "#d05030";
            v = Plasmoid.configuration.color4Start; _c4s = (v && v.length) ? v : "#4a8a7a";
            v = Plasmoid.configuration.color4End;   _c4e = (v && v.length) ? v : "#d0a050";
        }

        function setColor(i, hex) {
            var keyS = "color" + i + "Start";
            var keyE = "color" + i + "End";
            Plasmoid.configuration[keyS] = hex;
            Plasmoid.configuration[keyE] = hex;
            if (i === 0) { _c0s = hex; _c0e = hex; }
            if (i === 1) { _c1s = hex; _c1e = hex; }
            if (i === 2) { _c2s = hex; _c2e = hex; }
            if (i === 3) { _c3s = hex; _c3e = hex; }
            if (i === 4) { _c4s = hex; _c4e = hex; }
        }

        /* map system data → modulation factors for each hardware layer */
        function computeModulation() {
            // CPU layer (1)
            cpuMix   = Math.max(0, Math.min(1, sysCpu / 100));
            cpuPulse = 0.5 + Math.min(1, Math.max(0, (sysTemp - 35) / 55)) * 2.5;
            cpuRotSpd = 0.3 + Math.min(1, sysLoad / 3) * 2.7;

            // Memory layer (2)
            memMix    = Math.max(0, Math.min(1, sysMem / 100));
            memBright = 0.3 + memMix * 1.2;

            // Disk layer (0) — color by total throughput (low→start, high→end)
            var totalRate = sysDiskRead + sysDiskWrite;
            var refIO = 50000;  // ~25 MB/s reference
            diskColorMix = Math.min(1, totalRate / refIO);

            // GPU layer (3) — VRAM% → colour & pulse, temp → rotation speed
            gpuColorMix = Math.max(0, Math.min(1, sysGpu / 100));
            gpuPulse  = 0.5 + gpuColorMix * 2.5;
            var gpuTempNorm = Math.max(0, Math.min(1, (sysGpuTemp - 35) / 55));
            gpuRotSpd = 0.3 + gpuTempNorm * 2.7;

            // Network layer (4)
            var maxNet = 5 * 1024 * 1024;  // 5 MB/s reference
            netMix    = Math.min(1, sysNetDown / maxNet);
            netPulse  = 0.5 + Math.min(1, sysNetUp / maxNet) * 2.5;
            var total = (sysNetDown + sysNetUp) / (maxNet * 2);
            netRotSpd = 0.5 + Math.min(1, total) * 2.5;

            // ── 映射到 Halo #2139 的真实自由度 ──────────────────
            // 原则：每个物理量占一个【原版本来就有的】槽位，不新增几何。
            //   尺寸倍率  ← CPU      （只减不增，保证常态不越出组件边界）
            //   环 1 粗细 ← 内存     （3 = 原版细环；满 = 55% 半径的厚环）
            //   环 0 实心 ← 温度     （≥70°C 起渐入，white→1 时整盘是实心墨）
            //   三环活跃  ← 磁盘/GPU/网络
            //   旋转急促  ← 平均负载
            modSizeGain   = 0.80 + 0.20 * cpuMix;
            modRotSpeed   = 0.60 + Math.min(1, sysLoad / 2.0) * 1.90;

            // 环 1：3px（原版）→ 最多 55% 半径。用 radius(1)=40 游戏单位换算
            modRing1Thick = 3.0 + (40.0 * 0.55 - 3.0) * memMix;

            // 环 0：温度告警。70°C 起，90°C 全实心
            modWhiteForce = Math.max(0, Math.min(1, (sysTemp - 70) / 20));

            modBitGain = [ 0.30 + 0.70 * diskColorMix,     // 内环 10 齿  ← 磁盘
                           0.30 + 0.70 * gpuColorMix,      // 中环 30 齿  ← GPU
                           0.30 + 0.70 * netMix ];         // 外环 60 齿  ← 网络

            // force UI refresh (仅刷新 debug Text；绘制统一由动画 Timer 驱动)
            paintTick++;
        }

        // ─── 2d. animation state ── 见 2b（halo）───────────────

        // ─── 2e. color helpers (hex with optional alpha) ────────
        function parseColor(hex) {
            hex = hex.replace('#', '');
            var r = parseInt(hex.substr(0, 2), 16);
            var g = parseInt(hex.substr(2, 2), 16);
            var b = parseInt(hex.substr(4, 2), 16);
            var a = hex.length >= 8 ? parseInt(hex.substr(6, 2), 16) / 255 : 1.0;
            return Qt.rgba(r / 255, g / 255, b / 255, a);
        }

        /* linear interpolation between two hex colours */
        function lerpColor(h1, h2, t) {
            t = Math.max(0, Math.min(1, t));
            var r1 = parseInt(h1.substr(1,2), 16);
            var g1 = parseInt(h1.substr(3,2), 16);
            var b1 = parseInt(h1.substr(5,2), 16);
            var r2 = parseInt(h2.substr(1,2), 16);
            var g2 = parseInt(h2.substr(3,2), 16);
            var b2 = parseInt(h2.substr(5,2), 16);
            var r = Math.round(r1 + (r2 - r1) * t);
            var g = Math.round(g1 + (g2 - g1) * t);
            var b = Math.round(b1 + (b2 - b1) * t);
            return '#' + r.toString(16).padStart(2,'0')
                     + g.toString(16).padStart(2,'0')
                     + b.toString(16).padStart(2,'0');
        }

        // ─── 2g. system monitor (executable engine) ──────────
        P5Support.DataSource {
            id: sysMon
            engine: "executable"
            interval: 3000
            connectedSources: []

            onNewData: (sourceName, data) => {
                // 单个合并脚本输出，每行带类型标记：
                //   C <cpu%> / M <memfrac> / L <load> / T <temp°C>
                //   N <rxBytes> <txBytes> / D <readSect> <writeSect> / G <usedMiB> <totalMiB> <temp>
                var out = (data["stdout"] || "").trim();
                if (!out) return;
                var lines = out.split('\n');
                for (var li = 0; li < lines.length; li++) {
                    var line = lines[li].trim();
                    if (!line) continue;
                    var p = line.split(/\s+/);
                    switch (p[0]) {
                    case "C":
                        w.sysCpu = Math.min(100, parseFloat(p[1]) || 0);
                        break;
                    case "M":
                        w.sysMem = (parseFloat(p[1]) || 0) * 100;
                        break;
                    case "L":
                        w.sysLoad = parseFloat(p[1]) || 0;
                        break;
                    case "T": {
                        var t = parseFloat(p[1]) || 0;
                        w.sysTemp = isNaN(t) ? 40 : Math.max(20, Math.min(100, t));
                        break;
                    }
                    case "N": {
                        if (p.length >= 3) {
                            var now = Date.now();
                            var d = parseInt(p[1]) || 0;
                            var u = parseInt(p[2]) || 0;
                            if (w._netTime > 0) {
                                var dt = (now - w._netTime) / 1000;
                                if (dt > 0.1) {
                                    w.sysNetDown = Math.max(0, (d - w._netPrev.d) / dt);
                                    w.sysNetUp   = Math.max(0, (u - w._netPrev.u) / dt);
                                }
                            }
                            w._netPrev = { d: d, u: u };
                            w._netTime = now;
                        }
                        break;
                    }
                    case "D": {
                        if (p.length >= 3) {
                            var now = Date.now();
                            var r = parseInt(p[1]) || 0;
                            var w_ = parseInt(p[2]) || 0;
                            if (w._diskTime > 0) {
                                var dt = (now - w._diskTime) / 1000;
                                if (dt > 0.1) {
                                    w.sysDiskRead  = Math.max(0, (r - w._diskPrev.r) / dt);
                                    w.sysDiskWrite = Math.max(0, (w_ - w._diskPrev.w) / dt);
                                }
                            }
                            w._diskPrev = { r: r, w: w_ };
                            w._diskTime = now;
                        }
                        break;
                    }
                    case "G": {
                        if (p.length >= 4) {
                            var used = parseFloat(p[1]) || 0;
                            var total = parseFloat(p[2]) || 1;
                            w.sysGpu = Math.min(100, Math.max(0, used / total * 100));
                            w.sysGpuTemp = parseFloat(p[3]) || 50;
                        }
                        break;
                    }
                    }
                }
                // recompute modulation factors after any data update
                // (不在此处 requestPaint：统一由动画 Timer 驱动重绘，避免双源竞争)
                w.computeModulation();
            }
        }

        // ─── 2g2. data poll ─────────────────────────────────────
        // 系统数据轮询在 2l lifecycle 的 Component.onCompleted 中
        // 一次性连接（单 source 合并脚本），此后 engine 持续推送，不再重复 connect。
        // ── 为什么不能每 2 秒 disconnect/reconnect？────────────
        // 旧版 pollTimer 每轮先 disconnect 全部旧 source、再 connect 7 个
        // 带随机 token 的新 source。disconnectSource 是异步的，追不上新 source
        // 的产生 → executable engine 内 QProcess 无限累积 →
        // 运行数小时后 plasmashell CPU/内存持续增长、widget 一卡一卡。
        // 同时旧版 nvidia-smi 无 timeout 保护，驱动异常时进程堆积雪上加霜。

        // ─── 2h. Canvas renderer ────────────────────────────────
        Canvas {
            id: cv
            anchors.fill: parent
            antialiasing: true
            clip: true              // IL 的大脉冲会超出常态外沿，裁到组件内

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (!halo) return;

                Halo.draw(ctx, halo, {
                    cx: width / 2,
                    cy: height / 2,
                    s:  haloScale,
                    // 5 个径向元素 ← 5 个颜色槽（沿用原有颜色配置的硬件语义）
                    ring0: parseColor(getColor(1)),       // 环 0        ← CPU
                    ring1: parseColor(getColor(2)),       // 环 1        ← 内存
                    bits:  [ parseColor(getColor(0)),     // 内环 10 齿  ← 磁盘
                             parseColor(getColor(3)),     // 中环 30 齿  ← GPU
                             parseColor(getColor(4)) ],   // 外环 60 齿  ← 网络
                    sizeGain:   modSizeGain,
                    ring1Thick: modRing1Thick,
                    whiteForce: modWhiteForce,
                    bitGain:    modBitGain,
                    alpha:      1.0
                });
            }
        }


        // ─── 2h. version badge ──────────────────────────────────
        Text {
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.margins: 4
            text:   version
            color:  "#5a7a6e"
            font {
                pixelSize: 10
                family:    "monospace"
            }
            opacity: 0.5
        }

        // ─── 2i. system data debug overlay ─────────────────────
        Text {
            id: sysDbg
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.margins: 6
            text: {
                // depend on paintTick to force re-evaluation after each poll
                var _ = w.paintTick;
                var nD = w.sysNetDown, nU = w.sysNetUp;
                var nDs = nD < 1000 ? nD.toFixed(0) + " B/s"
                      : nD < 1e6 ? (nD/1000).toFixed(1) + " KB/s"
                      : (nD/1e6).toFixed(1) + " MB/s";
                var nUs = nU < 1000 ? nU.toFixed(0) + " B/s"
                      : nU < 1e6 ? (nU/1000).toFixed(1) + " KB/s"
                      : (nU/1e6).toFixed(1) + " MB/s";
                return "CPU:" + w.sysCpu.toFixed(1) + "%  MEM:" + w.sysMem.toFixed(1)
                     + "%  LOAD:" + w.sysLoad.toFixed(2)
                     + "\nT:" + w.sysTemp.toFixed(1) + "°C GPUv:" + w.sysGpu.toFixed(1)
                     + "%(" + w.sysGpuTemp.toFixed(0) + "°C)"
                     + "\n↓" + nDs + "  ↑" + nUs
                     + "  ▣R:" + w.sysDiskRead.toFixed(0) + " W:" + w.sysDiskWrite.toFixed(0);
            }
            color:  "#5a7a6e"
            font {
                pixelSize: 9
                family:    "monospace"
            }
            opacity: 0.7
            lineHeight: 1.3
        }

        // ─── 2j. gear button ────────────────────────────────────
        Text {
            id: gearBtn
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            text:   "⚙"
            font.pixelSize: 14
            color:  panel.opened ? "#8fb3a6" : "#4a6a5e"
            opacity: 0.7

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked:  panel.toggle()
                onEntered:  parent.color = "#8fb3a6"
                onExited:   parent.color = panel.opened ? "#8fb3a6" : "#4a6a5e"
            }
        }

        // ─── 2j. colour settings panel ──────────────────────────
        Rectangle {
            id: panel
            anchors.centerIn: parent
            width:  parent.width  - 48
            height: parent.height - 80  // leave room for version + gear
            radius: 8
            color:  Qt.rgba(0.08, 0.08, 0.08, 0.88)
            border {
                width: 1
                color: "#3a5a4e"
            }

            visible: false
            opacity: 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            property bool opened: false

            function toggle() {
                opened = !opened;
                visible = true;
                opacity = opened ? 1 : 0;
                if (opened) forceActiveFocus();
            }

            Keys.onEscapePressed: {
                opened = false;
                opacity = 0;
            }

            MouseArea {
                anchors.fill: parent
                onClicked: forceActiveFocus()
            }

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.85
                spacing: 12

                // title
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:   "调色盘"
                    color:  "#8fb3a6"
                    font {
                        pixelSize: 22
                        bold: true
                    }
                }

                Repeater {
                    model: 5
                    delegate: Item {
                        id: layerRow
                        property int li: index
                        height: 68
                        width: parent.width

                        // layer name
                        Text {
                            id: lname
                            width:  64
                            height: 28
                            text:   ["光晕(磁盘)","稀疏(CPU)","环(内存)","配对(GPU)","密集(网络)"][layerRow.li]
                            color:  "#ccc"
                            font.pixelSize: 20
                            verticalAlignment: Text.AlignVCenter
                            anchors.top: parent.top
                        }

                        // ── 双端色层 (all) ──────────────────
                        Row {
                            visible: true
                            spacing: 20
                            anchors.left: lname.right
                            anchors.leftMargin: 14
                            anchors.top: parent.top
                            anchors.topMargin: -4

                            // start colour (low)
                            Column {
                                spacing: 2
                                Text {
                                    text:   "起始 / 低"
                                    color:  "#888"
                                    font.pixelSize: 10
                                }
                                Row {
                                    spacing: 6
                                    Rectangle {
                                        width:  28; height: 28; radius: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        border { width: 1; color: "#555" }
                                        color: parseColor(
                                            li === 0 ? _c0s : li === 1 ? _c1s : li === 2 ? _c2s : li === 3 ? _c3s : _c4s)
                                    }
                                    QQC2.TextField {
                                        width:  110; height: 28
                                        text:   li === 0 ? _c0s : li === 1 ? _c1s : li === 2 ? _c2s : li === 3 ? _c3s : _c4s
                                        font { pixelSize: 15; family: "monospace" }
                                        color: "#ccc"
                                        background: Rectangle {
                                            color: "#2a2a2a"; radius: 3
                                            border { width: 1; color: "#555" }
                                        }
                                        verticalAlignment: TextInput.AlignVCenter
                                        horizontalAlignment: TextInput.AlignHCenter
                                        leftPadding:  6; rightPadding: 6
                                        validator: RegularExpressionValidator {
                                            regularExpression: /^#[0-9a-fA-F]{6}$/
                                        }
                                        onEditingFinished: {
                                            var t = text.trim();
                                            if (!t.match(/^#[0-9a-fA-F]{6}$/)) return;
                                            var key = "color" + layerRow.li + "Start";
                                            Plasmoid.configuration[key] = t;
                                            if (li === 0) _c0s = t;
                                            else if (li === 1) _c1s = t;
                                            else if (li === 2) _c2s = t;
                                            else if (li === 3) _c3s = t;
                                            else _c4s = t;
                                        }
                                        Keys.onReturnPressed:  focus = false
                                        Keys.onEnterPressed:   focus = false
                                    }
                                }
                            }

                            // end colour (high)
                            Column {
                                spacing: 2
                                Text {
                                    text:   "终止 / 高"
                                    color:  "#888"
                                    font.pixelSize: 10
                                }
                                Row {
                                    spacing: 6
                                    Rectangle {
                                        width:  28; height: 28; radius: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        border { width: 1; color: "#555" }
                                        color: parseColor(
                                            li === 0 ? _c0e : li === 1 ? _c1e : li === 2 ? _c2e : li === 3 ? _c3e : _c4e)
                                    }
                                    QQC2.TextField {
                                        width:  110; height: 28
                                        text:   li === 0 ? _c0e : li === 1 ? _c1e : li === 2 ? _c2e : li === 3 ? _c3e : _c4e
                                        font { pixelSize: 15; family: "monospace" }
                                        color: "#ccc"
                                        background: Rectangle {
                                            color: "#2a2a2a"; radius: 3
                                            border { width: 1; color: "#555" }
                                        }
                                        verticalAlignment: TextInput.AlignVCenter
                                        horizontalAlignment: TextInput.AlignHCenter
                                        leftPadding:  6; rightPadding: 6
                                        validator: RegularExpressionValidator {
                                            regularExpression: /^#[0-9a-fA-F]{6}$/
                                        }
                                        onEditingFinished: {
                                            var t = text.trim();
                                            if (!t.match(/^#[0-9a-fA-F]{6}$/)) return;
                                            var key = "color" + layerRow.li + "End";
                                            Plasmoid.configuration[key] = t;
                                            if (li === 0) _c0e = t;
                                            else if (li === 1) _c1e = t;
                                            else if (li === 2) _c2e = t;
                                            else if (li === 3) _c3e = t;
                                            else _c4e = t;
                                        }
                                        Keys.onReturnPressed:  focus = false
                                        Keys.onEnterPressed:   focus = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─── 2k. animation timer ────────────────────────────────
        // IL 的动画以 40 tick/s（游戏帧率）推进，这里同频驱动状态机与重绘。
        Timer {
            id: ft
            interval: 1000 / Halo.TICK_HZ
            repeat:   true
            running:  visible && halo !== null

            onTriggered: {
                if (!halo) return;
                halo.rotSpeed = modRotSpeed;   // 唯一需要写回状态机的调制量
                Halo.step(halo);
                cv.requestPaint();
            }
        }


        // ─── 2l. lifecycle ──────────────────────────────────────
        Component.onCompleted: {
            syncColors();
            halo = Halo.create();
            // 一次性连接系统数据轮询：7 个独立进程 → 1 个脚本一次读完 /proc
            // （纯本机、极快）；nvidia-smi 放最后并用 timeout 保护，防止挂起。
            sysMon.connectSource(""
                + "printf 'C '; ps -eo %cpu --no-headers 2>/dev/null | awk -v n=\"$(nproc)\" '{s+=$1} END{printf \"%.1f\\n\", s/n}' ; "
                + "printf 'M '; awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.4f\\n\", (t-a)/t}' /proc/meminfo; "
                + "printf 'L '; awk '{print $1}' /proc/loadavg; "
                + "printf 'T '; awk '{printf \"%d\\n\", $1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0; "
                + "printf 'N '; awk '/enp|wlp/{r+=$2;t+=$10} END{printf \"%d %d\\n\", r, t}' /proc/net/dev; "
                + "printf 'D '; awk '/sd[a-z] |nvme[0-9]n[0-9] /{r+=$6;w+=$10} END{printf \"%d %d\\n\", r, w}' /proc/diskstats; "
                + "if command -v nvidia-smi >/dev/null 2>&1; then "
                + "printf 'G '; timeout 2 nvidia-smi --query-gpu=memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk -F', *' '{gsub(/ /,\"\",$1); gsub(/ /,\"\",$2); gsub(/ /,\"\",$3); printf \"%s %s %s\\n\", $1, $2, $3}'; "
                + "fi"
                + "");
            cv.requestPaint();
        }

        Component.onDestruction: {
            // 停动画、断开全部轮询源，避免 Plasma engine 侧残留
            ft.running = false;
            var cs = sysMon.connectedSources;
            for (var i = 0; i < cs.length; i++)
                sysMon.disconnectSource(cs[i]);
        }

        onVisibleChanged: {
            if (visible && halo)
                cv.requestPaint();
        }
    }
}
