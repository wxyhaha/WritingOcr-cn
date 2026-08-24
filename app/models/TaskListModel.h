#pragma once

#include "Task.h"
#include <QAbstractListModel>
#include <QVector>

namespace HandwritingOCR {

class TaskListModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum TaskRoles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        CreatedAtRole,
        UpdatedAtRole,
        StatusRole,
        PageCountRole,
        TotalCharactersRole,
        LowConfidenceCountRole
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

private:
    QVector<Task> m_tasks;
};

} // namespace HandwritingOCR
