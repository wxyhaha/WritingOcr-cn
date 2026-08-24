import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

Item {
    id: root

    signal openTaskRequested(string taskId)
    signal scanQrRequested()
    signal exportTaskRequested(string taskId)
    signal deleteTaskRequested(string taskId, string taskTitle, int pageCount)

    FileDialog {
        id: fileDialog
        title: "选择手写文章图片 (最多10张)"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["图片文件 (*.jpg *.jpeg *.png *.webp *.bmp)"]
        onAccepted: {
            app.importFiles(selectedFiles);
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: mainColumn.width
        clip: true

        Column {
            id: mainColumn
            width: Math.min(root.width - 48, 900)
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 32
            bottomPadding: 48
            spacing: 28

            // Top Hero / New Task Box
            Rectangle {
                width: parent.width
                height: 220
                radius: 12
                color: dropArea.containsDrag ? "#eff6ff" : "#ffffff"
                border.width: 2
                border.color: dropArea.containsDrag ? "#2563eb" : "#e2e8f0"

                DropArea {
                    id: dropArea
                    anchors.fill: parent
                    onDropped: (drop) => {
                        if (drop.hasUrls) {
                            app.importFiles(drop.urls);
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "📝"
                        font.pixelSize: 36
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "拖拽手写文章图片到这里开始识别"
                        font.bold: true
                        font.pixelSize: 17
                        color: "#1e293b"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "支持 JPG / PNG / WEBP 格式 · 单任务支持 1~10 张"
                        font.pixelSize: 13
                        color: "#64748b"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Row {
                        spacing: 12
                        topPadding: 6
                        anchors.horizontalCenter: parent.horizontalCenter

                        Button {
                            text: "新建空白任务"
                            height: 38
                            background: Rectangle {
                                color: "#2563eb"
                                radius: 6
                            }
                            contentItem: Text {
                                text: "新建空白任务"
                                color: "white"
                                font.bold: true
                                font.pixelSize: 13
                                anchors.centerIn: parent
                            }
                            onClicked: {
                                let tid = app.taskService.createNewTask();
                                if (tid) root.openTaskRequested(tid);
                            }
                        }

                        Button {
                            text: "从电脑选择图片"
                            height: 38
                            background: Rectangle {
                                color: "#f1f5f9"
                                border.color: "#cbd5e1"
                                radius: 6
                            }
                            contentItem: Text {
                                text: "从电脑选择图片"
                                color: "#334155"
                                font.bold: true
                                font.pixelSize: 13
                                anchors.centerIn: parent
                            }
                            onClicked: fileDialog.open()
                        }

                        Button {
                            text: "📱 手机扫码上传"
                            height: 38
                            background: Rectangle {
                                color: "#ecfdf5"
                                border.color: "#a7f3d0"
                                radius: 6
                            }
                            contentItem: Text {
                                text: "📱 手机扫码上传"
                                color: "#059669"
                                font.bold: true
                                font.pixelSize: 13
                                anchors.centerIn: parent
                            }
                            onClicked: root.scanQrRequested()
                        }
                    }
                }
            }

            // Recent Tasks Section
            Column {
                width: parent.width
                spacing: 12

                Row {
                    width: parent.width
                    Text {
                        text: "最近识别任务"
                        font.bold: true
                        font.pixelSize: 16
                        color: "#1e293b"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Tasks List
                ListView {
                    width: parent.width
                    implicitHeight: contentHeight
                    interactive: false
                    spacing: 10
                    model: app.taskListModel

                    delegate: Rectangle {
                        width: ListView.view ? ListView.view.width : 300
                        height: 76
                        radius: 8
                        color: "#ffffff"
                        border.color: "#e2e8f0"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 16

                            // Task Icon
                            Rectangle {
                                width: 44
                                height: 44
                                radius: 8
                                color: "#f8fafc"
                                border.color: "#e2e8f0"
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "📄"
                                    font.pixelSize: 20
                                }
                            }

                            // Task Title & Meta
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                width: parent.width - 340

                                Text {
                                    text: model.title
                                    font.bold: true
                                    font.pixelSize: 14
                                    color: "#0f172a"
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Row {
                                    spacing: 12
                                    Text { text: `页数: ${model.pageCount} 页`; font.pixelSize: 12; color: "#64748b" }
                                    Text { text: `字符: ${model.totalCharacters} 字`; font.pixelSize: 12; color: "#64748b" }
                                    Text {
                                        visible: model.lowConfidenceCount > 0
                                        text: `低置信度: ${model.lowConfidenceCount} 处`;
                                        font.pixelSize: 12;
                                        color: "#d97706";
                                        font.bold: true
                                    }
                                    Text { text: `更新: ${model.updatedAt.substring(0, 16).replace('T', ' ')}`; font.pixelSize: 11; color: "#94a3b8" }
                                }
                            }

                            Item { width: 1; height: 1 }

                            // Action buttons
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Button {
                                    text: "打开校对"
                                    height: 32
                                    background: Rectangle {
                                        color: "#eff6ff"
                                        border.color: "#bfdbfe"
                                        radius: 4
                                    }
                                    contentItem: Text {
                                        text: "打开校对"
                                        color: "#2563eb"
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.centerIn: parent
                                    }
                                    onClicked: {
                                        app.taskService.loadTask(model.id);
                                        root.openTaskRequested(model.id);
                                    }
                                }

                                Button {
                                    text: "导出"
                                    height: 32
                                    background: Rectangle {
                                        color: "#f1f5f9"
                                        border.color: "#cbd5e1"
                                        radius: 4
                                    }
                                    contentItem: Text {
                                        text: "导出"
                                        color: "#334155"
                                        font.pixelSize: 12
                                        anchors.centerIn: parent
                                    }
                                    onClicked: root.exportTaskRequested(model.id)
                                }

                                Button {
                                    text: "删除"
                                    height: 32
                                    background: Rectangle {
                                        color: "#fef2f2"
                                        border.color: "#fecaca"
                                        radius: 4
                                    }
                                    contentItem: Text {
                                        text: "删除"
                                        color: "#dc2626"
                                        font.pixelSize: 12
                                        anchors.centerIn: parent
                                    }
                                    onClicked: root.deleteTaskRequested(model.id, model.title, model.pageCount)
                                }
                            }
                        }
                    }
                }

                // Empty Tasks State
                Rectangle {
                    visible: app.taskListModel.rowCount() === 0
                    width: parent.width
                    height: 120
                    color: "#ffffff"
                    radius: 8
                    border.color: "#e2e8f0"

                    Text {
                        anchors.centerIn: parent
                        text: "暂无历史任务，点击上方按钮或拖拽图片即可开始！"
                        color: "#94a3b8"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
