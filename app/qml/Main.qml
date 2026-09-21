import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "pages"
import "dialogs"
import "components"
import "components/Theme.js" as Theme

ApplicationWindow {
    id: window
    width: 1280
    height: 840
    minimumWidth: 1020
    minimumHeight: 680
    visible: true
    title: "手写中文文章数字化工具"

    color: Theme.background
    background: Rectangle { color: Theme.background }

    property var appController: app
    property string currentView: "home" // "home" or "proofread"
    readonly property bool workerStarting: !appController.ocrService.isWorkerRunning
                                            && (appController.ocrService.workerStatusMessage.indexOf("初始化") >= 0
                                                || appController.ocrService.workerStatusMessage.indexOf("启动") >= 0)

    font.family: "Microsoft YaHei UI"
    palette.highlight: Theme.accent
    palette.highlightedText: Theme.paper
    palette.button: Theme.paper
    palette.buttonText: Theme.ink
    palette.window: Theme.background
    palette.windowText: Theme.ink
    palette.text: Theme.ink
    palette.base: Theme.paper

    header: Rectangle {
        height: window.currentView === "home" ? 68 : 52
        color: Theme.paper
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 24
            spacing: 12
            Icon { name: "edit"; size: 24; color: Theme.accent }
            Text { text: "手稿"; font.pixelSize: 20; font.bold: true; color: Theme.ink }
            Text {
                text: window.currentView === "home" ? "让纸上的文字，留下来。" : "校对工作台"
                font.pixelSize: 12
                color: Theme.muted
                Layout.leftMargin: 8
            }
            Item { Layout.fillWidth: true }
            ActionButton {
                visible: window.currentView === "home" && window.appController.taskService.hasCurrentTask
                text: "继续校对"
                iconName: "edit"
                quiet: true
                onClicked: window.currentView = "proofread"
            }
            Row {
                spacing: 7
                Rectangle {
                    width: 6; height: 6; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: window.appController.ocrService.isWorkerRunning ? Theme.accent : Theme.warning
                }
                Text {
                    text: window.appController.ocrService.isWorkerRunning ? "本地识别就绪" : (window.workerStarting ? "识别引擎启动中" : "识别引擎未就绪")
                    font.pixelSize: 12; color: Theme.secondary
                }
            }
            ActionButton {
                iconName: "settings"
                quiet: true
                ToolTip.text: "设置与识别引擎状态"
                onClicked: settingsDialog.open()
            }
        }
    }

    // Main Content Area
    StackLayout {
        id: stackLayout
        anchors.fill: parent
        currentIndex: window.currentView === "home" ? 0 : 1

        TaskHomeView {
            id: homeView
            appController: window.appController
            onOpenTaskRequested: (taskId) => {
                window.currentView = "proofread";
            }
            onScanQrRequested: qrCodeDialog.open()
            onExportTaskRequested: (taskId) => {
                exportDialog.targetTaskId = taskId;
                exportDialog.open();
            }
            onDeleteTaskRequested: (taskId, title, count) => {
                confirmDialog.targetTaskId = taskId;
                confirmDialog.targetTaskTitle = title;
                confirmDialog.targetPageCount = count;
                confirmDialog.open();
            }
        }

        ProofreadingView {
            id: proofreadView
            appController: window.appController
            onBackToHomeRequested: window.currentView = "home"
            onScanQrRequested: qrCodeDialog.open()
            onExportRequested: {
                exportDialog.targetTaskId = "";
                exportDialog.open();
            }
        }
    }

    // Modern Floating Toast Notification Banner
    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 16
        height: 42
        radius: 8
        color: toastType === "error" ? Theme.danger : (toastType === "warning" ? Theme.warning : Theme.accent)
        width: Math.min(toastContentRow.implicitWidth + 36, parent.width - 40)
        opacity: 0
        visible: opacity > 0
        z: 9999

        property string toastType: "info"

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
        }

        Row {
            id: toastContentRow
            anchors.centerIn: parent
            spacing: 8
            Icon {
                name: toast.toastType === "error" ? "close" : (toast.toastType === "warning" ? "warning" : "check")
                color: Theme.paper
                size: 20
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: toastText
                text: ""
                color: "white"
                font.bold: true
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Timer {
            id: toastTimer
            interval: 3200
            onTriggered: toast.opacity = 0
        }

        function show(msg, type) {
            toastText.text = msg;
            toast.toastType = type || "info";
            toast.opacity = 1;
            toastTimer.restart();
        }
    }

    Connections {
        target: window.appController
        function onNotifyUser(msg, type) {
            toast.show(msg, type);
        }
        function onNavigateToProofreading() {
            qrCodeDialog.close();
            window.currentView = "proofread";
        }
    }

    // Dialog Instances
    QrCodeDialog {
        id: qrCodeDialog
        appController: window.appController
    }
    ConfirmDialog {
        id: confirmDialog
        onConfirmed: (taskId) => {
            window.appController.taskService.deleteTask(taskId);
        }
    }
    SettingsDialog {
        id: settingsDialog
        appController: window.appController
    }
    ExportDialog {
        id: exportDialog
        appController: window.appController
    }
}
