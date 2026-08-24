#pragma once

#include "../../models/OcrResult.h"
#include <QString>
#include <optional>

namespace HandwritingOCR {

struct ProviderInfo {
    QString name = "PaddleOCR";
    QString version = "PP-OCRv5";
    bool isAvailable = false;
    QString description;
};

struct OcrRequest {
    QString imagePath;
    QString lang = "ch";
    bool filterPrintedText = true;
};

class IOcrProvider {
public:
    virtual ~IOcrProvider() = default;

    virtual ProviderInfo info() const = 0;
    virtual bool checkAvailability(QString* statusMessage = nullptr) = 0;
    virtual std::optional<OcrResult> recognize(const OcrRequest& request, QString* errorMsg = nullptr) = 0;
};

} // namespace HandwritingOCR
