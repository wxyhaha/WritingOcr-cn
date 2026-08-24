import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: root

    signal openTaskRequested(string taskId)
    signal scanQrRequested()
    signal exportTaskRequested(string taskId)
    signal deleteTaskRequested(string taskId, string taskTitle, int pageCount)

    FileDialog {
        id: fileDialog
        title: "选择手写文章图片 (单任务支持 1~10 张)"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["图片文件 (*.jpg *.jpeg *.png *.webp *.bmp)"]
        onAccepted: {
            app.importFiles(selectedFiles);
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        Column {
            id: mainColumn
            width: Math.min(root.width - 64, 1180)
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 32
            bottomPadding: 64
            spacing: 28

            // 1. Top Quick Upload Banner (居中、精致高雅的导入操作栏)
            Rectangle {
                id: bannerCard
                width: parent.width
                height: 104
                radius: 16
                color: dropArea.containsDrag ? "#f0fdf4" : "#ffffff"
                border.width: dropArea.containsDrag ? 2 : 1
                border.color: dropArea.containsDrag ? "#22c55e" : "#e2e8f0"

                // Subtle card shadow
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    color: "transparent"
                    border.color: "#0f172a0a"
                    radius: 17
                    z: -1
                }

                DropArea {
                    id: dropArea
                    anchors.fill: parent
                    onDropped: (drop) => {
                        if (drop.hasUrls) {
                            app.importFiles(drop.urls);
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    spacing: 20

                    // Banner Icon & Centered Typography
                    Row {
                        spacing: 16
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            width: 54
                            height: 54
                            radius: 14
                            color: dropArea.containsDrag ? "#dcfce7" : "#eff6ff"
                            border.color: dropArea.containsDrag ? "#86efac" : "#bfdbfe"
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: dropArea.containsDrag ? "📥" : "📝"
                                font.pixelSize: 26
                                anchors.centerIn: parent
                            }
                        }

                        Column {
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: dropArea.containsDrag ? "松开鼠标立即导入并识别" : "拖拽手写文章图片到这里开始"
                                font.bold: true
                                font.pixelSize: 16
                                color: "#0f172a"
                            }

                            Text {
                                text: "支持 JPG / PNG / WEBP · 单任务支持 1~10 张连续手写页"
                                font.pixelSize: 12
                                color: "#64748b"
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Action Buttons Trio
                    Row {
                        spacing: 12
                        Layout.alignment: Qt.AlignVCenter

                        // Primary Action: Choose from computer
                        Button {
                            height: 40
                            background: Rectangle {
                                color: parent.hovered ? "#1d4ed8" : "#2563eb"
                                radius: 8
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            contentItem: Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "📁"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "导入图片识别"; color: "white"; font.bold: true; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                            }
                            onClicked: fileDialog.open()
                        }

                        // Mobile scan upload
                        Button {
                            height: 40
                            background: Rectangle {
                                color: parent.hovered ? "#dcfce7" : "#ecfdf5"
                                border.color: parent.hovered ? "#86efac" : "#a7f3d0"
                                radius: 8
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            contentItem: Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: "📱"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "手机扫码"; color: "#047857"; font.bold: true; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                            }
                            onClicked: root.scanQrRequested()
                        }

                        // New blank task
                        Button {
                            height: 40
                            background: Rectangle {
                                color: parent.hovered ? "#f1f5f9" : "#ffffff"
                                border.color: parent.hovered ? "#94a3b8" : "#cbd5e1"
                                radius: 8
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            contentItem: Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Text { text: "➕"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "新建空白"; color: "#334155"; font.bold: true; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                            }
                            onClicked: {
                                let tid = app.taskService.createNewTask();
                                if (tid) root.openTaskRequested(tid);
                            }
                        }
                    }
                }
            }

            // 2. Section Header with Page Margins
            RowLayout {
                width: parent.width
                visible: app.taskListModel.count > 0

                Row {
                    spacing: 10
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: "我的手写文章"
                        font.bold: true
                        font.pixelSize: 17
                        color: "#0f172a"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        height: 22
                        radius: 11
                        color: "#eff6ff"
                        border.color: "#bfdbfe"
                        width: countLabel.implicitWidth + 16
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: countLabel
                            text: `${app.taskListModel.count} 篇`
                            font.pixelSize: 11
                            font.bold: true
                            color: "#1d4ed8"
                            anchors.centerIn: parent
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // 3. Document Cards Grid (方案 A：带有优雅内边距的图文卡片流)
            Flow {
                id: cardGrid
                width: parent.width
                spacing: 20
                visible: app.taskListModel.count > 0

                Repeater {
                    model: app.taskListModel

                    delegate: Rectangle {
                        id: taskCard
                        width: 270
                        height: 310
                        radius: 16
                        color: "#ffffff"
                        border.width: cardMouseArea.containsMouse ? 1.5 : 1
                        border.color: cardMouseArea.containsMouse ? "#3b82f6" : "#e2e8f0"

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        // Card elevation drop-shadow
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -1
                            color: "transparent"
                            border.color: cardMouseArea.containsMouse ? "#2563eb1f" : "#0f172a08"
                            radius: 17
                            z: -1
                        }

                        MouseArea {
                            id: cardMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                app.taskService.loadTask(model.id);
                                root.openTaskRequested(model.id);
                            }
                        }

                        // Top Framed Thumbnail Image (优雅的相框式缩略图预览)
                        Rectangle {
                            id: thumbFrame
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 10
                            height: 156
                            radius: 10
                            color: "#f1f5f9"
                            clip: true

                            // Fallback pattern when no image loaded
                            Column {
                                anchors.centerIn: parent
                                visible: coverImg.status === Image.Null || coverImg.status === Image.Error || coverImg.source == ""
                                spacing: 6

                                Text {
                                    text: "📄"
                                    font.pixelSize: 32
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: "手写文章"
                                    font.pixelSize: 11
                                    color: "#94a3b8"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            // Real Handwritten Document Thumbnail
                            Image {
                                id: coverImg
                                anchors.fill: parent
                                source: (model.coverThumbnail && model.coverThumbnail !== "")
                                        ? app.localFileToUrl(model.coverThumbnail)
                                        : ((model.coverImage && model.coverImage !== "") ? app.localFileToUrl(model.coverImage) : "")
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                mipmap: true
                                scale: cardMouseArea.containsMouse ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                            }

                            // Top-Left Page Count Badge
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 8
                                height: 22
                                radius: 6
                                color: "#d90f172a"
                                width: pageBadgeText.implicitWidth + 12

                                Text {
                                    id: pageBadgeText
                                    anchors.centerIn: parent
                                    text: `📄 ${model.pageCount} 页`
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            // Top-Right Low Confidence Warning Badge
                            Rectangle {
                                visible: model.lowConfidenceCount > 0
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                height: 22
                                radius: 6
                                color: "#f59e0b"
                                width: lowConfBadgeText.implicitWidth + 12

                                Text {
                                    id: lowConfBadgeText
                                    anchors.centerIn: parent
                                    text: `⚠️ ${model.lowConfidenceCount}`
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            // Hover CTA Overlay
                            Rectangle {
                                anchors.fill: parent
                                color: "#500f172a"
                                opacity: cardMouseArea.containsMouse ? 1.0 : 0.0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 180 } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    height: 34
                                    radius: 17
                                    color: "#2563eb"
                                    width: enterText.implicitWidth + 24

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            id: enterText
                                            text: "进入校对"
                                            color: "white"
                                            font.bold: true
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "→"
                                            color: "white"
                                            font.bold: true
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }

                        // Bottom Info & Actions with Generous Inner Padding
                        Item {
                            anchors.top: thumbFrame.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            anchors.topMargin: 8
                            anchors.bottomMargin: 12

                            Column {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 6

                                // Task Title
                                Text {
                                    width: parent.width
                                    text: model.title
                                    font.bold: true
                                    font.pixelSize: 14
                                    color: "#0f172a"
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                // Metadata row
                                Row {
                                    spacing: 8
                                    width: parent.width

                                    // Word count pill
                                    Rectangle {
                                        height: 20
                                        radius: 4
                                        color: "#f1f5f9"
                                        width: wordBadgeText.implicitWidth + 10

                                        Text {
                                            id: wordBadgeText
                                            text: `✍️ ${model.totalCharacters} 字`
                                            font.pixelSize: 11
                                            color: "#475569"
                                            anchors.centerIn: parent
                                        }
                                    }

                                    // Date
                                    Text {
                                        text: `${model.updatedAt.substring(5, 16).replace('T', ' ')}`
                                        font.pixelSize: 11
                                        color: "#94a3b8"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Card Bottom Action Buttons
                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                spacing: 8

                                Button {
                                    height: 30
                                    Layout.fillWidth: true
                                    background: Rectangle {
                                        color: parent.hovered ? "#eff6ff" : "#f8fafc"
                                        border.color: parent.hovered ? "#bfdbfe" : "#e2e8f0"
                                        radius: 6
                                    }
                                    contentItem: Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text { text: "📥"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "导出"; font.pixelSize: 11; font.bold: true; color: "#334155"; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    onClicked: root.exportTaskRequested(model.id)
                                }

                                Button {
                                    height: 30
                                    Layout.preferredWidth: 34
                                    background: Rectangle {
                                        color: parent.hovered ? "#fee2e2" : "#f8fafc"
                                        border.color: parent.hovered ? "#fca5a5" : "#e2e8f0"
                                        radius: 6
                                    }
                                    contentItem: Text {
                                        text: "🗑️"
                                        font.pixelSize: 11
                                        anchors.centerIn: parent
                                    }
                                    onClicked: root.deleteTaskRequested(model.id, model.title, model.pageCount)
                                    ToolTip.visible: hovered
                                    ToolTip.text: "删除任务"
                                    ToolTip.delay: 300
                                }
                            }
                        }
                    }
                }
            }

            // Empty State Card (when no tasks)
            Rectangle {
                visible: app.taskListModel.count === 0
                width: parent.width
                height: 220
                color: "#ffffff"
                radius: 16
                border.color: "#e2e8f0"

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Rectangle {
                        width: 56
                        height: 56
                        radius: 28
                        color: "#f8fafc"
                        border.color: "#e2e8f0"
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            text: "📂"
                            font.pixelSize: 26
                            anchors.centerIn: parent
                        }
                    }

                    Text {
                        text: "暂无历史任务"
                        font.bold: true
                        font.pixelSize: 15
                        color: "#1e293b"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "点击上方【导入图片识别】或直接拖拽图片开始数字化"
                        font.pixelSize: 13
                        color: "#64748b"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}
