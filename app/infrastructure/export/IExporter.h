#pragma once

#include "../../models/Task.h"
#include <QString>

namespace HandwritingOCR {

class IExporter {
public:
    virtual ~IExporter() = default;
    virtual QString formatName() const = 0;
    virtual QString fileExtension() const = 0;
    virtual bool exportDocument(const Task& task, const QString& outputPath, QString* errorMsg = nullptr) = 0;
};

} // namespace HandwritingOCR
