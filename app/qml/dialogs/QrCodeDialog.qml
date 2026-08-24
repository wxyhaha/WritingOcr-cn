import QtQuick
import QtQuick.Controls

Dialog {
    id: root
    title: "手机局域网扫码上传"
    modal: true
    anchors.centerIn: parent
    width: 420
    height: 520
    standardButtons: Dialog.Close

    background: Rectangle {
        color: "#ffffff"
        radius: 12
        border.color: "#e2e8f0"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Text {
            text: "使用手机相机或浏览器扫描下方二维码"
            font.pixelSize: 14
            color: "#475569"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            width: 260
            height: 260
            color: "#ffffff"
            border.color: "#e2e8f0"
            radius: 8
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                anchors.fill: parent
                anchors.margins: 12
                source: app.lanUploadService.qrCodeDataUrl
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        // URL display and refresh button
        Row {
            spacing: 8
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text: app.lanUploadService.uploadUrl
                font.pixelSize: 12
                color: "#2563eb"
                anchors.verticalCenter: parent.verticalCenter
            }

            Button {
                text: "刷新二维码"
                height: 28
                background: Rectangle {
                    color: "#f1f5f9"
                    border.color: "#cbd5e1"
                    radius: 4
                }
                contentItem: Text {
                    text: "刷新二维码"
                    font.pixelSize: 11
                    color: "#334155"
                    anchors.centerIn: parent
                }
                onClicked: app.lanUploadService.refreshSessionToken()
            }
        }

        // Live Upload Status
        Rectangle {
            width: parent.width - 20
            height: 48
            radius: 6
            color: app.lanUploadService.receivedImageCount > 0 ? "#ecfdf5" : "#f8fafc"
            border.color: app.lanUploadService.receivedImageCount > 0 ? "#a7f3d0" : "#e2e8f0"
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: app.lanUploadService.receivedImageCount > 0
                          ? `✓ 已收到 ${app.lanUploadService.receivedImageCount} 张图片，已自动加入当前任务`
                          : "等待手机端上传图片 (1~10张)..."
                    font.pixelSize: 12
                    font.bold: app.lanUploadService.receivedImageCount > 0
                    color: app.lanUploadService.receivedImageCount > 0 ? "#059669" : "#64748b"
                }
            }
        }
    }
}
