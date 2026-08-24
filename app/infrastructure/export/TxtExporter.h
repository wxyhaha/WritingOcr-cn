#pragma once

#include "IExporter.h"

namespace HandwritingOCR {

class TxtExporter : public IExporter {
public:
    QString formatName() const override { return "Plain Text"; }
    QString fileExtension() const override { return "txt"; }
    bool exportDocument(const Task& task, const QString& outputPath, QString* errorMsg = nullptr) override;
};

} // namespace HandwritingOCR
