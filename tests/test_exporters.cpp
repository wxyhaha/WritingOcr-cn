#include "../app/infrastructure/export/TxtExporter.h"
#include "../app/infrastructure/export/MarkdownExporter.h"
#include "../app/infrastructure/export/DocxExporter.h"
#include "../app/models/Task.h"
#include "../app/models/Page.h"
#include "../app/models/OcrResult.h"

#include <iostream>
#include <cassert>
#include <QDir>
#include <QFile>
#include <QCoreApplication>

using namespace HandwritingOCR;

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);
    std::cout << "=== Running Exporters Unit Tests ===" << std::endl;

    QString exportTestDir = QDir::tempPath() + "/handwriting_ocr_test_exports";
    QDir().mkpath(exportTestDir);

    Task task;
    task.id = "exp_task_1";
    task.title = "测试手写文章导出";

    Page page1;
    page1.id = "exp_p1";
    page1.pageIndex = 0;
    page1.editedText = "第一页：今天下午天气很好，我去了人民公园散步。";
    task.pages.append(page1);

    Page page2;
    page2.id = "exp_p2";
    page2.pageIndex = 1;
    page2.editedText = "第二页：公园里有很多老人在打太极拳，湖边微风徐徐。";
    task.pages.append(page2);

    // 1. Test TXT Exporter
    TxtExporter txtExp;
    QString txtPath = exportTestDir + "/result.txt";
    QString err;
    bool txtOk = txtExp.exportDocument(task, txtPath, &err);
    assert(txtOk);
    assert(QFile::exists(txtPath));
    std::cout << "[PASS] TXT Export" << std::endl;

    // 2. Test Markdown Exporter
    MarkdownExporter mdExp;
    QString mdPath = exportTestDir + "/result.md";
    bool mdOk = mdExp.exportDocument(task, mdPath, &err);
    assert(mdOk);
    assert(QFile::exists(mdPath));
    std::cout << "[PASS] Markdown Export" << std::endl;

    // 3. Test DOCX Exporter
    DocxExporter docxExp;
    QString docxPath = exportTestDir + "/result.docx";
    bool docxOk = docxExp.exportDocument(task, docxPath, &err);
    assert(docxOk);
    assert(QFile::exists(docxPath));
    std::cout << "[PASS] DOCX Export" << std::endl;

    std::cout << "All Exporter tests passed successfully!" << std::endl;
    return 0;
}
