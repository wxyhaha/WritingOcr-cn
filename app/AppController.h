#pragma once

#include "services/TaskService.h"
#include "services/ImageService.h"
#include "services/OcrService.h"
#include "services/LanUploadService.h"
#include "services/ExportService.h"
#include "services/SettingsService.h"
#include "models/TaskListModel.h"
#include "models/PageListModel.h"
#include "models/OcrBlockListModel.h"
#include <QObject>
#include <QUrl>
#include <QList>

namespace HandwritingOCR {

class AppController : public QObject {
    Q_OBJECT
    Q_PROPERTY(TaskService* taskService READ taskService CONSTANT)
    Q_PROPERTY(ImageService* imageService READ imageService CONSTANT)
    Q_PROPERTY(OcrService* ocrService READ ocrService CONSTANT)
    Q_PROPERTY(LanUploadService* lanUploadService READ lanUploadService CONSTANT)
    Q_PROPERTY(ExportService* exportService READ exportService CONSTANT)
    Q_PROPERTY(SettingsService* settingsService READ settingsService CONSTANT)

    Q_PROPERTY(TaskListModel* taskListModel READ taskListModel CONSTANT)
    Q_PROPERTY(PageListModel* pageListModel READ pageListModel CONSTANT)
    Q_PROPERTY(OcrBlockListModel* ocrBlockListModel READ ocrBlockListModel CONSTANT)

public:
    explicit AppController(QObject* parent = nullptr);
    ~AppController() override = default;

    TaskService* taskService() const { return &TaskService::instance(); }
    ImageService* imageService() const { return &ImageService::instance(); }
    OcrService* ocrService() const { return &OcrService::instance(); }
    LanUploadService* lanUploadService() const { return &LanUploadService::instance(); }
    ExportService* exportService() const { return &ExportService::instance(); }
    SettingsService* settingsService() const { return &SettingsService::instance(); }

    TaskListModel* taskListModel() const { return TaskService::instance().taskListModel(); }
    PageListModel* pageListModel() const { return TaskService::instance().pageListModel(); }
    OcrBlockListModel* ocrBlockListModel() const { return TaskService::instance().ocrBlockListModel(); }

    Q_INVOKABLE void importFiles(const QList<QUrl>& urls);
    Q_INVOKABLE void importFilePaths(const QStringList& filePaths);
    Q_INVOKABLE void copyToClipboard(const QString& text);
    Q_INVOKABLE void openFolder(const QString& path);
    Q_INVOKABLE QString urlToLocalFile(const QUrl& url) const;
    Q_INVOKABLE QString localFileToUrl(const QString& path) const;

signals:
    void notifyUser(const QString& message, const QString& type = "info");
    void navigateToProofreading();
};

} // namespace HandwritingOCR
