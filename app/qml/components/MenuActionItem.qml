import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

MenuItem {
    id: control

    property string iconName: "document"
    implicitHeight: 38
    height: implicitHeight
    padding: 0
    leftPadding: 12
    rightPadding: 12
    hoverEnabled: true
    font.family: "Microsoft YaHei UI"
    font.pixelSize: 13

    contentItem: Row {
        anchors.fill: parent
        anchors.leftMargin: control.leftPadding
        anchors.rightMargin: control.rightPadding
        spacing: 10

        Icon {
            name: control.iconName
            size: 16
            color: control.enabled
                   ? (control.highlighted ? Theme.accent : Theme.secondary)
                   : Theme.muted
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            width: parent.width - 26
            text: control.text
            color: control.enabled
                   ? (control.highlighted ? Theme.accentHover : Theme.ink)
                   : Theme.muted
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    background: Rectangle {
        radius: 6
        color: control.highlighted ? Theme.accentSoft : "transparent"
    }
}
