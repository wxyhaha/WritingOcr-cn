import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs 6.5
import "../components"
import "../components/Theme.js" as Theme

pragma ComponentBehavior: Bound

Item {
    id: root
    property var appController
    signal openTaskRequested(string taskId)
    signal scanQrRequested()
    signal exportTaskRequested(string taskId)
    signal deleteTaskRequested(string taskId, string taskTitle, int pageCount)
    readonly property bool hasTasks: appController.taskListModel.count > 0

    FileDialog {
        id: fileDialog
        title: "选择手稿图片（最多 10 页）"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["图片文件 (*.jpg *.jpeg *.png *.webp *.bmp)"]
        onAccepted: root.appController.importFiles(selectedFiles)
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        Column {
            width: Math.min(root.width - 64, 1180)
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 36
            bottomPadding: 40
            spacing: 24

            RowLayout {
                width: parent.width
                Column {
                    spacing: 6
                    Text { text: "我的手稿"; font.pixelSize: 28; font.bold: true; color: Theme.ink }
                    Text {
                        text: root.hasTasks ? root.appController.taskListModel.count + " 篇手稿，保存在这台电脑上" : "从一页手写开始，整理你的文字"
                        font.pixelSize: 13; color: Theme.secondary
                    }
                }
                Item { Layout.fillWidth: true }
                ActionButton { text: "手机上传"; iconName: "phone"; onClicked: root.scanQrRequested() }
                ActionButton {
                    text: "新建手稿"; quiet: true
                    onClicked: {
                        let tid = root.appController.taskService.createNewTask();
                        if (tid) root.openTaskRequested(tid);
                    }
                }
                ActionButton { text: "导入手稿"; iconName: "plus"; primary: true; onClicked: fileDialog.open() }
            }

            Rectangle {
                width: parent.width
                height: root.hasTasks ? 76 : 180
                radius: 12
                color: dropArea.containsDrag ? Theme.accentSoft : Theme.paper
                border.color: dropArea.containsDrag ? Theme.accent : Theme.border
                border.width: dropArea.containsDrag ? 2 : 1
                DropArea {
                    id: dropArea
                    anchors.fill: parent
                    onDropped: (drop) => {
                        if (drop.hasUrls) root.appController.importFiles(drop.urls);
                    }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 18
                    Icon { name: "upload"; size: 28; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        spacing: 7
                        Text {
                            text: dropArea.containsDrag ? "松开即可导入" : "将手稿照片拖到这里"
                            font.pixelSize: root.hasTasks ? 14 : 18
                            font.bold: !root.hasTasks
                            color: Theme.ink
                        }
                        Text { text: "JPG / PNG / WEBP / BMP  ·  每篇最多 10 页"; font.pixelSize: 12; color: Theme.muted }
                    }
                }
            }

            Flow {
                id: cardGrid
                width: parent.width
                spacing: 20
                Repeater {
                    model: root.appController.taskListModel
                    delegate: Rectangle {
                        id: taskCard
                        required property var model
                        required property int index
                        readonly property int columns: Math.max(1, Math.floor((cardGrid.width + 20) / 260))
                        width: (cardGrid.width - (columns - 1) * 20) / columns
                        height: 328
                        radius: 10
                        color: Theme.paper
                        border.color: openButton.hovered || openButton.visualFocus ? Theme.accentBorder : Theme.border
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Button {
                            id: openButton
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 274
                            padding: 0
                            Accessible.name: "打开手稿：" + taskCard.model.title
                            background: Item {}
                            contentItem: Item {
                                Rectangle {
                                    id: preview
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 12
                                    height: 180
                                    radius: 6
                                    color: Theme.surface
                                    clip: true
                                    Icon {
                                        anchors.centerIn: parent
                                        size: 36
                                        name: "document"
                                        color: Theme.muted
                                        visible: cover.status !== Image.Ready
                                    }
                                    Image {
                                        id: cover
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        source: taskCard.model.coverThumbnail
                                            ? root.appController.localFileToUrl(taskCard.model.coverThumbnail)
                                            : (taskCard.model.coverImage ? root.appController.localFileToUrl(taskCard.model.coverImage) : "")
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        mipmap: true
                                    }
                                }
                                Text {
                                    anchors.top: preview.bottom
                                    anchors.topMargin: 16
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    text: taskCard.model.title
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Theme.ink
                                    elide: Text.ElideRight
                                }
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.top: preview.bottom
                                    anchors.topMargin: 43
                                    text: taskCard.model.pageCount + " 页  ·  " + taskCard.model.totalCharacters + " 字  ·  "
                                        + taskCard.model.updatedAt.substring(5, 10)
                                    font.pixelSize: 12
                                    color: Theme.muted
                                }
                            }
                            onClicked: {
                                if (root.appController.taskService.loadTask(taskCard.model.id))
                                    root.openTaskRequested(taskCard.model.id);
                            }
                        }
                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 12
                            spacing: 4
                            Text {
                                Layout.fillWidth: true
                                text: taskCard.model.lowConfidenceCount > 0 ? taskCard.model.lowConfidenceCount + " 处待核对" : "手稿"
                                color: taskCard.model.lowConfidenceCount > 0 ? Theme.warning : Theme.muted
                                font.pixelSize: 12
                            }
                            ActionButton {
                                iconName: "download"; quiet: true
                                ToolTip.text: "导出手稿"
                                onClicked: root.exportTaskRequested(taskCard.model.id)
                            }
                            ActionButton {
                                iconName: "trash"; quiet: true
                                ToolTip.text: "删除手稿"
                                onClicked: root.deleteTaskRequested(taskCard.model.id, taskCard.model.title, taskCard.model.pageCount)
                            }
                        }
                    }
                }
            }
            Text {
                visible: !root.hasTasks
                anchors.horizontalCenter: parent.horizontalCenter
                text: "导入照片，识别文字，再对照原稿慢慢校订。"
                font.pixelSize: 14
                color: Theme.muted
            }
        }
    }
}
