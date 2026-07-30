import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0

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

    readonly property var isSingleLayer: [
        false,  // 0 — 光晕 (磁盘)
        false,  // 1 — 稀疏齿 (CPU)
        false,  // 2 — 环 (内存)
        false,  // 3 — 配对齿 (GPU)
    readonly property var defaultColors: [
        [ "#5a8a7a", "#c0a050" ],             // 层0 磁盘 (低→高)
        [ "#2a6e7e", "#c04040" ],             // 层1 CPU (低→高)
        [ "#3a9a6a", "#b058d0" ],             // 层2 内存 (低→高)
        [ "#6ab0c0", "#d05030" ],             // 层3 GPU (冷→热)
        [ "#4a8a7a", "#d0a050" ],             // 层4 网络 (低→高)
    ]
    ]

    // 默认色值（与 main.xml 中的 <default> 一致）
    readonly property var defaultColors: [
        [ "#8fb3a6" ],                        // 层0 单色
        [ "#2a6e7e", "#c04040" ],             // 层1 双端 (低→高)
        [ "#3a9a6a", "#b058d0" ],             // 层2 双端 (低→高)
        [ "#d6ece4" ],                        // 层3 单色
        [ "#4a8a7a", "#d0a050" ],             // 层4 双端 (低→高)
    ]

    // ── 读写配置 ────────────────────────────────────────────
    function getConfig(i, isStart) {
        if (isSingleLayer[i]) {
            var v = Plasmoid.configuration["color" + i];
            return (v && v.length > 0) ? v : defaultColors[i][0];
        } else {
            var key = "color" + i + (isStart ? "Start" : "End");
            var v = Plasmoid.configuration[key];
            return (v && v.length > 0) ? v : defaultColors[i][isStart ? 0 : 1];
        }
    }

    function setConfig(i, isStart, hex) {
        if (isSingleLayer[i]) {
            Plasmoid.configuration["color" + i] = hex;
        } else {
            var key = "color" + i + (isStart ? "Start" : "End");
            Plasmoid.configuration[key] = hex;
        }
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
                spacing: 10
                Layout.fillWidth: true

                // ── 层名标签 ────────────────────────────────
                QQC2.Label {
                    text: layerNames[index]
                    Layout.minimumWidth: 160
                    Layout.maximumWidth: 160
                    color: "#ddd"
                    verticalAlignment: Text.AlignVCenter
                }

                // ════════════════════════════════════════════
                //  单色层 (层 0, 层 3)
                // ════════════════════════════════════════════
                RowLayout {
                    id: singleBlock
                    visible: isSingleLayer[index]
                    spacing: 8

                    Rectangle {
                        id: swatchSingle
                        width: 36; height: 24
                        radius: 4
                        border.width: 1
                        border.color: "#666"
                        color: getConfig(index, true)
                    }

                    QQC2.TextField {
                        id: hexSingle
                        text: getConfig(index, true)
                        font.family: "monospace"
                        Layout.preferredWidth: 110
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

                // ── 单色层：重置按钮 ───────────────────────
                QQC2.Button {
                    id: resetSingle
                    visible: isSingleLayer[index]
                    text: "重置"
                    onClicked: {
                        Plasmoid.configuration["color" + index] = "";
                        hexSingle.text = defaultColors[index][0];
                    }
                }

                // ════════════════════════════════════════════
                //  双端色层 (层 1, 2, 4)
                // ════════════════════════════════════════════
                RowLayout {
                    id: dualBlock
                    visible: !isSingleLayer[index]
                    spacing: 16

                    // ── 起始色 / 低 ──────────────────────────
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
                                id: swatchDualStart
                                width: 36; height: 24
                                radius: 4
                                border.width: 1
                                border.color: "#666"
                Connections {
                    target: Plasmoid.configuration

                    function onColor0StartChanged() {
                        if (index === 0) swatchDualStart.color = getConfig(0, true);
                    }
                    function onColor0EndChanged() {
                        if (index === 0) swatchDualEnd.color = getConfig(0, false);
                    }
                    function onColor1StartChanged() {
                        if (index === 1) swatchDualStart.color = getConfig(1, true);
                    }
                    function onColor1EndChanged() {
                        if (index === 1) swatchDualEnd.color = getConfig(1, false);
                    }
                    function onColor2StartChanged() {
                        if (index === 2) swatchDualStart.color = getConfig(2, true);
                    }
                    function onColor2EndChanged() {
                        if (index === 2) swatchDualEnd.color = getConfig(2, false);
                    }
                    function onColor3StartChanged() {
                        if (index === 3) swatchDualStart.color = getConfig(3, true);
                    }
                    function onColor3EndChanged() {
                        if (index === 3) swatchDualEnd.color = getConfig(3, false);
                    }
                    function onColor4StartChanged() {
                        if (index === 4) swatchDualStart.color = getConfig(4, true);
                    }
                    function onColor4EndChanged() {
                        if (index === 4) swatchDualEnd.color = getConfig(4, false);
                    }
                }
                        QQC2.Label {
                            text: "终止色 / 高"
                            color: "#aaa"
                            font.pixelSize: 10
                        }

                        RowLayout {
                            spacing: 4

                            Rectangle {
                                id: swatchDualEnd
                                width: 36; height: 24
                                radius: 4
                                border.width: 1
                                border.color: "#666"
                                color: getConfig(index, false)
                            }

                            QQC2.TextField {
                                id: hexDualEnd
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

                    // ── 双端层：重置按钮 ────────────────────
                    QQC2.Button {
                        text: "重置"
                        onClicked: {
                            Plasmoid.configuration["color" + index + "Start"] = "";
                            Plasmoid.configuration["color" + index + "End"] = "";
                            hexDualStart.text = defaultColors[index][0];
                            hexDualEnd.text = defaultColors[index][1];
                        }
                    }
                }

                // ════════════════════════════════════════════
                //  Swatch 颜色联动：配置变更时实时刷新色块
                // ════════════════════════════════════════════
                Connections {
                    target: Plasmoid.configuration

                    function onColor0Changed() {
                        if (index === 0) swatchSingle.color = getConfig(0, true);
                    }
                    function onColor1StartChanged() {
                        if (index === 1) swatchDualStart.color = getConfig(1, true);
                    }
                    function onColor1EndChanged() {
                        if (index === 1) swatchDualEnd.color = getConfig(1, false);
                    }
                    function onColor2StartChanged() {
                        if (index === 2) swatchDualStart.color = getConfig(2, true);
                    }
                    function onColor2EndChanged() {
                        if (index === 2) swatchDualEnd.color = getConfig(2, false);
                    }
                    function onColor3Changed() {
                        if (index === 3) swatchSingle.color = getConfig(3, true);
                    }
                    function onColor4StartChanged() {
                        if (index === 4) swatchDualStart.color = getConfig(4, true);
                    }
                    function onColor4EndChanged() {
                        if (index === 4) swatchDualEnd.color = getConfig(4, false);
                    }
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
