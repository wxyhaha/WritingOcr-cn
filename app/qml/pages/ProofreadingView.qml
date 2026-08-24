import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: root

    signal backToHomeRequested()
    signal exportRequested()
    signal scanQrRequested()

    FileDialog {
        id: addImagesDialog
        title: "添加图片到当前任务"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["图片文件 (*.jpg *.jpeg *.png *.webp *.bmp)"]
        onAccepted: {
            app.importFiles(selectedFiles);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Subheader Action Bar
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: "#ffffff"
            border.color: "#e2e8f0"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                Button {
                    text: "← 返回"
                    height: 32
                    background: Rectangle { color: "#f1f5f9"; radius: 4 }
                    contentItem: Text { text: "← 任务列表"; font.pixelSize: 12; color: "#334155"; anchors.centerIn: parent }
                    onClicked: {
                        app.taskService.saveNow();
                        root.backToHomeRequested();
                    }
                }

                // Editable Title
                TextField {
                    id: titleField
                    text: app.taskService.currentTaskTitle
                    font.bold: true
                    font.pixelSize: 14
                    Layout.preferredWidth: 260
                    height: 32
                    background: Rectangle {
                        color: titleField.activeFocus ? "#ffffff" : "transparent"
                        border.color: titleField.activeFocus ? "#2563eb" : "transparent"
                        radius: 4
                    }
                    onEditingFinished: {
                        app.taskService.updateTaskTitle(text);
                    }
                }

                Item { Layout.fillWidth: true }

                // OCR Actions
                Button {
                    text: "⚡ 识别本页"
                    height: 32
                    enabled: !app.ocrService.isProcessing && app.taskService.currentPageIndex >= 0
                    background: Rectangle {
                        color: parent.enabled ? "#eff6ff" : "#f1f5f9"
                        border.color: parent.enabled ? "#bfdbfe" : "#e2e8f0"
                        radius: 4
                    }
                    contentItem: Text {
                        text: "⚡ 识别本页"
                        color: parent.enabled ? "#2563eb" : "#94a3b8"
                        font.bold: true
                        font.pixelSize: 12
                        anchors.centerIn: parent
                    }
                    onClicked: app.ocrService.recognizeCurrentPage()
                }

                Button {
                    text: "⚡⚡ 全篇识别"
                    height: 32
                    enabled: !app.ocrService.isProcessing && app.taskService.currentTaskPageCount > 0
                    background: Rectangle {
                        color: parent.enabled ? "#2563eb" : "#94a3b8"
                        radius: 4
                    }
                    contentItem: Text {
                        text: "⚡⚡ 全篇识别"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 12
                        anchors.centerIn: parent
                    }
                    onClicked: app.ocrService.recognizeCurrentTask()
                }

                Button {
                    text: "📱 手机加图"
                    height: 32
                    background: Rectangle { color: "#ecfdf5"; border.color: "#a7f3d0"; radius: 4 }
                    contentItem: Text { text: "📱 手机加图"; font.pixelSize: 12; color: "#059669"; anchors.centerIn: parent }
                    onClicked: root.scanQrRequested()
                }

                Button {
                    text: "📥 导出"
                    height: 32
                    background: Rectangle { color: "#10b981"; radius: 4 }
                    contentItem: Text { text: "📥 导出"; color: "white"; font.bold: true; font.pixelSize: 12; anchors.centerIn: parent }
                    onClicked: {
                        app.taskService.saveNow();
                        root.exportRequested();
                    }
                }
            }
        }

        // Processing Progress Bar (when OCR active)
        Rectangle {
            Layout.fillWidth: true
            height: app.ocrService.isProcessing ? 4 : 0
            color: "#e2e8f0"
            visible: app.ocrService.isProcessing

            Rectangle {
                height: parent.height
                width: app.ocrService.totalProgress > 0 ? (parent.width * app.ocrService.currentProgress / app.ocrService.totalProgress) : (parent.width * 0.3)
                color: "#2563eb"
            }
        }

        // Proofreading Dual Column Workspace
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // 1. Left Thumbnail Sidebar
                PageSidebar {
                    Layout.preferredWidth: 160
                    Layout.fillHeight: true
                    pageModel: app.pageListModel
                    currentIndex: app.taskService.currentPageIndex
                    onPageSelected: (idx) => app.taskService.selectPage(idx)
                    onPageDeleted: (idx) => app.taskService.deletePage(idx)
                    onAddPagesRequested: addImagesDialog.open()
                }

                // 2. Center: Image Viewer
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 300

                    ImageViewer {
                        id: imageViewer
                        anchors.fill: parent
                        imageSource: app.taskService.currentOriginalImage
                        blockModel: app.ocrBlockListModel
                        onBlockClicked: (idx, data) => {
                            // Block selected in image
                        }
                    }
                }

                // 3. Right: OCR Text Editor
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 300

                    TextEditorView {
                        id: textEditor
                        anchors.fill: parent
                        text: app.taskService.currentEditedText
                        blockModel: app.ocrBlockListModel
                        onTextEdited: (newTxt) => app.taskService.updateEditedText(newTxt)
                        onBlockRequested: (idx) => {
                            imageViewer.scrollToBlock(idx);
                        }
                    }
                }
            }
        }

        // Bottom Proofreading Status Toolbar
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: "#f8fafc"
            border.color: "#e2e8f0"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 16

                // Task Stats
                Row {
                    spacing: 12
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: `共 ${app.taskService.currentTaskPageCount} 页 (当前第 ${app.taskService.currentPageIndex + 1} 页)`
                        font.pixelSize: 12
                        color: "#475569"
                    }
                    Text { text: "·"; color: "#cbd5e1" }
                    Text {
                        text: `总字数: ${app.taskService.currentTaskTotalCharacters}`
                        font.pixelSize: 12
                        color: "#475569"
                    }
                    Text { text: "·"; color: "#cbd5e1" }
                    Text {
                        text: `本页低置信度: ${app.ocrBlockListModel.lowConfidenceCount} 处`
                        font.pixelSize: 12
                        font.bold: app.ocrBlockListModel.lowConfidenceCount > 0
                        color: app.ocrBlockListModel.lowConfidenceCount > 0 ? "#d97706" : "#059669"
                    }
                }

                Item { Layout.fillWidth: true }

                // Low confidence jump buttons
                Button {
                    text: "◀ 上一处低置信度"
                    height: 28
                    enabled: app.ocrBlockListModel.lowConfidenceCount > 0
                    background: Rectangle {
                        color: parent.enabled ? "#fef3c7" : "#f1f5f9"
                        border.color: parent.enabled ? "#fde68a" : "#e2e8f0"
                        radius: 4
                    }
                    contentItem: Text {
                        text: "◀ 上一处低置信度"
                        color: parent.enabled ? "#92400e" : "#94a3b8"
                        font.pixelSize: 11
                        font.bold: true
                        anchors.centerIn: parent
                    }
                    onClicked: {
                        let cur = app.ocrBlockListModel.selectedIndex;
                        let prev = app.ocrBlockListModel.findPreviousLowConfidenceIndex(cur);
                        if (prev !== -1) {
                            app.ocrBlockListModel.selectedIndex = prev;
                            imageViewer.scrollToBlock(prev);
                        }
                    }
                }

                Button {
                    text: "下一处低置信度 ▶"
                    height: 28
                    enabled: app.ocrBlockListModel.lowConfidenceCount > 0
                    background: Rectangle {
                        color: parent.enabled ? "#fef3c7" : "#f1f5f9"
                        border.color: parent.enabled ? "#fde68a" : "#e2e8f0"
                        radius: 4
                    }
                    contentItem: Text {
                        text: "下一处低置信度 ▶"
                        color: parent.enabled ? "#92400e" : "#94a3b8"
                        font.pixelSize: 11
                        font.bold: true
                        anchors.centerIn: parent
                    }
                    onClicked: {
                        let cur = app.ocrBlockListModel.selectedIndex;
                        let next = app.ocrBlockListModel.findNextLowConfidenceIndex(cur);
                        if (next !== -1) {
                            app.ocrBlockListModel.selectedIndex = next;
                            imageViewer.scrollToBlock(next);
                        }
                    }
                }

                Text {
                    text: "✓ 已自动保存"
                    font.pixelSize: 11
                    color: "#059669"
                }
            }
        }
    }
}
