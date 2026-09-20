import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "pages"
import "dialogs"

ApplicationWindow {
    id: window
    width: 1280
    height: 840
    minimumWidth: 1020
    minimumHeight: 680
    visible: true
    title: "手写中文文章数字化工具"

    color: "#f8fafc"

    property var appController: app
    property string currentView: "home" // "home" or "proofread"
    readonly property bool workerStarting: !appController.ocrService.isWorkerRunning
                                            && (appController.ocrService.workerStatusMessage.indexOf("初始化") >= 0
                                                || appController.ocrService.workerStatusMessage.indexOf("启动") >= 0)

    // Modern Header Navigation Bar
    header: Rectangle {
        height: 56
        color: "#ffffff"
        border.color: "#e2e8f0"
        z: 100

        // Subtle bottom border shadow
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#e2e8f0"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 16
            Layout.minimumWidth: 0

            // App Brand Logo & Title
            Row {
                spacing: 10
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: 32
                    height: 32
                    radius: 8
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#3b82f6" }
                        GradientStop { position: 1.0; color: "#1d4ed8" }
                    }
                    Text {
                        text: "✍️"
                        font.pixelSize: 18
                        anchors.centerIn: parent
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Row {
                        spacing: 6
                        Text {
                            text: "手写文章数字化"
                            font.bold: true
                            font.pixelSize: 15
                            color: "#0f172a"
                        }
                        Rectangle {
                            width: 36
                            height: 16
                            radius: 8
                            color: "#eff6ff"
                            border.color: "#bfdbfe"
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "PRO"
                                font.pixelSize: 9
                                font.bold: true
                                color: "#2563eb"
                                anchors.centerIn: parent
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 22
                color: "#e2e8f0"
                Layout.leftMargin: 8
                Layout.rightMargin: 8
            }

            // Segmented Navigation Tabs
            Rectangle {
                Layout.preferredHeight: 36
                radius: 8
                color: "#f1f5f9"
                Layout.preferredWidth: 220
                Layout.minimumWidth: 180
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    // Tab 1: Home
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: window.currentView === "home" ? "#ffffff" : "transparent"
                        border.color: window.currentView === "home" ? "#e2e8f0" : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "📋"
                                font.pixelSize: 12
                            }
                            Text {
                                text: "任务管理"
                                font.bold: window.currentView === "home"
                                font.pixelSize: 12
                                color: window.currentView === "home" ? "#2563eb" : "#64748b"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.currentView = "home"
                        }
                    }

                    // Tab 2: Proofreading
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: window.currentView === "proofread" ? "#ffffff" : "transparent"
                        border.color: window.currentView === "proofread" ? "#e2e8f0" : "transparent"
                        opacity: window.appController.taskService.hasCurrentTask ? 1.0 : 0.45

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "🔍"
                                font.pixelSize: 12
                            }
                            Text {
                                text: "校对工作区"
                                font.bold: window.currentView === "proofread"
                                font.pixelSize: 12
                                color: window.currentView === "proofread" ? "#2563eb" : "#64748b"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: window.appController.taskService.hasCurrentTask
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: window.currentView = "proofread"
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Right Status and Tools
            Row {
                spacing: 10
                Layout.alignment: Qt.AlignVCenter

                // Live OCR status indicator pill
                Rectangle {
                    height: 30
                    radius: 15
                    color: window.appController.ocrService.isWorkerRunning ? "#ecfdf5" : (window.workerStarting ? "#fffbeb" : "#fef2f2")
                    border.color: window.appController.ocrService.isWorkerRunning ? "#a7f3d0" : (window.workerStarting ? "#fde68a" : "#fecaca")
                    width: ocrStatusText.implicitWidth + 28
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            width: 7
                            height: 7
                            radius: 3.5
                            color: window.appController.ocrService.isWorkerRunning ? "#10b981" : (window.workerStarting ? "#f59e0b" : "#ef4444")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: ocrStatusText
                            text: window.appController.ocrService.isWorkerRunning ? "OCR 就绪" : (window.workerStarting ? "OCR 启动中" : "OCR 未就绪")
                            font.pixelSize: 11
                            font.bold: true
                            color: window.appController.ocrService.isWorkerRunning ? "#047857" : (window.workerStarting ? "#b45309" : "#b91c1c")
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!window.appController.ocrService.isWorkerRunning) {
                                window.appController.ocrService.startWorkerProcess();
                            }
                            settingsDialog.open();
                        }
                        ToolTip.visible: containsMouse
                        ToolTip.text: window.appController.ocrService.workerStatusMessage || "本地 PaddleOCR 引擎状态"
                        ToolTip.delay: 300
                    }
                }

                // Mobile QR button
                Button {
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    background: Rectangle {
                        color: "#f8fafc"
                        border.color: "#cbd5e1"
                        radius: 6
                    }
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "📱"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "手机扫码"; font.pixelSize: 12; font.bold: true; color: "#334155"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    onClicked: qrCodeDialog.open()
                }

                // Settings button
                Button {
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    background: Rectangle {
                        color: "#f8fafc"
                        border.color: "#cbd5e1"
                        radius: 6
                    }
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "⚙️"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "设置"; font.pixelSize: 12; color: "#334155"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    onClicked: settingsDialog.open()
                }
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
        color: toastType === "error" ? "#ef4444" : (toastType === "warning" ? "#f59e0b" : "#10b981")
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
            Text {
                text: toast.toastType === "error" ? "❌" : (toast.toastType === "warning" ? "⚠️" : "✅")
                font.pixelSize: 13
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
