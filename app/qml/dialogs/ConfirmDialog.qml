import QtQuick
import QtQuick.Controls

Dialog {
    id: root
    title: "删除任务确认"
    modal: true
    anchors.centerIn: parent
    width: 380
    height: 280
    standardButtons: Dialog.Cancel

    property string targetTaskId: ""
    property string targetTaskTitle: ""
    property int targetPageCount: 0

    signal confirmed(string taskId)

    background: Rectangle {
        color: "#ffffff"
        radius: 12
        border.color: "#e2e8f0"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: `确定要删除任务「${root.targetTaskTitle}」吗？`
            font.bold: true
            font.pixelSize: 15
            color: "#0f172a"
        }

        Text {
            text: "将永久删除："
            font.pixelSize: 13
            color: "#475569"
        }

        Column {
            spacing: 4
            anchors.leftMargin: 8

            Text { text: `• ${root.targetPageCount} 张原始图片`; font.pixelSize: 12; color: "#64748b" }
            Text { text: `• ${root.targetPageCount} 张预处理图片`; font.pixelSize: 12; color: "#64748b" }
            Text { text: "• OCR 结构化识别数据"; font.pixelSize: 12; color: "#64748b" }
            Text { text: "• 人工校对与编辑结果"; font.pixelSize: 12; color: "#64748b" }
            Text { text: "• 数据库任务记录"; font.pixelSize: 12; color: "#64748b" }
        }

        Text {
            text: "此操作不可恢复。"
            font.bold: true
            font.pixelSize: 12
            color: "#dc2626"
        }
    }

    footer: DialogButtonBox {
        Button {
            text: "取消"
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
        Button {
            text: "永久删除"
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            background: Rectangle {
                color: "#dc2626"
                radius: 4
            }
            contentItem: Text {
                text: "永久删除"
                color: "white"
                font.bold: true
                font.pixelSize: 12
                anchors.centerIn: parent
            }
            onClicked: {
                root.confirmed(root.targetTaskId);
                root.close();
            }
        }
    }
}
