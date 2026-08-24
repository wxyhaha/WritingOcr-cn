import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: ""
    modal: true
    anchors.centerIn: parent
    width: 480
    height: 380
    padding: 0

    property string targetTaskId: ""

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
                    Text { text: "📥"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "导出校对文章"; font.bold: true; font.pixelSize: 16; color: "#0f172a" }
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
            spacing: 12

            Text {
                text: "选择导出格式 (将导出所有页面校对后的最终文本):"
                font.pixelSize: 13
                color: "#475569"
            }

            ButtonGroup { id: formatGroup }

            // Format Selection Cards
            Column {
                Layout.fillWidth: true
                spacing: 8

                // Option 1: DOCX
                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 8
                    color: docxRadio.checked ? "#eff6ff" : (docxMouseArea.containsMouse ? "#f8fafc" : "#ffffff")
                    border.color: docxRadio.checked ? "#3b82f6" : "#e2e8f0"
                    border.width: docxRadio.checked ? 1.5 : 1

                    MouseArea {
                        id: docxMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: docxRadio.checked = true
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        RadioButton {
                            id: docxRadio
                            checked: true
                            ButtonGroup.group: formatGroup
                        }

                        Text {
                            text: "Microsoft Word 文档 (.docx)"
                            font.bold: true
                            font.pixelSize: 13
                            color: "#1e293b"
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            height: 20
                            radius: 4
                            color: "#dbeafe"
                            width: recText.implicitWidth + 10
                            Text {
                                id: recText
                                text: "推荐"
                                font.pixelSize: 10
                                font.bold: true
                                color: "#1d4ed8"
                                anchors.centerIn: parent
                            }
                        }
                    }
                }

                // Option 2: Markdown
                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 8
                    color: mdRadio.checked ? "#eff6ff" : (mdMouseArea.containsMouse ? "#f8fafc" : "#ffffff")
                    border.color: mdRadio.checked ? "#3b82f6" : "#e2e8f0"
                    border.width: mdRadio.checked ? 1.5 : 1

                    MouseArea {
                        id: mdMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mdRadio.checked = true
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        RadioButton {
                            id: mdRadio
                            ButtonGroup.group: formatGroup
                        }

                        Text {
                            text: "Markdown 笔记文档 (.md)"
                            font.pixelSize: 13
                            color: "#1e293b"
                            Layout.fillWidth: true
                        }
                    }
                }

                // Option 3: Plain Text
                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 8
                    color: txtRadio.checked ? "#eff6ff" : (txtMouseArea.containsMouse ? "#f8fafc" : "#ffffff")
                    border.color: txtRadio.checked ? "#3b82f6" : "#e2e8f0"
                    border.width: txtRadio.checked ? 1.5 : 1

                    MouseArea {
                        id: txtMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: txtRadio.checked = true
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        RadioButton {
                            id: txtRadio
                            ButtonGroup.group: formatGroup
                        }

                        Text {
                            text: "纯文本文件 (.txt)"
                            font.pixelSize: 13
                            color: "#1e293b"
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Text {
                text: "导出的文件将自动保存至系统「文档 / HandwritingOCR」文件夹中。"
                font.pixelSize: 11
                color: "#64748b"
            }
        }

        // Footer
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
                    background: Rectangle {
                        color: parent.hovered ? "#e2e8f0" : "#f1f5f9"
                        border.color: "#cbd5e1"
                        radius: 6
                    }
                    contentItem: Text {
                        text: "取消"
                        color: "#475569"
                        font.pixelSize: 12
                        anchors.centerIn: parent
                    }
                    onClicked: root.close()
                }

                Button {
                    height: 36
                    background: Rectangle {
                        color: parent.hovered ? "#059669" : "#10b981"
                        radius: 6
                    }
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "📥"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "立即导出"; color: "white"; font.bold: true; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
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
    }
}
