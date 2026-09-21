import QtQuick
import "Theme.js" as Theme
import QtQuick.Controls
import QtQuick.Layouts

pragma ComponentBehavior: Bound

Item {
    id: root

    property var pageModel: null
    property var appController
    property int currentIndex: 0
    readonly property int maxPageCount: 10
    readonly property bool canAddPages: appController && appController.taskService
                                          ? appController.taskService.currentTaskPageCount < maxPageCount
                                          : false

    signal pageSelected(int index)
    signal pageDeleted(int index)
    signal addPagesRequested()

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        border.color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Sidebar Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: Theme.paper
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: 8

                Row {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: "页面"
                        font.bold: true
                        font.pixelSize: 13
                        color: Theme.ink
                    }

                    Rectangle {
                        height: 18
                        radius: 9
                        color: Theme.surface
                        width: countText.implicitWidth + 10
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: countText
                            text: `${root.appController.taskService.currentTaskPageCount}`
                            font.pixelSize: 10
                            font.bold: true
                            color: Theme.secondary
                            anchors.centerIn: parent
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    id: addPagesButton
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    enabled: root.canAddPages
                    background: Rectangle {
                        color: !addPagesButton.enabled ? Theme.background : (addPagesButton.hovered ? Theme.border : Theme.surface)
                        border.color: !addPagesButton.enabled ? Theme.border : Theme.border
                        radius: 6
                    }
                    contentItem: Text {
                        text: addPagesButton.enabled ? "加页" : "已达 10 页"
                        color: addPagesButton.enabled ? Theme.secondary : Theme.muted
                        font.pixelSize: 11
                        font.bold: true
                        anchors.centerIn: parent
                    }
                    onClicked: root.addPagesRequested()
                    ToolTip.visible: hovered && !enabled
                    ToolTip.text: "单个任务最多包含 10 张图片"
                    ToolTip.delay: 300
                }
            }
        }

        // Thumbnails ListView
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 10
            topMargin: 12
            bottomMargin: 12
            model: root.pageModel

            delegate: Item {
                id: pageDelegate
                required property var model
                required property int index
                width: listView.width - 24
                height: 148
                x: 12

                property bool isCurrent: pageDelegate.index === root.currentIndex

                Rectangle {
                    id: cardBg
                    anchors.fill: parent
                    radius: 10
                    color: pageDelegate.isCurrent ? Theme.paper : (thumbMouseArea.containsMouse ? Theme.paper : Theme.background)
                    border.width: pageDelegate.isCurrent ? 2 : 1
                    border.color: pageDelegate.isCurrent ? Theme.accent : (thumbMouseArea.containsMouse ? Theme.accentBorder : Theme.border)

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    // Active left indicator bar
                    Rectangle {
                        visible: pageDelegate.isCurrent
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 4
                        width: 3
                        radius: 1.5
                        color: Theme.accent
                    }

                    MouseArea {
                        id: thumbMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pageSelected(pageDelegate.index)
                    }

                    Image {
                        id: thumbImage
                        anchors.fill: parent
                        anchors.margins: 6
                        anchors.leftMargin: pageDelegate.isCurrent ? 10 : 6
                        source: (pageDelegate.model.thumbnailPath && pageDelegate.model.thumbnailPath !== "") ? root.appController.localFileToUrl(pageDelegate.model.thumbnailPath) : (pageDelegate.model.originalImagePath ? root.appController.localFileToUrl(pageDelegate.model.originalImagePath) : "")
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                    }

                    // Page Index Floating Badge
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 6
                        anchors.leftMargin: pageDelegate.isCurrent ? 10 : 6
                        width: 24
                        height: 20
                        radius: 5
                        color: pageDelegate.isCurrent ? Theme.accent : Theme.secondary

                        Text {
                            anchors.centerIn: parent
                            text: `${pageDelegate.index + 1}`
                            color: "white"
                            font.bold: true
                            font.pixelSize: 11
                        }
                    }

                    // Low Confidence Badge
                    Rectangle {
                        visible: pageDelegate.model.lowConfidenceCount > 0
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        height: 18
                        radius: 9
                        color: Theme.warning
                        width: badgeText.implicitWidth + 10

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: `${pageDelegate.model.lowConfidenceCount}`
                            color: Theme.paper
                            font.bold: true
                            font.pixelSize: 10
                        }
                    }

                    // Page reorder controls
                    Row {
                        visible: thumbMouseArea.containsMouse || moveUpButton.hovered || moveDownButton.hovered
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        spacing: 4

                        Button {
                            id: moveUpButton
                            width: 24
                            height: 22
                            enabled: pageDelegate.index > 0
                            background: Rectangle {
                                color: moveUpButton.enabled && moveUpButton.hovered ? Theme.accentSoft : Theme.paper
                                border.color: moveUpButton.enabled ? Theme.accentBorder : Theme.border
                                radius: 5
                            }
                            contentItem: Icon {
                                name: "up"
                                color: moveUpButton.enabled ? Theme.accent : Theme.border
                                size: 18
                                anchors.centerIn: parent
                            }
                            Accessible.name: `上移第 ${pageDelegate.index + 1} 页`
                            ToolTip.visible: hovered
                            ToolTip.text: enabled ? "上移页面" : "已是第一页"
                            ToolTip.delay: 300
                            onClicked: root.appController.taskService.reorderPages(pageDelegate.index, pageDelegate.index - 1)
                        }

                        Button {
                            id: moveDownButton
                            width: 24
                            height: 22
                            enabled: pageDelegate.index < root.appController.taskService.currentTaskPageCount - 1
                            background: Rectangle {
                                color: moveDownButton.enabled && moveDownButton.hovered ? Theme.accentSoft : Theme.paper
                                border.color: moveDownButton.enabled ? Theme.accentBorder : Theme.border
                                radius: 5
                            }
                            contentItem: Icon {
                                name: "down"
                                color: moveDownButton.enabled ? Theme.accent : Theme.border
                                size: 18
                                anchors.centerIn: parent
                            }
                            Accessible.name: `下移第 ${pageDelegate.index + 1} 页`
                            ToolTip.visible: hovered
                            ToolTip.text: enabled ? "下移页面" : "已是最后一页"
                            ToolTip.delay: 300
                            onClicked: root.appController.taskService.reorderPages(pageDelegate.index, pageDelegate.index + 1)
                        }
                    }

                    // Delete Page Button (smooth hover)
                    Button {
                        id: deletePageButton
                        visible: thumbMouseArea.containsMouse || hovered
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        width: 22
                        height: 22
                        background: Rectangle {
                            color: deletePageButton.hovered ? "#fee2e2" : Theme.paper
                            border.color: "#fca5a5"
                            radius: 11
                        }
                        contentItem: Icon {
                            name: "close"
                            color: Theme.danger
                            size: 18
                            anchors.centerIn: parent
                        }
                        onClicked: root.pageDeleted(pageDelegate.index)
                        ToolTip.visible: hovered
                        ToolTip.text: "删除此页"
                        ToolTip.delay: 300
                    }
                }
            }
        }
    }
}
