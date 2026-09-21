import QtQuick
import "../components"
import "../components/Theme.js" as Theme
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: ""
    modal: true
    anchors.centerIn: parent
    width: Math.min(560, Math.max(440, (parent ? parent.width : 560) - 40))
    height: Math.min(600, Math.max(520, (parent ? parent.height : 600) - 48))
    padding: 0

    property var appController

    background: Rectangle {
        color: Theme.paper
        radius: 16
        border.color: Theme.border

        // Modal shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            color: "transparent"
            border.color: "#1e293b14"
            radius: 20
            z: -1
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: Theme.paper
            radius: 16

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 20

                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter
                    Icon { name: "settings"; size: 18; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        spacing: 2
                        Text { text: "应用设置"; font.bold: true; font.pixelSize: 16; color: Theme.ink }
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    id: closeSettingsButton
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    background: Rectangle {
                        color: closeSettingsButton.hovered ? Theme.surface : "transparent"
                        radius: 16
                    }
                    contentItem: Item {
                        Icon { name: "close"; color: Theme.secondary; size: 18; anchors.centerIn: parent }
                    }
                    onClicked: root.close()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.border
            }
        }

        // Content Body
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                width: parent.width - 48
                x: 24
                topPadding: 20
                bottomPadding: 20
                spacing: 22

                // Section 1: OCR Settings
                Column {
                    width: parent.width
                    spacing: 12

                    Row {
                        spacing: 6
                        Icon { name: "search"; size: 18 }
                        Text { text: "OCR 识别与模型设置"; font.bold: true; font.pixelSize: 13; color: Theme.ink }
                    }

                    Rectangle {
                        width: parent.width
                        height: ocrSettingCol.implicitHeight + 32
                        radius: 10
                        color: Theme.background
                        border.color: Theme.border

                        Column {
                            id: ocrSettingCol
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            // Engine
                            RowLayout {
                                width: parent.width
                                Layout.preferredHeight: 36
                                Text {
                                    text: "识别引擎"
                                    font.pixelSize: 13
                                    color: Theme.secondary
                                    Layout.preferredWidth: 128
                                }
                                SelectField {
                                    model: ["PaddleOCR (PP-OCRv5 本地引擎)"]
                                    currentIndex: 0
                                    Layout.fillWidth: true
                                }
                            }

                            // Low confidence threshold
                            RowLayout {
                                width: parent.width
                                Layout.preferredHeight: 34
                                Text {
                                    text: `低置信度阈值 · ${(thresholdSlider.value * 100).toFixed(0)}%`
                                    font.pixelSize: 13
                                    color: Theme.secondary
                                    Layout.preferredWidth: 128
                                    elide: Text.ElideRight
                                }
                                Slider {
                                    id: thresholdSlider
                                    from: 0.50
                                    to: 0.95
                                    stepSize: 0.01
                                    value: root.appController.settingsService.lowConfidenceThreshold
                                    Layout.fillWidth: true
                                    padding: 0
                                    background: Rectangle {
                                        x: thresholdSlider.leftPadding
                                        y: thresholdSlider.topPadding + thresholdSlider.availableHeight / 2 - height / 2
                                        width: thresholdSlider.availableWidth
                                        height: 4
                                        radius: 2
                                        color: Theme.border

                                        Rectangle {
                                            width: thresholdSlider.visualPosition * parent.width
                                            height: parent.height
                                            radius: 2
                                            color: Theme.accent
                                        }
                                    }
                                    handle: Rectangle {
                                        x: thresholdSlider.leftPadding
                                           + thresholdSlider.visualPosition * (thresholdSlider.availableWidth - width)
                                        y: thresholdSlider.topPadding + thresholdSlider.availableHeight / 2 - height / 2
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: Theme.paper
                                        border.width: 2
                                        border.color: thresholdSlider.pressed ? Theme.accentHover : Theme.accent
                                    }
                                    onMoved: {
                                        root.appController.settingsService.lowConfidenceThreshold = value;
                                    }
                                }
                            }

                            // Filter printed text switch
                            RowLayout {
                                width: parent.width
                                Layout.preferredHeight: 44
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "过滤印刷体 / 相机水印"; font.pixelSize: 13; color: Theme.ink; font.bold: true }
                                    Text { text: "基于像素形态学自动剔除印刷行头与拍照水印"; font.pixelSize: 11; color: Theme.secondary }
                                }
                                Switch {
                                    id: filterPrintedSwitch
                                    checked: root.appController.settingsService.filterPrintedText
                                    implicitWidth: 42
                                    implicitHeight: 24
                                    padding: 0
                                    indicator: Rectangle {
                                        width: 42
                                        height: 24
                                        radius: 12
                                        color: filterPrintedSwitch.checked ? Theme.accent : Theme.border
                                        border.color: filterPrintedSwitch.checked ? Theme.accent : Theme.muted

                                        Rectangle {
                                            x: filterPrintedSwitch.checked ? parent.width - width - 3 : 3
                                            y: 3
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: Theme.paper
                                            Behavior on x { NumberAnimation { duration: 140 } }
                                        }
                                    }
                                    onToggled: {
                                        root.appController.settingsService.filterPrintedText = checked;
                                        root.appController.taskService.applyFilterPrintedToAllPages(checked);
                                    }
                                }
                            }

                            // Image enhance switch
                            RowLayout {
                                width: parent.width
                                Layout.preferredHeight: 44
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "图像适度对比度增强"; font.pixelSize: 13; color: Theme.ink; font.bold: true }
                                    Text { text: "导入时自动拉伸直方图改善淡色墨水对比度"; font.pixelSize: 11; color: Theme.secondary }
                                }
                                Switch {
                                    id: autoEnhanceSwitch
                                    checked: root.appController.settingsService.autoEnhance
                                    implicitWidth: 42
                                    implicitHeight: 24
                                    padding: 0
                                    indicator: Rectangle {
                                        width: 42
                                        height: 24
                                        radius: 12
                                        color: autoEnhanceSwitch.checked ? Theme.accent : Theme.border
                                        border.color: autoEnhanceSwitch.checked ? Theme.accent : Theme.muted

                                        Rectangle {
                                            x: autoEnhanceSwitch.checked ? parent.width - width - 3 : 3
                                            y: 3
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: Theme.paper
                                            Behavior on x { NumberAnimation { duration: 140 } }
                                        }
                                    }
                                    onToggled: root.appController.settingsService.autoEnhance = checked
                                }
                            }
                        }
                    }
                }

                // Section 2: Worker Connection
                Column {
                    width: parent.width
                    spacing: 12

                    Row {
                        spacing: 6
                        Icon { name: "network"; size: 18 }
                        Text { text: "本地服务与网络配置"; font.bold: true; font.pixelSize: 13; color: Theme.ink }
                    }

                    Rectangle {
                        width: parent.width
                        height: netSettingCol.implicitHeight + 32
                        radius: 10
                        color: Theme.background
                        border.color: Theme.border

                        Column {
                            id: netSettingCol
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            RowLayout {
                                width: parent.width
                                Layout.preferredHeight: 36
                                Text {
                                    text: "OCR 服务端地址"
                                    font.pixelSize: 13
                                    color: Theme.secondary
                                    Layout.preferredWidth: 118
                                }
                                TextField {
                                    id: workerUrlField
                                    text: root.appController.settingsService.ocrWorkerUrl
                                    font.pixelSize: 13
                                    color: Theme.ink
                                    selectByMouse: true
                                    leftPadding: 10
                                    rightPadding: 10
                                    Layout.fillWidth: true
                                    background: Rectangle {
                                        radius: 7
                                        color: workerUrlField.activeFocus ? Theme.paper : Theme.surface
                                        border.width: workerUrlField.activeFocus ? 2 : 1
                                        border.color: workerUrlField.activeFocus ? Theme.accent : Theme.border
                                    }
                                    onEditingFinished: root.appController.settingsService.ocrWorkerUrl = text
                                }
                                Button {
                                    id: checkWorkerButton
                                    text: "检测"
                                    Layout.preferredWidth: 54
                                    Layout.preferredHeight: 36
                                    padding: 0
                                    background: Rectangle {
                                        color: checkWorkerButton.down || checkWorkerButton.hovered ? Theme.accentSoft : Theme.paper
                                        border.color: Theme.border
                                        radius: 7
                                    }
                                    contentItem: Text {
                                        text: checkWorkerButton.text
                                        color: Theme.accentHover
                                        font.pixelSize: 12
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: root.appController.ocrService.checkWorkerHealth()
                                }
                            }

                            // Status badge
                            Rectangle {
                                width: parent.width
                                height: 36
                                color: root.appController.ocrService.isWorkerRunning ? Theme.accentSoft : "#fff7ed"
                                radius: 6
                                border.color: root.appController.ocrService.isWorkerRunning ? Theme.accentBorder : "#fed7aa"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 6
                                    Icon {
                                        name: root.appController.ocrService.isWorkerRunning ? "check" : "warning"
                                        color: root.appController.ocrService.isWorkerRunning ? Theme.accent : "#f97316"
                                        size: 20
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Text {
                                        text: root.appController.ocrService.workerStatusMessage || "本地 PaddleOCR 服务状态"
                                        color: root.appController.ocrService.isWorkerRunning ? Theme.accent : "#c2410c"
                                        font.pixelSize: 11
                                        font.bold: true
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Footer
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: Theme.paper
            radius: 16

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.border
            }

            Button {
                id: finishSettingsButton
                objectName: "finishSettingsButton"
                text: "完成"
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                height: 36
                width: 96
                background: Rectangle {
                    color: finishSettingsButton.hovered ? Theme.accentHover : Theme.accent
                    radius: 6
                }
                contentItem: Text {
                    text: "完成"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.close()
            }
        }
    }
}
