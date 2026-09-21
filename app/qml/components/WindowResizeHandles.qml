import QtQuick
import QtQuick.Window

Item {
    id: root
    objectName: "windowResizeHandles"
    required property var targetWindow
    readonly property int grip: 6
    visible: targetWindow.visibility !== Window.Maximized
             && targetWindow.visibility !== Window.FullScreen

    // Only the outer six pixels intercept input; the content remains interactive.
    Repeater {
        model: [
            { edges: Qt.TopEdge, cursor: Qt.SizeVerCursor },
            { edges: Qt.BottomEdge, cursor: Qt.SizeVerCursor },
            { edges: Qt.LeftEdge, cursor: Qt.SizeHorCursor },
            { edges: Qt.RightEdge, cursor: Qt.SizeHorCursor },
            { edges: Qt.TopEdge | Qt.LeftEdge, cursor: Qt.SizeFDiagCursor },
            { edges: Qt.BottomEdge | Qt.RightEdge, cursor: Qt.SizeFDiagCursor },
            { edges: Qt.TopEdge | Qt.RightEdge, cursor: Qt.SizeBDiagCursor },
            { edges: Qt.BottomEdge | Qt.LeftEdge, cursor: Qt.SizeBDiagCursor }
        ]
        delegate: MouseArea {
            required property var modelData
            readonly property bool leftEdge: (modelData.edges & Qt.LeftEdge) !== 0
            readonly property bool rightEdge: (modelData.edges & Qt.RightEdge) !== 0
            readonly property bool topEdge: (modelData.edges & Qt.TopEdge) !== 0
            readonly property bool bottomEdge: (modelData.edges & Qt.BottomEdge) !== 0
            x: leftEdge ? 0 : rightEdge ? root.width - root.grip : root.grip
            y: topEdge ? 0 : bottomEdge ? root.height - root.grip : root.grip
            width: leftEdge || rightEdge ? root.grip : root.width - root.grip * 2
            height: topEdge || bottomEdge ? root.grip : root.height - root.grip * 2
            cursorShape: modelData.cursor
            acceptedButtons: Qt.LeftButton
            onPressed: root.targetWindow.startSystemResize(modelData.edges)
        }
    }
}
