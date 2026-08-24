import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "pages"
import "dialogs"

ApplicationWindow {
    id: window
    width: 1240
    height: 820
    minimumWidth: 960
    minimumHeight: 640
    visible: true
    title: "手写中文文章数字化工具 (MVP)"

    color: "#f8fafc"

    property string currentView: "home" // "home" or "proofread"

    // Header Navigation Bar
    header: Rectangle {
        height: 52
        color: "#ffffff"
        border.color: "#e2e8f0"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 16

            // App Logo & Title
            Row {
                spacing: 8
                Text { text: "✍️"; font.pixelSize: 22; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "手写文章数字化"
                    font.bold: true
                    font.pixelSize: 16
                    color: "#0f172a"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle { width: 1; height: 20; color: "#e2e8f0" }

            // Navigation tabs
            Button {
                text: "📋 任务管理"
                height: 34
                background: Rectangle {
                    color: window.currentView === "home" ? "#eff6ff" : "transparent"
                    radius: 6
                }
                contentItem: Text {
                    text: "📋 任务管理"
                    font.bold: window.currentView === "home"
                    color: window.currentView === "home" ? "#2563eb" : "#475569"
                    font.pixelSize: 13
                    anchors.centerIn: parent
                }
                onClicked: window.currentView = "home"
            }

            Button {
                text: "🔍 校对工作区"
                height: 34
                enabled: app.taskService.hasCurrentTask
                background: Rectangle {
                    color: window.currentView === "proofread" ? "#eff6ff" : "transparent"
                    radius: 6
                }
                contentItem: Text {
                    text: "🔍 校对工作区"
                    font.bold: window.currentView === "proofread"
                    color: window.currentView === "proofread" ? "#2563eb" : (app.taskService.hasCurrentTask ? "#475569" : "#94a3b8")
                    font.pixelSize: 13
                    anchors.centerIn: parent
                }
                onClicked: window.currentView = "proofread"
            }

            Item { Layout.fillWidth: true }

            // Live status pills
            Rectangle {
                height: 28
                radius: 14
                color: app.ocrService.isWorkerRunning ? "#ecfdf5" : "#fef2f2"
                border.color: app.ocrService.isWorkerRunning ? "#a7f3d0" : "#fecaca"
                width: ocrStatusText.implicitWidth + 24

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: app.ocrService.isWorkerRunning ? "#10b981" : "#ef4444"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: ocrStatusText
                        text: app.ocrService.isWorkerRunning ? "OCR 就绪" : "OCR 未连接"
                        font.pixelSize: 11
                        font.bold: true
                        color: app.ocrService.isWorkerRunning ? "#065f46" : "#991b1b"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsDialog.open()
                }
            }

            Button {
                text: "📱 手机扫码"
                height: 32
                background: Rectangle {
                    color: "#f1f5f9"
                    border.color: "#cbd5e1"
                    radius: 6
                }
                contentItem: Text {
                    text: "📱 手机扫码"
                    color: "#334155"
                    font.pixelSize: 12
                    font.bold: true
                    anchors.centerIn: parent
                }
                onClicked: qrCodeDialog.open()
            }

            Button {
                text: "⚙️ 设置"
                height: 32
                background: Rectangle {
                    color: "#f8fafc"
                    border.color: "#cbd5e1"
                    radius: 6
                }
                contentItem: Text {
                    text: "⚙️ 设置"
                    color: "#334155"
                    font.pixelSize: 12
                    anchors.centerIn: parent
                }
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
            onBackToHomeRequested: window.currentView = "home"
            onScanQrRequested: qrCodeDialog.open()
            onExportRequested: {
                exportDialog.targetTaskId = "";
                exportDialog.open();
            }
        }
    }

    // Toast Notification Banner
    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 20
        height: 40
        radius: 8
        color: toastType === "error" ? "#ef4444" : (toastType === "warning" ? "#f59e0b" : "#10b981")
        width: Math.min(toastText.implicitWidth + 40, parent.width - 40)
        opacity: 0
        visible: opacity > 0
        z: 9999

        property string toastType: "info"

        Behavior on opacity {
            NumberAnimation { duration: 250 }
        }

        Text {
            id: toastText
            anchors.centerIn: parent
            text: ""
            color: "white"
            font.bold: true
            font.pixelSize: 13
        }

        Timer {
            id: toastTimer
            interval: 3500
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
        target: app
        function onNotifyUser(msg, type) {
            toast.show(msg, type);
        }
    }

    // Dialog Instances
    QrCodeDialog { id: qrCodeDialog }
    ConfirmDialog {
        id: confirmDialog
        onConfirmed: (taskId) => {
            app.taskService.deleteTask(taskId);
        }
    }
    SettingsDialog { id: settingsDialog }
    ExportDialog { id: exportDialog }
}
