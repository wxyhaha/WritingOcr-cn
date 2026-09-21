import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

ComboBox {
    id: control

    implicitHeight: 36
    height: implicitHeight
    padding: 0
    leftPadding: 12
    rightPadding: 36
    hoverEnabled: true
    font.family: "Microsoft YaHei UI"
    font.pixelSize: 13
    opacity: enabled ? 1 : 0.48

    contentItem: Text {
        text: control.displayText
        color: control.enabled ? Theme.ink : Theme.muted
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Icon {
        x: control.width - width - 11
        y: (control.height - height) / 2
        name: "down"
        size: 16
        color: control.enabled ? Theme.secondary : Theme.muted
    }

    background: Rectangle {
        radius: 7
        color: control.down ? Theme.accentSoft : control.hovered ? Theme.surface : Theme.paper
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Theme.accent : Theme.border

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    delegate: ItemDelegate {
        id: itemDelegate
        width: control.width - 8
        height: 34
        leftPadding: 10
        rightPadding: 10
        hoverEnabled: true
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            text: modelData
            color: itemDelegate.highlighted || itemDelegate.hovered ? Theme.paper : Theme.ink
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: 6
            color: itemDelegate.highlighted || itemDelegate.hovered ? Theme.accent : "transparent"
        }
    }

    popup: Popup {
        id: popup
        y: control.height + 4
        width: control.width
        padding: 4
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, 240)

        contentItem: ListView {
            id: optionList
            clip: true
            implicitHeight: contentHeight
            model: popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            color: Theme.paper
            border.color: Theme.border
            radius: 8

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: "transparent"
                border.color: "#1e293b10"
                radius: 7
            }
        }
    }
}
