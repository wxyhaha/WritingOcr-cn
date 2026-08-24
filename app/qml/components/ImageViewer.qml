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
        color: "#1e1e1e"
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

                            // Visual styling: Yellow for low confidence, Blue for selected, Muted dashed for printed
                            border.width: isSel ? 3 : (isLow ? 2 : (isPrinted ? 1 : 0))
                            border.color: isSel ? "#3b82f6" : (isLow ? "#eab308" : (isPrinted ? "#94a3b8" : "transparent"))
                            color: isSel ? "#333b82f6" : (isLow ? "#22eab308" : (isPrinted ? "#1594a3b8" : "transparent"))
                            radius: 2

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
                                ToolTip.text: `${model.text}\n类型: ${model.isHandwriting ? "手写体" : "印刷体"}\n识别置信度: ${(model.confidence * 100).toFixed(1)}%`
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

        // Maintain center focus during zoom
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

        let scaleX = overlayLayer.scaleX;
        let scaleY = overlayLayer.scaleY;

        let targetX = (container.width - imageWrapper.width) / 2 + (map.bboxX + map.bboxWidth / 2) * scaleX - flickable.width / 2;
        let targetY = (container.height - imageWrapper.height) / 2 + (map.bboxY + map.bboxHeight / 2) * scaleY - flickable.height / 2;

        flickable.contentX = Math.max(0, Math.min(container.width - flickable.width, targetX));
        flickable.contentY = Math.max(0, Math.min(container.height - flickable.height, targetY));
    }

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onWheel: (wheel) => {
            let factor = wheel.angleDelta.y > 0 ? 1.15 : 0.85;
            root.zoom(factor, wheel.x, wheel.y);
            wheel.accepted = true;
        }

        onDoubleClicked: (mouse) => {
            if (Math.abs(root.currentScale - 1.0) < 0.1) {
                root.fitToWindow();
            } else {
                root.resetOriginalSize();
            }
        }
    }

    // Floating Zoom Controls Bar
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        height: 36
        radius: 18
        color: "#cc1f2937"
        border.color: "#374151"
        width: controlsRow.implicitWidth + 24

        Row {
            id: controlsRow
            anchors.centerIn: parent
            spacing: 12

            Button {
                text: "−"
                width: 24
                height: 24
                background: Rectangle { color: "transparent" }
                contentItem: Text { text: "−"; color: "white"; font.bold: true; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.zoom(0.8)
            }

            Text {
                text: `${Math.round(root.currentScale * 100)}%`
                color: "#e5e7eb"
                font.pixelSize: 12
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Button {
                text: "+"
                width: 24
                height: 24
                background: Rectangle { color: "transparent" }
                contentItem: Text { text: "+"; color: "white"; font.bold: true; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.zoom(1.25)
            }

            Rectangle { width: 1; height: 16; color: "#4b5563"; anchors.verticalCenter: parent.verticalCenter }

            Button {
                text: "适应"
                height: 24
                background: Rectangle { color: "transparent" }
                contentItem: Text { text: "适应窗口"; color: "#93c5fd"; font.pixelSize: 11; anchors.centerIn: parent }
                onClicked: root.fitToWindow()
            }

            Button {
                text: "100%"
                height: 24
                background: Rectangle { color: "transparent" }
                contentItem: Text { text: "1:1"; color: "#93c5fd"; font.pixelSize: 11; anchors.centerIn: parent }
                onClicked: root.resetOriginalSize()
            }
        }
    }
}
