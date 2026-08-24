import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: ""
    modal: true
    anchors.centerIn: parent
    width: 440
    height: 340
    padding: 0

    property string targetTaskId: ""
    property string targetTaskTitle: ""
    property int targetPageCount: 0

    signal confirmed(string taskId)

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
            height: 54
            color: "#ffffff"
            radius: 16

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16

                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: "#fee2e2"
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: "🗑️"
                            font.pixelSize: 14
                            anchors.centerIn: parent
                        }
                    }

                    Text {
                        text: "删除任务确认"
                        font.bold: true
                        font.pixelSize: 15
                        color: "#991b1b"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    width: 30
                    height: 30
                    background: Rectangle {
                        color: parent.hovered ? "#f1f5f9" : "transparent"
                        radius: 15
                    }
                    contentItem: Text { text: "✕"; color: "#64748b"; font.pixelSize: 13; anchors.centerIn: parent }
                    onClicked: root.close()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#fecdd3"
            }
        }

        // Body
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            spacing: 12

            Text {
                text: `确定要删除任务「${root.targetTaskTitle}」吗？`
                font.bold: true
                font.pixelSize: 14
                color: "#0f172a"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            // Danger info callout card
            Rectangle {
                Layout.fillWidth: true
                height: infoCol.implicitHeight + 18
                color: "#fff1f2"
                border.color: "#fecdd3"
                radius: 8

                Column {
                    id: infoCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        text: "该操作将从本地永久清除："
                        font.bold: true
                        font.pixelSize: 11
                        color: "#be123c"
                    }
                    Text { text: `• 包含本任务的 ${root.targetPageCount} 张原始图片与预处理图`; font.pixelSize: 11; color: "#9f1239" }
                    Text { text: "• OCR 文本识别结果、笔迹坐标数据与校对内容"; font.pixelSize: 11; color: "#9f1239" }
                    Text { text: "• 本地 SQLite 数据库任务记录"; font.pixelSize: 11; color: "#9f1239" }
                }
            }

            Text {
                text: "⚠️ 此操作不可撤销，请谨慎操作。"
                font.pixelSize: 11
                color: "#e11d48"
            }
        }

        // Footer Action Buttons
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: "#ffffff"
            radius: 16

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: "#e2e8f0"
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Button {
                    height: 36
                    width: 80
                    background: Rectangle {
                        color: parent.hovered ? "#e2e8f0" : "#f1f5f9"
                        border.color: "#cbd5e1"
                        radius: 6
                    }
                    contentItem: Text {
                        text: "取消"
                        color: "#475569"
                        font.pixelSize: 12
                        font.bold: true
                        anchors.centerIn: parent
                    }
                    onClicked: root.close()
                }

                Button {
                    height: 36
                    width: 96
                    background: Rectangle {
                        color: parent.hovered ? "#be123c" : "#e11d48"
                        radius: 6
                    }
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "🗑️"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "永久删除"; color: "white"; font.bold: true; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    onClicked: {
                        root.confirmed(root.targetTaskId);
                        root.close();
                    }
                }
            }
        }
    }
}
