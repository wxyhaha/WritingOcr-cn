import QtQuick
import "Theme.js" as Theme
import QtQuick.Controls

pragma ComponentBehavior: Bound

Item {
    id: root

    property string imagePath: ""
    property var appController
    property var blockModel: null
    property int selectedIndex: blockModel ? blockModel.selectedIndex : -1
    property int imageRotation: 0

    signal blockClicked(int index, var block)

    // Neutral canvas keeps the original photograph's colors unchanged.
    Rectangle {
        anchors.fill: parent
        color: "#E4E6DF"
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
                    source: root.imagePath ? root.appController.localFileToUrl(root.imagePath) : ""
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
                            Qt.callLater(root.fitToWindow);
                        }
                    }
                }

                // Overlay for OCR Bounding Boxes
                Item {
                    id: overlayLayer
                    anchors.fill: parent
                    rotation: root.imageRotation
                    transformOrigin: Item.Center
                    visible: imageItem.status === Image.Ready && root.blockModel !== null

                    // Scale factors from original image pixels to displayed image pixels
                    property real scaleX: imageItem.implicitWidth > 0 ? (imageWrapper.width / imageItem.implicitWidth) : 1.0
                    property real scaleY: imageItem.implicitHeight > 0 ? (imageWrapper.height / imageItem.implicitHeight) : 1.0

                    Repeater {
                        model: root.blockModel

                        delegate: Rectangle {
                            id: boxRect
                            required property var model
                            required property int index

                            // Bbox in original image pixel coordinate system
                            property real bX: boxRect.model.bboxX * overlayLayer.scaleX
                            property real bY: boxRect.model.bboxY * overlayLayer.scaleY
                            property real bW: boxRect.model.bboxWidth * overlayLayer.scaleX
                            property real bH: boxRect.model.bboxHeight * overlayLayer.scaleY
                            property bool isLow: boxRect.model.isLowConfidence
                            property bool isSel: (boxRect.model.isSelected === true) || (root.blockModel !== null && root.blockModel.selectedIndex === boxRect.index)
                            property bool isPrinted: !boxRect.model.isHandwriting

                            x: bX
                            y: bY
                            width: Math.max(bW, 4)
                            height: Math.max(bH, 4)
                            z: isSel ? 20 : 1

                            // Visual styling: Distinct & clean default state, bold highlight when selected
                            border.width: isSel ? 2.5 : (isLow ? 2.0 : (isPrinted ? 1.2 : 1.5))
                            border.color: isSel ? Theme.accent : (isLow ? Theme.warning : (isPrinted ? Theme.secondary : Theme.accentBorder))
                            color: isSel ? "#40365C49" : (isLow ? "#25976522" : (isPrinted ? "#15566259" : "#14365C49"))
                            radius: 3

                            visible: true

                            // Outer focus glow ring when selected
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -3
                                radius: 5
                                color: "transparent"
                                border.color: Theme.accent
                                border.width: 2.0
                                visible: boxRect.isSel
                                opacity: 0.9
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: false
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.blockModel) {
                                        root.blockModel.selectedIndex = boxRect.index;
                                    }
                                    root.blockClicked(boxRect.index, root.blockModel ? root.blockModel.getBlockMap(boxRect.index) : null);
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

    Column {
        anchors.centerIn: parent
        width: Math.max(0, root.width - 32)
        spacing: 8
        visible: !root.imagePath || imageItem.status === Image.Error
        Text {
            text: root.imagePath ? "图片加载失败" : "请选择一个页面"
            color: Theme.secondary
            font.bold: true
            font.pixelSize: 15
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
        Text {
            text: root.imagePath ? "请检查文件是否存在，或重新导入图片" : "从左侧页面列表选择要查看的图片"
            color: Theme.muted
            font.pixelSize: 12
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }

    // Compact image tools
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        height: 38
        radius: 19
        color: "#EB283D32"
        border.color: Theme.secondary
        width: controlsRow.implicitWidth + 24

        Row {
            id: controlsRow
            anchors.centerIn: parent
            spacing: root.width < 360 ? 4 : 8

            Button {
                id: zoomOutButton
                width: 26
                height: 26
                background: Rectangle {
                    color: zoomOutButton.hovered ? Theme.secondary : "transparent"
                    radius: 13
                }
                contentItem: Icon { name: "minus"; color: "white";  size: 18;  }
                onClicked: root.zoom(0.8)
                ToolTip.visible: hovered
                ToolTip.text: "缩小"
                ToolTip.delay: 300
            }

            Text {
                text: `${Math.round(root.currentScale * 100)}%`
                color: Theme.border
                font.pixelSize: 12
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Button {
                id: zoomInButton
                width: 26
                height: 26
                background: Rectangle {
                    color: zoomInButton.hovered ? Theme.secondary : "transparent"
                    radius: 13
                }
                contentItem: Icon { name: "plus"; color: "white";  size: 18;  }
                onClicked: root.zoom(1.25)
                ToolTip.visible: hovered
                ToolTip.text: "放大"
                ToolTip.delay: 300
            }

            Rectangle { width: 1; height: 16; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }

            Button {
                id: fitButton
                height: 26
                background: Rectangle {
                    color: fitButton.hovered ? Theme.secondary : "transparent"
                    radius: 6
                }
                contentItem: Text { text: "适应"; color: Theme.accentBorder; font.pixelSize: 11; anchors.centerIn: parent }
                onClicked: root.fitToWindow()
            }

            Button {
                id: originalSizeButton
                visible: root.width >= 360
                height: 26
                background: Rectangle {
                    color: originalSizeButton.hovered ? Theme.secondary : "transparent"
                    radius: 6
                }
                contentItem: Text { text: "1:1"; color: Theme.accentBorder; font.pixelSize: 11; anchors.centerIn: parent }
                onClicked: root.resetOriginalSize()
            }

            Rectangle { width: 1; height: 16; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }

            // Rotate buttons
            Button {
                id: rotateLeftButton
                width: 26
                height: 26
                background: Rectangle {
                    color: rotateLeftButton.hovered ? Theme.secondary : "transparent"
                    radius: 13
                }
                contentItem: Icon { name: "rotateLeft"; color: Theme.accentBorder;  size: 18; anchors.centerIn: parent }
                onClicked: root.rotateImage(-90)
                ToolTip.visible: hovered
                ToolTip.text: "逆时针旋转 90°"
                ToolTip.delay: 300
            }

            Button {
                id: rotateRightButton
                width: 26
                height: 26
                background: Rectangle {
                    color: rotateRightButton.hovered ? Theme.secondary : "transparent"
                    radius: 13
                }
                contentItem: Icon { name: "rotateRight"; color: Theme.accentBorder;  size: 18; anchors.centerIn: parent }
                onClicked: root.rotateImage(90)
                ToolTip.visible: hovered
                ToolTip.text: "顺时针旋转 90°"
                ToolTip.delay: 300
            }
        }
    }
}
