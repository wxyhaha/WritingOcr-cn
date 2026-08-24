#pragma once

#include "OcrResult.h"
#include <QString>
#include <QDateTime>
#include <QJsonObject>

namespace HandwritingOCR {

enum class PageStatus {
    Pending,
    Preprocessing,
    OCRProcessing,
    Reviewing,
    Completed,
    Failed
};

inline QString pageStatusToString(PageStatus status) {
    switch (status) {
        case PageStatus::Pending:       return "Pending";
        case PageStatus::Preprocessing: return "Preprocessing";
        case PageStatus::OCRProcessing: return "OCRProcessing";
        case PageStatus::Reviewing:     return "Reviewing";
        case PageStatus::Completed:     return "Completed";
        case PageStatus::Failed:        return "Failed";
        default:                        return "Pending";
    }
}

inline PageStatus pageStatusFromString(const QString& str) {
    if (str == "Preprocessing") return PageStatus::Preprocessing;
    if (str == "OCRProcessing") return PageStatus::OCRProcessing;
    if (str == "Reviewing")     return PageStatus::Reviewing;
    if (str == "Completed")     return PageStatus::Completed;
    if (str == "Failed")        return PageStatus::Failed;
    return PageStatus::Pending;
}

struct Page {
    QString id;
    QString taskId;
    int pageIndex = 0;
    QString originalImagePath;
    QString processedImagePath;
    QString thumbnailPath;
    QString ocrResultPath;
    QString editedText;
    PageStatus status = PageStatus::Pending;
    QString createdAt;
    QString updatedAt;

    // In-memory OCR result cache
    OcrResult ocrResult;

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["id"] = id;
        obj["taskId"] = taskId;
        obj["pageIndex"] = pageIndex;
        obj["originalImagePath"] = originalImagePath;
        obj["processedImagePath"] = processedImagePath;
        obj["thumbnailPath"] = thumbnailPath;
        obj["ocrResultPath"] = ocrResultPath;
        obj["editedText"] = editedText;
        obj["status"] = pageStatusToString(status);
        obj["createdAt"] = createdAt;
        obj["updatedAt"] = updatedAt;
        return obj;
    }

    static Page fromJson(const QJsonObject& obj) {
        Page page;
        page.id = obj["id"].toString();
        page.taskId = obj["taskId"].toString();
        page.pageIndex = obj["pageIndex"].toInt();
        page.originalImagePath = obj["originalImagePath"].toString();
        page.processedImagePath = obj["processedImagePath"].toString();
        page.thumbnailPath = obj["thumbnailPath"].toString();
        page.ocrResultPath = obj["ocrResultPath"].toString();
        page.editedText = obj["editedText"].toString();
        page.status = pageStatusFromString(obj["status"].toString());
        page.createdAt = obj["createdAt"].toString();
        page.updatedAt = obj["updatedAt"].toString();
        return page;
    }
};

} // namespace HandwritingOCR
