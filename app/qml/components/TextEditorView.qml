import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string text: ""
    property var blockModel: null
    property int selectedIndex: blockModel ? blockModel.selectedIndex : -1
    property int editorFontSize: 15

    signal textEdited(string newText)
    signal blockRequested(int index)
    signal blockSelected(int index)

    onTextChanged: {
        if (textArea.text !== root.text) {
            textArea.text = root.text;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#ffffff"
        border.color: "#e2e8f0"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Editor Quick Actions Toolbar
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: "#ffffff"
            border.color: "#e2e8f0"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                Row {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: "✍️"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "识别与校对文本"
                        font.bold: true
                        font.pixelSize: 13
                        color: "#0f172a"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item { Layout.fillWidth: true }

                // Font size adjuster
                Row {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    Button {
                        height: 26
                        width: 26
                        background: Rectangle {
                            color: parent.hovered ? "#f1f5f9" : "transparent"
                            border.color: "#cbd5e1"
                            radius: 4
                        }
                        contentItem: Text { text: "A-"; font.pixelSize: 10; font.bold: true; color: "#475569"; anchors.centerIn: parent }
                        onClicked: {
                            if (root.editorFontSize > 12) root.editorFontSize -= 1;
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: "缩小字号"
                        ToolTip.delay: 300
                    }

                    Button {
                        height: 26
                        width: 26
                        background: Rectangle {
                            color: parent.hovered ? "#f1f5f9" : "transparent"
                            border.color: "#cbd5e1"
                            radius: 4
                        }
                        contentItem: Text { text: "A+"; font.pixelSize: 10; font.bold: true; color: "#475569"; anchors.centerIn: parent }
                        onClicked: {
                            if (root.editorFontSize < 24) root.editorFontSize += 1;
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: "放大字号"
                        ToolTip.delay: 300
                    }
                }

                // Copy text button
                Button {
                    height: 28
                    Layout.alignment: Qt.AlignVCenter
                    enabled: textArea.text.trim().length > 0
                    background: Rectangle {
                        color: parent.hovered ? "#eff6ff" : "#f8fafc"
                        border.color: parent.hovered ? "#bfdbfe" : "#cbd5e1"
                        radius: 6
                    }
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "📋"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "复制文本"; font.pixelSize: 11; font.bold: true; color: "#1d4ed8"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    onClicked: {
                        app.copyToClipboard(textArea.text);
                    }
                }

                // Word count pill
                Rectangle {
                    height: 24
                    radius: 12
                    color: "#f1f5f9"
                    width: wordCountText.implicitWidth + 14
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: wordCountText
                        anchors.centerIn: parent
                        text: `${textArea.text.trim().length} 字`
                        font.pixelSize: 11
                        font.bold: true
                        color: "#475569"
                    }
                }
            }
        }

        // Main Text Area
        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            TextArea {
                id: textArea
                text: root.text
                wrapMode: TextArea.Wrap
                font.pixelSize: root.editorFontSize
                font.family: "Microsoft YaHei UI, PingFang SC, Segoe UI, sans-serif"
                color: "#1e293b"
                topPadding: 16
                bottomPadding: 24
                leftPadding: 18
                rightPadding: 18
                selectByMouse: true
                selectionColor: "#bfdbfe"
                selectedTextColor: "#1e3a8a"
                placeholderText: "暂无识别文本。\n\n点击上方【⚡ 识别本页】或【⚡⚡ 全篇识别】开始本地 OCR 识别。"

                background: Rectangle {
                    color: "#ffffff"
                }

                onTextChanged: {
                    if (text !== root.text) {
                        root.textEdited(text);
                    }
                }
            }
        }
    }
}
