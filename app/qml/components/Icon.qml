import QtQuick
import "Theme.js" as Theme
import "Icons.js" as Icons

Item {
    id: root
    property string name: "document"
    property color color: Theme.secondary
    property int size: 18
    implicitWidth: size
    implicitHeight: size
    Image {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio
        source: "data:image/svg+xml;utf8," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="'
            + root.color + '" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'
            + (Icons.paths[root.name] || Icons.paths.document) + '</svg>')
    }
}
