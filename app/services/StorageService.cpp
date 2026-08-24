#include "StorageService.h"
#include "../infrastructure/logging/Logger.h"
#include <QFileInfo>

namespace HandwritingOCR {

StorageService& StorageService::instance() {
    static StorageService s_instance;
    return s_instance;
}

void StorageService::init(const QString& customBasePath) {
    if (!customBasePath.isEmpty()) {
        m_baseDir = customBasePath;
    } else {
        QString docPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
        m_baseDir = QDir(docPath).filePath("HandwritingOCR");
    }

    QDir().mkpath(m_baseDir);
    QDir().mkpath(QDir(m_baseDir).filePath("tasks"));
    QDir().mkpath(QDir(m_baseDir).filePath("logs"));

    Logger::instance().info("StorageService", QString("Base storage directory set to: %1").arg(m_baseDir));
}

QString StorageService::getBaseStorageDir() const {
    return m_baseDir;
}

void StorageService::setBaseStorageDir(const QString& path) {
    m_baseDir = path;
    QDir().mkpath(m_baseDir);
    QDir().mkpath(QDir(m_baseDir).filePath("tasks"));
    QDir().mkpath(QDir(m_baseDir).filePath("logs"));
}

QString StorageService::getTaskDir(const QString& taskId) const {
    return QDir(m_baseDir).filePath(QString("tasks/%1").arg(taskId));
}

QString StorageService::getTaskSourceDir(const QString& taskId) const {
    return QDir(getTaskDir(taskId)).filePath("source");
}

QString StorageService::getTaskProcessedDir(const QString& taskId) const {
    return QDir(getTaskDir(taskId)).filePath("processed");
}

QString StorageService::getTaskThumbnailDir(const QString& taskId) const {
    return QDir(getTaskDir(taskId)).filePath("thumbnails");
}

QString StorageService::getTaskOcrDir(const QString& taskId) const {
    return QDir(getTaskDir(taskId)).filePath("ocr");
}

QString StorageService::getTaskExportDir(const QString& taskId) const {
    return QDir(getTaskDir(taskId)).filePath("exports");
}

bool StorageService::ensureTaskDirs(const QString& taskId) {
    bool ok = true;
    ok &= QDir().mkpath(getTaskSourceDir(taskId));
    ok &= QDir().mkpath(getTaskProcessedDir(taskId));
    ok &= QDir().mkpath(getTaskThumbnailDir(taskId));
    ok &= QDir().mkpath(getTaskOcrDir(taskId));
    ok &= QDir().mkpath(getTaskExportDir(taskId));
    return ok;
}

bool StorageService::deleteEntireTaskDir(const QString& taskId) {
    QString taskPath = getTaskDir(taskId);
    QDir dir(taskPath);
    if (!dir.exists()) {
        return true;
    }
    bool success = dir.removeRecursively();
    if (success) {
        Logger::instance().info("StorageService", QString("Successfully removed directory for task: %1").arg(taskId));
    } else {
        Logger::instance().error("StorageService", QString("Failed to remove directory for task: %1").arg(taskId));
    }
    return success;
}

QString StorageService::getDatabaseFilePath() const {
    return QDir(m_baseDir).filePath("handwriting_ocr.db");
}

QString StorageService::getLogFilePath() const {
    return QDir(m_baseDir).filePath("logs/app.log");
}

} // namespace HandwritingOCR
