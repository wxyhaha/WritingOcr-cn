import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var pageModel: null
    property int currentIndex: 0

    signal pageSelected(int index)
    signal pageDeleted(int index)
    signal addPagesRequested()

    Rectangle {
        anchors.fill: parent
        color: "#f8fafc"
        border.color: "#e2e8f0"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Sidebar Header
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: "#ffffff"
            border.color: "#e2e8f0"

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
                        color: "#0f172a"
                    }

                    Rectangle {
                        height: 18
                        radius: 9
                        color: "#f1f5f9"
                        width: countText.implicitWidth + 10
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: countText
                            text: `${app.taskService.currentTaskPageCount}`
                            font.pixelSize: 10
                            font.bold: true
                            color: "#64748b"
                            anchors.centerIn: parent
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    height: 28
                    Layout.alignment: Qt.AlignVCenter
                    background: Rectangle {
                        color: parent.hovered ? "#e2e8f0" : "#f1f5f9"
                        border.color: "#cbd5e1"
                        radius: 6
                    }
                    contentItem: Text {
                        text: "➕ 加页"
                        color: "#334155"
                        font.pixelSize: 11
                        font.bold: true
                        anchors.centerIn: parent
                    }
                    onClicked: root.addPagesRequested()
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
                width: listView.width - 24
                height: 148
                x: 12

                property bool isCurrent: index === root.currentIndex

                Rectangle {
                    id: cardBg
                    anchors.fill: parent
                    radius: 10
                    color: isCurrent ? "#ffffff" : (thumbMouseArea.containsMouse ? "#ffffff" : "#f8fafc")
                    border.width: isCurrent ? 2 : 1
                    border.color: isCurrent ? "#2563eb" : (thumbMouseArea.containsMouse ? "#93c5fd" : "#e2e8f0")

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    // Active left indicator bar
                    Rectangle {
                        visible: isCurrent
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 4
                        width: 3
                        radius: 1.5
                        color: "#2563eb"
                    }

                    MouseArea {
                        id: thumbMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pageSelected(index)
                    }

                    Image {
                        id: thumbImage
                        anchors.fill: parent
                        anchors.margins: 6
                        anchors.leftMargin: isCurrent ? 10 : 6
                        source: (model.thumbnailPath && model.thumbnailPath !== "") ? app.localFileToUrl(model.thumbnailPath) : (model.originalImagePath ? app.localFileToUrl(model.originalImagePath) : "")
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                    }

                    // Page Index Floating Badge
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 6
                        anchors.leftMargin: isCurrent ? 10 : 6
                        width: 24
                        height: 20
                        radius: 5
                        color: isCurrent ? "#2563eb" : "#334155"

                        Text {
                            anchors.centerIn: parent
                            text: `${index + 1}`
                            color: "white"
                            font.bold: true
                            font.pixelSize: 11
                        }
                    }

                    // Low Confidence Badge
                    Rectangle {
                        visible: model.lowConfidenceCount > 0
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        height: 18
                        radius: 9
                        color: "#f59e0b"
                        width: badgeText.implicitWidth + 10

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: `! ${model.lowConfidenceCount}`
                            color: "#ffffff"
                            font.bold: true
                            font.pixelSize: 10
                        }
                    }

                    // Delete Page Button (smooth hover)
                    Button {
                        visible: thumbMouseArea.containsMouse || hovered
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        width: 22
                        height: 22
                        background: Rectangle {
                            color: parent.hovered ? "#fee2e2" : "#ffffff"
                            border.color: "#fca5a5"
                            radius: 11
                        }
                        contentItem: Text {
                            text: "✕"
                            color: "#dc2626"
                            font.bold: true
                            font.pixelSize: 11
                            anchors.centerIn: parent
                        }
                        onClicked: root.pageDeleted(index)
                        ToolTip.visible: hovered
                        ToolTip.text: "删除此页"
                        ToolTip.delay: 300
                    }
                }
            }
        }
    }
}
