#include "MarkdownExporter.h"
#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QDir>

namespace HandwritingOCR {

bool MarkdownExporter::exportDocument(const Task& task, const QString& outputPath, QString* errorMsg) {
    QFileInfo fi(outputPath);
    QDir().mkpath(fi.absolutePath());

    QFile file(outputPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        if (errorMsg) *errorMsg = QString("无法写入文件: %1").arg(file.errorString());
        return false;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);

    out << "# " << task.title << "\n\n";

    for (int i = 0; i < task.pages.size(); ++i) {
        const auto& page = task.pages[i];
        QString text = page.editedText.isEmpty() ? page.ocrResult.rawText : page.editedText;
        if (task.pages.size() > 1) {
            out << "## 第 " << (i + 1) << " 页\n\n";
        }

        // Output lines with markdown paragraph structure
        QStringList lines = text.split("\n");
        for (const QString& line : lines) {
            QString trimmed = line.trimmed();
            if (!trimmed.isEmpty()) {
                out << trimmed << "\n\n";
            }
        }
    }

    file.close();
    return true;
}

} // namespace HandwritingOCR
