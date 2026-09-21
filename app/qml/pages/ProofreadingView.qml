import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs 6.5
import "../components"
import QtCore
import "../components/Theme.js" as Theme

pragma ComponentBehavior: Bound

Item {
    id: root
    objectName: "proofreadingView"

    property bool pagesVisible: true
    Settings {
        id: workspaceSettings
        category: "ProofreadingWorkspace"
        property real imageFraction: 0.5
        property alias pagesVisible: root.pagesVisible
    }

    property var appController

    signal backToHomeRequested()
    signal scanQrRequested()
    signal exportRequested()

    property string saveIndicatorText: "已自动保存"
    property color saveIndicatorColor: Theme.accent
    property bool saveFailed: false
    property int pendingDeletePageIndex: -1
    property bool textAnnotationsStale: false

    Timer {
        id: saveIndicatorTimer
        interval: 2400
        onTriggered: {
            if (!root.saveFailed) {
                root.saveIndicatorText = "已自动保存";
                root.saveIndicatorColor = Theme.accent;
            }
        }
    }

    Connections {
        target: root.appController.taskService
        function onCurrentPageChanged() {
            root.textAnnotationsStale = false;
        }
        function onTaskSaved() {
            root.saveFailed = false;
            root.saveIndicatorText = "已保存";
            root.saveIndicatorColor = Theme.accent;
            saveIndicatorTimer.restart();
        }
        function onTaskError(message) {
            if (message.indexOf("保存") < 0) {
                return;
            }
            root.saveFailed = true;
            root.saveIndicatorText = "保存失败";
            root.saveIndicatorColor = Theme.danger;
            saveIndicatorTimer.stop();
        }
    }

    Connections {
        target: root.appController.ocrService
        function onPageOcrCompleted(pageId) {
            if (pageId === root.appController.taskService.currentPageId) {
                root.textAnnotationsStale = false;
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+S"
        onActivated: root.appController.taskService.saveNow()
    }

    FileDialog {
        id: fileDialog
        title: "添加手写文章图片"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["图片文件 (*.jpg *.jpeg *.png *.webp *.bmp)"]
        onAccepted: {
            root.appController.importFiles(selectedFiles);
        }
    }

    Dialog {
        id: deletePageDialog
        title: "删除页面"
        modal: true
        anchors.centerIn: parent
        width: Math.min(420, Math.max(340, parent.width - 32))
        height: Math.min(260, Math.max(230, parent.height - 32))
        padding: 0

        background: Rectangle {
            color: Theme.paper
            radius: 16
            border.color: Theme.border

            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                color: "transparent"
                border.color: "#1e293b14"
                radius: 20
                z: -1
            }
        }

        onAccepted: {
            if (root.pendingDeletePageIndex >= 0) {
                root.appController.taskService.deletePage(root.pendingDeletePageIndex);
            }
            root.pendingDeletePageIndex = -1;
        }
        onRejected: root.pendingDeletePageIndex = -1

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                color: Theme.paper
                radius: 16

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16

                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter
                        Icon { name: "warning"; size: 18; color: Theme.warning }
                        Text { text: "删除页面"; font.bold: true; font.pixelSize: 15; color: Theme.ink }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        id: closeDeletePageButton
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        background: Rectangle {
                            color: closeDeletePageButton.hovered ? Theme.surface : "transparent"
                            radius: 15
                        }
                        contentItem: Item {
                            Icon { name: "close"; color: Theme.secondary; size: 18; anchors.centerIn: parent }
                        }
                        Accessible.name: "关闭删除页面对话框"
                        onClicked: deletePageDialog.reject()
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.border
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 20
                spacing: 10

                Text {
                    text: "确定删除当前页面吗？"
                    font.bold: true
                    font.pixelSize: 14
                    color: Theme.ink
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.warningSoft
                    border.color: "#ead7a7"
                    radius: 8

                    Text {
                        anchors.fill: parent
                        anchors.margins: 12
                        text: "页面图片、OCR 结果和校对文本都会从当前任务中移除，此操作不可撤销。"
                        font.pixelSize: 12
                        color: Theme.warning
                        wrapMode: Text.Wrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: Theme.paper
                radius: 16

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: Theme.border
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Button {
                        id: cancelDeletePageButton
                        width: 80
                        height: 36
                        background: Rectangle {
                            color: cancelDeletePageButton.hovered ? Theme.border : Theme.surface
                            border.color: Theme.border
                            radius: 6
                        }
                        contentItem: Text {
                            text: "取消"
                            color: Theme.secondary
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        Accessible.name: "取消删除页面"
                        onClicked: deletePageDialog.reject()
                    }

                    Button {
                        id: confirmDeletePageButton
                        width: 96
                        height: 36
                        background: Rectangle {
                            color: confirmDeletePageButton.hovered ? Theme.danger : "#c05a4f"
                            radius: 6
                        }
                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Icon { name: "trash"; color: Theme.paper; size: 17; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "删除页面"; color: Theme.paper; font.bold: true; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                        Accessible.name: "确认删除页面"
                        onClicked: deletePageDialog.accept()
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: Theme.paper
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10
                    ActionButton {
                        iconName: "left"; text: "手稿库"; quiet: true
                        onClicked: {
                            if (root.appController.taskService.saveNow()) root.backToHomeRequested();
                        }
                    }
                    ActionButton {
                        iconName: "sidebar"; quiet: true
                        ToolTip.text: root.pagesVisible ? "收起页面列表" : "展开页面列表"
                        onClicked: root.pagesVisible = !root.pagesVisible
                    }
                    TextField {
                        id: titleField
                        text: root.appController.taskService.currentTaskTitle
                        Layout.fillWidth: true
                        Layout.minimumWidth: 100
                        Layout.preferredHeight: 36
                        font.pixelSize: 16
                        font.bold: true
                        color: Theme.ink
                        selectByMouse: true
                        background: Rectangle {
                            radius: 6
                            color: titleField.activeFocus ? Theme.paper : "transparent"
                            border.color: titleField.activeFocus ? Theme.accent : "transparent"
                        }
                        onEditingFinished: root.appController.taskService.updateTaskTitle(text)
                    }
                    CheckBox {
                        id: filterPrintedCheck
                        objectName: "filterPrintedCheck"
                        text: "过滤印刷体"
                        checked: root.appController.settingsService.filterPrintedText
                        implicitHeight: 34
                        spacing: 8
                        padding: 0
                        indicator: Rectangle {
                            width: 22
                            height: 22
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 5
                            color: filterPrintedCheck.checked ? Theme.accent : Theme.paper
                            border.width: filterPrintedCheck.visualFocus ? 2 : 1
                            border.color: filterPrintedCheck.checked ? Theme.accent : Theme.border

                            Icon {
                                visible: filterPrintedCheck.checked
                                anchors.centerIn: parent
                                name: "check"
                                size: 15
                                color: Theme.paper
                            }
                        }
                        contentItem: Text {
                            text: filterPrintedCheck.text
                            color: Theme.secondary
                            font.pixelSize: 12
                            leftPadding: filterPrintedCheck.indicator.width + filterPrintedCheck.spacing
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                        }
                        onToggled: {
                            root.appController.settingsService.filterPrintedText = checked;
                            root.appController.taskService.applyFilterPrintedToCurrentPage(checked);
                        }
                    }
                    ActionButton {
                        id: recognizeButton
                        objectName: "recognizeButton"
                        text: root.appController.ocrService.isProcessing ? "正在识别" : "开始识别"
                        iconName: "scan"
                        trailingIconName: root.appController.ocrService.isProcessing ? "" : "down"
                        primary: true
                        enabled: !root.appController.ocrService.isProcessing && root.appController.taskService.currentTaskPageCount > 0
                        onClicked: recognitionMenu.open()
                        Menu {
                            id: recognitionMenu
                            objectName: "recognitionMenu"
                            x: 0
                            y: recognizeButton.height + 6
                            width: 188
                            padding: 6
                            font.family: "Microsoft YaHei UI"
                            font.pixelSize: 13
                            background: Rectangle {
                                color: Theme.paper
                                border.color: Theme.border
                                radius: 9

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    color: "transparent"
                                    border.color: "#1e293b10"
                                    radius: 8
                                }
                            }
                            MenuActionItem {
                                iconName: "document"
                                text: "识别当前页"
                                enabled: root.appController.taskService.currentPageIndex >= 0
                                onTriggered: root.appController.ocrService.recognizeCurrentPage()
                            }
                            MenuActionItem {
                                iconName: "scan"
                                text: "识别整篇手稿"
                                onTriggered: root.appController.ocrService.recognizeCurrentTask()
                            }
                        }
                    }
                    ActionButton { text: "手机加图"; iconName: "phone"; onClicked: root.scanQrRequested() }
                    ActionButton {
                        text: "导出"; iconName: "download"
                        onClicked: {
                            if (root.appController.taskService.saveNow()) root.exportRequested();
                        }
                    }
                }
            }

            // Processing Progress Bar Line (when OCR active)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.appController.ocrService.isProcessing ? 3 : 0
                color: Theme.border
                visible: root.appController.ocrService.isProcessing

                Rectangle {
                    height: parent.height
                    width: root.appController.ocrService.totalProgress > 0
                           ? parent.width * Math.max(0, Math.min(1, root.appController.ocrService.currentProgress / root.appController.ocrService.totalProgress))
                           : (parent.width * 0.4)
                    color: Theme.accent
                }
            }

            // Proofreading Workspace & Floating HUD
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                SplitView {
                    id: workspaceSplit
                    objectName: "workspaceSplit"
                    anchors.fill: parent
                    orientation: Qt.Horizontal
                    onResizingChanged: {
                        if (!resizing && width > 0)
                            workspaceSettings.imageFraction = imageViewer.width / Math.max(1, imageViewer.width + textEditor.width);
                    }
                    handle: Rectangle {
                        implicitWidth: 7
                        color: SplitHandle.pressed ? Theme.accentBorder : SplitHandle.hovered ? Theme.accentSoft : Theme.background
                        Rectangle { anchors.centerIn: parent; width: 1; height: 32; color: Theme.border }
                    }

                    // Left Thumbnail Page Sidebar
                    PageSidebar {
                        id: pageSidebar
                        objectName: "pageSidebar"
                        appController: root.appController
                        visible: root.pagesVisible
                        SplitView.preferredWidth: 164
                        SplitView.minimumWidth: 140
                        SplitView.maximumWidth: 230
                        pageModel: root.appController.pageListModel
                        currentIndex: root.appController.taskService.currentPageIndex
                        onPageSelected: (index) => {
                            root.appController.taskService.selectPage(index);
                        }
                        onPageDeleted: (index) => {
                            root.pendingDeletePageIndex = index;
                            deletePageDialog.open();
                        }
                        onAddPagesRequested: {
                            fileDialog.open();
                        }
                    }

                    // Middle Original Image Viewer
                    ImageViewer {
                        id: imageViewer
                        objectName: "imageViewer"
                        SplitView.preferredWidth: (workspaceSplit.width - (root.pagesVisible ? pageSidebar.width + 7 : 0) - 7) * workspaceSettings.imageFraction
                        SplitView.minimumWidth: 260
                        appController: root.appController
                        imagePath: (root.appController.taskService.currentProcessedImage !== "" ? root.appController.taskService.currentProcessedImage : root.appController.taskService.currentOriginalImage)
                        blockModel: root.appController.ocrBlockListModel
                        onBlockClicked: (index, blockMap) => {
                            root.appController.ocrBlockListModel.selectedIndex = index;
                            textEditor.selectTextForBlock(index);
                        }
                    }

                    // Right Proofreading Text Editor
                    TextEditorView {
                        id: textEditor
                        objectName: "textEditor"
                        SplitView.fillWidth: true
                        SplitView.minimumWidth: 360
                        appController: root.appController
                        text: root.appController.taskService.currentEditedText
                        blockModel: root.appController.ocrBlockListModel
                        annotationsStale: root.textAnnotationsStale
                        onTextEdited: (newText) => {
                            root.textAnnotationsStale = true;
                            root.saveFailed = false;
                            root.saveIndicatorText = "待保存";
                            root.saveIndicatorColor = Theme.warning;
                            saveIndicatorTimer.stop();
                            root.appController.taskService.updateEditedText(newText);
                        }
                        onBlockSelected: (blockIndex) => {
                            imageViewer.focusBlock(blockIndex);
                        }
                    }
                }

                // Modern Floating Recognition Progress HUD
                Rectangle {
                    id: progressHud
                    visible: root.appController.ocrService.isProcessing
                    width: Math.min(380, Math.max(280, parent.width - 32))
                    height: 64
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    color: Theme.paper
                    radius: 10
                    border.color: Theme.accentBorder
                    z: 50

                    // Drop shadow effect simulation
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        color: "transparent"
                        border.color: "#1e40af1a"
                        radius: 12
                        z: -1
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        BusyIndicator {
                            running: root.appController.ocrService.isProcessing
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            contentItem: Item {
                                Icon {
                                    anchors.centerIn: parent
                                    name: "scan"
                                    size: 26
                                    color: Theme.accent
                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 900
                                        loops: Animation.Infinite
                                        running: root.appController.ocrService.isProcessing
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: root.appController.ocrService.progressText || "正在进行 OCR 识别..."
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: "#1e3a8a"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: `${root.appController.ocrService.elapsedSeconds.toFixed(1)}s`
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.accent
                                }
                            }

                            // Sub progress bar
                            ProgressBar {
                                Layout.fillWidth: true
                                from: 0
                                to: Math.max(1, root.appController.ocrService.totalProgress)
                                value: root.appController.ocrService.currentProgress
                                background: Rectangle {
                                    implicitHeight: 4
                                    height: 4
                                    radius: 2
                                    color: Theme.border
                                }
                                contentItem: Item {
                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1, progressHudProgress.value / progressHudProgress.to))
                                        height: parent.height
                                        radius: 2
                                        color: Theme.accent
                                    }
                                }
                                id: progressHudProgress
                            }
                        }

                        Button {
                            text: "取消"
                            Layout.preferredHeight: 28
                            background: Rectangle {
                                color: "#fee2e2"
                                border.color: "#fca5a5"
                                radius: 4
                            }
                            contentItem: Text {
                                text: "取消"
                                font.pixelSize: 11
                                color: "#b91c1c"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: root.appController.ocrService.cancelRecognition()
                        }
                    }
                }
            }

            // Bottom Status Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                color: Theme.paper
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 10

                    Text {
                        text: `${Math.max(0, root.appController.taskService.currentPageIndex + 1)} / ${root.appController.taskService.currentTaskPageCount} 页`
                        font.pixelSize: 12
                        color: Theme.secondary
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 14
                        color: Theme.border
                    }

                    Text {
                        text: `总字数 ${root.appController.taskService.currentEditedText.length}`
                        font.pixelSize: 12
                        color: Theme.secondary
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 14
                        color: Theme.border
                    }

                    RowLayout {
                        spacing: 5

                        Icon {
                            name: "warning"
                            size: 14
                            color: root.appController.ocrBlockListModel.lowConfidenceCount > 0 ? Theme.warning : Theme.muted
                        }
                        Text {
                            text: `低置信度 ${root.appController.ocrBlockListModel.lowConfidenceCount} 处`
                            font.pixelSize: 12
                            color: root.appController.ocrBlockListModel.lowConfidenceCount > 0 ? Theme.warning : Theme.secondary
                            font.bold: root.appController.ocrBlockListModel.lowConfidenceCount > 0
                        }
                    }


                    Item { Layout.fillWidth: true }

                    // Low confidence jump buttons
                    Button {
                        id: previousLowConfidenceButton
                        text: "上一处疑点"
                        implicitWidth: 88
                        Layout.preferredHeight: 28
                        padding: 0
                        hoverEnabled: true
                        enabled: root.appController.ocrBlockListModel.lowConfidenceCount > 0
                        background: Rectangle {
                            color: !previousLowConfidenceButton.enabled ? Theme.surface
                                   : previousLowConfidenceButton.down || previousLowConfidenceButton.hovered
                                   ? Theme.warningSoft : Theme.paper
                            border.color: previousLowConfidenceButton.enabled ? "#e7c76b" : Theme.border
                            radius: 7
                        }
                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Icon {
                                    name: "up"
                                    size: 13
                                    color: previousLowConfidenceButton.enabled ? Theme.warning : Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: previousLowConfidenceButton.text
                                    color: previousLowConfidenceButton.enabled ? Theme.warning : Theme.muted
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        onClicked: {
                            let cur = root.appController.ocrBlockListModel.selectedIndex;
                            let prev = root.appController.ocrBlockListModel.findPreviousLowConfidenceIndex(cur);
                            if (prev !== -1) {
                                root.appController.ocrBlockListModel.selectedIndex = prev;
                                imageViewer.focusBlock(prev);
                                textEditor.selectTextForBlock(prev);
                            }
                        }
                    }

                    Button {
                        id: nextLowConfidenceButton
                        text: "下一处疑点"
                        implicitWidth: 88
                        Layout.preferredHeight: 28
                        padding: 0
                        hoverEnabled: true
                        enabled: root.appController.ocrBlockListModel.lowConfidenceCount > 0
                        background: Rectangle {
                            color: !nextLowConfidenceButton.enabled ? Theme.surface
                                   : nextLowConfidenceButton.down || nextLowConfidenceButton.hovered
                                   ? Theme.warningSoft : Theme.paper
                            border.color: nextLowConfidenceButton.enabled ? "#e7c76b" : Theme.border
                            radius: 7
                        }
                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Icon {
                                    name: "down"
                                    size: 13
                                    color: nextLowConfidenceButton.enabled ? Theme.warning : Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: nextLowConfidenceButton.text
                                    color: nextLowConfidenceButton.enabled ? Theme.warning : Theme.muted
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        onClicked: {
                            let cur = root.appController.ocrBlockListModel.selectedIndex;
                            let next = root.appController.ocrBlockListModel.findNextLowConfidenceIndex(cur);
                            if (next !== -1) {
                                root.appController.ocrBlockListModel.selectedIndex = next;
                                imageViewer.focusBlock(next);
                                textEditor.selectTextForBlock(next);
                            }
                        }
                    }

                    Text {
                        text: root.saveIndicatorText
                        font.pixelSize: 11
                        color: root.saveIndicatorColor
                    }
                }
            }
        }
    }
}
