import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: ""
    modal: true
    anchors.centerIn: parent
    width: 460
    height: 570
    padding: 0

    onOpened: {
        app.lanUploadService.refreshSessionToken();
    }

    background: Rectangle {
        color: "#ffffff"
        radius: 16
        border.color: "#e2e8f0"

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
                    Text { text: "📱"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "手机局域网扫码上传"; font.bold: true; font.pixelSize: 16; color: "#0f172a" }
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

        // Body
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            spacing: 14

            Text {
                text: "请确保手机与电脑连接在同一个 WiFi 局域网下"
                font.pixelSize: 13
                color: "#64748b"
                Layout.alignment: Qt.AlignHCenter
            }

            // QR Code Container Card
            Rectangle {
                Layout.preferredWidth: 230
                Layout.preferredHeight: 230
                color: "#ffffff"
                border.color: "#e2e8f0"
                radius: 12
                Layout.alignment: Qt.AlignHCenter

                Image {
                    anchors.fill: parent
                    anchors.margins: 12
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
                height: 40
                color: "#f8fafc"
                border.color: "#e2e8f0"
                radius: 8

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: app.lanUploadService.uploadUrl
                        font.pixelSize: 11
                        color: "#2563eb"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Button {
                        height: 28
                        background: Rectangle {
                            color: parent.hovered ? "#dbeafe" : "#eff6ff"
                            border.color: "#bfdbfe"
                            radius: 6
                        }
                        contentItem: Text {
                            text: "复制链接"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#1d4ed8"
                            anchors.centerIn: parent
                        }
                        onClicked: {
                            app.copyToClipboard(app.lanUploadService.uploadUrl);
                        }
                    }

                    Button {
                        height: 28
                        background: Rectangle {
                            color: parent.hovered ? "#e2e8f0" : "#f1f5f9"
                            border.color: "#cbd5e1"
                            radius: 6
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
                height: 56
                color: app.lanUploadService.receivedImageCount > 0 ? "#f0fdf4" : "#f8fafc"
                border.color: app.lanUploadService.receivedImageCount > 0 ? "#bbf7d0" : "#e2e8f0"
                radius: 8

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Text {
                        text: app.lanUploadService.receivedImageCount > 0 ? "✅" : "📱"
                        font.pixelSize: 20
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
                            color: app.lanUploadService.receivedImageCount > 0 ? "#15803d" : "#334155"
                        }
                        Text {
                            text: "单次任务最多支持 10 张手写文章图片"
                            font.pixelSize: 11
                            color: "#64748b"
                        }
                    }
                }
            }
        }

        // Footer
        Rectangle {
            Layout.fillWidth: true
            height: 52
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
                text: "关闭"
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                height: 34
                width: 80
                background: Rectangle {
                    color: parent.hovered ? "#e2e8f0" : "#f1f5f9"
                    border.color: "#cbd5e1"
                    radius: 6
                }
                contentItem: Text {
                    text: "关闭"
                    color: "#334155"
                    font.bold: true
                    font.pixelSize: 12
                    anchors.centerIn: parent
                }
                onClicked: root.close()
            }
        }
    }
}
