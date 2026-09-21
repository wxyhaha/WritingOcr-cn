import QtQuick
import QtQuick.Controls
import QtTest
import "../app/qml"
import "../app/qml/dialogs"

Item {
    width: 1280
    height: 840
    Main {
        id: preview
        appController: mock
        QtObject {
            id: mock
            signal notifyUser(string msg, string type)
            signal navigateToProofreading
            property var taskListModel: tasks
            property var pageListModel: pages
            property var ocrBlockListModel: blocks
            property var taskService: task
            property var ocrService: ocr
            property var settingsService: settings
            property var lanUploadService: lan
            property var exportService: exporter
            function localFileToUrl(path) {
                return path;
            }
        }
        ListModel {
            id: tasks
            Component.onCompleted: {
                append({
                        "title": "秋日随笔",
                        "id": "preview",
                        "pageCount": 3,
                        "totalCharacters": 826,
                        "updatedAt": "2026-09-21T10:00",
                        "lowConfidenceCount": 4,
                        "coverImage": "",
                        "coverThumbnail": ""
                    });
                append({
                        "title": "关于阅读的几段记录",
                        "id": "preview2",
                        "pageCount": 2,
                        "totalCharacters": 532,
                        "updatedAt": "2026-09-20T10:00",
                        "lowConfidenceCount": 0,
                        "coverImage": "",
                        "coverThumbnail": ""
                    });
                append({
                        "title": "给远方的一封信",
                        "id": "preview3",
                        "pageCount": 1,
                        "totalCharacters": 310,
                        "updatedAt": "2026-09-18T10:00",
                        "lowConfidenceCount": 2,
                        "coverImage": "",
                        "coverThumbnail": ""
                    });
            }
        }
        ListModel {
            id: pages
            ListElement {
                thumbnailPath: ""
                originalImagePath: ""
                lowConfidenceCount: 4
            }
            ListElement {
                thumbnailPath: ""
                originalImagePath: ""
                lowConfidenceCount: 0
            }
            ListElement {
                thumbnailPath: ""
                originalImagePath: ""
                lowConfidenceCount: 0
            }
        }
        ListModel {
            id: blocks
            property int selectedIndex: -1
            property int lowConfidenceCount: 4
            property int totalCount: 0
            function findBlockIndexForCursor() {
                return -1;
            }
        }
        QtObject {
            id: task
            property bool hasCurrentTask: true
            property string currentTaskTitle: "秋日随笔"
            property int currentTaskPageCount: 3
            property int currentPageIndex: 0
            property string currentPageId: "preview"
            property string currentProcessedImage: ""
            property string currentOriginalImage: ""
            property string currentEditedText: "秋日随笔\n\n午后，阳光从窗边缓缓移过，落在摊开的笔记本上。那些写在纸上的句子，记录着当时的心情，也留下了时间的痕迹。\n\n整理手稿，是重新阅读过去的自己。偶尔遇见一个模糊的字，停下来，对照原稿，再继续往下读。"
            signal taskSaved
            signal taskError(string message)
            function saveNow() {
                return true;
            }
            function updateEditedText(text) {
            }
            function updateTaskTitle(text) {
            }
        }
        QtObject {
            id: ocr
            property bool isWorkerRunning: true
            property bool isProcessing: false
            property string workerStatusMessage: "本地识别就绪"
            property int totalProgress: 3
            property int currentProgress: 1
            property real elapsedSeconds: 1.2
            property string progressText: "正在识别第 2 页"
            signal pageOcrCompleted(string pageId)
        }
        QtObject {
            id: settings
            property bool filterPrintedText: true
            property bool autoEnhance: false
            property real lowConfidenceThreshold: 0.75
            property string ocrWorkerUrl: "http://127.0.0.1:8766"
        }
        QtObject {
            id: lan
            property var availableLanIps: ["127.0.0.1"]
            property string lanIp: "127.0.0.1"
            property string uploadUrl: "http://127.0.0.1:8765"
            property string qrCodeDataUrl: ""
            property int receivedImageCount: 0
            function refreshSessionToken() {
            }
        }
        QtObject {
            id: exporter
        }
        SettingsDialog {
            id: settingsPreview
            appController: mock
        }
        ExportDialog {
            id: exportPreview
            appController: mock
        }
        TestCase {
            id: uiTests
            name: "ManuscriptWorkspace"
            when: windowShown

            function init() {
                preview.width = 1280;
                preview.height = 840;
                preview.currentView = "proofread";
                findChild(preview.contentItem, "proofreadingView").pagesVisible = true;
                wait(80);
            }

            function test_svgIconsAndCompactLayout() {
                preview.width = 1020;
                preview.height = 680;
                wait(80);
                let editor = findChild(preview.contentItem, "textEditor");
                let image = findChild(preview.contentItem, "imageViewer");
                verify(editor.width >= 360, "The editor must remain readable at minimum window size");
                verify(image.width >= 260, "Image tools must fit in the minimum pane width");
                let button = findChild(preview.contentItem, "recognizeButton");
                function collectSvg(item) {
                    let result = [];
                    if (item.source !== undefined && String(item.source).indexOf("data:image/svg+xml") === 0)
                        result.push(item);
                    for (let i = 0; i < item.children.length; ++i)
                        result = result.concat(collectSvg(item.children[i]));
                    return result;
                }
                let icons = collectSvg(button);
                verify(icons.length > 0, "The recognition action uses an SVG, not a font glyph");
                for (let i = 0; i < icons.length; ++i)
                    compare(icons[i].status, Image.Ready);
            }

            function test_resizeAndCollapsePages() {
                let split = findChild(preview.contentItem, "workspaceSplit");
                let image = findChild(preview.contentItem, "imageViewer");
                let page = findChild(preview.contentItem, "pageSidebar");
                let before = image.width;
                mouseDrag(split, image.x + image.width + 3, split.height / 2, 70, 0, Qt.LeftButton);
                wait(80);
                verify(image.width > before + 30, "Dragging the divider must resize the image pane");
                let workspace = findChild(preview.contentItem, "proofreadingView");
                workspace.pagesVisible = false;
                wait(80);
                verify(!page.visible);
                verify(image.width > 0);
                workspace.pagesVisible = true;
            }

            function test_recognitionMenu() {
                let button = findChild(preview.contentItem, "recognizeButton");
                let menu = findChild(button, "recognitionMenu");
                mouseClick(button);
                tryCompare(menu, "visible", true);
                compare(menu.count, 2);
                compare(menu.itemAt(0).text, "识别当前页");
                compare(menu.itemAt(1).text, "识别整篇手稿");
                menu.close();
            }
        }
    }
}
