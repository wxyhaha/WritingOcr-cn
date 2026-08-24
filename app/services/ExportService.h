#pragma once

#include "../infrastructure/export/IExporter.h"
#include "../infrastructure/export/TxtExporter.h"
#include "../infrastructure/export/MarkdownExporter.h"
#include "../infrastructure/export/DocxExporter.h"
#include <QObject>
#include <QString>
#include <QMap>
#include <memory>

namespace HandwritingOCR {

class ExportService : public QObject {
    Q_OBJECT

public:
    static ExportService& instance();

    Q_INVOKABLE bool exportCurrentTask(const QString& format, const QString& outputPath);
    Q_INVOKABLE bool exportTaskById(const QString& taskId, const QString& format, const QString& outputPath);
    Q_INVOKABLE QString getDefaultExportPath(const QString& format) const;

signals:
    void exportFinished(const QString& filePath);
    void exportError(const QString& message);

private:
    explicit ExportService(QObject* parent = nullptr);
    ~ExportService() override = default;
    ExportService(const ExportService&) = delete;
    ExportService& operator=(const ExportService&) = delete;

    QMap<QString, std::shared_ptr<IExporter>> m_exporters;
};

} // namespace HandwritingOCR
