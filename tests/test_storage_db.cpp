#include "../app/infrastructure/database/DatabaseManager.h"
#include "../app/services/StorageService.h"
#include "../app/models/Task.h"
#include "../app/models/Page.h"
#include "../app/models/OcrResult.h"
#include "../app/infrastructure/logging/Logger.h"

#include <iostream>
#include <cassert>
#include <QDir>
#include <QFile>
#include <QCoreApplication>

using namespace HandwritingOCR;

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);
    std::cout << "=== Running Database & Storage Unit Tests ===" << std::endl;

    QString testBaseDir = QDir::tempPath() + "/handwriting_ocr_test_storage";
    QDir(testBaseDir).removeRecursively();

    StorageService::instance().init(testBaseDir);
    DatabaseManager::instance().init(StorageService::instance().getDatabaseFilePath());

    // 1. Test Task Insertion
    Task task;
    task.id = "test_task_1";
    task.title = "测试任务 1";
    task.status = TaskStatus::Draft;
    task.pageCount = 2;
    task.totalCharacters = 100;
    task.lowConfidenceCount = 5;

    bool insertOk = DatabaseManager::instance().insertTask(task);
    assert(insertOk);
    std::cout << "[PASS] Task insertion" << std::endl;

    // 2. Test Storage directories
    bool dirOk = StorageService::instance().ensureTaskDirs(task.id);
    assert(dirOk);
    assert(QDir(StorageService::instance().getTaskSourceDir(task.id)).exists());
    assert(QDir(StorageService::instance().getTaskOcrDir(task.id)).exists());
    std::cout << "[PASS] Storage directories creation" << std::endl;

    // 3. Test Pages Insertion
    Page page1;
    page1.id = "p1";
    page1.taskId = task.id;
    page1.pageIndex = 0;
    page1.originalImagePath = StorageService::instance().getTaskSourceDir(task.id) + "/001.jpg";
    page1.status = PageStatus::Pending;
    assert(DatabaseManager::instance().insertPage(page1));

    Page page2;
    page2.id = "p2";
    page2.taskId = task.id;
    page2.pageIndex = 1;
    page2.originalImagePath = StorageService::instance().getTaskSourceDir(task.id) + "/002.jpg";
    page2.status = PageStatus::Pending;
    assert(DatabaseManager::instance().insertPage(page2));
    std::cout << "[PASS] Pages insertion" << std::endl;

    // 4. Test OCR Results and Blocks Insertion
    OcrResult ocr;
    ocr.id = "ocr_res_1";
    ocr.pageId = page1.id;
    ocr.engine = "PaddleOCR";
    ocr.engineVersion = "PP-OCRv5";
    ocr.rawText = "今天天气很好";

    OcrBlock blk;
    blk.id = "blk_1";
    blk.pageId = page1.id;
    blk.text = "今天天气很好";
    blk.confidence = 0.95;
    blk.bbox = {10, 20, 300, 40};
    ocr.blocks.append(blk);

    assert(DatabaseManager::instance().saveOcrResult(ocr));
    std::cout << "[PASS] Save OCR result & blocks" << std::endl;

    // 5. Test Querying
    auto retrievedTask = DatabaseManager::instance().getTask(task.id);
    assert(retrievedTask != nullptr);
    assert(retrievedTask->title == "测试任务 1");

    auto retrievedPages = DatabaseManager::instance().getPagesByTaskId(task.id);
    assert(retrievedPages.size() == 2);

    auto retrievedOcr = DatabaseManager::instance().getOcrResultByPageId(page1.id);
    assert(retrievedOcr != nullptr);
    assert(retrievedOcr->blocks.size() == 1);
    assert(retrievedOcr->blocks[0].text == "今天天气很好");
    std::cout << "[PASS] Query task, pages, and OCR structure" << std::endl;

    // 6. Test Cascade Task Deletion
    assert(StorageService::instance().deleteEntireTaskDir(task.id));
    assert(!QDir(StorageService::instance().getTaskDir(task.id)).exists());
    assert(DatabaseManager::instance().deleteTask(task.id));
    assert(DatabaseManager::instance().getTask(task.id) == nullptr);
    assert(DatabaseManager::instance().getPagesByTaskId(task.id).isEmpty());
    assert(DatabaseManager::instance().getOcrResultByPageId(page1.id) == nullptr);
    std::cout << "[PASS] Cascade deletion of task, files, and DB records" << std::endl;

    std::cout << "All Database & Storage tests passed successfully!" << std::endl;
    return 0;
}
