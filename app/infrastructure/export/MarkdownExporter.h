#pragma once

#include "IExporter.h"

namespace HandwritingOCR {

class MarkdownExporter : public IExporter {
public:
    QString formatName() const override { return "Markdown"; }
    QString fileExtension() const override { return "md"; }
    bool exportDocument(const Task& task, const QString& outputPath, QString* errorMsg = nullptr) override;
};

} // namespace HandwritingOCR
