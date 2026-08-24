import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string text: ""
    property var blockModel: null
    property int selectedIndex: blockModel ? blockModel.selectedIndex : -1
    property int editorFontSize: 15
    property bool isSearchOpen: false

    signal textEdited(string newText)
    signal blockRequested(int index)
    signal blockSelected(int index)

    property bool isProgrammaticSelecting: false

    onTextChanged: {
        if (textArea.text !== root.text) {
            textArea.text = root.text;
        }
    }

    function selectTextForBlock(blockIndex) {
        if (!blockModel || blockIndex < 0 || blockIndex >= blockModel.totalCount) return;
        let map = blockModel.getBlockMap(blockIndex);
        let blockText = map.text ? map.text.trim() : "";
        let fullText = textArea.text;

        let start = -1;
        let len = 0;

        // 1. Try finding by block text in current editor content
        if (blockText.length >= 2) {
            let pos = fullText.indexOf(blockText);
            if (pos !== -1) {
                start = pos;
                len = blockText.length;
            }
        }

        // 2. Fallback to charStart/charLength
        if (start === -1) {
            let cs = blockModel.getCharStart(blockIndex);
            let cl = blockModel.getCharLength(blockIndex);
            if (cs >= 0 && cl > 0 && cs + cl <= fullText.length) {
                start = cs;
                len = cl;
            }
        }

        if (start >= 0 && len > 0) {
            isProgrammaticSelecting = true;
            textArea.forceActiveFocus();
            textArea.select(start, start + len);
            isProgrammaticSelecting = false;

            // Smooth scroll into visible area
            Qt.callLater(() => {
                let rect = textArea.cursorRectangle;
                if (textArea.height > 0) {
                    let targetScroll = Math.max(0, Math.min(1.0 - scrollView.ScrollBar.vertical.size, (rect.y - 60) / textArea.height));
                    scrollView.ScrollBar.vertical.position = targetScroll;
                }
            });
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

        // 1. Editor Quick Actions Toolbar
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

                // Search toggle button
                Button {
                    height: 26
                    background: Rectangle {
                        color: root.isSearchOpen ? "#eff6ff" : (parent.hovered ? "#f1f5f9" : "transparent")
                        border.color: root.isSearchOpen ? "#3b82f6" : "#cbd5e1"
                        radius: 4
                    }
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "🔍"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "查找替换"; font.pixelSize: 11; color: root.isSearchOpen ? "#1d4ed8" : "#475569"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    onClicked: {
                        root.isSearchOpen = !root.isSearchOpen;
                        if (root.isSearchOpen) {
                            searchField.forceActiveFocus();
                        }
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "查找与批量替换 (Ctrl+F)"
                    ToolTip.delay: 300
                }

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

        // 2. Sliding Search & Replace Bar (Modern 2-Row Layout)
        Rectangle {
            id: searchBar
            Layout.fillWidth: true
            height: root.isSearchOpen ? 80 : 0
            visible: height > 0
            clip: true
            color: "#f8fafc"
            border.color: "#e2e8f0"

            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

            property int matchCount: 0
            property int currentMatchIndex: 0
            property var matchPositions: []

            function updateMatches() {
                let query = searchField.text;
                matchPositions = [];
                currentMatchIndex = 0;
                if (!query) {
                    matchCount = 0;
                    return;
                }
                let src = textArea.text;
                let pos = src.indexOf(query, 0);
                while (pos !== -1) {
                    matchPositions.push(pos);
                    pos = src.indexOf(query, pos + query.length);
                }
                matchCount = matchPositions.length;
                if (matchCount > 0) {
                    highlightMatch(0);
                }
            }

            function highlightMatch(idx) {
                if (idx < 0 || idx >= matchPositions.length) return;
                currentMatchIndex = idx;
                let start = matchPositions[idx];
                let len = searchField.text.length;
                textArea.select(start, start + len);
                textArea.cursorPosition = start + len;
            }

            function nextMatch() {
                if (matchCount <= 0) return;
                let nextIdx = (currentMatchIndex + 1) % matchCount;
                highlightMatch(nextIdx);
            }

            function prevMatch() {
                if (matchCount <= 0) return;
                let prevIdx = (currentMatchIndex - 1 + matchCount) % matchCount;
                highlightMatch(prevIdx);
            }

            function replaceCurrent() {
                if (matchCount <= 0 || !searchField.text) return;
                let start = matchPositions[currentMatchIndex];
                let len = searchField.text.length;
                let before = textArea.text.substring(0, start);
                let after = textArea.text.substring(start + len);
                textArea.text = before + replaceField.text + after;
                updateMatches();
            }

            function replaceAll() {
                if (matchCount <= 0 || !searchField.text) return;
                textArea.text = textArea.text.split(searchField.text).join(replaceField.text);
                updateMatches();
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Row 1: Search & Navigation
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    TextField {
                        id: searchField
                        placeholderText: "🔍 查找内容..."
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        background: Rectangle {
                            color: "#ffffff"
                            border.color: searchField.activeFocus ? "#3b82f6" : "#cbd5e1"
                            radius: 4
                        }
                        onTextChanged: searchBar.updateMatches()
                        onAccepted: searchBar.nextMatch()
                    }

                    // Match counter badge
                    Rectangle {
                        height: 26
                        width: matchCountText.implicitWidth + 12
                        radius: 4
                        color: searchBar.matchCount > 0 ? "#eff6ff" : "#f1f5f9"
                        border.color: searchBar.matchCount > 0 ? "#bfdbfe" : "#e2e8f0"
                        Text {
                            id: matchCountText
                            anchors.centerIn: parent
                            text: searchBar.matchCount > 0 ? `${searchBar.currentMatchIndex + 1}/${searchBar.matchCount}` : (searchField.text ? "无匹配" : "-")
                            font.pixelSize: 11
                            color: searchBar.matchCount > 0 ? "#1d4ed8" : "#94a3b8"
                        }
                    }

                    Button {
                        height: 26
                        width: 26
                        enabled: searchBar.matchCount > 0
                        background: Rectangle { color: parent.hovered ? "#e2e8f0" : "#f1f5f9"; border.color: "#cbd5e1"; radius: 4 }
                        contentItem: Text { text: "▲"; font.pixelSize: 10; color: parent.enabled ? "#334155" : "#94a3b8"; anchors.centerIn: parent }
                        onClicked: searchBar.prevMatch()
                        ToolTip.visible: hovered
                        ToolTip.text: "上一个"
                        ToolTip.delay: 200
                    }

                    Button {
                        height: 26
                        width: 26
                        enabled: searchBar.matchCount > 0
                        background: Rectangle { color: parent.hovered ? "#e2e8f0" : "#f1f5f9"; border.color: "#cbd5e1"; radius: 4 }
                        contentItem: Text { text: "▼"; font.pixelSize: 10; color: parent.enabled ? "#334155" : "#94a3b8"; anchors.centerIn: parent }
                        onClicked: searchBar.nextMatch()
                        ToolTip.visible: hovered
                        ToolTip.text: "下一个"
                        ToolTip.delay: 200
                    }

                    Button {
                        height: 26
                        width: 26
                        background: Rectangle { color: parent.hovered ? "#fee2e2" : "transparent"; radius: 4 }
                        contentItem: Text { text: "✕"; font.pixelSize: 12; color: "#64748b"; anchors.centerIn: parent }
                        onClicked: root.isSearchOpen = false
                        ToolTip.visible: hovered
                        ToolTip.text: "关闭 (Esc)"
                        ToolTip.delay: 200
                    }
                }

                // Row 2: Replace & Actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    TextField {
                        id: replaceField
                        placeholderText: "✍️ 替换为..."
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        background: Rectangle {
                            color: "#ffffff"
                            border.color: replaceField.activeFocus ? "#3b82f6" : "#cbd5e1"
                            radius: 4
                        }
                    }

                    Button {
                        height: 26
                        text: "替换"
                        enabled: searchBar.matchCount > 0
                        background: Rectangle {
                            color: parent.enabled ? (parent.hovered ? "#dbeafe" : "#eff6ff") : "#f1f5f9"
                            border.color: parent.enabled ? "#bfdbfe" : "#e2e8f0"
                            radius: 4
                        }
                        contentItem: Text { text: "替换"; font.pixelSize: 11; font.bold: true; color: parent.enabled ? "#1d4ed8" : "#94a3b8"; anchors.centerIn: parent }
                        onClicked: searchBar.replaceCurrent()
                    }

                    Button {
                        height: 26
                        text: "全部替换"
                        enabled: searchBar.matchCount > 0
                        background: Rectangle {
                            color: parent.enabled ? (parent.hovered ? "#dbeafe" : "#eff6ff") : "#f1f5f9"
                            border.color: parent.enabled ? "#bfdbfe" : "#e2e8f0"
                            radius: 4
                        }
                        contentItem: Text { text: "全部替换"; font.pixelSize: 11; font.bold: true; color: parent.enabled ? "#1d4ed8" : "#94a3b8"; anchors.centerIn: parent }
                        onClicked: searchBar.replaceAll()
                    }
                }
            }
        }

        // 3. Main Text Area with Bidirectional Cursor Sync
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
                persistentSelection: true
                selectionColor: "#fef08a"
                selectedTextColor: "#1d4ed8"
                placeholderText: "暂无识别文本。\n\n点击上方【⚡ 识别本页】或【⚡⚡ 全篇识别】开始本地 OCR 识别。"

                background: Rectangle {
                    color: "#ffffff"
                }

                // Keyboard shortcut: Ctrl + F toggle search
                Keys.onPressed: (event) => {
                    if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_F) {
                        root.isSearchOpen = !root.isSearchOpen;
                        if (root.isSearchOpen) {
                            searchField.forceActiveFocus();
                        }
                        event.accepted = true;
                    }
                }

                function syncCursorToImage() {
                    if (root.isProgrammaticSelecting) return;
                    if (root.blockModel) {
                        let bIdx = root.blockModel.findBlockIndexForCursor(cursorPosition, textArea.text);
                        if (bIdx >= 0) {
                            root.blockModel.selectedIndex = bIdx;
                            root.blockSelected(bIdx);
                        }
                    }
                }

                // Direction B: Editor -> Image Interactive Sync
                onCursorPositionChanged: syncCursorToImage()
                onPressed: syncCursorToImage()
                onReleased: syncCursorToImage()

                onTextChanged: {
                    if (text !== root.text) {
                        root.textEdited(text);
                    }
                }
            }
        }
    }
}
