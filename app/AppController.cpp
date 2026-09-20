#include "AppController.h"
#include "infrastructure/logging/Logger.h"
#include <QGuiApplication>
#include <QClipboard>
#include <QDesktopServices>
#include <QFileInfo>
#include <QDir>
#include <QFile>

namespace HandwritingOCR {

AppController::AppController(QObject* parent) : QObject(parent) {
    // Connect Mobile Upload to Automatic Import & Navigation
    connect(&LanUploadService::instance(), &LanUploadService::imagesUploaded, this, [this](const QStringList& tempFilePaths) {
        Logger::instance().info("AppController", QString("Received %1 images from mobile upload, importing into task...").arg(tempFilePaths.size()));
        importFilePaths(tempFilePaths);
        for (const auto& tempPath : tempFilePaths) {
            if (!QFile::remove(tempPath)) {
                Logger::instance().warn("AppController", QString("Unable to remove upload temp file: %1").arg(tempPath));
            }
        }
        emit navigateToProofreading();
    });

    // Forward signals to notifyUser
    connect(&TaskService::instance(), &TaskService::taskError, this, [this](const QString& msg) {
        emit notifyUser(msg, "error");
    });
    connect(&OcrService::instance(), &OcrService::ocrError, this, [this](const QString& msg) {
        emit notifyUser(msg, "error");
    });
    connect(&ExportService::instance(), &ExportService::exportError, this, [this](const QString& msg) {
        emit notifyUser(msg, "error");
    });
    connect(&ExportService::instance(), &ExportService::exportFinished, this, [this](const QString& path) {
        emit notifyUser(QString("导出成功: %1").arg(path), "success");
    });
}

void AppController::importFiles(const QList<QUrl>& urls) {
    QStringList paths;
    for (const auto& u : urls) {
        if (u.isLocalFile()) {
            paths.append(u.toLocalFile());
        } else {
            paths.append(u.toString());
        }
    }
    importFilePaths(paths);
}

void AppController::importFilePaths(const QStringList& filePaths) {
    auto& taskService = TaskService::instance();
    if (!taskService.hasCurrentTask()) {
        taskService.createNewTask();
    }

    QString taskId = taskService.currentTaskId();
    bool autoEnhance = SettingsService::instance().autoEnhance();
    const int existingCount = taskService.currentTaskPageCount();
    const int remaining = qMax(0, 10 - existingCount);

    if (remaining == 0) {
        emit notifyUser("单个任务最多包含 10 张图片。", "warning");
        return;
    }

    QStringList acceptedPaths = filePaths.mid(0, remaining);
    if (acceptedPaths.size() < filePaths.size()) {
        emit notifyUser(QString("任务最多 10 页，本次仅导入前 %1 张图片。").arg(acceptedPaths.size()), "warning");
    }

    auto newPages = ImageService::instance().importImages(taskId, acceptedPaths, autoEnhance, existingCount);
    for (const auto& page : newPages) {
        taskService.addPageToCurrentTask(page);
    }

    if (newPages.isEmpty()) {
        emit notifyUser("未成功导入图片，请确认格式为 JPG/PNG/WEBP。", "warning");
    } else {
        emit notifyUser(QString("已成功导入 %1 张图片").arg(newPages.size()), "success");
    }
}

void AppController::copyToClipboard(const QString& text) {
    QClipboard* clipboard = QGuiApplication::clipboard();
    if (clipboard) {
        clipboard->setText(text);
        emit notifyUser("文本已复制到剪贴板", "info");
    }
}

void AppController::openFolder(const QString& path) {
    QFileInfo fi(path);
    QString dirPath = fi.isDir() ? path : fi.absolutePath();
    QDesktopServices::openUrl(QUrl::fromLocalFile(dirPath));
}

QString AppController::urlToLocalFile(const QUrl& url) const {
    return url.toLocalFile();
}

QString AppController::localFileToUrl(const QString& path) const {
    return QUrl::fromLocalFile(path).toString();
}

} // namespace HandwritingOCR
