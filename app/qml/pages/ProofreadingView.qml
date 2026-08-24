import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: root

    signal backToHomeRequested()
    signal scanQrRequested()
    signal exportRequested()

    FileDialog {
        id: fileDialog
        title: "添加手写文章图片"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["图片文件 (*.jpg *.jpeg *.png *.webp *.bmp)"]
        onAccepted: {
            app.importFiles(selectedFiles);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#f8fafc"

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Top Proofreading Toolbar
            Rectangle {
                Layout.fillWidth: true
                height: 52
                color: "#ffffff"
                border.color: "#e2e8f0"
                z: 10

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Button {
                        text: "← 返回主页"
                        height: 32
                        background: Rectangle {
                            color: "#f1f5f9"
                            border.color: "#cbd5e1"
                            radius: 4
                        }
                        contentItem: Text {
                            text: "← 返回主页"
                            color: "#334155"
                            font.pixelSize: 12
                            anchors.centerIn: parent
                        }
                        onClicked: {
                            app.taskService.saveNow();
                            root.backToHomeRequested();
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 24
                        color: "#e2e8f0"
                    }

                    // Editable Title
                    TextField {
                        id: titleField
                        text: app.taskService.currentTaskTitle
                        font.bold: true
                        font.pixelSize: 14
                        Layout.preferredWidth: 220
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

                    // Quick Filter Printed Text Switch
                    CheckBox {
                        id: filterPrintedCheck
                        text: "过滤印刷体"
                        checked: app.settingsService.filterPrintedText
                        onToggled: {
                            app.settingsService.filterPrintedText = checked;
                            app.taskService.applyFilterPrintedToCurrentPage(checked);
                        }
                        contentItem: Text {
                            text: filterPrintedCheck.text
                            font.pixelSize: 12
                            color: "#475569"
                            leftPadding: filterPrintedCheck.indicator.width + 4
                            verticalAlignment: Text.AlignVCenter
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

            // Processing Progress Bar Line (when OCR active)
            Rectangle {
                Layout.fillWidth: true
                height: app.ocrService.isProcessing ? 3 : 0
                color: "#e2e8f0"
                visible: app.ocrService.isProcessing

                Rectangle {
                    height: parent.height
                    width: app.ocrService.totalProgress > 0 ? (parent.width * app.ocrService.currentProgress / app.ocrService.totalProgress) : (parent.width * 0.4)
                    color: "#2563eb"
                }
            }

            // Proofreading Workspace & Floating HUD
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Left Thumbnail Page Sidebar
                    PageSidebar {
                        id: pageSidebar
                        Layout.preferredWidth: 160
                        Layout.fillHeight: true
                        pageModel: app.pageListModel
                        currentIndex: app.taskService.currentPageIndex
                        onPageSelected: (index) => {
                            app.taskService.selectPage(index);
                        }
                        onPageDeleted: (index) => {
                            app.taskService.deletePage(index);
                        }
                        onAddPagesRequested: {
                            fileDialog.open();
                        }
                    }

                    // Middle Original Image Viewer
                    ImageViewer {
                        id: imageViewer
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        imagePath: (app.taskService.currentProcessedImage !== "" ? app.taskService.currentProcessedImage : app.taskService.currentOriginalImage)
                        blockModel: app.ocrBlockListModel
                        onBlockClicked: (index, blockMap) => {
                            app.ocrBlockListModel.selectedIndex = index;
                        }
                    }

                    // Right Proofreading Text Editor
                    TextEditorView {
                        id: textEditor
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        text: app.taskService.currentEditedText
                        blockModel: app.ocrBlockListModel
                        onTextEdited: (newText) => {
                            app.taskService.updateCurrentPageText(newText);
                        }
                        onBlockSelected: (blockIndex) => {
                            imageViewer.scrollToBlock(blockIndex);
                        }
                    }
                }

                // Modern Floating Recognition Progress HUD
                Rectangle {
                    id: progressHud
                    visible: app.ocrService.isProcessing
                    width: 380
                    height: 64
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    color: "#ffffff"
                    radius: 10
                    border.color: "#bfdbfe"
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
                            running: app.ocrService.isProcessing
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: app.ocrService.progressText || "正在进行 OCR 识别..."
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: "#1e3a8a"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: `⏱️ ${app.ocrService.elapsedSeconds.toFixed(1)}s`
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#2563eb"
                                }
                            }

                            // Sub progress bar
                            ProgressBar {
                                Layout.fillWidth: true
                                from: 0
                                to: Math.max(1, app.ocrService.totalProgress)
                                value: app.ocrService.currentProgress
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
                                anchors.centerIn: parent
                            }
                            onClicked: app.ocrService.cancelRecognition()
                        }
                    }
                }
            }

            // Bottom Status Bar
            Rectangle {
                Layout.fillWidth: true
                height: 36
                color: "#ffffff"
                border.color: "#e2e8f0"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Text {
                        text: `当前第 ${app.taskService.currentPageIndex + 1} / ${app.taskService.currentTaskPageCount} 页`
                        font.pixelSize: 12
                        color: "#64748b"
                    }

                    Text {
                        text: `|  总字数: ${app.taskService.currentEditedText.length}`
                        font.pixelSize: 12
                        color: "#64748b"
                    }

                    Text {
                        text: `|  低置信度: ${app.ocrBlockListModel.lowConfidenceCount} 处`
                        font.pixelSize: 12
                        color: app.ocrBlockListModel.lowConfidenceCount > 0 ? "#b45309" : "#64748b"
                        font.bold: app.ocrBlockListModel.lowConfidenceCount > 0
                    }

                    Text {
                        visible: app.ocrService.lastDuration > 0
                        text: `|  ⚡ 最近识别耗时: ${app.ocrService.lastDuration.toFixed(1)} 秒`
                        font.pixelSize: 12
                        color: "#2563eb"
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
}
