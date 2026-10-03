// ================================================================
// HALO — 配置页 (5 层光环调色)
// Plasma 6 / Qt6
// ================================================================

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid

Item {
    id: configRoot

    // ── 层信息 ──────────────────────────────────────────────
    readonly property var layerNames: [
        "光环 0 — 光晕 (磁盘)",
        "光环 1 — 稀疏齿 (CPU)",
        "光环 2 — 环 (内存)",
        "光环 3 — 配对齿 (GPU)",
        "光环 4 — 密集齿 (网络)",
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

        // ── 底部信息 ────────────────────────────────────────
        Item { height: 8 }

        QQC2.Label {
            text: "输入 #rrggbb 格式颜色，修改即时生效"
            color: "#888"
            font.pixelSize: 11
        }
    }
}
