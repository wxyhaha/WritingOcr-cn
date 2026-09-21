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
    width: Math.min(440, Math.max(360, (parent ? parent.width : 440) - 32))
    height: Math.min(340, Math.max(300, (parent ? parent.height : 340) - 32))
    padding: 0

    property string targetTaskId: ""
    property string targetTaskTitle: ""
    property int targetPageCount: 0

    signal confirmed(string taskId)

    background: Rectangle {
        color: Theme.paper
        radius: 16
        border.color: Theme.border

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
            Layout.preferredHeight: 54
            color: Theme.paper
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
                        Icon {
                            name: "trash"
                            size: 18
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
                    id: closeConfirmButton
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    background: Rectangle {
                        color: closeConfirmButton.hovered ? Theme.surface : "transparent"
                        radius: 15
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
                color: Theme.ink
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            // Danger info callout card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: infoCol.implicitHeight + 18
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
                text: "此操作不可撤销，请谨慎操作。"
                font.pixelSize: 11
                color: "#e11d48"
            }
        }

        // Footer Action Buttons
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: Theme.paper
            radius: 16

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.border
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Button {
                    id: cancelConfirmButton
                    height: 36
                    width: 80
                    background: Rectangle {
                        color: cancelConfirmButton.hovered ? Theme.border : Theme.surface
                        border.color: Theme.border
                        radius: 6
                    }
                    contentItem: Text {
                        text: "取消"
                        color: Theme.secondary
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root.close()
                }

                Button {
                    id: deleteConfirmButton
                    height: 36
                    width: 96
                    background: Rectangle {
                        color: deleteConfirmButton.hovered ? "#be123c" : "#e11d48"
                        radius: 6
                    }
                    contentItem: Item {
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { name: "trash"; color: Theme.paper; size: 18; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "永久删除"; color: "white"; font.bold: true; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
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
