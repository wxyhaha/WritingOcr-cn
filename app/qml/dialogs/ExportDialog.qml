import QtQuick
import QtQuick.Controls

Dialog {
    id: root
    title: "导出文章结果"
    modal: true
    anchors.centerIn: parent
    width: 440
    height: 320
    standardButtons: Dialog.Cancel

    property string targetTaskId: ""

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
            text: "选择导出文件格式 (将导出当前人工校对后的最终文本):"
            font.pixelSize: 13
            color: "#475569"
        }

        ButtonGroup { id: formatGroup }

        Column {
            spacing: 8

            RadioButton {
                id: docxRadio
                text: "Microsoft Word 文档 (.docx) — 推荐"
                checked: true
                ButtonGroup.group: formatGroup
            }

            RadioButton {
                id: mdRadio
                text: "Markdown 文档 (.md) — 适合笔记与排版"
                ButtonGroup.group: formatGroup
            }

            RadioButton {
                id: txtRadio
                text: "纯文本文件 (.txt) — 通用纯文本"
                ButtonGroup.group: formatGroup
            }
        }

        Text {
            text: "导出文件将保存在系统的「文档」文件夹中。"
            font.pixelSize: 12
            color: "#64748b"
        }
    }

    footer: DialogButtonBox {
        Button {
            text: "取消"
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
        Button {
            text: "确认导出"
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            background: Rectangle {
                color: "#2563eb"
                radius: 4
            }
            contentItem: Text {
                text: "确认导出"
                color: "white"
                font.bold: true
                font.pixelSize: 12
                anchors.centerIn: parent
            }
            onClicked: {
                let fmt = docxRadio.checked ? "docx" : (mdRadio.checked ? "md" : "txt");
                let defaultPath = app.exportService.getDefaultExportPath(fmt);
                if (root.targetTaskId) {
                    app.exportService.exportTaskById(root.targetTaskId, fmt, defaultPath);
                } else {
                    app.exportService.exportCurrentTask(fmt, defaultPath);
                }
                root.close();
            }
        }
    }
}
