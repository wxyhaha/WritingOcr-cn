#pragma once

#include "../models/Task.h"
#include "../models/Page.h"
#include "../models/TaskListModel.h"
#include "../models/PageListModel.h"
#include "../models/OcrBlockListModel.h"
#include <QObject>
#include <QTimer>
#include <memory>

namespace HandwritingOCR {

class TaskService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool hasCurrentTask READ hasCurrentTask NOTIFY currentTaskChanged)
    Q_PROPERTY(QString currentTaskId READ currentTaskId NOTIFY currentTaskChanged)
    Q_PROPERTY(QString currentTaskTitle READ currentTaskTitle NOTIFY currentTaskChanged)
    Q_PROPERTY(QString currentTaskStatus READ currentTaskStatus NOTIFY currentTaskChanged)
    Q_PROPERTY(int currentTaskPageCount READ currentTaskPageCount NOTIFY currentTaskChanged)
    Q_PROPERTY(int currentTaskTotalCharacters READ currentTaskTotalCharacters NOTIFY currentTaskChanged)
    Q_PROPERTY(int currentTaskLowConfidenceCount READ currentTaskLowConfidenceCount NOTIFY currentTaskChanged)

    Q_PROPERTY(int currentPageIndex READ currentPageIndex NOTIFY currentPageChanged)
    Q_PROPERTY(QString currentPageId READ currentPageId NOTIFY currentPageChanged)
    Q_PROPERTY(QString currentOriginalImage READ currentOriginalImage NOTIFY currentPageChanged)
    Q_PROPERTY(QString currentProcessedImage READ currentProcessedImage NOTIFY currentPageChanged)
    Q_PROPERTY(QString currentEditedText READ currentEditedText NOTIFY currentPageChanged)
    Q_PROPERTY(QString currentPageStatus READ currentPageStatus NOTIFY currentPageChanged)

public:
    static TaskService& instance();

    void init();

    TaskListModel* taskListModel() { return &m_taskListModel; }
    PageListModel* pageListModel() { return &m_pageListModel; }
    OcrBlockListModel* ocrBlockListModel() { return &m_ocrBlockListModel; }

    bool hasCurrentTask() const { return m_currentTask != nullptr; }
    QString currentTaskId() const { return m_currentTask ? m_currentTask->id : QString(); }
    QString currentTaskTitle() const { return m_currentTask ? m_currentTask->title : QString(); }
    QString currentTaskStatus() const { return m_currentTask ? taskStatusToString(m_currentTask->status) : QString(); }
    int currentTaskPageCount() const { return m_currentTask ? static_cast<int>(m_currentTask->pages.size()) : 0; }
    int currentTaskTotalCharacters() const;
    int currentTaskLowConfidenceCount() const;

    int currentPageIndex() const { return m_currentPageIndex; }
    QString currentPageId() const;
    QString currentOriginalImage() const;
    QString currentProcessedImage() const;
    QString currentEditedText() const;
    QString currentPageStatus() const;

    // Task operations
    Q_INVOKABLE QString createNewTask(const QString& title = QString());
    Q_INVOKABLE bool loadTask(const QString& taskId);
    Q_INVOKABLE bool closeCurrentTask();
    Q_INVOKABLE bool updateTaskTitle(const QString& title);
    Q_INVOKABLE bool deleteTask(const QString& taskId);
    Q_INVOKABLE void refreshTaskList();

    // Page operations
    Q_INVOKABLE bool selectPage(int index);
    Q_INVOKABLE bool selectPageById(const QString& pageId);
    Q_INVOKABLE bool deletePage(int index);
    Q_INVOKABLE void updateEditedText(const QString& newText);
    Q_INVOKABLE void reorderPages(int fromIndex, int toIndex);

    // Save
    Q_INVOKABLE void triggerAutoSave();
    Q_INVOKABLE void saveNow();

    void addPageToCurrentTask(const Page& page);
    void updatePageOcrResult(const QString& pageId, const OcrResult& result);
    Task* currentTaskPtr() { return m_currentTask.get(); }
    Page* currentPagePtr();

signals:
    void currentTaskChanged();
    void currentPageChanged();
    void taskSaved();
    void taskDeleted(const QString& taskId);
    void taskError(const QString& message);

private slots:
    void onAutoSaveTimeout();

private:
    explicit TaskService(QObject* parent = nullptr);
    ~TaskService() override = default;
    TaskService(const TaskService&) = delete;
    TaskService& operator=(const TaskService&) = delete;

    void updateStatsAndNotify();

    TaskListModel m_taskListModel;
    PageListModel m_pageListModel;
    OcrBlockListModel m_ocrBlockListModel;

    std::unique_ptr<Task> m_currentTask;
    int m_currentPageIndex = -1;

    QTimer m_autoSaveTimer;
    bool m_hasUnsavedChanges = false;
};

} // namespace HandwritingOCR
