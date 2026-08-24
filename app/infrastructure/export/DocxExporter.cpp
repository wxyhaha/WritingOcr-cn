#include "DocxExporter.h"
#include "../logging/Logger.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTemporaryFile>
#include <QProcess>
#include <QCoreApplication>
#include <QDir>
#include <QFile>

namespace HandwritingOCR {

bool DocxExporter::exportDocument(const Task& task, const QString& outputPath, QString* errorMsg) {
    QJsonObject root;
    root["title"] = task.title;

    QJsonArray pagesArr;
    for (const auto& page : task.pages) {
        QJsonObject pObj;
        pObj["editedText"] = page.editedText;
        pObj["rawText"] = page.ocrResult.rawText;
        pagesArr.append(pObj);
    }
    root["pages"] = pagesArr;

    QTemporaryFile tmpJson;
    if (!tmpJson.open()) {
        if (errorMsg) *errorMsg = "无法创建临时 JSON 文件进行 DOCX 导出";
        return false;
    }

    tmpJson.write(QJsonDocument(root).toJson());
    tmpJson.flush();
    QString tempJsonPath = tmpJson.fileName();

    QString appDir = QCoreApplication::applicationDirPath();
    QString scriptPath = QDir(appDir).filePath("scripts/export_docx.py");
    if (!QFile::exists(scriptPath)) {
        scriptPath = "d:/otherCode/WritingOcr-cn/scripts/export_docx.py";
    }

    QProcess process;
    process.start("python", QStringList() << scriptPath << tempJsonPath << outputPath);
    if (!process.waitForFinished(15000)) {
        process.kill();
        if (errorMsg) *errorMsg = "DOCX 导出进程超时";
        return false;
    }

    if (process.exitCode() != 0) {
        QString err = process.readAllStandardError();
        if (errorMsg) *errorMsg = QString("DOCX 导出失败: %1").arg(err.trimmed());
        Logger::instance().error("DocxExporter", QString("Docx export error: %1").arg(err));
        return false;
    }

    Logger::instance().info("DocxExporter", QString("DOCX exported successfully to %1").arg(outputPath));
    return true;
}

} // namespace HandwritingOCR
