import QtQuick
import QtQuick.Controls

Item {
    id: root

    property string imageSource: ""
    property string imagePath: ""
    property var blockModel: null
    property int selectedIndex: blockModel ? blockModel.selectedIndex : -1

    signal blockClicked(int index, var blockData)

    clip: true

    Rectangle {
        anchors.fill: parent
        color: "#0f172a" // Sleek dark slate
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: container.width
        contentHeight: container.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Item {
            id: container
            width: Math.max(flickable.width, (imageItem.implicitWidth > 0 ? imageItem.implicitWidth * currentScale : 800) + 100)
            height: Math.max(flickable.height, (imageItem.implicitHeight > 0 ? imageItem.implicitHeight * currentScale : 1000) + 100)

            Item {
                id: imageWrapper
                width: imageItem.implicitWidth > 0 ? imageItem.implicitWidth * currentScale : 800
                height: imageItem.implicitHeight > 0 ? imageItem.implicitHeight * currentScale : 1000
                anchors.centerIn: parent

                Image {
                    id: imageItem
                    anchors.fill: parent
                    source: (root.imagePath !== "" ? root.imagePath : root.imageSource) ? app.localFileToUrl(root.imagePath !== "" ? root.imagePath : root.imageSource) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true

                    onStatusChanged: {
                        if (status === Image.Ready) {
                            Qt.callLater(fitToWindow);
                        }
                    }
                }

                // Overlay for OCR Bounding Boxes
                Item {
                    id: overlayLayer
                    anchors.fill: parent
                    visible: imageItem.status === Image.Ready && blockModel !== null

                    // Scale factors from original image pixels to displayed image pixels
                    property real scaleX: imageItem.implicitWidth > 0 ? (imageWrapper.width / imageItem.implicitWidth) : 1.0
                    property real scaleY: imageItem.implicitHeight > 0 ? (imageWrapper.height / imageItem.implicitHeight) : 1.0

                    Repeater {
                        model: root.blockModel

                        delegate: Rectangle {
                            id: boxRect

                            // Bbox in original image pixel coordinate system
                            property real bX: model.bboxX * overlayLayer.scaleX
                            property real bY: model.bboxY * overlayLayer.scaleY
                            property real bW: model.bboxWidth * overlayLayer.scaleX
                            property real bH: model.bboxHeight * overlayLayer.scaleY
                            property bool isLow: model.isLowConfidence
                            property bool isSel: model.isSelected
                            property bool isPrinted: !model.isHandwriting

                            x: bX
                            y: bY
                            width: Math.max(bW, 4)
                            height: Math.max(bH, 4)

                            // Visual styling: Amber for low confidence, Blue for selected, Muted for printed
                            border.width: isSel ? 2.5 : (isLow ? 2 : (isPrinted ? 1 : 0))
                            border.color: isSel ? "#3b82f6" : (isLow ? "#f59e0b" : (isPrinted ? "#64748b" : "transparent"))
                            color: isSel ? "#303b82f6" : (isLow ? "#25f59e0b" : (isPrinted ? "#1564748b" : "transparent"))
                            radius: 3

                            visible: isLow || isSel || isPrinted

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.blockClicked(index, blockModel.getBlockMap(index));
                                    if (blockModel) {
                                        blockModel.selectedIndex = index;
                                    }
                                }

                                ToolTip.visible: containsMouse
                                ToolTip.text: `${model.text}\n类型: ${model.isHandwriting ? "✍️ 手写体" : "🖨️ 印刷体"}\n识别置信度: ${(model.confidence * 100).toFixed(1)}%`
                                ToolTip.delay: 200
                            }
                        }
                    }
                }
            }
        }
    }

    // Zoom and pan control
    property real currentScale: 1.0
    property real minScale: 0.1
    property real maxScale: 5.0

    function zoom(factor, centerX, centerY) {
        let newScale = Math.max(minScale, Math.min(maxScale, currentScale * factor));
        if (Math.abs(newScale - currentScale) < 0.001) return;

        let prevScale = currentScale;
        currentScale = newScale;

        let contentX = flickable.contentX;
        let contentY = flickable.contentY;
        let focalX = centerX !== undefined ? centerX : flickable.width / 2;
        let focalY = centerY !== undefined ? centerY : flickable.height / 2;

        flickable.contentX = (contentX + focalX) * (newScale / prevScale) - focalX;
        flickable.contentY = (contentY + focalY) * (newScale / prevScale) - focalY;
    }

    function fitToWindow() {
        if (imageItem.implicitWidth <= 0 || imageItem.implicitHeight <= 0) {
            currentScale = 1.0;
            return;
        }
        let scaleX = (flickable.width - 40) / imageItem.implicitWidth;
        let scaleY = (flickable.height - 40) / imageItem.implicitHeight;
        currentScale = Math.max(minScale, Math.min(scaleX, scaleY, 1.0));
        Qt.callLater(() => {
            flickable.contentX = (container.width - flickable.width) / 2;
            flickable.contentY = (container.height - flickable.height) / 2;
        });
    }

    function resetOriginalSize() {
        currentScale = 1.0;
        flickable.contentX = (container.width - flickable.width) / 2;
        flickable.contentY = (container.height - flickable.height) / 2;
    }

    function scrollToBlock(index) {
        if (!blockModel || index < 0 || index >= blockModel.totalCount) return;
        let map = blockModel.getBlockMap(index);
        if (!map || map.bboxX === undefined) return;

        let scaleX = imageItem.implicitWidth > 0 ? (imageWrapper.width / imageItem.implicitWidth) : 1.0;
        let scaleY = imageItem.implicitHeight > 0 ? (imageWrapper.height / imageItem.implicitHeight) : 1.0;

        let targetImageX = map.bboxX * scaleX;
        let targetImageY = map.bboxY * scaleY;

        let targetContainerX = imageWrapper.x + targetImageX;
        let targetContainerY = imageWrapper.y + targetImageY;

        flickable.contentX = Math.max(0, Math.min(flickable.contentWidth - flickable.width, targetContainerX - flickable.width / 2));
        flickable.contentY = Math.max(0, Math.min(flickable.contentHeight - flickable.height, targetContainerY - flickable.height / 2));
    }

    // Wheel zoom
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                root.zoom(1.15, wheel.x, wheel.y);
            } else if (wheel.angleDelta.y < 0) {
                root.zoom(0.85, wheel.x, wheel.y);
            }
        }
    }

    // Modern Floating Glassmorphic Zoom HUD
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        height: 38
        radius: 19
        color: "#d91e293b" // Translucent dark slate
        border.color: "#334155"
        width: controlsRow.implicitWidth + 24

        Row {
            id: controlsRow
            anchors.centerIn: parent
            spacing: 10

            Button {
                width: 26
                height: 26
                background: Rectangle {
                    color: parent.hovered ? "#334155" : "transparent"
                    radius: 13
                }
                contentItem: Text { text: "−"; color: "white"; font.bold: true; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.zoom(0.8)
                ToolTip.visible: hovered
                ToolTip.text: "缩小"
                ToolTip.delay: 300
            }

            Text {
                text: `${Math.round(root.currentScale * 100)}%`
                color: "#e2e8f0"
                font.pixelSize: 12
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Button {
                width: 26
                height: 26
                background: Rectangle {
                    color: parent.hovered ? "#334155" : "transparent"
                    radius: 13
                }
                contentItem: Text { text: "+"; color: "white"; font.bold: true; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.zoom(1.25)
                ToolTip.visible: hovered
                ToolTip.text: "放大"
                ToolTip.delay: 300
            }

            Rectangle { width: 1; height: 16; color: "#475569"; anchors.verticalCenter: parent.verticalCenter }

            Button {
                height: 26
                background: Rectangle {
                    color: parent.hovered ? "#334155" : "transparent"
                    radius: 6
                }
                contentItem: Text { text: "适应窗口"; color: "#93c5fd"; font.pixelSize: 11; anchors.centerIn: parent }
                onClicked: root.fitToWindow()
            }

            Button {
                height: 26
                background: Rectangle {
                    color: parent.hovered ? "#334155" : "transparent"
                    radius: 6
                }
                contentItem: Text { text: "1:1 原图"; color: "#93c5fd"; font.pixelSize: 11; anchors.centerIn: parent }
                onClicked: root.resetOriginalSize()
            }
        }
    }
}
