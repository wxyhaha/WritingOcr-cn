import QtQuick
import QtQuick.Controls

Dialog {
    id: root
    title: "应用设置"
    modal: true
    anchors.centerIn: parent
    width: 480
    height: 480
    standardButtons: Dialog.Close

    background: Rectangle {
        color: "#ffffff"
        radius: 12
        border.color: "#e2e8f0"
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 16
        clip: true

        Column {
            width: parent.width
            spacing: 16

            // Section 1: OCR Settings
            Text { text: "OCR 识别设置"; font.bold: true; font.pixelSize: 14; color: "#0f172a" }

            Row {
                width: parent.width
                spacing: 12
                Text { text: "识别引擎:"; font.pixelSize: 13; color: "#475569"; width: 110; anchors.verticalCenter: parent.verticalCenter }
                ComboBox {
                    model: ["PaddleOCR (PP-OCRv5 本地引擎)"]
                    currentIndex: 0
                    width: 260
                }
            }

            Row {
                width: parent.width
                spacing: 12
                Text {
                    text: `低置信度阈值 (${(thresholdSlider.value * 100).toFixed(0)}%):`
                    font.pixelSize: 13
                    color: "#475569"
                    width: 140
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    id: thresholdSlider
                    from: 0.50
                    to: 0.95
                    stepSize: 0.01
                    value: app.settingsService.lowConfidenceThreshold
                    width: 220
                    onMoved: {
                        app.settingsService.lowConfidenceThreshold = value;
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 12
                Text { text: "图像适度增强:"; font.pixelSize: 13; color: "#475569"; width: 110; anchors.verticalCenter: parent.verticalCenter }
                Switch {
                    checked: app.settingsService.autoEnhance
                    onToggled: app.settingsService.autoEnhance = checked
                }
            }

            Row {
                width: parent.width
                spacing: 12
                Text { text: "过滤印刷体/水印:"; font.pixelSize: 13; color: "#475569"; width: 110; anchors.verticalCenter: parent.verticalCenter }
                Switch {
                    checked: app.settingsService.filterPrintedText
                    onToggled: app.settingsService.filterPrintedText = checked
                }
                Text {
                    text: "(自动过滤笔记本印刷行头与相机水印)"
                    font.pixelSize: 11
                    color: "#94a3b8"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                width: parent.width
                spacing: 12
                Text { text: "OCR 服务端地址:"; font.pixelSize: 13; color: "#475569"; width: 110; anchors.verticalCenter: parent.verticalCenter }
                TextField {
                    id: workerUrlField
                    text: app.settingsService.ocrWorkerUrl
                    width: 180
                    onEditingFinished: app.settingsService.ocrWorkerUrl = text
                }
                Button {
                    text: "检测"
                    height: 36
                    onClicked: app.ocrService.checkWorkerHealth()
                }
            }

            Rectangle {
                width: parent.width
                height: 36
                color: app.ocrService.isWorkerRunning ? "#ecfdf5" : "#fff7ed"
                radius: 6
                border.color: app.ocrService.isWorkerRunning ? "#a7f3d0" : "#fed7aa"

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: app.ocrService.isWorkerRunning
                              ? `● ${app.ocrService.workerStatusMessage}`
                              : `○ ${app.ocrService.workerStatusMessage}`
                        color: app.ocrService.isWorkerRunning ? "#059669" : "#c2410c"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#e2e8f0" }

            // Section 2: LAN Upload
            Text { text: "局域网扫码上传设置"; font.bold: true; font.pixelSize: 14; color: "#0f172a" }

            Row {
                width: parent.width
                spacing: 12
                Text { text: "启用局域网上传:"; font.pixelSize: 13; color: "#475569"; width: 110; anchors.verticalCenter: parent.verticalCenter }
                Switch {
                    checked: app.settingsService.lanUploadEnabled
                    onToggled: {
                        app.settingsService.lanUploadEnabled = checked;
                        if (checked) app.lanUploadService.startServer(app.settingsService.lanUploadPort);
                        else app.lanUploadService.stopServer();
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 12
                Text { text: "上传监听端口:"; font.pixelSize: 13; color: "#475569"; width: 110; anchors.verticalCenter: parent.verticalCenter }
                TextField {
                    text: `${app.settingsService.lanUploadPort}`
                    width: 100
                    validator: IntValidator { bottom: 1025; top: 65535 }
                    onEditingFinished: {
                        app.settingsService.lanUploadPort = parseInt(text);
                        app.lanUploadService.startServer(parseInt(text));
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#e2e8f0" }

            // Section 3: Storage
            Text { text: "存储设置"; font.bold: true; font.pixelSize: 14; color: "#0f172a" }

            Column {
                width: parent.width
                spacing: 6
                Text { text: "数据保存根目录:"; font.pixelSize: 12; color: "#64748b" }
                Text {
                    text: app.settingsService.storageDir
                    font.pixelSize: 12
                    color: "#0f172a"
                    wrapMode: Text.WrapAnywhere
                    width: parent.width
                }
                Button {
                    text: "打开存储文件夹"
                    onClicked: app.openFolder(app.settingsService.storageDir)
                }
            }
        }
    }
}
