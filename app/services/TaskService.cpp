#include "TaskService.h"
#include "StorageService.h"
#include "SettingsService.h"
#include "../infrastructure/database/DatabaseManager.h"
#include "../infrastructure/logging/Logger.h"
#include <QUuid>
#include <QDateTime>

namespace HandwritingOCR {

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

    StorageService::instance().ensureTaskDirs(taskId);

    if (DatabaseManager::instance().insertTask(task)) {
        m_taskListModel.addTask(task);
        loadTask(taskId);
        Logger::instance().info("TaskService", QString("Created new task: %1 (%2)").arg(taskTitle, taskId));
        return taskId;
    } else {
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
    m_currentTask->title = title.trimmed();
    DatabaseManager::instance().updateTaskTitle(m_currentTask->id, m_currentTask->title);
    m_taskListModel.updateTask(*m_currentTask);
    emit currentTaskChanged();
    return true;
}

bool TaskService::deleteTask(const QString& taskId) {
    Logger::instance().info("TaskService", QString("Deleting task: %1 and all its associated data").arg(taskId));

    if (m_currentTask && m_currentTask->id == taskId) {
        m_currentTask.reset();
        m_currentPageIndex = -1;
        m_pageListModel.setPages({});
        m_ocrBlockListModel.setBlocks({});
        emit currentTaskChanged();
        emit currentPageChanged();
    }

    // 1. Delete file system directory
    bool fsOk = StorageService::instance().deleteEntireTaskDir(taskId);

    // 2. Delete database records
    bool dbOk = DatabaseManager::instance().deleteTask(taskId);

    if (dbOk) {
        m_taskListModel.removeTask(taskId);
        emit taskDeleted(taskId);
        Logger::instance().info("TaskService", QString("Task %1 successfully deleted.").arg(taskId));
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

    QString pageId = m_currentTask->pages[index].id;
    m_currentTask->pages.removeAt(index);
    m_currentTask->pageCount = static_cast<int>(m_currentTask->pages.size());

    // Re-index remaining pages
    for (int i = 0; i < m_currentTask->pages.size(); ++i) {
        m_currentTask->pages[i].pageIndex = i;
        DatabaseManager::instance().updatePage(m_currentTask->pages[i]);
    }

    DatabaseManager::instance().deletePage(pageId);
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
            DatabaseManager::instance().updatePageEditedText(page.id, page.editedText);
        }

        m_currentTask->totalCharacters = currentTaskTotalCharacters();
        m_currentTask->lowConfidenceCount = currentTaskLowConfidenceCount();
        m_currentTask->pageCount = static_cast<int>(m_currentTask->pages.size());
        DatabaseManager::instance().updateTask(*m_currentTask);
        m_taskListModel.updateTask(*m_currentTask);

        m_hasUnsavedChanges = false;
        emit taskSaved();
    }
}

void TaskService::addPageToCurrentTask(const Page& page) {
    if (!m_currentTask) return;

    m_currentTask->pages.append(page);
    m_currentTask->pageCount = static_cast<int>(m_currentTask->pages.size());
    DatabaseManager::instance().insertPage(page);
    DatabaseManager::instance().updateTask(*m_currentTask);

    m_pageListModel.addPage(page);
    m_taskListModel.updateTask(*m_currentTask);

    if (m_currentPageIndex == -1) {
        selectPage(0);
    }
    updateStatsAndNotify();
}

void TaskService::updatePageOcrResult(const QString& pageId, const OcrResult& result) {
    if (!m_currentTask) return;

    for (int i = 0; i < m_currentTask->pages.size(); ++i) {
        if (m_currentTask->pages[i].id == pageId) {
            auto& page = m_currentTask->pages[i];
            page.ocrResult = result;
            page.editedText = result.rawText;
            page.status = PageStatus::Reviewing;

            DatabaseManager::instance().saveOcrResult(result);
            DatabaseManager::instance().updatePage(page);
            m_pageListModel.updatePage(page);

            if (m_currentPageIndex == i) {
                m_ocrBlockListModel.setBlocks(result.blocks);
                emit currentPageChanged();
            }
            break;
        }
    }

    m_currentTask->status = TaskStatus::Reviewing;
    m_currentTask->totalCharacters = currentTaskTotalCharacters();
    m_currentTask->lowConfidenceCount = currentTaskLowConfidenceCount();
    DatabaseManager::instance().updateTask(*m_currentTask);
    m_taskListModel.updateTask(*m_currentTask);

    updateStatsAndNotify();
}

void TaskService::applyFilterPrintedToCurrentPage(bool filterPrinted) {
    if (!m_currentTask || m_currentPageIndex < 0 || m_currentPageIndex >= m_currentTask->pages.size()) {
        return;
    }

    auto& page = m_currentTask->pages[m_currentPageIndex];
    if (page.ocrResult.blocks.isEmpty()) return;

    QStringList lines;
    for (const auto& block : page.ocrResult.blocks) {
        if (!filterPrinted || block.isHandwriting()) {
            lines.append(block.text);
        }
    }

    page.editedText = lines.join("\n");
    DatabaseManager::instance().updatePageEditedText(page.id, page.editedText);
    m_pageListModel.updatePage(page);
    m_hasUnsavedChanges = true;
    updateStatsAndNotify();
    emit currentPageChanged();
}

void TaskService::applyFilterPrintedToAllPages(bool filterPrinted) {
    if (!m_currentTask) return;

    for (int i = 0; i < m_currentTask->pages.size(); ++i) {
        auto& page = m_currentTask->pages[i];
        if (page.ocrResult.blocks.isEmpty()) continue;

        QStringList lines;
        for (const auto& block : page.ocrResult.blocks) {
            if (!filterPrinted || block.isHandwriting()) {
                lines.append(block.text);
            }
        }
        page.editedText = lines.join("\n");
        DatabaseManager::instance().updatePageEditedText(page.id, page.editedText);
        m_pageListModel.updatePage(page);
    }

    m_hasUnsavedChanges = true;
    updateStatsAndNotify();
    emit currentPageChanged();
}

void TaskService::updateStatsAndNotify() {
    emit currentTaskChanged();
}

} // namespace HandwritingOCR
