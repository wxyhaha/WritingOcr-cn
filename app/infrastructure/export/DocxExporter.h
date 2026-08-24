#pragma once

#include "IExporter.h"

namespace HandwritingOCR {

class DocxExporter : public IExporter {
public:
    QString formatName() const override { return "Microsoft Word (.docx)"; }
    QString fileExtension() const override { return "docx"; }
    bool exportDocument(const Task& task, const QString& outputPath, QString* errorMsg = nullptr) override;
};

} // namespace HandwritingOCR
