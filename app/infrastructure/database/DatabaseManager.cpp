#include "DatabaseManager.h"
#include "../logging/Logger.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QFileInfo>
#include <QDir>
#include <QVariant>

namespace HandwritingOCR {

DatabaseManager& DatabaseManager::instance() {
    static DatabaseManager s_instance;
    return s_instance;
}

DatabaseManager::~DatabaseManager() {
    close();
}

bool DatabaseManager::init(const QString& dbPath) {
    QMutexLocker locker(&m_mutex);
    if (m_initialized) return true;

    QFileInfo fi(dbPath);
    QDir().mkpath(fi.absolutePath());

    if (QSqlDatabase::contains(m_connectionName)) {
        m_db = QSqlDatabase::database(m_connectionName);
    } else {
        m_db = QSqlDatabase::addDatabase("QSQLITE", m_connectionName);
        m_db.setDatabaseName(dbPath);
    }

    if (!m_db.open()) {
        Logger::instance().error("Database", QString("Failed to open SQLite database: %1").arg(m_db.lastError().text()));
        return false;
    }

    // Enable foreign keys and WAL mode for better concurrency and safety
    QSqlQuery pragmaQuery(m_db);
    pragmaQuery.exec("PRAGMA foreign_keys = ON;");
    pragmaQuery.exec("PRAGMA journal_mode = WAL;");

    if (!createTables()) {
        Logger::instance().error("Database", "Failed to create database tables.");
        return false;
    }

    m_initialized = true;
    Logger::instance().info("Database", QString("SQLite database initialized at: %1").arg(dbPath));
    return true;
}

void DatabaseManager::close() {
    QMutexLocker locker(&m_mutex);
    if (m_initialized && m_db.isOpen()) {
        m_db.close();
        m_initialized = false;
    }
}

bool DatabaseManager::createTables() {
    QSqlQuery q(m_db);

    // tasks table
    QString createTasks = R"(
        CREATE TABLE IF NOT EXISTS tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            status TEXT NOT NULL,
            page_count INTEGER DEFAULT 0,
            total_characters INTEGER DEFAULT 0,
            low_confidence_count INTEGER DEFAULT 0
        );
    )";
    if (!q.exec(createTasks)) {
        Logger::instance().error("Database", QString("Create tasks error: %1").arg(q.lastError().text()));
        return false;
    }

    // pages table
    QString createPages = R"(
        CREATE TABLE IF NOT EXISTS pages (
            id TEXT PRIMARY KEY,
            task_id TEXT NOT NULL,
            page_index INTEGER NOT NULL,
            original_image_path TEXT NOT NULL,
            processed_image_path TEXT,
            thumbnail_path TEXT,
            ocr_result_path TEXT,
            edited_text TEXT,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
        );
    )";
    if (!q.exec(createPages)) {
        Logger::instance().error("Database", QString("Create pages error: %1").arg(q.lastError().text()));
        return false;
    }

    // ocr_results table
    QString createOcrResults = R"(
        CREATE TABLE IF NOT EXISTS ocr_results (
            id TEXT PRIMARY KEY,
            page_id TEXT NOT NULL,
            engine TEXT NOT NULL,
            engine_version TEXT NOT NULL,
            created_at TEXT NOT NULL,
            image_width INTEGER DEFAULT 0,
            image_height INTEGER DEFAULT 0,
            raw_text TEXT,
            FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
        );
    )";
    if (!q.exec(createOcrResults)) {
        Logger::instance().error("Database", QString("Create ocr_results error: %1").arg(q.lastError().text()));
        return false;
    }

    // ocr_blocks table
    QString createOcrBlocks = R"(
        CREATE TABLE IF NOT EXISTS ocr_blocks (
            id TEXT PRIMARY KEY,
            page_id TEXT NOT NULL,
            text TEXT NOT NULL,
            confidence REAL DEFAULT 1.0,
            bbox_x REAL DEFAULT 0,
            bbox_y REAL DEFAULT 0,
            bbox_w REAL DEFAULT 0,
            bbox_h REAL DEFAULT 0,
            line_index INTEGER DEFAULT 0,
            block_index INTEGER DEFAULT 0,
            type TEXT DEFAULT 'text',
            status TEXT DEFAULT 'raw',
            FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
        );
    )";
    if (!q.exec(createOcrBlocks)) {
        Logger::instance().error("Database", QString("Create ocr_blocks error: %1").arg(q.lastError().text()));
        return false;
    }

    // settings table
    QString createSettings = R"(
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
    )";
    if (!q.exec(createSettings)) {
        Logger::instance().error("Database", QString("Create settings error: %1").arg(q.lastError().text()));
        return false;
    }

    return true;
}

// ----------------- Tasks CRUD -----------------

bool DatabaseManager::insertTask(const Task& task) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO tasks (id, title, created_at, updated_at, status, page_count, total_characters, low_confidence_count) "
              "VALUES (:id, :title, :created_at, :updated_at, :status, :page_count, :total_characters, :low_confidence_count)");
    q.bindValue(":id", task.id);
    q.bindValue(":title", task.title);
    q.bindValue(":created_at", task.createdAt.isEmpty() ? QDateTime::currentDateTime().toString(Qt::ISODate) : task.createdAt);
    q.bindValue(":updated_at", task.updatedAt.isEmpty() ? QDateTime::currentDateTime().toString(Qt::ISODate) : task.updatedAt);
    q.bindValue(":status", taskStatusToString(task.status));
    q.bindValue(":page_count", task.pageCount);
    q.bindValue(":total_characters", task.totalCharacters);
    q.bindValue(":low_confidence_count", task.lowConfidenceCount);

    if (!q.exec()) {
        Logger::instance().error("Database", QString("Insert task failed: %1").arg(q.lastError().text()));
        return false;
    }
    return true;
}

bool DatabaseManager::updateTask(const Task& task) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("UPDATE tasks SET title = :title, updated_at = :updated_at, status = :status, "
              "page_count = :page_count, total_characters = :total_characters, low_confidence_count = :low_confidence_count "
              "WHERE id = :id");
    q.bindValue(":title", task.title);
    q.bindValue(":updated_at", QDateTime::currentDateTime().toString(Qt::ISODate));
    q.bindValue(":status", taskStatusToString(task.status));
    q.bindValue(":page_count", task.pageCount);
    q.bindValue(":total_characters", task.totalCharacters);
    q.bindValue(":low_confidence_count", task.lowConfidenceCount);
    q.bindValue(":id", task.id);

    if (!q.exec()) {
        Logger::instance().error("Database", QString("Update task failed: %1").arg(q.lastError().text()));
        return false;
    }
    return true;
}

bool DatabaseManager::updateTaskStatus(const QString& taskId, TaskStatus status) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("UPDATE tasks SET status = :status, updated_at = :updated_at WHERE id = :id");
    q.bindValue(":status", taskStatusToString(status));
    q.bindValue(":updated_at", QDateTime::currentDateTime().toString(Qt::ISODate));
    q.bindValue(":id", taskId);
    return q.exec();
}

bool DatabaseManager::updateTaskTitle(const QString& taskId, const QString& title) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("UPDATE tasks SET title = :title, updated_at = :updated_at WHERE id = :id");
    q.bindValue(":title", title);
    q.bindValue(":updated_at", QDateTime::currentDateTime().toString(Qt::ISODate));
    q.bindValue(":id", taskId);
    return q.exec();
}

bool DatabaseManager::updateTaskStats(const QString& taskId, int totalCharacters, int lowConfidenceCount) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("UPDATE tasks SET total_characters = :tc, low_confidence_count = :lc, updated_at = :updated_at WHERE id = :id");
    q.bindValue(":tc", totalCharacters);
    q.bindValue(":lc", lowConfidenceCount);
    q.bindValue(":updated_at", QDateTime::currentDateTime().toString(Qt::ISODate));
    q.bindValue(":id", taskId);
    return q.exec();
}

bool DatabaseManager::deleteTask(const QString& taskId) {
    QMutexLocker locker(&m_mutex);
    m_db.transaction();

    // Cascade deletion of child records
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM ocr_blocks WHERE page_id IN (SELECT id FROM pages WHERE task_id = :task_id)");
    q.bindValue(":task_id", taskId);
    q.exec();

    q.prepare("DELETE FROM ocr_results WHERE page_id IN (SELECT id FROM pages WHERE task_id = :task_id)");
    q.bindValue(":task_id", taskId);
    q.exec();

    q.prepare("DELETE FROM pages WHERE task_id = :task_id");
    q.bindValue(":task_id", taskId);
    q.exec();

    q.prepare("DELETE FROM tasks WHERE id = :id");
    q.bindValue(":id", taskId);
    if (!q.exec()) {
        m_db.rollback();
        Logger::instance().error("Database", QString("Delete task failed: %1").arg(q.lastError().text()));
        return false;
    }

    m_db.commit();
    return true;
}

std::unique_ptr<Task> DatabaseManager::getTask(const QString& taskId) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("SELECT id, title, created_at, updated_at, status, page_count, total_characters, low_confidence_count FROM tasks WHERE id = :id");
    q.bindValue(":id", taskId);

    if (q.exec() && q.next()) {
        auto task = std::make_unique<Task>();
        task->id = q.value("id").toString();
        task->title = q.value("title").toString();
        task->createdAt = q.value("created_at").toString();
        task->updatedAt = q.value("updated_at").toString();
        task->status = taskStatusFromString(q.value("status").toString());
        task->pageCount = q.value("page_count").toInt();
        task->totalCharacters = q.value("total_characters").toInt();
        task->lowConfidenceCount = q.value("low_confidence_count").toInt();
        return task;
    }
    return nullptr;
}

QVector<Task> DatabaseManager::getAllTasks() {
    QMutexLocker locker(&m_mutex);
    QVector<Task> list;
    QSqlQuery q(m_db);
    q.prepare("SELECT id, title, created_at, updated_at, status, page_count, total_characters, low_confidence_count FROM tasks ORDER BY updated_at DESC");

    if (q.exec()) {
        while (q.next()) {
            Task task;
            task.id = q.value("id").toString();
            task.title = q.value("title").toString();
            task.createdAt = q.value("created_at").toString();
            task.updatedAt = q.value("updated_at").toString();
            task.status = taskStatusFromString(q.value("status").toString());
            task.pageCount = q.value("page_count").toInt();
            task.totalCharacters = q.value("total_characters").toInt();
            task.lowConfidenceCount = q.value("low_confidence_count").toInt();
            list.append(task);
        }
    }
    return list;
}

// ----------------- Pages CRUD -----------------

bool DatabaseManager::insertPage(const Page& page) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO pages (id, task_id, page_index, original_image_path, processed_image_path, thumbnail_path, ocr_result_path, edited_text, status, created_at, updated_at) "
              "VALUES (:id, :task_id, :page_index, :original_image_path, :processed_image_path, :thumbnail_path, :ocr_result_path, :edited_text, :status, :created_at, :updated_at)");
    q.bindValue(":id", page.id);
    q.bindValue(":task_id", page.taskId);
    q.bindValue(":page_index", page.pageIndex);
    q.bindValue(":original_image_path", page.originalImagePath);
    q.bindValue(":processed_image_path", page.processedImagePath);
    q.bindValue(":thumbnail_path", page.thumbnailPath);
    q.bindValue(":ocr_result_path", page.ocrResultPath);
    q.bindValue(":edited_text", page.editedText);
    q.bindValue(":status", pageStatusToString(page.status));
    q.bindValue(":created_at", page.createdAt.isEmpty() ? QDateTime::currentDateTime().toString(Qt::ISODate) : page.createdAt);
    q.bindValue(":updated_at", page.updatedAt.isEmpty() ? QDateTime::currentDateTime().toString(Qt::ISODate) : page.updatedAt);

    if (!q.exec()) {
        Logger::instance().error("Database", QString("Insert page failed: %1").arg(q.lastError().text()));
        return false;
    }
    return true;
}

bool DatabaseManager::updatePage(const Page& page) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("UPDATE pages SET page_index = :page_index, original_image_path = :original_image_path, "
              "processed_image_path = :processed_image_path, thumbnail_path = :thumbnail_path, "
              "ocr_result_path = :ocr_result_path, edited_text = :edited_text, status = :status, updated_at = :updated_at "
              "WHERE id = :id");
    q.bindValue(":page_index", page.pageIndex);
    q.bindValue(":original_image_path", page.originalImagePath);
    q.bindValue(":processed_image_path", page.processedImagePath);
    q.bindValue(":thumbnail_path", page.thumbnailPath);
    q.bindValue(":ocr_result_path", page.ocrResultPath);
    q.bindValue(":edited_text", page.editedText);
    q.bindValue(":status", pageStatusToString(page.status));
    q.bindValue(":updated_at", QDateTime::currentDateTime().toString(Qt::ISODate));
    q.bindValue(":id", page.id);

    return q.exec();
}

bool DatabaseManager::updatePageEditedText(const QString& pageId, const QString& editedText) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("UPDATE pages SET edited_text = :edited_text, updated_at = :updated_at WHERE id = :id");
    q.bindValue(":edited_text", editedText);
    q.bindValue(":updated_at", QDateTime::currentDateTime().toString(Qt::ISODate));
    q.bindValue(":id", pageId);
    return q.exec();
}

bool DatabaseManager::updatePageStatus(const QString& pageId, PageStatus status) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("UPDATE pages SET status = :status, updated_at = :updated_at WHERE id = :id");
    q.bindValue(":status", pageStatusToString(status));
    q.bindValue(":updated_at", QDateTime::currentDateTime().toString(Qt::ISODate));
    q.bindValue(":id", pageId);
    return q.exec();
}

bool DatabaseManager::deletePage(const QString& pageId) {
    QMutexLocker locker(&m_mutex);
    m_db.transaction();
    QSqlQuery q(m_db);

    q.prepare("DELETE FROM ocr_blocks WHERE page_id = :page_id");
    q.bindValue(":page_id", pageId);
    q.exec();

    q.prepare("DELETE FROM ocr_results WHERE page_id = :page_id");
    q.bindValue(":page_id", pageId);
    q.exec();

    q.prepare("DELETE FROM pages WHERE id = :id");
    q.bindValue(":id", pageId);
    if (!q.exec()) {
        m_db.rollback();
        return false;
    }
    m_db.commit();
    return true;
}

bool DatabaseManager::deletePagesByTaskId(const QString& taskId) {
    QMutexLocker locker(&m_mutex);
    m_db.transaction();
    QSqlQuery q(m_db);

    q.prepare("DELETE FROM ocr_blocks WHERE page_id IN (SELECT id FROM pages WHERE task_id = :task_id)");
    q.bindValue(":task_id", taskId);
    q.exec();

    q.prepare("DELETE FROM ocr_results WHERE page_id IN (SELECT id FROM pages WHERE task_id = :task_id)");
    q.bindValue(":task_id", taskId);
    q.exec();

    q.prepare("DELETE FROM pages WHERE task_id = :task_id");
    q.bindValue(":task_id", taskId);
    if (!q.exec()) {
        m_db.rollback();
        return false;
    }
    m_db.commit();
    return true;
}

QVector<Page> DatabaseManager::getPagesByTaskId(const QString& taskId) {
    QMutexLocker locker(&m_mutex);
    QVector<Page> list;
    QSqlQuery q(m_db);
    q.prepare("SELECT id, task_id, page_index, original_image_path, processed_image_path, thumbnail_path, "
              "ocr_result_path, edited_text, status, created_at, updated_at "
              "FROM pages WHERE task_id = :task_id ORDER BY page_index ASC");
    q.bindValue(":task_id", taskId);

    if (q.exec()) {
        while (q.next()) {
            Page page;
            page.id = q.value("id").toString();
            page.taskId = q.value("task_id").toString();
            page.pageIndex = q.value("page_index").toInt();
            page.originalImagePath = q.value("original_image_path").toString();
            page.processedImagePath = q.value("processed_image_path").toString();
            page.thumbnailPath = q.value("thumbnail_path").toString();
            page.ocrResultPath = q.value("ocr_result_path").toString();
            page.editedText = q.value("edited_text").toString();
            page.status = pageStatusFromString(q.value("status").toString());
            page.createdAt = q.value("created_at").toString();
            page.updatedAt = q.value("updated_at").toString();
            list.append(page);
        }
    }
    return list;
}

std::unique_ptr<Page> DatabaseManager::getPage(const QString& pageId) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("SELECT id, task_id, page_index, original_image_path, processed_image_path, thumbnail_path, "
              "ocr_result_path, edited_text, status, created_at, updated_at "
              "FROM pages WHERE id = :id");
    q.bindValue(":id", pageId);

    if (q.exec() && q.next()) {
        auto page = std::make_unique<Page>();
        page->id = q.value("id").toString();
        page->taskId = q.value("task_id").toString();
        page->pageIndex = q.value("page_index").toInt();
        page->originalImagePath = q.value("original_image_path").toString();
        page->processedImagePath = q.value("processed_image_path").toString();
        page->thumbnailPath = q.value("thumbnail_path").toString();
        page->ocrResultPath = q.value("ocr_result_path").toString();
        page->editedText = q.value("edited_text").toString();
        page->status = pageStatusFromString(q.value("status").toString());
        page->createdAt = q.value("created_at").toString();
        page->updatedAt = q.value("updated_at").toString();
        return page;
    }
    return nullptr;
}

// ----------------- OCR Results & Blocks -----------------

bool DatabaseManager::saveOcrResult(const OcrResult& ocrResult) {
    QMutexLocker locker(&m_mutex);
    m_db.transaction();

    QSqlQuery qDel(m_db);
    qDel.prepare("DELETE FROM ocr_blocks WHERE page_id = :page_id");
    qDel.bindValue(":page_id", ocrResult.pageId);
    qDel.exec();

    qDel.prepare("DELETE FROM ocr_results WHERE page_id = :page_id");
    qDel.bindValue(":page_id", ocrResult.pageId);
    qDel.exec();

    QSqlQuery qRes(m_db);
    qRes.prepare("INSERT INTO ocr_results (id, page_id, engine, engine_version, created_at, image_width, image_height, raw_text) "
                 "VALUES (:id, :page_id, :engine, :engine_version, :created_at, :image_width, :image_height, :raw_text)");
    qRes.bindValue(":id", ocrResult.id);
    qRes.bindValue(":page_id", ocrResult.pageId);
    qRes.bindValue(":engine", ocrResult.engine);
    qRes.bindValue(":engine_version", ocrResult.engineVersion);
    qRes.bindValue(":created_at", ocrResult.createdAt.isEmpty() ? QDateTime::currentDateTime().toString(Qt::ISODate) : ocrResult.createdAt);
    qRes.bindValue(":image_width", ocrResult.imageWidth);
    qRes.bindValue(":image_height", ocrResult.imageHeight);
    qRes.bindValue(":raw_text", ocrResult.rawText);

    if (!qRes.exec()) {
        m_db.rollback();
        Logger::instance().error("Database", QString("Save ocr_result failed: %1").arg(qRes.lastError().text()));
        return false;
    }

    QSqlQuery qBlock(m_db);
    qBlock.prepare("INSERT INTO ocr_blocks (id, page_id, text, confidence, bbox_x, bbox_y, bbox_w, bbox_h, line_index, block_index, type, status) "
                   "VALUES (:id, :page_id, :text, :confidence, :bbox_x, :bbox_y, :bbox_w, :bbox_h, :line_index, :block_index, :type, :status)");

    for (const auto& block : ocrResult.blocks) {
        qBlock.bindValue(":id", block.id);
        qBlock.bindValue(":page_id", ocrResult.pageId);
        qBlock.bindValue(":text", block.text);
        qBlock.bindValue(":confidence", block.confidence);
        qBlock.bindValue(":bbox_x", block.bbox.x);
        qBlock.bindValue(":bbox_y", block.bbox.y);
        qBlock.bindValue(":bbox_w", block.bbox.width);
        qBlock.bindValue(":bbox_h", block.bbox.height);
        qBlock.bindValue(":line_index", block.lineIndex);
        qBlock.bindValue(":block_index", block.blockIndex);
        qBlock.bindValue(":type", block.type);
        qBlock.bindValue(":status", block.status);
        if (!qBlock.exec()) {
            m_db.rollback();
            Logger::instance().error("Database", QString("Save ocr_block failed: %1").arg(qBlock.lastError().text()));
            return false;
        }
    }

    m_db.commit();
    return true;
}

std::unique_ptr<OcrResult> DatabaseManager::getOcrResultByPageId(const QString& pageId) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("SELECT id, page_id, engine, engine_version, created_at, image_width, image_height, raw_text FROM ocr_results WHERE page_id = :page_id");
    q.bindValue(":page_id", pageId);

    if (q.exec() && q.next()) {
        auto result = std::make_unique<OcrResult>();
        result->id = q.value("id").toString();
        result->pageId = q.value("page_id").toString();
        result->engine = q.value("engine").toString();
        result->engineVersion = q.value("engine_version").toString();
        result->createdAt = q.value("created_at").toString();
        result->imageWidth = q.value("image_width").toInt();
        result->imageHeight = q.value("image_height").toInt();
        result->rawText = q.value("raw_text").toString();

        QSqlQuery qBlocks(m_db);
        qBlocks.prepare("SELECT id, text, confidence, bbox_x, bbox_y, bbox_w, bbox_h, line_index, block_index, type, status FROM ocr_blocks WHERE page_id = :page_id ORDER BY line_index ASC, block_index ASC");
        qBlocks.bindValue(":page_id", pageId);
        if (qBlocks.exec()) {
            while (qBlocks.next()) {
                OcrBlock block;
                block.id = qBlocks.value("id").toString();
                block.pageId = pageId;
                block.text = qBlocks.value("text").toString();
                block.confidence = qBlocks.value("confidence").toDouble();
                block.bbox.x = qBlocks.value("bbox_x").toDouble();
                block.bbox.y = qBlocks.value("bbox_y").toDouble();
                block.bbox.width = qBlocks.value("bbox_w").toDouble();
                block.bbox.height = qBlocks.value("bbox_h").toDouble();
                block.lineIndex = qBlocks.value("line_index").toInt();
                block.blockIndex = qBlocks.value("block_index").toInt();
                block.type = qBlocks.value("type").toString();
                block.status = qBlocks.value("status").toString();
                result->blocks.append(block);
            }
        }
        return result;
    }
    return nullptr;
}

bool DatabaseManager::deleteOcrResultByPageId(const QString& pageId) {
    QMutexLocker locker(&m_mutex);
    m_db.transaction();
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM ocr_blocks WHERE page_id = :page_id");
    q.bindValue(":page_id", pageId);
    q.exec();

    q.prepare("DELETE FROM ocr_results WHERE page_id = :page_id");
    q.bindValue(":page_id", pageId);
    q.exec();

    m_db.commit();
    return true;
}

// ----------------- Settings -----------------

bool DatabaseManager::setSetting(const QString& key, const QString& value) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO settings (key, value) VALUES (:key, :value) "
              "ON CONFLICT(key) DO UPDATE SET value = excluded.value");
    q.bindValue(":key", key);
    q.bindValue(":value", value);
    return q.exec();
}

QString DatabaseManager::getSetting(const QString& key, const QString& defaultValue) {
    QMutexLocker locker(&m_mutex);
    QSqlQuery q(m_db);
    q.prepare("SELECT value FROM settings WHERE key = :key");
    q.bindValue(":key", key);
    if (q.exec() && q.next()) {
        return q.value("value").toString();
    }
    return defaultValue;
}

} // namespace HandwritingOCR
