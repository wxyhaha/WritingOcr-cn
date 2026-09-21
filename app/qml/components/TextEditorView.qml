import QtQuick
import "Theme.js" as Theme
import QtQuick.Controls
import QtQuick.Layouts

pragma ComponentBehavior: Bound

Item {
    id: root

    property string text: ""
    property var appController
    property var blockModel: null
    property int selectedIndex: blockModel ? blockModel.selectedIndex : -1
    property int editorFontSize: 18
    property bool isSearchOpen: false
    property bool annotationsStale: false

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
        color: Theme.paper
        border.color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Editor Quick Actions Toolbar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: Theme.paper
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                Row {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter

                    Icon {
                        name: "edit"
                        size: 18
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "校对稿"
                        font.bold: true
                        font.pixelSize: 13
                        color: Theme.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item { Layout.fillWidth: true }

                // Search toggle button
                Button {
                    id: searchToggleButton
                    Layout.preferredHeight: 26
                    background: Rectangle {
                        color: root.isSearchOpen ? Theme.accentSoft : (searchToggleButton.hovered ? Theme.surface : "transparent")
                        border.color: root.isSearchOpen ? Theme.accent : Theme.border
                        radius: 4
                    }
                    contentItem: Item {
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { name: "search"; size: 18; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "查找替换"; font.pixelSize: 11; color: root.isSearchOpen ? Theme.accentHover : Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
                        }
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
                        id: decreaseFontButton
                        height: 26
                        width: 26
                        enabled: root.editorFontSize > 12
                        background: Rectangle {
                            color: decreaseFontButton.hovered ? Theme.surface : "transparent"
                            border.color: Theme.border
                            radius: 4
                        }
                        contentItem: Text { text: "A-"; font.pixelSize: 10; font.bold: true; color: decreaseFontButton.enabled ? Theme.secondary : Theme.muted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        Accessible.name: "缩小编辑器字号"
                        onClicked: {
                            if (root.editorFontSize > 12) root.editorFontSize -= 1;
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: "缩小字号"
                        ToolTip.delay: 300
                    }

                    Button {
                        id: increaseFontButton
                        height: 26
                        width: 26
                        enabled: root.editorFontSize < 24
                        background: Rectangle {
                            color: increaseFontButton.hovered ? Theme.surface : "transparent"
                            border.color: Theme.border
                            radius: 4
                        }
                        contentItem: Text { text: "A+"; font.pixelSize: 10; font.bold: true; color: increaseFontButton.enabled ? Theme.secondary : Theme.muted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        Accessible.name: "放大编辑器字号"
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
                    id: copyTextButton
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    enabled: textArea.text.trim().length > 0
                    background: Rectangle {
                        color: copyTextButton.hovered ? Theme.accentSoft : Theme.background
                        border.color: copyTextButton.hovered ? Theme.accentBorder : Theme.border
                        radius: 6
                    }
                    contentItem: Item {
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { name: "copy"; size: 18; color: copyTextButton.enabled ? Theme.accent : Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                            Text { visible: root.width >= 440; text: "复制文本"; font.pixelSize: 11; font.bold: true; color: copyTextButton.enabled ? Theme.accentHover : Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    onClicked: {
                        root.appController.copyToClipboard(textArea.text);
                    }
                    Accessible.name: "复制文本"
                    ToolTip.visible: hovered
                    ToolTip.text: "复制文本"
                }

                // Word count pill
                Rectangle {
                    visible: root.width >= 480
                    Layout.preferredHeight: 24
                    radius: 12
                    color: Theme.surface
                    Layout.preferredWidth: wordCountText.implicitWidth + 14
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: wordCountText
                        anchors.centerIn: parent
                        text: `${textArea.text.trim().length} 字`
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.secondary
                    }
                }
            }
        }

        // 2. Sliding Search & Replace Bar (Modern 2-Row Layout)
        Rectangle {
            id: searchBar
            Layout.fillWidth: true
            Layout.preferredHeight: root.isSearchOpen ? 86 : 0
            visible: root.isSearchOpen
            clip: true
            color: Theme.background
            border.color: Theme.border

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
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 6

                // Row 1: Search & Navigation
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    spacing: 6

                    TextField {
                        id: searchField
                        placeholderText: "查找内容..."
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        padding: 0
                        leftPadding: 8
                        rightPadding: 8
                        background: Rectangle {
                            implicitHeight: 28
                            color: Theme.paper
                            border.color: searchField.activeFocus ? Theme.accent : Theme.border
                            radius: 4
                        }
                        onTextChanged: searchBar.updateMatches()
                        onAccepted: searchBar.nextMatch()
                    }

                    // Match counter badge
                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: matchCountText.implicitWidth + 12
                        radius: 4
                        color: searchBar.matchCount > 0 ? Theme.accentSoft : Theme.surface
                        border.color: searchBar.matchCount > 0 ? Theme.accentBorder : Theme.border
                        Text {
                            id: matchCountText
                            anchors.centerIn: parent
                            text: searchBar.matchCount > 0 ? `${searchBar.currentMatchIndex + 1}/${searchBar.matchCount}` : (searchField.text ? "无匹配" : "-")
                            font.pixelSize: 11
                            color: searchBar.matchCount > 0 ? Theme.accentHover : Theme.muted
                        }
                    }

                    Button {
                        id: previousMatchButton
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: 26
                        enabled: searchBar.matchCount > 0
                        background: Rectangle { color: previousMatchButton.hovered ? Theme.border : Theme.surface; border.color: Theme.border; radius: 4 }
                        contentItem: Item { Icon { name: "up"; size: 18; color: previousMatchButton.enabled ? Theme.secondary : Theme.muted; anchors.centerIn: parent } }
                        onClicked: searchBar.prevMatch()
                    }

                    Button {
                        id: nextMatchButton
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: 26
                        enabled: searchBar.matchCount > 0
                        background: Rectangle { color: nextMatchButton.hovered ? Theme.border : Theme.surface; border.color: Theme.border; radius: 4 }
                        contentItem: Item { Icon { name: "down"; size: 18; color: nextMatchButton.enabled ? Theme.secondary : Theme.muted; anchors.centerIn: parent } }
                        onClicked: searchBar.nextMatch()
                    }

                    Button {
                        id: closeSearchButton
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: 26
                        background: Rectangle { color: closeSearchButton.hovered ? "#fee2e2" : "transparent"; radius: 4 }
                        contentItem: Item { Icon { name: "close"; size: 18; color: Theme.secondary; anchors.centerIn: parent } }
                        onClicked: root.isSearchOpen = false
                    }
                }

                // Row 2: Replace & Actions
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    spacing: 6

                    TextField {
                        id: replaceField
                        placeholderText: "替换为..."
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        font.pixelSize: 12
                        verticalAlignment: TextInput.AlignVCenter
                        padding: 0
                        leftPadding: 8
                        rightPadding: 8
                        background: Rectangle {
                            implicitHeight: 28
                            color: Theme.paper
                            border.color: replaceField.activeFocus ? Theme.accent : Theme.border
                            radius: 4
                        }
                    }

                    Button {
                        id: replaceButton
                        Layout.preferredHeight: 26
                        text: "替换"
                        enabled: searchBar.matchCount > 0
                        background: Rectangle {
                            color: replaceButton.enabled ? (replaceButton.hovered ? Theme.accentSoft : Theme.accentSoft) : Theme.surface
                            border.color: replaceButton.enabled ? Theme.accentBorder : Theme.border
                            radius: 4
                        }
                        contentItem: Text { text: "替换"; font.pixelSize: 11; font.bold: true; color: replaceButton.enabled ? Theme.accentHover : Theme.muted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: searchBar.replaceCurrent()
                    }

                    Button {
                        id: replaceAllButton
                        Layout.preferredHeight: 26
                        text: "全部替换"
                        enabled: searchBar.matchCount > 0
                        background: Rectangle {
                            color: replaceAllButton.enabled ? (replaceAllButton.hovered ? Theme.accentSoft : Theme.accentSoft) : Theme.surface
                            border.color: replaceAllButton.enabled ? Theme.accentBorder : Theme.border
                            radius: 4
                        }
                        contentItem: Text { text: "全部替换"; font.pixelSize: 11; font.bold: true; color: replaceAllButton.enabled ? Theme.accentHover : Theme.muted; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        onClicked: searchBar.replaceAll()
                    }
                }
            }
        }

        Rectangle {
            visible: root.annotationsStale
            Layout.fillWidth: true
            Layout.preferredHeight: root.annotationsStale ? 30 : 0
            color: Theme.warningSoft
            border.color: "#fde68a"
            clip: true

            Text {
                anchors.fill: parent
                anchors.leftMargin: 12
                verticalAlignment: Text.AlignVCenter
                text: "文本已修改，OCR 标注可能已过期；重新识别可恢复框选对应关系"
                color: Theme.warning
                font.pixelSize: 11
                elide: Text.ElideRight
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
                font.family: "Microsoft YaHei UI"
                color: Theme.ink
                topPadding: 24
                bottomPadding: 24
                leftPadding: 26
                rightPadding: 26
                selectByMouse: true
                persistentSelection: true
                selectionColor: Theme.selection
                selectedTextColor: Theme.accentHover
                placeholderText: "暂无识别文本。\n\n点击上方「开始识别」，选择当前页或整篇手稿。"

                background: Rectangle {
                    color: Theme.paper
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
