import QtQuick
import QtQuick.Controls

Item {
    id: root

    property string text: ""
    property var blockModel: null
    property int selectedIndex: blockModel ? blockModel.selectedIndex : -1

    signal textEdited(string newText)
    signal blockRequested(int index)

    onTextChanged: {
        if (textArea.text !== root.text) {
            textArea.text = root.text;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#ffffff"
        border.color: "#e5e7eb"
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: 12
        clip: true

        TextArea {
            id: textArea
            text: root.text
            wrapMode: TextArea.Wrap
            font.pixelSize: 15
            font.family: "Microsoft YaHei, PingFang SC, sans-serif"
            color: "#1f2937"
            selectByMouse: true
            selectionColor: "#93c5fd"
            selectedTextColor: "#1e3a8a"
            placeholderText: "暂无识别文本。点击上方【单页识别】或【全篇识别】开始本地 OCR 识别。"

            background: Rectangle {
                color: "transparent"
            }

            onTextChanged: {
                if (text !== root.text) {
                    root.textEdited(text);
                }
            }

            onCursorPositionChanged: {
                // Find block corresponding to cursor position if possible
                // (Optional fine-grained block matching)
            }
        }
    }

    // Floating format / quick info bar
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        height: 28
        radius: 6
        color: "#f3f4f6"
        border.color: "#e5e7eb"
        width: wordCountText.implicitWidth + 20

        Text {
            id: wordCountText
            anchors.centerIn: parent
            text: `本页共 ${textArea.text.trim().length} 字`
            font.pixelSize: 11
            color: "#6b7280"
        }
    }
}
