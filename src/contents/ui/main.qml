// ================================================================
// HALO — 液压联动光环 | KDE Plasma 5 Widget
// version v0.10
// ================================================================

import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0

// ================================================================
// 1. ROOT — Plasmoid shell
// ================================================================

Item {
    id: root
    width:  400
    height: 400

    Plasmoid.backgroundHints:        PlasmaCore.Types.NoBackground
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    // ============================================================
    // 2. fullRepresentation — main widget surface
    // ============================================================

    Plasmoid.fullRepresentation: Item {
        id: w
        anchors.fill: parent

        // ─── 2a. layout constants ───────────────────────────────
        readonly property real sf:        Math.min(width, height) / 400
        readonly property real gap:       3
        readonly property real minThick:  1.5
        readonly property real maxR:      195
        readonly property string version: "v0.10"

        // ─── 2b. per-layer animation config ─────────────────────
        readonly property var layerConf: [
            //   dashAngles (deg)                 flashMs  rotate  rotMs
            {  dashAngles: [],                        fMs: 3000,  rot: false, rotMs: 0 },
            {  dashAngles: [1.1, 18.9],               fMs: 5000,  rot: true,  rotMs: 23000 },
            {  dashAngles: [],                        fMs: 7000,  rot: false, rotMs: 0 },
            {  dashAngles: [1, 2.6, 1, 19.4],         fMs: 11000, rot: true,  rotMs: 29000 },
            {  dashAngles: [0.65, 4.35],              fMs: 13000, rot: true,  rotMs: 31000 },
        ]

        readonly property var layerPulse: [
            //   innerInterval  outerInterval  transitionDur
            {  iInt: 2200,  oInt: 3100,  tDur: 600 },
            {  iInt: 2800,  oInt: 3700,  tDur: 500 },
            {  iInt: 3400,  oInt: 4300,  tDur: 450 },
            {  iInt: 4100,  oInt: 5200,  tDur: 550 },
            {  iInt: 4800,  oInt: 6100,  tDur: 500 },
        ]

        readonly property var flickerKfs: [
            [ [0,0.4],[0.42,0.4],[0.43,0],[0.44,0.4],[0.45,0.1],[0.46,0.4],
              [0.78,0.4],[0.79,0],[0.80,0.4],[1,0.4] ],
            [ [0,0.8],[0.30,0.8],[0.31,0],[0.32,0.8],[0.33,0.1],[0.34,0.8],
              [0.65,0.8],[0.66,0],[0.67,0.8],[1,0.8] ],
            [ [0,0.6],[0.53,0.6],[0.54,0],[0.55,0.6],[0.89,0.6],[0.90,0.1],[0.91,0.6],[1,0.6] ],
            [ [0,0.8],[0.23,0.8],[0.24,0],[0.25,0.8],[0.26,0.1],[0.27,0.8],
              [0.61,0.8],[0.62,0],[0.63,0.8],[1,0.8] ],
            [ [0,0.8],[0.17,0.8],[0.18,0],[0.19,0.8],[0.47,0.8],[0.48,0.1],[0.49,0.8],
              [0.73,0.8],[0.74,0],[0.75,0.8],[1,0.8] ],
        ]

        readonly property var rotKfs: [
            [],
            [ [0,0],[0.10,0],[0.20,60],[0.30,60],

              [0.45,120],[0.60,120],[0.75,240],[0.90,240],[1,360] ],
            [],
            [ [0,0],[0.15,0],[0.25,-90],[0.40,-90],
              [0.55,-180],[0.70,-180],[0.85,-270],[0.95,-270],[1,-360] ],
            [ [0,0],[0.05,0],[0.15,45],[0.25,45],[0.35,90],[0.50,90],
              [0.65,180],[0.80,180],[0.90,270],[0.95,270],[1,360] ],
        ]

        readonly property var initBounds: [
            { i:20,  o:80  },
            { i:115, o:125 },
            { i:136, o:138 },
            { i:150, o:162 },
            { i:175, o:185 },
        ]
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

        // dual‑color (start / end) for data‑driven layers (CPU, Mem, Net)
        property string _c1s: "#2a6e7e"
        property string _c1e: "#c04040"
        property string _c2s: "#3a9a6a"
        property string _c2e: "#b058d0"
        property string _c4s: "#4a8a7a"
        property string _c4e: "#d0a050"

        function getColor(i) {
            if (i === 0) return _c0;
            if (i === 1) return lerpColor(_c1s, _c1e, cpuMix);
            if (i === 2) return lerpColor(_c2s, _c2e, memMix);
            if (i === 3) return _c3;
            if (i === 4) return lerpColor(_c4s, _c4e, netMix);
            return "#000000";
        }

        function syncColors() {
            var v;
            v = Plasmoid.configuration.color0; _c0 = (v && v.length) ? v : defaultColors[0];
            v = Plasmoid.configuration.color1; _c1 = (v && v.length) ? v : defaultColors[1];
            v = Plasmoid.configuration.color2; _c2 = (v && v.length) ? v : defaultColors[2];
            v = Plasmoid.configuration.color3; _c3 = (v && v.length) ? v : defaultColors[3];
            v = Plasmoid.configuration.color4; _c4 = (v && v.length) ? v : defaultColors[4];
            // dual‑color configs
            v = Plasmoid.configuration.color1Start; _c1s = (v && v.length) ? v : "#2a6e7e";
            v = Plasmoid.configuration.color1End;   _c1e = (v && v.length) ? v : "#c04040";
            v = Plasmoid.configuration.color2Start; _c2s = (v && v.length) ? v : "#3a9a6a";
            v = Plasmoid.configuration.color2End;   _c2e = (v && v.length) ? v : "#b058d0";
            v = Plasmoid.configuration.color4Start; _c4s = (v && v.length) ? v : "#4a8a7a";
            v = Plasmoid.configuration.color4End;   _c4e = (v && v.length) ? v : "#d0a050";
        }

        function setColor(i, hex) {
            if (i === 1 || i === 2 || i === 4) {
                // dual‑color layers: set both start and end to same hex
                Plasmoid.configuration["color" + i + "Start"] = hex;
                Plasmoid.configuration["color" + i + "End"]   = hex;
                if (i === 1) { _c1s = hex; _c1e = hex; }
                if (i === 2) { _c2s = hex; _c2e = hex; }
                if (i === 4) { _c4s = hex; _c4e = hex; }
            } else {
                Plasmoid.configuration["color" + i] = hex;
                if      (i === 0) _c0 = hex;
                else if (i === 3) _c3 = hex;
            }
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

            // Network layer (4)
            var maxNet = 5 * 1024 * 1024;  // 5 MB/s reference
            netMix    = Math.min(1, sysNetDown / maxNet);
            netPulse  = 0.5 + Math.min(1, sysNetUp / maxNet) * 2.5;
            var total = (sysNetDown + sysNetUp) / (maxNet * 2);
            netRotSpd = 0.5 + Math.min(1, total) * 2.5;

            // force UI refresh
            paintTick++;
            if (cv) cv.requestPaint();
        }

        // ─── 2d. animation state ────────────────────────────────
        property var  st:       []
        property var  t0:       0
        property bool stReady:  false

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

        // ─── 2f. animation math functions ───────────────────────

        /* cubic‑bezier solver (0,0)–(0.4,0.2)–(1,1) */
        function cb(t) {
            var bx = 0.4, by = 0.2, g = t;
            for (var i = 0; i < 8; i++) {
                var x  = 3*bx*g*(1-g)*(1-g) + 3*by*g*g*(1-g) + g*g*g - t;
                var dx = 3*bx*(1-g)*(1-g) - 6*bx*g*(1-g) + 3*by*g*(2-3*g) + 3*g*g;
                if (Math.abs(x) < 1e-6) break;
                g -= x / dx; g = Math.max(0, Math.min(1, g));
            }
            return 3*0*g*(1-g)*(1-g) + 3*1*g*g*(1-g) + g*g*g;
        }

        /* linear eval of keyframe table */
        function ev(k, p) {
            if (p <= k[0][0]) return k[0][1];
            if (p >= k[k.length-1][0]) return k[k.length-1][1];
            for (var i = 0; i < k.length-1; i++) {
                if (p >= k[i][0] && p < k[i+1][0]) {
                    var seg = (p - k[i][0]) / (k[i+1][0] - k[i][0]);
                    return k[i][1] + (k[i+1][1] - k[i][1]) * seg;
                }
            }
            return k[0][1];
        }

        /* bezier‑eased eval of rotation keyframes */
        function evr(k, p) {
            if (p <= k[0][0]) return k[0][1];
            if (p >= k[k.length-1][0]) return k[k.length-1][1];
            for (var i = 0; i < k.length-1; i++) {
                if (p >= k[i][0] && p < k[i+1][0]) {
                    var seg = (p - k[i][0]) / (k[i+1][0] - k[i][0]);
                    return k[i][1] + (k[i+1][1] - k[i][1]) * cb(seg);
                }
            }
            return k[0][1];
        }

        /* ease‑out cubic */
        function eoc(t) { return 1 - Math.pow(1 - t, 3); }

        /* next pulse time with jitter */
        function npt(a) { return a * (0.3 + Math.random() * 2.2); }

        /* update a single channel (inner/outer) */
        function uc(ch, now, li, ct) {
            if (now >= ch.np) {
                ch.f = ch.c;
                var b = [];
                for (var bi = 0; bi < st.length; bi++)
                    b.push({ i: st[bi].ii.c, o: st[bi].oo.c });

                var mn, mx;
                if (ct === 'i') {
                    mn = (li === 0) ? 0 : b[li-1].o + gap;
                    mx = Math.min(b[li].o - minThick,
                                  (li === 4) ? maxR - minThick
                                             : b[li+1].i - gap - minThick);
                } else {
                    mn = b[li].i + minThick;
                    mx = (li === 4) ? maxR : b[li+1].i - gap;
                }
                if (mn > mx) { ch.np = now + npt(ch.iv); return; }
                ch.t  = mn + Math.random() * (mx - mn);
                ch.st = now;
                ch.d  = ch.td * (0.6 + Math.random() * 0.8);
                // modulate pulse speed by system data (higher factor = faster = more agitated)
                if (li === 1) ch.d /= Math.max(0.3, w.cpuPulse);
                if (li === 4) ch.d /= Math.max(0.3, w.netPulse);
                ch.np = now + ch.d + npt(ch.iv);
            }
            if (now < ch.st + ch.d) {
                var pr = (now - ch.st) / ch.d;
                ch.c = ch.f + (ch.t - ch.f) * eoc(Math.min(pr, 1));
            } else {
                ch.c = ch.t;
            }
        }

        /* enforce boundary constraints (iterative) */
        function enf() {
            for (var it = 0; it < 3; it++) {
                for (var i = 0; i < st.length; i++) {
                    if (i === 0)
                        st[i].ii.c = Math.max(0, st[i].ii.c);
                    else
                        st[i].ii.c = Math.max(st[i-1].oo.c + gap, st[i].ii.c);

                    if (i === st.length-1)
                        st[i].oo.c = Math.min(maxR, st[i].oo.c);
                    else
                        st[i].oo.c = Math.min(st[i+1].ii.c - gap, st[i].oo.c);

                    if (st[i].oo.c < st[i].ii.c + minThick) {
                        if (i === st.length-1 ||
                            st[i].oo.c + minThick <= st[i+1].ii.c - gap)
                            st[i].oo.c = st[i].ii.c + minThick;
                        else
                            st[i].ii.c = st[i].oo.c - minThick;
                    }
                }
            }
        }

        /* initialise all channels */
        function initState() {
            var n = Date.now();
            t0 = n;
            var s = [];
            for (var i = 0; i < 5; i++) {
                var p = layerPulse[i];
                s.push({
                    ii: {
                        c:  initBounds[i].i, t: initBounds[i].i, f: initBounds[i].i,
                        st: 0, d: 600,
                        np: n + Math.random() * p.iInt,
                        iv: p.iInt, td: p.tDur
                    },
                    oo: {
                        c:  initBounds[i].o, t: initBounds[i].o, f: initBounds[i].o,
                        st: 0, d: 600,
                        np: n + Math.random() * p.oInt,
                        iv: p.oInt, td: p.tDur
                    },
                });
            }
            st = s;
            stReady = true;
        }

        /* manual arc drawer (bypass Qt arc() undersampling for small arcs) */
        function arcAt(ctx, cx, cy, r, sa, ea) {
            var span = ea - sa;
            var n = Math.max(4, Math.round(span * r * 0.5));
            var stp = span / n;
            for (var j = 0; j <= n; j++) {
                var a = sa + j * stp;
                if (j === 0)
                    ctx.moveTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
                else
                    ctx.lineTo(cx + r * Math.cos(a), cy + r * Math.sin(a));
            }
        }

        // ─── 2g. system monitor (executable engine) ──────────
        PlasmaCore.DataSource {
            id: sysMon
            engine: "executable"
            connectedSources: []

            onNewData: {
                var out = (data["stdout"] || "").trim();
                var src = sourceName;

                if (src.indexOf("#CPU") >= 0) {
                    w.sysCpu = Math.min(100, parseFloat(out) || 0);
                } else if (src.indexOf("#MEM") >= 0) {
                    w.sysMem = (parseFloat(out) || 0) * 100;
                } else if (src.indexOf("#LOAD") >= 0) {
                    w.sysLoad = parseFloat(out) || 0;
                } else if (src.indexOf("#TEMP") >= 0) {
                    var t = parseInt(out) / 1000;
                    w.sysTemp = isNaN(t) ? 40 : Math.max(20, Math.min(100, t));
                } else if (src.indexOf("#NET") >= 0) {
                    var parts = out.split(/\s+/);
                    if (parts.length >= 2) {
                        var now = Date.now();
                        var d = parseInt(parts[0]) || 0;
                        var u = parseInt(parts[1]) || 0;
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
                }
                // recompute modulation factors after any data update
                w.computeModulation();
            }
        }

        // ─── 2g2. data poll timer ──────────────────────────────
        Timer {
            id: pollTimer
            interval: 2000
            running: true
            repeat: true
            onTriggered: {
                var tok = "#R" + Math.random().toString(36).substr(2, 6);
                sysMon.connectSource(
                    "ps -eo %cpu --no-headers 2>/dev/null | awk -v n=\"$(nproc)\" '{s+=$1} END{printf \"%.1f\", s/n}' #CPU " + tok);
                sysMon.connectSource(
                    "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.4f\", (t-a)/t}' /proc/meminfo #MEM " + tok);
                sysMon.connectSource(
                    "awk '{print $1}' /proc/loadavg #LOAD " + tok);
                sysMon.connectSource(
                    "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0 #TEMP " + tok);
                sysMon.connectSource(
                    "awk '/enp|wlp/{r+=$2;t+=$10} END{printf \"%d %d\", r, t}' /proc/net/dev #NET " + tok);
            }
            onRunningChanged: { if (running) triggered(); }
        }

        // ─── 2h. Canvas renderer ────────────────────────────────
        Canvas {
            id: cv
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (!stReady || st.length === 0) return;

                var el   = Date.now() - t0;
                var s    = w.sf;
                var cx   = width  / 2;
                var cy   = height / 2;

                for (var i = 0; i < 5; i++) {
                    var ci = st[i].ii.c * s;
                    var co = st[i].oo.c * s;
                    var r  = (ci + co) / 2;
                    var sw = Math.max(co - ci, 0.1);

                    ctx.save();

                    // rotation transform (modulated by system data for layers 1,4)
                    if (layerConf[i].rot) {
                        var effMs = layerConf[i].rotMs;
                        if (i === 1) effMs = layerConf[1].rotMs / Math.max(0.05, w.cpuRotSpd);
                        if (i === 4) effMs = layerConf[4].rotMs / Math.max(0.05, w.netRotSpd);
                        var a = evr(rotKfs[i],
                                    (el % effMs) / effMs);
                        ctx.translate(cx, cy);
                        ctx.rotate(a * Math.PI / 180);
                        ctx.translate(-cx, -cy);
                    }

                    // colour & opacity
                    ctx.strokeStyle = parseColor(getColor(i));
                    ctx.lineWidth   = sw;
                    var alpha = ev(flickerKfs[i],
                                   (el % layerConf[i].fMs) / layerConf[i].fMs);
                    if (i === 2) alpha *= Math.min(1.5, Math.max(0.2, w.memBright));
                    ctx.globalAlpha = Math.min(1, Math.max(0, alpha));

                    // draw
                    var da = layerConf[i].dashAngles;
                    if (da.length > 0) {
                        var cycleTotal = 0;
                        for (var d = 0; d < da.length; d++) cycleTotal += da[d];
                        var numTeeth = Math.round(360 / cycleTotal);
                        ctx.beginPath();
                        for (var k = 0; k < numTeeth; k++) {
                            var ang = k * cycleTotal;
                            for (var seg = 0; seg < da.length; seg++) {
                                if (seg % 2 === 0) {
                                    var sr = ang * Math.PI / 180;
                                    var er = (ang + da[seg]) * Math.PI / 180;
                                    arcAt(ctx, cx, cy, r, sr, er);
                                }
                                ang += da[seg];
                            }
                        }
                    } else {
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                    }
                    ctx.stroke();
                    ctx.restore();
                }
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
                     + "\nT:" + w.sysTemp.toFixed(1) + "°C  ↓" + nDs + "  ↑" + nUs;
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
                        height: {
                            // single layers (0,3) need less space
                            return (li === 0 || li === 3) ? 44 : 68;
                        }
                        width: parent.width

                        // layer name
                        Text {
                            id: lname
                            width:  64
                            height: 28
                            text:   ["光晕","稀疏","环","配对","密集"][layerRow.li]
                            color:  "#ccc"
                            font.pixelSize: 20
                            verticalAlignment: Text.AlignVCenter
                            anchors.top: parent.top
                        }

                        // ── 单色层 (0, 3) ──────────────────
                        Row {
                            visible: li === 0 || li === 3
                            spacing: 10
                            anchors.left: lname.right
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width:  36; height: 36; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                border { width: 1; color: "#555" }
                                color: parseColor(getColor(layerRow.li))
                            }

                            QQC2.TextField {
                                width:  140; height: 36
                                text:   getColor(layerRow.li)
                                font { pixelSize: 18; family: "monospace" }
                                color: "#ccc"
                                background: Rectangle {
                                    color: "#2a2a2a"; radius: 3
                                    border { width: 1; color: "#555" }
                                }
                                verticalAlignment: TextInput.AlignVCenter
                                horizontalAlignment: TextInput.AlignHCenter
                                leftPadding:  8; rightPadding: 8
                                validator: RegExpValidator {
                                    regExp: /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/
                                }
                                onEditingFinished: {
                                    var t = text.trim();
                                    if (t.match(/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/))
                                        setColor(layerRow.li, t);
                                }
                                Keys.onReturnPressed:  focus = false
                                Keys.onEnterPressed:   focus = false
                            }
                        }

                        // ── 双端色层 (1, 2, 4) ──────────────
                        Row {
                            visible: li === 1 || li === 2 || li === 4
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
                                            li === 1 ? _c1s : li === 2 ? _c2s : _c4s)
                                    }
                                    QQC2.TextField {
                                        width:  110; height: 28
                                        text:   li === 1 ? _c1s : li === 2 ? _c2s : _c4s
                                        font { pixelSize: 15; family: "monospace" }
                                        color: "#ccc"
                                        background: Rectangle {
                                            color: "#2a2a2a"; radius: 3
                                            border { width: 1; color: "#555" }
                                        }
                                        verticalAlignment: TextInput.AlignVCenter
                                        horizontalAlignment: TextInput.AlignHCenter
                                        leftPadding:  6; rightPadding: 6
                                        validator: RegExpValidator {
                                            regExp: /^#[0-9a-fA-F]{6}$/
                                        }
                                        onEditingFinished: {
                                            var t = text.trim();
                                            if (!t.match(/^#[0-9a-fA-F]{6}$/)) return;
                                            var key = "color" + layerRow.li + "Start";
                                            Plasmoid.configuration[key] = t;
                                            if (li === 1) _c1s = t;
                                            else if (li === 2) _c2s = t;
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
                                            li === 1 ? _c1e : li === 2 ? _c2e : _c4e)
                                    }
                                    QQC2.TextField {
                                        width:  110; height: 28
                                        text:   li === 1 ? _c1e : li === 2 ? _c2e : _c4e
                                        font { pixelSize: 15; family: "monospace" }
                                        color: "#ccc"
                                        background: Rectangle {
                                            color: "#2a2a2a"; radius: 3
                                            border { width: 1; color: "#555" }
                                        }
                                        verticalAlignment: TextInput.AlignVCenter
                                        horizontalAlignment: TextInput.AlignHCenter
                                        leftPadding:  6; rightPadding: 6
                                        validator: RegExpValidator {
                                            regExp: /^#[0-9a-fA-F]{6}$/
                                        }
                                        onEditingFinished: {
                                            var t = text.trim();
                                            if (!t.match(/^#[0-9a-fA-F]{6}$/)) return;
                                            var key = "color" + layerRow.li + "End";
                                            Plasmoid.configuration[key] = t;
                                            if (li === 1) _c1e = t;
                                            else if (li === 2) _c2e = t;
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
        Timer {
            id: ft
            interval: 16
            repeat:   true
            running:  true

            onTriggered: {
                if (!stReady || st.length === 0) return;
                var now = Date.now();
                for (var i = 0; i < 5; i++) {
                    uc(st[i].ii, now, i, 'i');
                    uc(st[i].oo, now, i, 'o');
                }
                enf();
                cv.requestPaint();
            }
        }

        // ─── 2l. lifecycle ──────────────────────────────────────
        Component.onCompleted: {
            syncColors();
            initState();
            cv.requestPaint();
        }

        onVisibleChanged: {
            if (visible && stReady)
                cv.requestPaint();
        }
    }
}
