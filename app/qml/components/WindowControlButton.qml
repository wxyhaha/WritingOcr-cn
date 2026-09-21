import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Button {
    id: control
    property string iconName
    property bool destructive: false
    implicitWidth: 44
    implicitHeight: 36
    hoverEnabled: true
    Accessible.name: text
    ToolTip.text: text
    ToolTip.visible: hovered
    ToolTip.delay: 600
    background: Rectangle {
        radius: 5
        color: control.down || control.hovered
               ? (control.destructive ? Theme.danger : Theme.accentSoft)
               : "transparent"
        border.width: control.visualFocus ? 1 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: 100 } }
    }
    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            name: control.iconName
            size: 16
            color: control.destructive && (control.hovered || control.down) ? Theme.paper : Theme.secondary
        }
    }
}
