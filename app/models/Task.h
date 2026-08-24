#pragma once

#include "Page.h"
#include <QString>
#include <QVector>
#include <QDateTime>
#include <QJsonObject>
#include <QJsonArray>

namespace HandwritingOCR {

enum class TaskStatus {
    Draft,
    Uploading,
    Ready,
    Processing,
    Reviewing,
    Completed,
    Failed
};

inline QString taskStatusToString(TaskStatus status) {
    switch (status) {
        case TaskStatus::Draft:      return "Draft";
        case TaskStatus::Uploading:  return "Uploading";
        case TaskStatus::Ready:      return "Ready";
        case TaskStatus::Processing: return "Processing";
        case TaskStatus::Reviewing:  return "Reviewing";
        case TaskStatus::Completed:  return "Completed";
        case TaskStatus::Failed:     return "Failed";
        default:                     return "Draft";
    }
}

inline TaskStatus taskStatusFromString(const QString& str) {
    if (str == "Uploading")  return TaskStatus::Uploading;
    if (str == "Ready")      return TaskStatus::Ready;
    if (str == "Processing") return TaskStatus::Processing;
    if (str == "Reviewing")  return TaskStatus::Reviewing;
    if (str == "Completed")  return TaskStatus::Completed;
    if (str == "Failed")     return TaskStatus::Failed;
    return TaskStatus::Draft;
}

struct Task {
    QString id;
    QString title;
    QString createdAt;
    QString updatedAt;
    TaskStatus status = TaskStatus::Draft;
    int pageCount = 0;
    int totalCharacters = 0;
    int lowConfidenceCount = 0;
    QString coverThumbnailPath;
    QString coverImagePath;
    QVector<Page> pages;

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["id"] = id;
        obj["title"] = title;
        obj["createdAt"] = createdAt;
        obj["updatedAt"] = updatedAt;
        obj["status"] = taskStatusToString(status);
        obj["pageCount"] = pageCount;
        obj["totalCharacters"] = totalCharacters;
        obj["lowConfidenceCount"] = lowConfidenceCount;

        QJsonArray pagesArr;
        for (const auto& page : pages) {
            pagesArr.append(page.toJson());
        }
        obj["pages"] = pagesArr;
        return obj;
    }

    static Task fromJson(const QJsonObject& obj) {
        Task task;
        task.id = obj["id"].toString();
        task.title = obj["title"].toString();
        task.createdAt = obj["createdAt"].toString();
        task.updatedAt = obj["updatedAt"].toString();
        task.status = taskStatusFromString(obj["status"].toString());
        task.pageCount = obj["pageCount"].toInt();
        task.totalCharacters = obj["totalCharacters"].toInt();
        task.lowConfidenceCount = obj["lowConfidenceCount"].toInt();

        QJsonArray pagesArr = obj["pages"].toArray();
        for (const auto& pVal : pagesArr) {
            task.pages.append(Page::fromJson(pVal.toObject()));
        }
        return task;
    }
};

} // namespace HandwritingOCR
