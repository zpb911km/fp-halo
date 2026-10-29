// ================================================================
// HALO — 配置页（5 个径向元素调色 + 数据映射说明）
// Plasma 6 / Qt6
// ================================================================

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid

Item {
    id: configRoot
    implicitWidth:  620
    implicitHeight: layoutRoot.implicitHeight + layoutRoot.anchors.margins * 2

    // ── 层信息 ──────────────────────────────────────────────
    // 颜色槽 → 径向元素（Halo #2139 的 5 个同心结构）。
    // 槽位编号是历史配置键（colorNStart/End），顺序不代表由内到外。
    readonly property var layerNames: [
        "内齿环 ×10 — 磁盘 I/O",
        "环 0 — CPU",
        "环 1 — 内存",
        "中齿环 ×30 — GPU 显存",
        "外齿环 ×60 — 网络吞吐",
    ]

    // ── 数据映射说明（与 docs/HALO_2139_SPEC.md §10.3 同步）────
    readonly property var mapRows: [
        { slot: "整体尺寸",   data: "CPU 占用",  look: "越忙光环越大（80% → 100% 内接圆）" },
        { slot: "环 1 粗细",  data: "内存占用",  look: "3px 细环 → 逐渐加粗为厚环" },
        { slot: "环 0 实心",  data: "温度",      look: "≥70°C 起渐入，90°C 整盘填成实心墨" },
        { slot: "内齿环 齿长", data: "磁盘 I/O",  look: "吞吐越高，10 个齿越长" },
        { slot: "中齿环 齿长", data: "GPU 显存",  look: "显存越高，30 个齿越长" },
        { slot: "外齿环 齿长", data: "网络吞吐",  look: "带宽越高，60 个齿越长、越易连成毛刷" },
        { slot: "旋转急促度", data: "平均负载",  look: "负载越高，抽搐式旋转越快" },
    ]

    // 默认色值（与 main.xml 中的 <default> 一致）：[起始/低, 终止/高]
    readonly property var defaultColors: [
        [ "#5a8a7a", "#c0a050" ],   // 层0 磁盘 (低→高)
        [ "#2a6e7e", "#c04040" ],   // 层1 CPU (低→高)
        [ "#3a9a6a", "#b058d0" ],   // 层2 内存 (低→高)
        [ "#6ab0c0", "#d05030" ],   // 层3 GPU (冷→热)
        [ "#4a8a7a", "#d0a050" ],   // 层4 网络 (低→高)
    ]

    // ── 读写配置 ────────────────────────────────────────────
    function keyFor(i, isStart) {
        return "color" + i + (isStart ? "Start" : "End");
    }

    function getConfig(i, isStart) {
        var v = Plasmoid.configuration[keyFor(i, isStart)];
        return (v && v.length > 0) ? v : defaultColors[i][isStart ? 0 : 1];
    }

    function setConfig(i, isStart, hex) {
        Plasmoid.configuration[keyFor(i, isStart)] = hex;
    }

    // ── UI ──────────────────────────────────────────────────
    ColumnLayout {
        id: layoutRoot
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Repeater {
            model: 5

            delegate: RowLayout {
                id: rowDelegate
                spacing: 12
                Layout.fillWidth: true

                // ── 层名标签 ────────────────────────────────
                QQC2.Label {
                    text: layerNames[index]
                    Layout.minimumWidth: 160
                    Layout.maximumWidth: 160
                    color: "#ddd"
                    verticalAlignment: Text.AlignVCenter
                }

                // ── 起始色 / 低 ─────────────────────────────
                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignBottom

                    QQC2.Label {
                        text: "起始色 / 低"
                        color: "#aaa"
                        font.pixelSize: 10
                    }

                    RowLayout {
                        spacing: 4

                        Rectangle {
                            id: swatchStart
                            width: 36; height: 24
                            radius: 4
                            border.width: 1
                            border.color: "#666"
                            color: getConfig(index, true)
                        }

                        QQC2.TextField {
                            id: hexStart
                            text: getConfig(index, true)
                            font.family: "monospace"
                            Layout.preferredWidth: 100
                            selectByMouse: true
                            validator: RegularExpressionValidator {
                                regularExpression: /^#[0-9a-fA-F]{6}$/
                            }
                            onTextChanged: {
                                var t = text.trim();
                                if (t.match(/^#[0-9a-fA-F]{6}$/)) {
                                    setConfig(index, true, t);
                                }
                            }
                        }
                    }
                }

                // ── 终止色 / 高 ─────────────────────────────
                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignBottom

                    QQC2.Label {
                        text: "终止色 / 高"
                        color: "#aaa"
                        font.pixelSize: 10
                    }

                    RowLayout {
                        spacing: 4

                        Rectangle {
                            id: swatchEnd
                            width: 36; height: 24
                            radius: 4
                            border.width: 1
                            border.color: "#666"
                            color: getConfig(index, false)
                        }

                        QQC2.TextField {
                            id: hexEnd
                            text: getConfig(index, false)
                            font.family: "monospace"
                            Layout.preferredWidth: 100
                            selectByMouse: true
                            validator: RegularExpressionValidator {
                                regularExpression: /^#[0-9a-fA-F]{6}$/
                            }
                            onTextChanged: {
                                var t = text.trim();
                                if (t.match(/^#[0-9a-fA-F]{6}$/)) {
                                    setConfig(index, false, t);
                                }
                            }
                        }
                    }
                }

                // ── 重置按钮 ────────────────────────────────
                QQC2.Button {
                    text: "重置"
                    Layout.alignment: Qt.AlignBottom
                    onClicked: {
                        Plasmoid.configuration[keyFor(index, true)] = "";
                        Plasmoid.configuration[keyFor(index, false)] = "";
                        hexStart.text = defaultColors[index][0];
                        hexEnd.text = defaultColors[index][1];
                    }
                }

                // ── Swatch 颜色联动：配置变更时实时刷新色块 ──
                Connections {
                    target: Plasmoid.configuration

                    function onColor0StartChanged() { if (index === 0) swatchStart.color = getConfig(0, true); }
                    function onColor0EndChanged()   { if (index === 0) swatchEnd.color   = getConfig(0, false); }
                    function onColor1StartChanged() { if (index === 1) swatchStart.color = getConfig(1, true); }
                    function onColor1EndChanged()   { if (index === 1) swatchEnd.color   = getConfig(1, false); }
                    function onColor2StartChanged() { if (index === 2) swatchStart.color = getConfig(2, true); }
                    function onColor2EndChanged()   { if (index === 2) swatchEnd.color   = getConfig(2, false); }
                    function onColor3StartChanged() { if (index === 3) swatchStart.color = getConfig(3, true); }
                    function onColor3EndChanged()   { if (index === 3) swatchEnd.color   = getConfig(3, false); }
                    function onColor4StartChanged() { if (index === 4) swatchStart.color = getConfig(4, true); }
                    function onColor4EndChanged()   { if (index === 4) swatchEnd.color   = getConfig(4, false); }
                }
            }
        }

        // ── 数据映射说明 ────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 6
            implicitHeight: mapCol.implicitHeight + 24
            radius: 6
            color: Qt.rgba(1, 1, 1, 0.05)
            border { width: 1; color: Qt.rgba(1, 1, 1, 0.10) }

            ColumnLayout {
                id: mapCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 5

                QQC2.Label {
                    text: "数据映射规则"
                    color: "#cfd8dd"
                    font.pixelSize: 12
                    font.bold: true
                    Layout.bottomMargin: 2
                }
                QQC2.Label {
                    text: "每个物理量占用一个原版光环本来就有的视觉自由度，不额外添加几何。"
                    color: "#8b9aa3"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // 表头
                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    QQC2.Label {
                        text: "视觉槽位"; color: "#6f7d86"; font.pixelSize: 10
                        Layout.minimumWidth: 108; Layout.maximumWidth: 108
                    }
                    QQC2.Label {
                        text: "物理量"; color: "#6f7d86"; font.pixelSize: 10
                        Layout.minimumWidth: 84; Layout.maximumWidth: 84
                    }
                    QQC2.Label {
                        text: "观感"; color: "#6f7d86"; font.pixelSize: 10
                        Layout.fillWidth: true
                    }
                }

                Repeater {
                    model: mapRows
                    delegate: RowLayout {
                        spacing: 10
                        Layout.fillWidth: true
                        QQC2.Label {
                            text: modelData.slot
                            color: "#c4d2da"; font.pixelSize: 11
                            font.family: "monospace"
                            Layout.minimumWidth: 108; Layout.maximumWidth: 108
                        }
                        QQC2.Label {
                            text: modelData.data
                            color: "#a8bcc7"; font.pixelSize: 11
                            Layout.minimumWidth: 84; Layout.maximumWidth: 84
                        }
                        QQC2.Label {
                            text: modelData.look
                            color: "#8695a0"; font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // ── 缩放说明 ────────────────────────────────────────
        QQC2.Label {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: "缩放：光环常态外沿（含最外圈齿）内接于组件矩形，随组件尺寸等比缩放，"
                + "不是固定像素。数据调制只会让它变小，不会顶出边界。"
            color: "#7d8a93"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        // ── 底部信息 ────────────────────────────────────────
        Item { height: 8 }

        QQC2.Label {
            text: "输入 #rrggbb 格式颜色，修改即时生效"
            color: "#888"
            font.pixelSize: 11
        }
    }
}
