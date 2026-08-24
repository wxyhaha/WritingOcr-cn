#pragma once

#include <QString>
#include <QStandardPaths>
#include <QDir>

namespace HandwritingOCR {

class StorageService {
public:
    static StorageService& instance();

    void init(const QString& customBasePath = QString());
    QString getBaseStorageDir() const;
    void setBaseStorageDir(const QString& path);

    // Task directories
    QString getTaskDir(const QString& taskId) const;
    QString getTaskSourceDir(const QString& taskId) const;
    QString getTaskProcessedDir(const QString& taskId) const;
    QString getTaskThumbnailDir(const QString& taskId) const;
    QString getTaskOcrDir(const QString& taskId) const;
    QString getTaskExportDir(const QString& taskId) const;

    bool ensureTaskDirs(const QString& taskId);
    bool deleteEntireTaskDir(const QString& taskId);

    // Database & logs paths
    QString getDatabaseFilePath() const;
    QString getLogFilePath() const;

private:
    StorageService() = default;
    ~StorageService() = default;
    StorageService(const StorageService&) = delete;
    StorageService& operator=(const StorageService&) = delete;

    QString m_baseDir;
};

} // namespace HandwritingOCR
