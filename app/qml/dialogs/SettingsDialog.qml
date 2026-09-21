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
    width: Math.min(520, Math.max(400, (parent ? parent.width : 520) - 32))
    height: Math.min(560, Math.max(480, (parent ? parent.height : 560) - 32))
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
            Layout.preferredHeight: 56
            color: Theme.paper
            radius: 16

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16

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
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    background: Rectangle {
                        color: closeSettingsButton.hovered ? Theme.surface : "transparent"
                        radius: 16
                    }
                    contentItem: Icon { name: "close"; color: Theme.secondary; size: 18; anchors.centerIn: parent }
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
                width: parent.width - 40
                x: 20
                topPadding: 16
                bottomPadding: 16
                spacing: 20

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
                        height: ocrSettingCol.implicitHeight + 24
                        radius: 10
                        color: Theme.background
                        border.color: Theme.border

                        Column {
                            id: ocrSettingCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14

                            // Engine
                            RowLayout {
                                width: parent.width
                                Text { text: "识别引擎:"; font.pixelSize: 13; color: Theme.secondary; Layout.preferredWidth: 120 }
                                ComboBox {
                                    model: ["PaddleOCR (PP-OCRv5 本地引擎)"]
                                    currentIndex: 0
                                    Layout.fillWidth: true
                                }
                            }

                            // Low confidence threshold
                            RowLayout {
                                width: parent.width
                                Text {
                                    text: `低置信度阈值 (${(thresholdSlider.value * 100).toFixed(0)}%):`
                                    font.pixelSize: 13
                                    color: Theme.secondary
                                    Layout.preferredWidth: 130
                                }
                                Slider {
                                    id: thresholdSlider
                                    from: 0.50
                                    to: 0.95
                                    stepSize: 0.01
                                    value: root.appController.settingsService.lowConfidenceThreshold
                                    Layout.fillWidth: true
                                    onMoved: {
                                        root.appController.settingsService.lowConfidenceThreshold = value;
                                    }
                                }
                            }

                            // Filter printed text switch
                            RowLayout {
                                width: parent.width
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "过滤印刷体/相机水印:"; font.pixelSize: 13; color: Theme.secondary; font.bold: true }
                                    Text { text: "基于像素形态学自动剔除印刷行头与拍照水印"; font.pixelSize: 11; color: Theme.secondary }
                                }
                                Switch {
                                    checked: root.appController.settingsService.filterPrintedText
                                    onToggled: {
                                        root.appController.settingsService.filterPrintedText = checked;
                                        root.appController.taskService.applyFilterPrintedToAllPages(checked);
                                    }
                                }
                            }

                            // Image enhance switch
                            RowLayout {
                                width: parent.width
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "图像适度对比度增强:"; font.pixelSize: 13; color: Theme.secondary }
                                    Text { text: "导入时自动拉伸直方图改善淡色墨水对比度"; font.pixelSize: 11; color: Theme.secondary }
                                }
                                Switch {
                                    checked: root.appController.settingsService.autoEnhance
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
                        height: netSettingCol.implicitHeight + 24
                        radius: 10
                        color: Theme.background
                        border.color: Theme.border

                        Column {
                            id: netSettingCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            RowLayout {
                                width: parent.width
                                Text { text: "OCR 服务端地址:"; font.pixelSize: 13; color: Theme.secondary; Layout.preferredWidth: 120 }
                                TextField {
                                    id: workerUrlField
                                    text: root.appController.settingsService.ocrWorkerUrl
                                    Layout.fillWidth: true
                                    onEditingFinished: root.appController.settingsService.ocrWorkerUrl = text
                                }
                                Button {
                                    id: checkWorkerButton
                                    text: "检测"
                                    Layout.preferredHeight: 34
                                    background: Rectangle { color: checkWorkerButton.hovered ? Theme.border : Theme.surface; border.color: Theme.border; radius: 6 }
                                    onClicked: root.appController.ocrService.checkWorkerHealth()
                                }
                            }

                            // Status badge
                            Rectangle {
                                width: parent.width
                                height: 32
                                color: root.appController.ocrService.isWorkerRunning ? Theme.accentSoft : "#fff7ed"
                                radius: 6
                                border.color: root.appController.ocrService.isWorkerRunning ? Theme.accentBorder : "#fed7aa"

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Icon {
                                        name: root.appController.ocrService.isWorkerRunning ? "check" : "warning"
                                        color: root.appController.ocrService.isWorkerRunning ? Theme.accent : "#f97316"
                                        size: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.appController.ocrService.workerStatusMessage || "本地 PaddleOCR 服务状态"
                                        color: root.appController.ocrService.isWorkerRunning ? Theme.accent : "#c2410c"
                                        font.pixelSize: 11
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
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
            Layout.preferredHeight: 54
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
                text: "完成"
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                height: 34
                width: 90
                background: Rectangle {
                    color: finishSettingsButton.hovered ? Theme.accentHover : Theme.accent
                    radius: 6
                }
                contentItem: Text {
                    text: "完成"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 13
                    anchors.centerIn: parent
                }
                onClicked: root.close()
            }
        }
    }
}
