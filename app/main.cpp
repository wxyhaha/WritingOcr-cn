#include "AppController.h"
#include "services/StorageService.h"
#include "services/SettingsService.h"
#include "services/TaskService.h"
#include "services/ImageService.h"
#include "services/LanUploadService.h"
#include "services/OcrService.h"
#include "services/ExportService.h"
#include "infrastructure/database/DatabaseManager.h"
#include "infrastructure/logging/Logger.h"
#include "infrastructure/utils/PathUtils.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QIcon>
#include <QDir>
#include <QFileInfo>

using namespace HandwritingOCR;

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setOrganizationName("HandwritingOCR");
    app.setApplicationName("HandwritingOCR");
    app.setApplicationVersion("1.0.0");

    QQuickStyle::setStyle("Basic");

    // 1. Initialize Storage & Logging
    StorageService::instance().init();
    Logger::instance().init(StorageService::instance().getLogFilePath());
    Logger::instance().info("Main", "=== Starting Handwriting OCR Digitalizer MVP ===");

    // 2. Initialize Database & Settings
    DatabaseManager::instance().init(StorageService::instance().getDatabaseFilePath());
    SettingsService::instance().load();

    // 3. Initialize Services
    TaskService::instance().init();
    LanUploadService::instance().init();
    OcrService::instance().init();

    // Install Qt Message Handler
    qInstallMessageHandler([](QtMsgType type, const QMessageLogContext &context, const QString &msg) {
        LogLevel lvl = LogLevel::Info;
        if (type == QtWarningMsg) lvl = LogLevel::Warn;
        else if (type == QtCriticalMsg || type == QtFatalMsg) lvl = LogLevel::Error;
        else if (type == QtDebugMsg) lvl = LogLevel::Debug;
        Logger::instance().log(lvl, "Qt", msg);
    });

    // 4. QML Engine Setup
    QQmlApplicationEngine engine;

    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const auto &w : warnings) {
            Logger::instance().error("QML", w.toString());
        }
    });

    AppController controller;
    engine.rootContext()->setContextProperty("app", &controller);
    engine.rootContext()->setContextProperty("taskService", TaskService::instance().taskListModel());
    engine.rootContext()->setContextProperty("pageService", TaskService::instance().pageListModel());
    engine.rootContext()->setContextProperty("ocrBlockModel", TaskService::instance().ocrBlockListModel());

    // Register models metatypes
    qRegisterMetaType<TaskListModel*>("TaskListModel*");
    qRegisterMetaType<PageListModel*>("PageListModel*");
    qRegisterMetaType<OcrBlockListModel*>("OcrBlockListModel*");

    // Load Main.qml
    const QUrl url(QStringLiteral("qrc:/qml/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
            Logger::instance().error("Main", "Failed to load Main.qml");
            QCoreApplication::exit(-1);
        }
    }, Qt::QueuedConnection);

    engine.load(url);

    if (engine.rootObjects().isEmpty()) {
        // Fallback to loading directly from file if resource not bundled during dev
        QString qmlPath = PathUtils::findResourcePath("app/qml/Main.qml");
        if (QFile::exists(qmlPath)) {
            engine.load(QUrl::fromLocalFile(qmlPath));
        }
    }

    QObject::connect(&app, &QCoreApplication::aboutToQuit, []() {
        Logger::instance().info("Main", "Cleaning up services on exit...");
        OcrService::instance().stopWorkerProcess();
        LanUploadService::instance().stopServer();
    });

    int ret = app.exec();
    OcrService::instance().stopWorkerProcess();
    LanUploadService::instance().stopServer();
    Logger::instance().info("Main", "=== Application Exited ===");
    return ret;
}
