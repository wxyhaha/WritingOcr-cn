#include "ExportService.h"
#include "TaskService.h"
#include "StorageService.h"
#include "../infrastructure/database/DatabaseManager.h"
#include "../infrastructure/logging/Logger.h"
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>

namespace HandwritingOCR {

ExportService& ExportService::instance() {
    static ExportService s_instance;
    return s_instance;
}

ExportService::ExportService(QObject* parent) : QObject(parent) {
    m_exporters["txt"] = std::make_shared<TxtExporter>();
    m_exporters["md"] = std::make_shared<MarkdownExporter>();
    m_exporters["docx"] = std::make_shared<DocxExporter>();
}

QString ExportService::getDefaultExportPath(const QString& format) const {
    QString docPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    auto& taskService = TaskService::instance();
    QString title = taskService.hasCurrentTask() ? taskService.currentTaskTitle() : "手写文章导出";
    QString safeTitle = title.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");
    QString ext = format.toLower();
    if (!ext.startsWith(".")) ext = "." + ext;

    return QDir(docPath).filePath(QString("%1_%2%3")
                                      .arg(safeTitle)
                                      .arg(QDateTime::currentDateTime().toString("yyyyMMdd_hhmm"))
                                      .arg(ext));
}

bool ExportService::exportCurrentTask(const QString& format, const QString& outputPath) {
    auto& taskService = TaskService::instance();
    if (!taskService.hasCurrentTask()) {
        emit exportError("没有可导出的当前任务。");
        return false;
    }

    taskService.saveNow();
    Task* task = taskService.currentTaskPtr();
    if (!task) {
        emit exportError("任务数据为空。");
        return false;
    }

    QString fmt = format.toLower();
    if (!m_exporters.contains(fmt)) {
        emit exportError(QString("不支持的导出格式: %1").arg(format));
        return false;
    }

    QString errMsg;
    bool ok = m_exporters[fmt]->exportDocument(*task, outputPath, &errMsg);
    if (ok) {
        Logger::instance().info("ExportService", QString("Exported task %1 to %2").arg(task->id, outputPath));
        emit exportFinished(outputPath);
        return true;
    } else {
        Logger::instance().error("ExportService", QString("Export error: %1").arg(errMsg));
        emit exportError(errMsg);
        return false;
    }
}

bool ExportService::exportTaskById(const QString& taskId, const QString& format, const QString& outputPath) {
    auto task = DatabaseManager::instance().getTask(taskId);
    if (!task) {
        emit exportError("指定任务不存在。");
        return false;
    }

    auto pages = DatabaseManager::instance().getPagesByTaskId(taskId);
    for (auto& p : pages) {
        auto ocr = DatabaseManager::instance().getOcrResultByPageId(p.id);
        if (ocr) p.ocrResult = *ocr;
    }
    task->pages = pages;

    QString fmt = format.toLower();
    if (!m_exporters.contains(fmt)) {
        emit exportError(QString("不支持的导出格式: %1").arg(format));
        return false;
    }

    QString errMsg;
    bool ok = m_exporters[fmt]->exportDocument(*task, outputPath, &errMsg);
    if (ok) {
        Logger::instance().info("ExportService", QString("Exported task %1 to %2").arg(taskId, outputPath));
        emit exportFinished(outputPath);
        return true;
    } else {
        emit exportError(errMsg);
        return false;
    }
}

} // namespace HandwritingOCR
