import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string imagePath: ""
    property var blockModel: null
    property int selectedIndex: blockModel ? blockModel.selectedIndex : -1
    property int imageRotation: 0

    signal blockClicked(int index, var block)

    // Dark Slate canvas background
    Rectangle {
        anchors.fill: parent
        color: "#0f172a"
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: Math.max(container.width, width)
        contentHeight: Math.max(container.height, height)
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds

        NumberAnimation { id: animContentX; target: flickable; property: "contentX"; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { id: animContentY; target: flickable; property: "contentY"; duration: 240; easing.type: Easing.OutCubic }

        Item {
            id: container
            width: Math.max(imageWrapper.width * root.currentScale, flickable.width)
            height: Math.max(imageWrapper.height * root.currentScale, flickable.height)

            Item {
                id: imageWrapper
                width: imageItem.implicitWidth > 0 ? imageItem.implicitWidth : 800
                height: imageItem.implicitHeight > 0 ? imageItem.implicitHeight : 600
                scale: root.currentScale
                transformOrigin: Item.TopLeft
                x: Math.max(0, (container.width - width * root.currentScale) / 2)
                y: Math.max(0, (container.height - height * root.currentScale) / 2)

                Image {
                    id: imageItem
                    anchors.fill: parent
                    source: root.imagePath ? app.localFileToUrl(root.imagePath) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    rotation: root.imageRotation

                    Behavior on rotation {
                        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }

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
                            property bool isSel: (model.isSelected === true) || (root.blockModel !== null && root.blockModel.selectedIndex === index)
                            property bool isPrinted: !model.isHandwriting

                            x: bX
                            y: bY
                            width: Math.max(bW, 4)
                            height: Math.max(bH, 4)
                            z: isSel ? 20 : 1

                            // Visual styling: Distinct & clean default state, bold highlight when selected
                            border.width: isSel ? 2.5 : (isLow ? 2.0 : (isPrinted ? 1.2 : 1.5))
                            border.color: isSel ? "#2563eb" : (isLow ? "#d97706" : (isPrinted ? "#64748b" : "#0284c7"))
                            color: isSel ? "#402563eb" : (isLow ? "#25d97706" : (isPrinted ? "#1564748b" : "#140284c7"))
                            radius: 3

                            visible: true

                            // Outer focus glow ring when selected
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -3
                                radius: 5
                                color: "transparent"
                                border.color: "#2563eb"
                                border.width: 2.0
                                visible: isSel
                                opacity: 0.9
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: false
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (blockModel) {
                                        blockModel.selectedIndex = index;
                                    }
                                    root.blockClicked(index, blockModel ? blockModel.getBlockMap(index) : null);
                                }
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

    function rotateImage(degrees) {
        root.imageRotation = (root.imageRotation + degrees + 360) % 360;
    }

    function focusBlock(index) {
        if (!blockModel || index < 0 || index >= blockModel.totalCount) return;
        blockModel.selectedIndex = index;
        scrollToBlock(index);
    }

    function scrollToBlock(index) {
        if (!blockModel || index < 0 || index >= blockModel.totalCount) return;
        let map = blockModel.getBlockMap(index);
        if (!map || map.bboxX === undefined) return;

        let scaleX = imageItem.implicitWidth > 0 ? (imageWrapper.width / imageItem.implicitWidth) : 1.0;
        let scaleY = imageItem.implicitHeight > 0 ? (imageWrapper.height / imageItem.implicitHeight) : 1.0;

        let targetImageX = (map.bboxX + map.bboxWidth / 2) * scaleX;
        let targetImageY = (map.bboxY + map.bboxHeight / 2) * scaleY;

        let targetContainerX = imageWrapper.x + targetImageX * root.currentScale;
        let targetContainerY = imageWrapper.y + targetImageY * root.currentScale;

        let destX = Math.max(0, Math.min(flickable.contentWidth - flickable.width, targetContainerX - flickable.width / 2));
        let destY = Math.max(0, Math.min(flickable.contentHeight - flickable.height, targetContainerY - flickable.height / 2));

        animContentX.stop();
        animContentX.to = destX;
        animContentX.start();

        animContentY.stop();
        animContentY.to = destY;
        animContentY.start();
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

    // Modern Floating Glassmorphic Zoom & Rotate HUD
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

            Rectangle { width: 1; height: 16; color: "#475569"; anchors.verticalCenter: parent.verticalCenter }

            // Rotate buttons
            Button {
                width: 26
                height: 26
                background: Rectangle {
                    color: parent.hovered ? "#334155" : "transparent"
                    radius: 13
                }
                contentItem: Text { text: "⟲"; color: "#93c5fd"; font.bold: true; font.pixelSize: 14; anchors.centerIn: parent }
                onClicked: root.rotateImage(-90)
                ToolTip.visible: hovered
                ToolTip.text: "逆时针旋转 90°"
                ToolTip.delay: 300
            }

            Button {
                width: 26
                height: 26
                background: Rectangle {
                    color: parent.hovered ? "#334155" : "transparent"
                    radius: 13
                }
                contentItem: Text { text: "⟳"; color: "#93c5fd"; font.bold: true; font.pixelSize: 14; anchors.centerIn: parent }
                onClicked: root.rotateImage(90)
                ToolTip.visible: hovered
                ToolTip.text: "顺时针旋转 90°"
                ToolTip.delay: 300
            }
        }
    }
}
