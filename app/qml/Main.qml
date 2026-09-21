import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "pages"
import "dialogs"
import "components"
import "components/Theme.js" as Theme

ApplicationWindow {
    id: mainWindow
    width: 1280
    height: 840
    minimumWidth: 1020
    minimumHeight: 680
    visible: true
    title: currentView === "proofread" && appController.taskService.hasCurrentTask
           ? appController.taskService.currentTaskTitle + " · 手稿" : "手稿 · 手写文章数字化"
    flags: Qt.Window | Qt.FramelessWindowHint

    function toggleMaximized() {
        if (visibility === Window.Maximized) showNormal();
        else showMaximized();
    }

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

    WindowResizeHandles {
        parent: mainWindow.contentItem.parent
        anchors.fill: parent
        z: 100
        targetWindow: mainWindow
    }

    Rectangle {
        parent: mainWindow.contentItem.parent
        anchors.fill: parent
        z: 99
        color: "transparent"
        border.width: mainWindow.visibility === Window.Maximized ? 0 : 1
        border.color: Theme.border
    }

    header: Rectangle {
        objectName: "windowTitleBar"
        height: 60
        color: Theme.paper
        MouseArea {
            objectName: "titleBarDragArea"
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            property point pressPosition
            onPressed: (mouse) => { pressPosition = Qt.point(mouse.x, mouse.y); }
            onPositionChanged: (mouse) => {
                if (pressed && (Math.abs(mouse.x - pressPosition.x) > 6 || Math.abs(mouse.y - pressPosition.y) > 6))
                    mainWindow.startSystemMove();
            }
            onDoubleClicked: mainWindow.toggleMaximized()
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 10
            spacing: 12
            Icon { name: "edit"; size: 24; color: Theme.accent }
            Text { text: "手稿"; font.pixelSize: 20; font.bold: true; color: Theme.ink }
            Text {
                text: mainWindow.currentView === "home" ? "让纸上的文字，留下来。" : "校对工作台"
                font.pixelSize: 12
                color: Theme.muted
                Layout.leftMargin: 8
            }
            Item { Layout.fillWidth: true }
            ActionButton {
                visible: mainWindow.currentView === "home" && mainWindow.appController.taskService.hasCurrentTask
                text: "继续校对"
                iconName: "edit"
                quiet: true
                onClicked: mainWindow.currentView = "proofread"
            }
            Row {
                spacing: 7
                Rectangle {
                    width: 6; height: 6; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: mainWindow.appController.ocrService.isWorkerRunning ? Theme.accent : Theme.warning
                }
                Text {
                    text: mainWindow.appController.ocrService.isWorkerRunning ? "本地识别就绪" : (mainWindow.workerStarting ? "识别引擎启动中" : "识别引擎未就绪")
                    font.pixelSize: 12; color: Theme.secondary
                }
            }
            ActionButton {
                iconName: "settings"
                quiet: true
                ToolTip.text: "设置与识别引擎状态"
                onClicked: settingsDialog.open()
            }
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 20
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                color: Theme.border
            }
            Row {
                spacing: 2
                WindowControlButton {
                    objectName: "minimizeWindowButton"
                    text: "最小化"
                    iconName: "minus"
                    onClicked: mainWindow.showMinimized()
                }
                WindowControlButton {
                    objectName: "maximizeWindowButton"
                    text: mainWindow.visibility === Window.Maximized ? "还原" : "最大化"
                    iconName: mainWindow.visibility === Window.Maximized ? "restore" : "maximize"
                    onClicked: mainWindow.toggleMaximized()
                }
                WindowControlButton {
                    objectName: "closeWindowButton"
                    text: "关闭"
                    iconName: "close"
                    destructive: true
                    onClicked: mainWindow.close()
                }
            }
        }
    }

    // Main Content Area
    StackLayout {
        id: stackLayout
        anchors.fill: parent
        currentIndex: mainWindow.currentView === "home" ? 0 : 1

        TaskHomeView {
            id: homeView
            appController: mainWindow.appController
            onOpenTaskRequested: (taskId) => {
                mainWindow.currentView = "proofread";
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
            appController: mainWindow.appController
            onBackToHomeRequested: mainWindow.currentView = "home"
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
        target: mainWindow.appController
        function onNotifyUser(msg, type) {
            toast.show(msg, type);
        }
        function onNavigateToProofreading() {
            qrCodeDialog.close();
            mainWindow.currentView = "proofread";
        }
    }

    // Dialog Instances
    QrCodeDialog {
        id: qrCodeDialog
        appController: mainWindow.appController
    }
    ConfirmDialog {
        id: confirmDialog
        onConfirmed: (taskId) => {
            mainWindow.appController.taskService.deleteTask(taskId);
        }
    }
    SettingsDialog {
        id: settingsDialog
        appController: mainWindow.appController
    }
    ExportDialog {
        id: exportDialog
        appController: mainWindow.appController
    }
}
