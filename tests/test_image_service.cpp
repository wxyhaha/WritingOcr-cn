#include "../app/services/ImageService.h"
#include "../app/services/StorageService.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QImage>
#include <iostream>

using namespace HandwritingOCR;

#define CHECK(condition) do { \
    if (!(condition)) { \
        std::cerr << "[FAIL] " #condition " at line " << __LINE__ << std::endl; \
        return 1; \
    } \
} while (false)

int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);
    const QString baseDir = QDir::tempPath() + "/handwriting_ocr_test_images";
    QDir(baseDir).removeRecursively();
    StorageService::instance().init(baseDir);

    // Width 3 forces scan-line padding in Format_Grayscale8. Both equal input
    // rows must remain equal after enhancement.
    QImage padded(3, 2, QImage::Format_Grayscale8);
    const uchar values[] = {10, 100, 200};
    for (int y = 0; y < padded.height(); ++y) {
        uchar* row = padded.scanLine(y);
        for (int x = 0; x < padded.width(); ++x) row[x] = values[x];
    }
    const QImage enhanced = ImageService::instance().applyModerateEnhancement(padded);
    CHECK(!enhanced.isNull());
    for (int x = 0; x < enhanced.width(); ++x) {
        CHECK(enhanced.constScanLine(0)[x] == enhanced.constScanLine(1)[x]);
    }

    const QString input1 = QDir(baseDir).filePath("input1.png");
    const QString input2 = QDir(baseDir).filePath("input2.png");
    QImage source(16, 16, QImage::Format_RGB32);
    source.fill(Qt::white);
    CHECK(source.save(input1));
    CHECK(source.save(input2));

    const auto pages = ImageService::instance().importImages("task_a", {input1, input2}, false, 4);
    CHECK(pages.size() == 2);
    CHECK(pages[0].pageIndex == 4);
    CHECK(pages[1].pageIndex == 5);
    CHECK(QFile::exists(pages[0].originalImagePath));
    CHECK(QFile::exists(pages[1].thumbnailPath));

    QDir(baseDir).removeRecursively();
    std::cout << "All image service tests passed successfully!" << std::endl;
    return 0;
}
