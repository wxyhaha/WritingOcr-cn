import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

Button {
    id: control
    property string iconName: ""
    property string trailingIconName: ""
    property bool primary: false
    property bool quiet: false
    implicitHeight: 36
    implicitWidth: Math.max(iconName && !text ? 36 : 0, label.implicitWidth + 24)
    padding: 10
    hoverEnabled: true
    opacity: enabled ? 1 : 0.42
    font.pixelSize: 13
    Accessible.name: text || ToolTip.text
    background: Rectangle {
        radius: 7
        color: control.primary ? (control.down ? Theme.accentHover : control.hovered ? Theme.accentHover : Theme.accent)
                               : control.down || control.hovered ? Theme.accentSoft : control.quiet ? "transparent" : Theme.paper
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Theme.accent : control.primary || control.quiet ? "transparent" : Theme.border
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    contentItem: Item {
        implicitWidth: label.implicitWidth
        implicitHeight: 18
        Row {
            id: label
            anchors.centerIn: parent
            spacing: control.text && (control.iconName || control.trailingIconName) ? 7 : 0
            Icon {
                visible: control.iconName !== ""
                name: control.iconName
                color: control.primary ? Theme.paper : Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: control.text
                font: control.font
                color: control.primary ? Theme.paper : Theme.ink
                anchors.verticalCenter: parent.verticalCenter
            }
            Icon {
                visible: control.trailingIconName !== ""
                name: control.trailingIconName
                size: 14
                color: control.primary ? Theme.paper : Theme.secondary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    ToolTip.visible: hovered && ToolTip.text !== ""
    ToolTip.delay: 600
}
