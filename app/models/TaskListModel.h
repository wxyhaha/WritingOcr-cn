#pragma once

#include "Task.h"
#include <QAbstractListModel>
#include <QVector>

namespace HandwritingOCR {

class TaskListModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum TaskRoles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        CreatedAtRole,
        UpdatedAtRole,
        StatusRole,
        PageCountRole,
        TotalCharactersRole,
        LowConfidenceCountRole,
        CoverThumbnailRole,
        CoverImageRole
    };

    explicit TaskListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setTasks(const QVector<Task>& tasks);
    void addTask(const Task& task);
    void updateTask(const Task& task);
    void removeTask(const QString& taskId);
    const QVector<Task>& tasks() const { return m_tasks; }
    int count() const { return static_cast<int>(m_tasks.size()); }

signals:
    void countChanged();

private:
    QVector<Task> m_tasks;
};

} // namespace HandwritingOCR
