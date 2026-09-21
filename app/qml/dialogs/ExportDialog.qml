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
    width: Math.min(480, Math.max(380, (parent ? parent.width : 480) - 32))
    height: Math.min(380, Math.max(340, (parent ? parent.height : 380) - 32))
    padding: 0

    property string targetTaskId: ""
    property var appController

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
            Layout.preferredHeight: 56
            color: Theme.paper
            radius: 16

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16

                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter
                    Icon { name: "download"; size: 18; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "导出校对文章"; font.bold: true; font.pixelSize: 16; color: Theme.ink }
                }

                Item { Layout.fillWidth: true }

                Button {
                    id: closeExportButton
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    background: Rectangle {
                        color: closeExportButton.hovered ? Theme.surface : "transparent"
                        radius: 16
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
                color: Theme.border
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
                color: Theme.secondary
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
                    color: docxRadio.checked ? Theme.accentSoft : (docxMouseArea.containsMouse ? Theme.background : Theme.paper)
                    border.color: docxRadio.checked ? Theme.accent : Theme.border
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
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            padding: 0
                            indicator: Item {
                                width: 20
                                height: 20
                                implicitWidth: 20
                                implicitHeight: 20
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: docxRadio.visualFocus ? Theme.accentHover : docxRadio.checked ? Theme.accent : Theme.border
                                }
                                Rectangle {
                                    visible: docxRadio.checked
                                    anchors.centerIn: parent
                                    width: 9
                                    height: 9
                                    radius: width / 2
                                    color: Theme.accent
                                }
                            }
                            contentItem: Item {}
                        }

                        Text {
                            text: "Microsoft Word 文档 (.docx)"
                            font.bold: true
                            font.pixelSize: 13
                            color: Theme.ink
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredHeight: 20
                            radius: 4
                            color: Theme.accentSoft
                            Layout.preferredWidth: recText.implicitWidth + 10
                            Text {
                                id: recText
                                text: "推荐"
                                font.pixelSize: 10
                                font.bold: true
                                color: Theme.accentHover
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
                    color: mdRadio.checked ? Theme.accentSoft : (mdMouseArea.containsMouse ? Theme.background : Theme.paper)
                    border.color: mdRadio.checked ? Theme.accent : Theme.border
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
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            padding: 0
                            indicator: Item {
                                width: 20
                                height: 20
                                implicitWidth: 20
                                implicitHeight: 20
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: mdRadio.visualFocus ? Theme.accentHover : mdRadio.checked ? Theme.accent : Theme.border
                                }
                                Rectangle {
                                    visible: mdRadio.checked
                                    anchors.centerIn: parent
                                    width: 9
                                    height: 9
                                    radius: width / 2
                                    color: Theme.accent
                                }
                            }
                            contentItem: Item {}
                        }

                        Text {
                            text: "Markdown 笔记文档 (.md)"
                            font.pixelSize: 13
                            color: Theme.ink
                            Layout.fillWidth: true
                        }
                    }
                }

                // Option 3: Plain Text
                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 8
                    color: txtRadio.checked ? Theme.accentSoft : (txtMouseArea.containsMouse ? Theme.background : Theme.paper)
                    border.color: txtRadio.checked ? Theme.accent : Theme.border
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
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            padding: 0
                            indicator: Item {
                                width: 20
                                height: 20
                                implicitWidth: 20
                                implicitHeight: 20
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: txtRadio.visualFocus ? Theme.accentHover : txtRadio.checked ? Theme.accent : Theme.border
                                }
                                Rectangle {
                                    visible: txtRadio.checked
                                    anchors.centerIn: parent
                                    width: 9
                                    height: 9
                                    radius: width / 2
                                    color: Theme.accent
                                }
                            }
                            contentItem: Item {}
                        }

                        Text {
                            text: "纯文本文件 (.txt)"
                            font.pixelSize: 13
                            color: Theme.ink
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Text {
                text: "导出的文件将自动保存至系统「文档 / HandwritingOCR」文件夹中。"
                font.pixelSize: 11
                color: Theme.secondary
            }
        }

        // Footer
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
                    id: cancelExportButton
                    height: 36
                    background: Rectangle {
                        color: cancelExportButton.hovered ? Theme.border : Theme.surface
                        border.color: Theme.border
                        radius: 6
                    }
                    contentItem: Text {
                        text: "取消"
                        color: Theme.secondary
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root.close()
                }

                Button {
                    id: confirmExportButton
                    height: 36
                    background: Rectangle {
                        color: confirmExportButton.hovered ? Theme.accentHover : Theme.accent
                        radius: 6
                    }
                    contentItem: Item {
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { name: "download"; color: Theme.paper; size: 18; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "立即导出"; color: "white"; font.bold: true; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    onClicked: {
                        let fmt = docxRadio.checked ? "docx" : (mdRadio.checked ? "md" : "txt");
                        let defaultPath = root.appController.exportService.getDefaultExportPath(fmt);
                        let exported = false;
                        if (root.targetTaskId) {
                            exported = root.appController.exportService.exportTaskById(root.targetTaskId, fmt, defaultPath);
                        } else {
                            exported = root.appController.exportService.exportCurrentTask(fmt, defaultPath);
                        }
                        if (exported) {
                            root.close();
                        }
                    }
                }
            }
        }
    }
}
