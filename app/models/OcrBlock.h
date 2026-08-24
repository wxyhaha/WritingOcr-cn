#pragma once

#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QRectF>

namespace HandwritingOCR {

struct BoundingBox {
    double x = 0.0;
    double y = 0.0;
    double width = 0.0;
    double height = 0.0;

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["x"] = x;
        obj["y"] = y;
        obj["width"] = width;
        obj["height"] = height;
        return obj;
    }

    static BoundingBox fromJson(const QJsonObject& obj) {
        BoundingBox bbox;
        bbox.x = obj["x"].toDouble();
        bbox.y = obj["y"].toDouble();
        bbox.width = obj["width"].toDouble();
        bbox.height = obj["height"].toDouble();
        return bbox;
    }

    QRectF toQRectF() const {
        return QRectF(x, y, width, height);
    }
};

struct OcrBlock {
    QString id;
    QString pageId;
    QString text;
    double confidence = 1.0;
    BoundingBox bbox;
    int lineIndex = 0;
    int blockIndex = 0;
    QString type = "text";   // "text", "title", "punctuation"
    QString status = "raw";  // "raw", "reviewed", "modified"

    bool isLowConfidence(double threshold = 0.75) const {
        return confidence < threshold;
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["id"] = id;
        obj["pageId"] = pageId;
        obj["text"] = text;
        obj["confidence"] = confidence;
        obj["bbox"] = bbox.toJson();
        obj["lineIndex"] = lineIndex;
        obj["blockIndex"] = blockIndex;
        obj["type"] = type;
        obj["status"] = status;
        return obj;
    }

    static OcrBlock fromJson(const QJsonObject& obj) {
        OcrBlock block;
        block.id = obj["id"].toString();
        block.pageId = obj["pageId"].toString();
        block.text = obj["text"].toString();
        block.confidence = obj["confidence"].toDouble(1.0);
        block.bbox = BoundingBox::fromJson(obj["bbox"].toObject());
        block.lineIndex = obj["lineIndex"].toInt();
        block.blockIndex = obj["blockIndex"].toInt();
        block.type = obj["type"].toString("text");
        block.status = obj["status"].toString("raw");
        return block;
    }
};

} // namespace HandwritingOCR
