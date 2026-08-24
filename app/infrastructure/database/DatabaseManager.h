#pragma once

#include "../../models/Task.h"
#include "../../models/Page.h"
#include "../../models/OcrResult.h"
#include "../../models/OcrBlock.h"
#include <QString>
#include <QVector>
#include <QSqlDatabase>
#include <QMutex>
#include <memory>

namespace HandwritingOCR {

class DatabaseManager {
public:
    static DatabaseManager& instance();

    bool init(const QString& dbPath);
    void close();

    // Tasks CRUD
    bool insertTask(const Task& task);
    bool updateTask(const Task& task);
    bool updateTaskStatus(const QString& taskId, TaskStatus status);
    bool updateTaskTitle(const QString& taskId, const QString& title);
    bool updateTaskStats(const QString& taskId, int totalCharacters, int lowConfidenceCount);
    bool deleteTask(const QString& taskId);
    std::unique_ptr<Task> getTask(const QString& taskId);
    QVector<Task> getAllTasks();

    // Pages CRUD
    bool insertPage(const Page& page);
    bool updatePage(const Page& page);
    bool updatePageEditedText(const QString& pageId, const QString& editedText);
    bool updatePageStatus(const QString& pageId, PageStatus status);
    bool deletePage(const QString& pageId);
    bool deletePagesByTaskId(const QString& taskId);
    QVector<Page> getPagesByTaskId(const QString& taskId);
    std::unique_ptr<Page> getPage(const QString& pageId);

    // OCR Results & Blocks
    bool saveOcrResult(const OcrResult& ocrResult);
    std::unique_ptr<OcrResult> getOcrResultByPageId(const QString& pageId);
    bool deleteOcrResultByPageId(const QString& pageId);

    // Settings
    bool setSetting(const QString& key, const QString& value);
    QString getSetting(const QString& key, const QString& defaultValue = QString());

private:
    DatabaseManager() = default;
    ~DatabaseManager();
    DatabaseManager(const DatabaseManager&) = delete;
    DatabaseManager& operator=(const DatabaseManager&) = delete;

    bool createTables();

    QSqlDatabase m_db;
    QMutex m_mutex;
    bool m_initialized = false;
    QString m_connectionName = "HandwritingOCR_DB";
};

} // namespace HandwritingOCR
