import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0

Item {
    id: configRoot

    readonly property var layerNames: [
        "光环 0 — 光晕",
        "光环 1 — 稀疏齿",
        "光环 2 — 环",
        "光环 3 — 配对齿",
        "光环 4 — 密集齿",
    ]

    readonly property var defaultColors: [
        "#8fb3a6", "#cfe7df", "#bfe0d6", "#d6ece4", "#c4e0d8"
    ]

    function getConfig(i) {
        var v = Plasmoid.configuration["color" + i];
        return (v && v.length > 0) ? v : defaultColors[i];
    }

    function setConfig(i, hex) {
        Plasmoid.configuration["color" + i] = hex;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Repeater {
            model: 5

            delegate: RowLayout {
                spacing: 10
                Layout.fillWidth: true

                QQC2.Label {
                    text: layerNames[index]
                    Layout.minimumWidth: 140
                    color: "#ddd"
                }

                Rectangle {
                    id: swatch
                    width: 36; height: 24
                    radius: 4
                    border.width: 1
                    border.color: "#666"
                    color: getConfig(index)

                    Connections {
                        target: Plasmoid.configuration
                        function onColor0Changed() { if(index===0) swatch.color = getConfig(0); }
                        function onColor1Changed() { if(index===1) swatch.color = getConfig(1); }
                        function onColor2Changed() { if(index===2) swatch.color = getConfig(2); }
                        function onColor3Changed() { if(index===3) swatch.color = getConfig(3); }
                        function onColor4Changed() { if(index===4) swatch.color = getConfig(4); }
                    }
                }

                QQC2.TextField {
                    id: hexField
                    text: getConfig(index)
                    font.family: "monospace"
                    Layout.preferredWidth: 110
                    selectByMouse: true
                    validator: RegularExpressionValidator { regularExpression: /^#[0-9a-fA-F]{6}$/ }
                    onTextChanged: {
                        var t = text.trim();
                        if (t.match(/^#[0-9a-fA-F]{6}$/)) {
                            setConfig(index, t);
                        }
                    }
                }

                QQC2.Button {
                    text: "重置"
                    onClicked: {
                        Plasmoid.configuration["color" + index] = "";
                        hexField.text = defaultColors[index];
                    }
                }
            }
        }

        Item { height: 8 }

        QQC2.Label {
            text: "输入 #rrggbb 格式颜色，回车即时生效"
            color: "#888"
            font.pixelSize: 11
        }
    }
}
