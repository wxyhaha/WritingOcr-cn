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

    Column {
        anchors.fill: parent
        spacing: 0

        // Sidebar Header
        Rectangle {
            width: parent.width
            height: 44
            color: "#f1f5f9"
            border.color: "#e2e8f0"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: "页面列表"
                    font.bold: true
                    font.pixelSize: 13
                    color: "#334155"
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "+ 添加"
                    height: 28
                    Layout.alignment: Qt.AlignVCenter
                    background: Rectangle {
                        color: "#e2e8f0"
                        radius: 4
                    }
                    contentItem: Text {
                        text: "+ 添加"
                        color: "#0f172a"
                        font.pixelSize: 12
                        anchors.centerIn: parent
                    }
                    onClicked: root.addPagesRequested()
                }
            }
        }

        // Thumbnails ListView
        ListView {
            id: listView
            width: parent.width
            height: parent.height - 44
            clip: true
            spacing: 12
            topMargin: 12
            bottomMargin: 12
            model: root.pageModel

            delegate: Item {
                width: listView.width - 24
                height: 140
                x: 12

                property bool isCurrent: index === root.currentIndex

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: isCurrent ? "#ffffff" : "#f8fafc"
                    border.width: isCurrent ? 2 : 1
                    border.color: isCurrent ? "#2563eb" : "#cbd5e1"
                    layer.enabled: isCurrent

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pageSelected(index)
                    }

                    Image {
                        id: thumbImage
                        anchors.fill: parent
                        anchors.margins: 4
                        source: (model.thumbnailPath && model.thumbnailPath !== "") ? app.localFileToUrl(model.thumbnailPath) : (model.originalImagePath ? app.localFileToUrl(model.originalImagePath) : "")
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                    }

                    // Page Index Badge
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 6
                        width: 24
                        height: 20
                        radius: 4
                        color: isCurrent ? "#2563eb" : "#475569"

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
                        height: 20
                        radius: 10
                        color: "#eab308"
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

                    // Delete Page Button
                    Button {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        width: 22
                        height: 22
                        background: Rectangle {
                            color: "#fecaca"
                            radius: 11
                        }
                        contentItem: Text {
                            text: "×"
                            color: "#dc2626"
                            font.bold: true
                            font.pixelSize: 14
                            anchors.centerIn: parent
                        }
                        onClicked: root.pageDeleted(index)
                    }
                }
            }
        }
    }
}
