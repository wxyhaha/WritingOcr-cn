#include "TaskListModel.h"

namespace HandwritingOCR {

TaskListModel::TaskListModel(QObject* parent) : QAbstractListModel(parent) {}

int TaskListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_tasks.size());
}

QVariant TaskListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_tasks.size()) {
        return QVariant();
    }

    const auto& task = m_tasks[index.row()];
    switch (role) {
        case IdRole:                 return task.id;
        case TitleRole:              return task.title;
        case CreatedAtRole:          return task.createdAt;
        case UpdatedAtRole:          return task.updatedAt;
        case StatusRole:             return taskStatusToString(task.status);
        case PageCountRole:          return task.pageCount;
        case TotalCharactersRole:    return task.totalCharacters;
        case LowConfidenceCountRole: return task.lowConfidenceCount;
        default:                     return QVariant();
    }
}

QHash<int, QByteArray> TaskListModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[IdRole] = "id";
    roles[TitleRole] = "title";
    roles[CreatedAtRole] = "createdAt";
    roles[UpdatedAtRole] = "updatedAt";
    roles[StatusRole] = "status";
    roles[PageCountRole] = "pageCount";
    roles[TotalCharactersRole] = "totalCharacters";
    roles[LowConfidenceCountRole] = "lowConfidenceCount";
    return roles;
}

void TaskListModel::setTasks(const QVector<Task>& tasks) {
    beginResetModel();
    m_tasks = tasks;
    endResetModel();
}

void TaskListModel::addTask(const Task& task) {
    beginInsertRows(QModelIndex(), 0, 0);
    m_tasks.prepend(task);
    endInsertRows();
}

void TaskListModel::updateTask(const Task& task) {
    for (int i = 0; i < m_tasks.size(); ++i) {
        if (m_tasks[i].id == task.id) {
            m_tasks[i] = task;
            QModelIndex idx = index(i, 0);
            emit dataChanged(idx, idx);
            break;
        }
    }
}

void TaskListModel::removeTask(const QString& taskId) {
    for (int i = 0; i < m_tasks.size(); ++i) {
        if (m_tasks[i].id == taskId) {
            beginRemoveRows(QModelIndex(), i, i);
            m_tasks.removeAt(i);
            endRemoveRows();
            break;
        }
    }
}

} // namespace HandwritingOCR
