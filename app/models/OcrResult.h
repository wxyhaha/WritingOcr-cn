#pragma once

#include "OcrBlock.h"
#include <QString>
#include <QVector>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>

namespace HandwritingOCR {

struct OcrResult {
    QString id;
    QString pageId;
    QString engine = "PaddleOCR";
    QString engineVersion = "PP-OCRv5";
    QString createdAt;
    int imageWidth = 0;
    int imageHeight = 0;
    QVector<OcrBlock> blocks;
    QString rawText;

    int totalCharacters() const {
        int count = 0;
        for (const auto& block : blocks) {
            count += block.text.trimmed().length();
        }
        return count;
    }

    int lowConfidenceCount(double threshold = 0.75) const {
        int count = 0;
        for (const auto& block : blocks) {
            if (block.isLowConfidence(threshold)) {
                count++;
            }
        }
        return count;
    }

    QJsonObject toJson() const {
        QJsonObject obj;
        obj["id"] = id;
        obj["pageId"] = pageId;
        obj["engine"] = engine;
        obj["engineVersion"] = engineVersion;
        obj["createdAt"] = createdAt.isEmpty() ? QDateTime::currentDateTime().toString(Qt::ISODate) : createdAt;
        obj["imageWidth"] = imageWidth;
        obj["imageHeight"] = imageHeight;
        obj["rawText"] = rawText;

        QJsonArray blocksArr;
        for (const auto& block : blocks) {
            blocksArr.append(block.toJson());
        }
        obj["blocks"] = blocksArr;
        return obj;
    }

    static OcrResult fromJson(const QJsonObject& obj) {
        OcrResult res;
        res.id = obj["id"].toString();
        res.pageId = obj["pageId"].toString();
        res.engine = obj["engine"].toString("PaddleOCR");
        res.engineVersion = obj["engineVersion"].toString("PP-OCRv5");
        res.createdAt = obj["createdAt"].toString();
        res.imageWidth = obj["imageWidth"].toInt();
        res.imageHeight = obj["imageHeight"].toInt();
        res.rawText = obj["rawText"].toString();

        QJsonArray blocksArr = obj["blocks"].toArray();
        for (const auto& bVal : blocksArr) {
            res.blocks.append(OcrBlock::fromJson(bVal.toObject()));
        }
        return res;
    }
};

} // namespace HandwritingOCR
