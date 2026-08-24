import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: ""
    modal: true
    anchors.centerIn: parent
    width: 520
    height: 560
    padding: 0

    background: Rectangle {
        color: "#ffffff"
        radius: 16
        border.color: "#e2e8f0"

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
            height: 56
            color: "#ffffff"
            radius: 16

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16

                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter
                    Text { text: "⚙️"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        spacing: 2
                        Text { text: "应用设置"; font.bold: true; font.pixelSize: 16; color: "#0f172a" }
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    width: 32
                    height: 32
                    background: Rectangle {
                        color: parent.hovered ? "#f1f5f9" : "transparent"
                        radius: 16
                    }
                    contentItem: Text { text: "✕"; color: "#64748b"; font.pixelSize: 14; anchors.centerIn: parent }
                    onClicked: root.close()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#e2e8f0"
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
                        Text { text: "🔍"; font.pixelSize: 13 }
                        Text { text: "OCR 识别与模型设置"; font.bold: true; font.pixelSize: 13; color: "#1e293b" }
                    }

                    Rectangle {
                        width: parent.width
                        height: ocrSettingCol.implicitHeight + 24
                        radius: 10
                        color: "#f8fafc"
                        border.color: "#e2e8f0"

                        Column {
                            id: ocrSettingCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14

                            // Engine
                            RowLayout {
                                width: parent.width
                                Text { text: "识别引擎:"; font.pixelSize: 13; color: "#475569"; Layout.preferredWidth: 120 }
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
                                    color: "#475569"
                                    Layout.preferredWidth: 130
                                }
                                Slider {
                                    id: thresholdSlider
                                    from: 0.50
                                    to: 0.95
                                    stepSize: 0.01
                                    value: app.settingsService.lowConfidenceThreshold
                                    Layout.fillWidth: true
                                    onMoved: {
                                        app.settingsService.lowConfidenceThreshold = value;
                                    }
                                }
                            }

                            // Filter printed text switch
                            RowLayout {
                                width: parent.width
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "过滤印刷体/相机水印:"; font.pixelSize: 13; color: "#334155"; font.bold: true }
                                    Text { text: "基于像素形态学自动剔除印刷行头与拍照水印"; font.pixelSize: 11; color: "#64748b" }
                                }
                                Switch {
                                    checked: app.settingsService.filterPrintedText
                                    onToggled: {
                                        app.settingsService.filterPrintedText = checked;
                                        app.taskService.applyFilterPrintedToAllPages(checked);
                                    }
                                }
                            }

                            // Image enhance switch
                            RowLayout {
                                width: parent.width
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "图像适度对比度增强:"; font.pixelSize: 13; color: "#334155" }
                                    Text { text: "导入时自动拉伸直方图改善淡色墨水对比度"; font.pixelSize: 11; color: "#64748b" }
                                }
                                Switch {
                                    checked: app.settingsService.autoEnhance
                                    onToggled: app.settingsService.autoEnhance = checked
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
                        Text { text: "🌐"; font.pixelSize: 13 }
                        Text { text: "本地服务与网络配置"; font.bold: true; font.pixelSize: 13; color: "#1e293b" }
                    }

                    Rectangle {
                        width: parent.width
                        height: netSettingCol.implicitHeight + 24
                        radius: 10
                        color: "#f8fafc"
                        border.color: "#e2e8f0"

                        Column {
                            id: netSettingCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            RowLayout {
                                width: parent.width
                                Text { text: "OCR 服务端地址:"; font.pixelSize: 13; color: "#475569"; Layout.preferredWidth: 120 }
                                TextField {
                                    id: workerUrlField
                                    text: app.settingsService.ocrWorkerUrl
                                    Layout.fillWidth: true
                                    onEditingFinished: app.settingsService.ocrWorkerUrl = text
                                }
                                Button {
                                    text: "检测"
                                    Layout.preferredHeight: 34
                                    background: Rectangle { color: parent.hovered ? "#e2e8f0" : "#f1f5f9"; border.color: "#cbd5e1"; radius: 6 }
                                    onClicked: app.ocrService.checkWorkerHealth()
                                }
                            }

                            // Status badge
                            Rectangle {
                                width: parent.width
                                height: 32
                                color: app.ocrService.isWorkerRunning ? "#ecfdf5" : "#fff7ed"
                                radius: 6
                                border.color: app.ocrService.isWorkerRunning ? "#a7f3d0" : "#fed7aa"

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: app.ocrService.isWorkerRunning ? "●" : "○"
                                        color: app.ocrService.isWorkerRunning ? "#10b981" : "#f97316"
                                        font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: app.ocrService.workerStatusMessage || "本地 PaddleOCR 服务状态"
                                        color: app.ocrService.isWorkerRunning ? "#047857" : "#c2410c"
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
            height: 54
            color: "#ffffff"
            radius: 16

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: "#e2e8f0"
            }

            Button {
                text: "完成"
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                height: 34
                width: 90
                background: Rectangle {
                    color: parent.hovered ? "#1d4ed8" : "#2563eb"
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
