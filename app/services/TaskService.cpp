#include "TaskService.h"
#include "StorageService.h"
#include "SettingsService.h"
#include "../infrastructure/database/DatabaseManager.h"
#include "../infrastructure/logging/Logger.h"
#include <QUuid>
#include <QDateTime>
#include <QFile>
#include <QSet>
#include <QSaveFile>
#include <QJsonDocument>

namespace HandwritingOCR {

namespace {

QString textFromBlocks(const QVector<OcrBlock>& blocks, bool filterPrinted) {
    QStringList lines;
    for (const auto& block : blocks) {
        if (!filterPrinted || block.isHandwriting()) {
            lines.append(block.text);
        }
    }
    return lines.join('\n');
}

bool isUneditedOcrText(const Page& page) {
    if (page.editedText.isEmpty()) return true;
    if (page.editedText == page.ocrResult.rawText) return true;
    if (page.ocrResult.blocks.isEmpty()) return false;
    return page.editedText == textFromBlocks(page.ocrResult.blocks, false)
        || page.editedText == textFromBlocks(page.ocrResult.blocks, true);
}

void removePageFiles(const Page& page) {
    QSet<QString> paths;
    paths << page.originalImagePath << page.processedImagePath
          << page.thumbnailPath << page.ocrResultPath;
    for (const auto& path : paths) {
        if (!path.isEmpty() && QFile::exists(path) && !QFile::remove(path)) {
            Logger::instance().warn("TaskService", QString("Unable to remove page file: %1").arg(path));
        }
    }
}

} // namespace

TaskService& TaskService::instance() {
    static TaskService s_instance;
    return s_instance;
}

TaskService::TaskService(QObject* parent) : QObject(parent) {
    m_autoSaveTimer.setSingleShot(true);
    m_autoSaveTimer.setInterval(500); // 500ms debounce
    connect(&m_autoSaveTimer, &QTimer::timeout, this, &TaskService::onAutoSaveTimeout);

    connect(&SettingsService::instance(), &SettingsService::settingsChanged, this, [this]() {
        m_ocrBlockListModel.setLowConfidenceThreshold(SettingsService::instance().lowConfidenceThreshold());
        updateStatsAndNotify();
    });
}

void TaskService::init() {
    refreshTaskList();
}

void TaskService::refreshTaskList() {
    auto tasks = DatabaseManager::instance().getAllTasks();
    m_taskListModel.setTasks(tasks);
}

int TaskService::currentTaskTotalCharacters() const {
    if (!m_currentTask) return 0;
    int total = 0;
    for (const auto& page : m_currentTask->pages) {
        if (!page.editedText.isEmpty()) {
            total += page.editedText.trimmed().length();
        } else {
            total += page.ocrResult.totalCharacters();
        }
    }
    return total;
}

int TaskService::currentTaskLowConfidenceCount() const {
    if (!m_currentTask) return 0;
    double threshold = SettingsService::instance().lowConfidenceThreshold();
    int count = 0;
    for (const auto& page : m_currentTask->pages) {
        count += page.ocrResult.lowConfidenceCount(threshold);
    }
    return count;
}

QString TaskService::currentPageId() const {
    if (m_currentTask && m_currentPageIndex >= 0 && m_currentPageIndex < m_currentTask->pages.size()) {
        return m_currentTask->pages[m_currentPageIndex].id;
    }
    return QString();
}

QString TaskService::currentOriginalImage() const {
    if (m_currentTask && m_currentPageIndex >= 0 && m_currentPageIndex < m_currentTask->pages.size()) {
        return m_currentTask->pages[m_currentPageIndex].originalImagePath;
    }
    return QString();
}

QString TaskService::currentProcessedImage() const {
    if (m_currentTask && m_currentPageIndex >= 0 && m_currentPageIndex < m_currentTask->pages.size()) {
        const auto& p = m_currentTask->pages[m_currentPageIndex];
        return p.processedImagePath.isEmpty() ? p.originalImagePath : p.processedImagePath;
    }
    return QString();
}

QString TaskService::currentEditedText() const {
    if (m_currentTask && m_currentPageIndex >= 0 && m_currentPageIndex < m_currentTask->pages.size()) {
        const auto& p = m_currentTask->pages[m_currentPageIndex];
        if (!p.editedText.isEmpty()) {
            return p.editedText;
        }
        return p.ocrResult.rawText;
    }
    return QString();
}

QString TaskService::currentPageStatus() const {
    if (m_currentTask && m_currentPageIndex >= 0 && m_currentPageIndex < m_currentTask->pages.size()) {
        return pageStatusToString(m_currentTask->pages[m_currentPageIndex].status);
    }
    return QString();
}

Page* TaskService::currentPagePtr() {
    if (m_currentTask && m_currentPageIndex >= 0 && m_currentPageIndex < m_currentTask->pages.size()) {
        return &m_currentTask->pages[m_currentPageIndex];
    }
    return nullptr;
}

QString TaskService::createNewTask(const QString& title) {
    saveNow();

    QString taskId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QString taskTitle = title.isEmpty() ? QString("%1 手写文章").arg(QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm")) : title;

    Task task;
    task.id = taskId;
    task.title = taskTitle;
    task.createdAt = QDateTime::currentDateTime().toString(Qt::ISODate);
    task.updatedAt = task.createdAt;
    task.status = TaskStatus::Draft;
    task.pageCount = 0;
    task.totalCharacters = 0;
    task.lowConfidenceCount = 0;

    if (!StorageService::instance().ensureTaskDirs(taskId)) {
        emit taskError("创建任务失败，无法创建任务存储目录。");
        return QString();
    }

    if (DatabaseManager::instance().insertTask(task)) {
        m_taskListModel.addTask(task);
        loadTask(taskId);
        Logger::instance().info("TaskService", QString("Created new task: %1 (%2)").arg(taskTitle, taskId));
        return taskId;
    } else {
        StorageService::instance().deleteEntireTaskDir(taskId);
        emit taskError("创建任务失败，数据库写入异常。");
        return QString();
    }
}

bool TaskService::loadTask(const QString& taskId) {
    saveNow();

    auto task = DatabaseManager::instance().getTask(taskId);
    if (!task) {
        emit taskError(QString("无法加载任务 %1: 任务不存在").arg(taskId));
        return false;
    }

    auto pages = DatabaseManager::instance().getPagesByTaskId(taskId);
    for (auto& page : pages) {
        auto ocrRes = DatabaseManager::instance().getOcrResultByPageId(page.id);
        if (ocrRes) {
            page.ocrResult = *ocrRes;
        }
    }
    task->pages = pages;
    task->pageCount = static_cast<int>(pages.size());

    m_currentTask = std::move(task);
    m_pageListModel.setPages(m_currentTask->pages);

    if (!m_currentTask->pages.isEmpty()) {
        selectPage(0);
    } else {
        m_currentPageIndex = -1;
        m_ocrBlockListModel.setBlocks({});
        emit currentPageChanged();
    }

    updateStatsAndNotify();
    emit currentTaskChanged();
    Logger::instance().info("TaskService", QString("Loaded task: %1 with %2 pages").arg(m_currentTask->title).arg(m_currentTask->pages.size()));
    return true;
}

bool TaskService::closeCurrentTask() {
    saveNow();
    m_currentTask.reset();
    m_currentPageIndex = -1;
    m_pageListModel.setPages({});
    m_ocrBlockListModel.setBlocks({});
    emit currentTaskChanged();
    emit currentPageChanged();
    return true;
}

bool TaskService::updateTaskTitle(const QString& title) {
    if (!m_currentTask || title.trimmed().isEmpty()) return false;
    const QString normalizedTitle = title.trimmed();
    if (!DatabaseManager::instance().updateTaskTitle(m_currentTask->id, normalizedTitle)) {
        emit taskError("任务标题保存失败。");
        return false;
    }
    m_currentTask->title = normalizedTitle;
    m_taskListModel.updateTask(*m_currentTask);
    emit currentTaskChanged();
    return true;
}

bool TaskService::deleteTask(const QString& taskId) {
    Logger::instance().info("TaskService", QString("Deleting task: %1 and all its associated data").arg(taskId));

    // Delete database records first so a database failure never leaves records
    // pointing at files that have already been destroyed.
    bool dbOk = DatabaseManager::instance().deleteTask(taskId);

    if (dbOk) {
        if (m_currentTask && m_currentTask->id == taskId) {
            m_currentTask.reset();
            m_currentPageIndex = -1;
            m_pageListModel.setPages({});
            m_ocrBlockListModel.setBlocks({});
            emit currentTaskChanged();
            emit currentPageChanged();
        }

        bool fsOk = StorageService::instance().deleteEntireTaskDir(taskId);
        m_taskListModel.removeTask(taskId);
        emit taskDeleted(taskId);
        if (!fsOk) {
            emit taskError(QString("任务已从数据库删除，但部分文件未能清理：%1").arg(taskId));
            Logger::instance().warn("TaskService", QString("Task %1 deleted with orphaned files.").arg(taskId));
        } else {
            Logger::instance().info("TaskService", QString("Task %1 successfully deleted.").arg(taskId));
        }
        return true;
    } else {
        emit taskError(QString("删除任务 %1 失败，数据库记录清理异常。").arg(taskId));
        return false;
    }
}

bool TaskService::selectPage(int index) {
    if (!m_currentTask || index < 0 || index >= m_currentTask->pages.size()) {
        return false;
    }

    if (m_hasUnsavedChanges) {
        saveNow();
    }

    m_currentPageIndex = index;
    const auto& page = m_currentTask->pages[index];
    m_ocrBlockListModel.setBlocks(page.ocrResult.blocks);
    emit currentPageChanged();
    return true;
}

bool TaskService::selectPageById(const QString& pageId) {
    if (!m_currentTask) return false;
    for (int i = 0; i < m_currentTask->pages.size(); ++i) {
        if (m_currentTask->pages[i].id == pageId) {
            return selectPage(i);
        }
    }
    return false;
}

bool TaskService::deletePage(int index) {
    if (!m_currentTask || index < 0 || index >= m_currentTask->pages.size()) {
        return false;
    }

    const Page pageToDelete = m_currentTask->pages[index];
    QString pageId = pageToDelete.id;

    if (!DatabaseManager::instance().deletePage(pageId)) {
        emit taskError("删除页面失败，数据库记录未更改。");
        return false;
    }

    m_currentTask->pages.removeAt(index);
    m_currentTask->pageCount = static_cast<int>(m_currentTask->pages.size());

    // Re-index remaining pages
    for (int i = 0; i < m_currentTask->pages.size(); ++i) {
        m_currentTask->pages[i].pageIndex = i;
        if (!DatabaseManager::instance().updatePage(m_currentTask->pages[i])) {
            Logger::instance().warn("TaskService", QString("Unable to persist page index for %1").arg(m_currentTask->pages[i].id));
        }
    }

    removePageFiles(pageToDelete);
    m_pageListModel.setPages(m_currentTask->pages);

    if (m_currentTask->pages.isEmpty()) {
        m_currentPageIndex = -1;
        m_ocrBlockListModel.setBlocks({});
    } else {
        if (m_currentPageIndex >= m_currentTask->pages.size()) {
            m_currentPageIndex = static_cast<int>(m_currentTask->pages.size()) - 1;
        }
        selectPage(m_currentPageIndex);
    }

    updateStatsAndNotify();
    DatabaseManager::instance().updateTask(*m_currentTask);
    m_taskListModel.updateTask(*m_currentTask);
    return true;
}

void TaskService::updateEditedText(const QString& newText) {
    if (!m_currentTask || m_currentPageIndex < 0 || m_currentPageIndex >= m_currentTask->pages.size()) {
        return;
    }

    auto& page = m_currentTask->pages[m_currentPageIndex];
    if (page.editedText != newText) {
        page.editedText = newText;
        m_hasUnsavedChanges = true;
        triggerAutoSave();
        updateStatsAndNotify();
    }
}

void TaskService::reorderPages(int fromIndex, int toIndex) {
    if (!m_currentTask || fromIndex < 0 || fromIndex >= m_currentTask->pages.size() ||
        toIndex < 0 || toIndex >= m_currentTask->pages.size() || fromIndex == toIndex) {
        return;
    }

    Page p = m_currentTask->pages.takeAt(fromIndex);
    m_currentTask->pages.insert(toIndex, p);

    for (int i = 0; i < m_currentTask->pages.size(); ++i) {
        m_currentTask->pages[i].pageIndex = i;
        DatabaseManager::instance().updatePage(m_currentTask->pages[i]);
    }

    m_pageListModel.setPages(m_currentTask->pages);
    m_currentPageIndex = toIndex;
    DatabaseManager::instance().updateTask(*m_currentTask);
    m_taskListModel.updateTask(*m_currentTask);
    emit currentPageChanged();
}

void TaskService::triggerAutoSave() {
    m_autoSaveTimer.start();
}

void TaskService::onAutoSaveTimeout() {
    saveNow();
}

void TaskService::saveNow() {
    if (!m_hasUnsavedChanges && (!m_currentTask || m_currentPageIndex < 0)) {
        return;
    }

    if (m_currentTask) {
        if (m_currentPageIndex >= 0 && m_currentPageIndex < m_currentTask->pages.size()) {
            const auto& page = m_currentTask->pages[m_currentPageIndex];
            if (!DatabaseManager::instance().updatePageEditedText(page.id, page.editedText)) {
                emit taskError("校对文本自动保存失败。");
                return;
            }
        }

        m_currentTask->totalCharacters = currentTaskTotalCharacters();
        m_currentTask->lowConfidenceCount = currentTaskLowConfidenceCount();
        m_currentTask->pageCount = static_cast<int>(m_currentTask->pages.size());
        if (!DatabaseManager::instance().updateTask(*m_currentTask)) {
            emit taskError("任务统计信息保存失败。");
            return;
        }
        m_taskListModel.updateTask(*m_currentTask);

        m_hasUnsavedChanges = false;
        emit taskSaved();
    }
}

void TaskService::addPageToCurrentTask(const Page& page) {
    if (!m_currentTask) return;

    if (!DatabaseManager::instance().insertPage(page)) {
        emit taskError(QString("页面 %1 写入数据库失败，未加入任务。").arg(page.id));
        removePageFiles(page);
        return;
    }

    m_currentTask->pages.append(page);
    m_currentTask->pageCount = static_cast<int>(m_currentTask->pages.size());
    if (m_currentTask->coverThumbnailPath.isEmpty() && !page.thumbnailPath.isEmpty()) {
        m_currentTask->coverThumbnailPath = page.thumbnailPath;
        m_currentTask->coverImagePath = page.originalImagePath;
    }
    if (!DatabaseManager::instance().updateTask(*m_currentTask)) {
        Logger::instance().warn("TaskService", "Page inserted, but task statistics could not be updated.");
    }

    m_pageListModel.addPage(page);
    m_taskListModel.updateTask(*m_currentTask);

    if (m_currentPageIndex == -1) {
        selectPage(0);
    }
    updateStatsAndNotify();
}

void TaskService::updatePageOcrResult(const QString& pageId, const OcrResult& result) {
    int currentIndex = -1;
    Page* page = nullptr;
    std::unique_ptr<Page> detachedPage;

    if (m_currentTask) {
        for (int i = 0; i < m_currentTask->pages.size(); ++i) {
            if (m_currentTask->pages[i].id == pageId) {
                currentIndex = i;
                page = &m_currentTask->pages[i];
                break;
            }
        }
    }

    // OCR may finish after the user navigates to another task. Persist by page
    // id even when the page is no longer represented by the current UI model.
    if (!page) {
        detachedPage = DatabaseManager::instance().getPage(pageId);
        if (!detachedPage) {
            Logger::instance().warn("TaskService", QString("Discarding OCR result for deleted page %1").arg(pageId));
            return;
        }
        if (auto previous = DatabaseManager::instance().getOcrResultByPageId(pageId)) {
            detachedPage->ocrResult = *previous;
        }
        page = detachedPage.get();
    }

    const bool canReplaceEditedText = isUneditedOcrText(*page);
    page->ocrResult = result;
    if (canReplaceEditedText) page->editedText = result.rawText;
    page->status = PageStatus::Reviewing;

    const QString archivePath = QDir(StorageService::instance().getTaskOcrDir(page->taskId))
                                    .filePath(page->id + ".json");
    QSaveFile archive(archivePath);
    if (archive.open(QIODevice::WriteOnly)
        && archive.write(QJsonDocument(result.toJson()).toJson()) >= 0
        && archive.commit()) {
        page->ocrResultPath = archivePath;
    } else {
        Logger::instance().warn("TaskService", QString("Unable to archive OCR JSON: %1").arg(archivePath));
    }

    if (!DatabaseManager::instance().saveOcrResult(result)
        || !DatabaseManager::instance().updatePage(*page)) {
        emit taskError("OCR 结果保存失败，请勿关闭程序并重试。");
        return;
    }

    if (currentIndex >= 0 && m_currentTask) {
        m_pageListModel.updatePage(*page);
        if (m_currentPageIndex == currentIndex) {
            m_ocrBlockListModel.setBlocks(result.blocks);
            emit currentPageChanged();
        }

        m_currentTask->status = TaskStatus::Reviewing;
        m_currentTask->totalCharacters = currentTaskTotalCharacters();
        m_currentTask->lowConfidenceCount = currentTaskLowConfidenceCount();
        DatabaseManager::instance().updateTask(*m_currentTask);
        m_taskListModel.updateTask(*m_currentTask);
        updateStatsAndNotify();
    } else {
        DatabaseManager::instance().updateTaskStatus(page->taskId, TaskStatus::Reviewing);
        refreshTaskList();
    }
}

void TaskService::applyFilterPrintedToCurrentPage(bool filterPrinted) {
    if (!m_currentTask || m_currentPageIndex < 0 || m_currentPageIndex >= m_currentTask->pages.size()) {
        return;
    }

    auto& page = m_currentTask->pages[m_currentPageIndex];
    if (page.ocrResult.blocks.isEmpty()) return;

    // Filtering is allowed to rewrite only an untouched OCR projection. Never
    // discard a user's proofreading edits merely because a display option changed.
    if (!isUneditedOcrText(page)) {
        emit currentPageChanged();
        return;
    }

    page.editedText = textFromBlocks(page.ocrResult.blocks, filterPrinted);
    if (!DatabaseManager::instance().updatePageEditedText(page.id, page.editedText)) {
        emit taskError("过滤结果保存失败。");
        return;
    }
    m_pageListModel.updatePage(page);
    updateStatsAndNotify();
    DatabaseManager::instance().updateTask(*m_currentTask);
    m_taskListModel.updateTask(*m_currentTask);
    emit currentPageChanged();
}

void TaskService::applyFilterPrintedToAllPages(bool filterPrinted) {
    if (!m_currentTask) return;

    for (int i = 0; i < m_currentTask->pages.size(); ++i) {
        auto& page = m_currentTask->pages[i];
        if (page.ocrResult.blocks.isEmpty() || !isUneditedOcrText(page)) continue;

        page.editedText = textFromBlocks(page.ocrResult.blocks, filterPrinted);
        if (!DatabaseManager::instance().updatePageEditedText(page.id, page.editedText)) {
            emit taskError(QString("页面 %1 的过滤结果保存失败。").arg(i + 1));
            continue;
        }
        m_pageListModel.updatePage(page);
    }

    updateStatsAndNotify();
    DatabaseManager::instance().updateTask(*m_currentTask);
    m_taskListModel.updateTask(*m_currentTask);
    emit currentPageChanged();
}

void TaskService::updateStatsAndNotify() {
    if (m_currentTask) {
        m_currentTask->pageCount = static_cast<int>(m_currentTask->pages.size());
        m_currentTask->totalCharacters = currentTaskTotalCharacters();
        m_currentTask->lowConfidenceCount = currentTaskLowConfidenceCount();
    }
    emit currentTaskChanged();
}

} // namespace HandwritingOCR
