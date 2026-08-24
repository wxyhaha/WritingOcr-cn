import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "手机局域网扫码上传"
    modal: true
    anchors.centerIn: parent
    width: 440
    height: 560
    standardButtons: Dialog.Close

    onOpened: {
        app.lanUploadService.refreshSessionToken();
    }

    background: Rectangle {
        color: "#ffffff"
        radius: 12
        border.color: "#e2e8f0"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        Text {
            text: "请确保手机与电脑连接在同一个 WiFi 局域网下"
            font.pixelSize: 13
            color: "#64748b"
            Layout.alignment: Qt.AlignHCenter
        }

        // QR Code Container
        Rectangle {
            Layout.preferredWidth: 240
            Layout.preferredHeight: 240
            color: "#ffffff"
            border.color: "#e2e8f0"
            radius: 8
            Layout.alignment: Qt.AlignHCenter

            Image {
                anchors.fill: parent
                anchors.margins: 10
                source: app.lanUploadService.qrCodeDataUrl
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        // IP Network Selector
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: app.lanUploadService.availableLanIps.length > 1

            Text {
                text: "局域网 IP:"
                font.pixelSize: 12
                color: "#475569"
            }

            ComboBox {
                Layout.fillWidth: true
                model: app.lanUploadService.availableLanIps
                currentIndex: Math.max(0, model.indexOf(app.lanUploadService.lanIp))
                onActivated: (index) => {
                    app.lanUploadService.setLanIp(model[index]);
                }
            }
        }

        // URL display and actions
        Rectangle {
            Layout.fillWidth: true
            height: 38
            color: "#f8fafc"
            border.color: "#e2e8f0"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 8

                Text {
                    text: app.lanUploadService.uploadUrl
                    font.pixelSize: 11
                    color: "#2563eb"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Button {
                    text: "复制链接"
                    height: 26
                    background: Rectangle {
                        color: "#e0e7ff"
                        radius: 4
                    }
                    contentItem: Text {
                        text: "复制"
                        font.pixelSize: 11
                        color: "#3730a3"
                        anchors.centerIn: parent
                    }
                    onClicked: {
                        app.copyToClipboard(app.lanUploadService.uploadUrl);
                    }
                }

                Button {
                    text: "刷新"
                    height: 26
                    background: Rectangle {
                        color: "#f1f5f9"
                        border.color: "#cbd5e1"
                        radius: 4
                    }
                    contentItem: Text {
                        text: "刷新"
                        font.pixelSize: 11
                        color: "#334155"
                        anchors.centerIn: parent
                    }
                    onClicked: app.lanUploadService.refreshSessionToken()
                }
            }
        }

        // Live Upload Status
        Rectangle {
            Layout.fillWidth: true
            height: 52
            color: app.lanUploadService.receivedImageCount > 0 ? "#f0fdf4" : "#f8fafc"
            border.color: app.lanUploadService.receivedImageCount > 0 ? "#bbf7d0" : "#e2e8f0"
            radius: 6

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Text {
                    text: app.lanUploadService.receivedImageCount > 0 ? "✅" : "📱"
                    font.pixelSize: 18
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: app.lanUploadService.receivedImageCount > 0 
                              ? `手机已成功上传 ${app.lanUploadService.receivedImageCount} 张照片！`
                              : "手机扫码后可直接拍照或在相册中多选批量上传"
                        font.bold: app.lanUploadService.receivedImageCount > 0
                        font.pixelSize: 12
                        color: app.lanUploadService.receivedImageCount > 0 ? "#166534" : "#475569"
                    }
                    Text {
                        text: "单次任务最多支持 10 张手写文章图片"
                        font.pixelSize: 10
                        color: "#94a3b8"
                    }
                }
            }
        }
    }
}
