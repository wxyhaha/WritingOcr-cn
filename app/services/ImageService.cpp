#include "ImageService.h"
#include "StorageService.h"
#include "../infrastructure/logging/Logger.h"
#include <QImageReader>
#include <QImageWriter>
#include <QFileInfo>
#include <QFile>
#include <QDir>
#include <QUuid>
#include <QDateTime>
#include <QPainter>

namespace HandwritingOCR {

ImageService& ImageService::instance() {
    static ImageService s_instance;
    return s_instance;
}

ImageService::ImageService(QObject* parent) : QObject(parent) {}

bool ImageService::isSupportedImageFile(const QString& filePath) {
    QFileInfo fi(filePath);
    if (!fi.exists() || !fi.isFile()) return false;
    QString ext = fi.suffix().toLower();
    return (ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "webp" || ext == "bmp");
}

QImage ImageService::loadAndCorrectExif(const QString& filePath) {
    QImageReader reader(filePath);
    reader.setAutoTransform(true); // Qt handles EXIF orientation automatically
    QImage image = reader.read();
    if (image.isNull()) {
        Logger::instance().error("ImageService", QString("Failed to read image at: %1 (%2)").arg(filePath, reader.errorString()));
    }
    return image;
}

QImage ImageService::applyModerateEnhancement(const QImage& input) {
    if (input.isNull()) return input;

    // Convert to grayscale for contrast analysis and gentle enhancement
    QImage gray = input.convertToFormat(QImage::Format_Grayscale8);

    // Calculate histogram for min/max stretch (clip 1% extremes to avoid noise saturation)
    int totalPixels = gray.width() * gray.height();
    if (totalPixels <= 0) return QImage();
    int hist[256] = {0};
    for (int y = 0; y < gray.height(); ++y) {
        const uchar* row = gray.constScanLine(y);
        for (int x = 0; x < gray.width(); ++x) {
            hist[row[x]]++;
        }
    }

    int lowCut = totalPixels * 0.02;  // 2% black point
    int highCut = totalPixels * 0.98; // 98% white point

    int count = 0;
    int minVal = 0;
    for (int i = 0; i < 256; ++i) {
        count += hist[i];
        if (count >= lowCut) {
            minVal = i;
            break;
        }
    }

    count = 0;
    int maxVal = 255;
    for (int i = 255; i >= 0; --i) {
        count += hist[i];
        if (count >= (totalPixels - highCut)) {
            maxVal = i;
            break;
        }
    }

    if (maxVal <= minVal) {
        maxVal = 255;
        minVal = 0;
    }

    // Build lookup table for gentle linear contrast stretching
    uchar lut[256];
    for (int i = 0; i < 256; ++i) {
        if (i <= minVal) lut[i] = 0;
        else if (i >= maxVal) lut[i] = 255;
        else lut[i] = static_cast<uchar>((i - minVal) * 255.0 / (maxVal - minVal));
    }

    QImage enhanced(gray.size(), QImage::Format_Grayscale8);
    if (enhanced.isNull()) return QImage();
    for (int y = 0; y < gray.height(); ++y) {
        const uchar* inputRow = gray.constScanLine(y);
        uchar* outputRow = enhanced.scanLine(y);
        for (int x = 0; x < gray.width(); ++x) {
            outputRow[x] = lut[inputRow[x]];
        }
    }

    return enhanced;
}

bool ImageService::generateThumbnail(const QString& imagePath, const QString& thumbnailPath, int maxDimension) {
    QImage image = loadAndCorrectExif(imagePath);
    if (image.isNull()) return false;

    QImage thumb = image.scaled(maxDimension, maxDimension, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    QFileInfo fi(thumbnailPath);
    QDir().mkpath(fi.absolutePath());

    return thumb.save(thumbnailPath, "JPG", 85);
}

bool ImageService::preprocessImage(const QString& sourcePath, const QString& outputPath, bool autoEnhance) {
    QImage image = loadAndCorrectExif(sourcePath);
    if (image.isNull()) return false;

    QImage finalImage = image;
    if (autoEnhance) {
        finalImage = applyModerateEnhancement(image);
    }

    QFileInfo fi(outputPath);
    QDir().mkpath(fi.absolutePath());
    return finalImage.save(outputPath, "PNG");
}

QVector<Page> ImageService::importImages(const QString& taskId, const QStringList& filePaths,
                                         bool autoEnhance, int startPageIndex) {
    QVector<Page> createdPages;
    if (taskId.isEmpty() || filePaths.isEmpty()) {
        return createdPages;
    }

    auto& storage = StorageService::instance();
    storage.ensureTaskDirs(taskId);

    QString sourceDir = storage.getTaskSourceDir(taskId);
    QString processedDir = storage.getTaskProcessedDir(taskId);
    QString thumbDir = storage.getTaskThumbnailDir(taskId);

    int total = filePaths.size();
    for (int i = 0; i < total; ++i) {
        const QString& filePath = filePaths[i];
        if (!isSupportedImageFile(filePath)) {
            Logger::instance().warn("ImageService", QString("Skipping unsupported file: %1").arg(filePath));
            continue;
        }

        QString pageId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        QString fileExt = QFileInfo(filePath).suffix().toLower();
        if (fileExt.isEmpty()) fileExt = "jpg";

        const int pageIndex = startPageIndex + static_cast<int>(createdPages.size());
        const QString pageNumber = QString::number(pageIndex + 1).rightJustified(3, '0');
        QString targetSourceName = QString("%1_%2.%3").arg(pageNumber, pageId.left(8), fileExt);
        QString targetProcessedName = QString("%1_%2.png").arg(pageNumber, pageId.left(8));
        QString targetThumbName = QString("%1_%2_thumb.jpg").arg(pageNumber, pageId.left(8));

        QString targetSourcePath = QDir(sourceDir).filePath(targetSourceName);
        QString targetProcessedPath = QDir(processedDir).filePath(targetProcessedName);
        QString targetThumbPath = QDir(thumbDir).filePath(targetThumbName);

        // 1. Copy source image (or save auto-rotated version if EXIF rotation was needed)
        QImage img = loadAndCorrectExif(filePath);
        if (img.isNull()) {
            emit importError(QString("无法读取图片: %1").arg(filePath));
            continue;
        }

        // Save normalized source image
        if (!img.save(targetSourcePath)) {
            emit importError(QString("无法保存原始图片: %1").arg(filePath));
            continue;
        }

        // 2. Preprocess image
        if (autoEnhance) {
            QImage enhanced = applyModerateEnhancement(img);
            if (enhanced.isNull() || !enhanced.save(targetProcessedPath, "PNG")) {
                QFile::remove(targetSourcePath);
                emit importError(QString("无法保存预处理图片: %1").arg(filePath));
                continue;
            }
        } else {
            // In original mode, processed image is identical to source
            targetProcessedPath = targetSourcePath;
        }

        // 3. Generate thumbnail
        QImage thumb = img.scaled(260, 260, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        if (!thumb.save(targetThumbPath, "JPG", 85)) {
            QFile::remove(targetSourcePath);
            if (targetProcessedPath != targetSourcePath) QFile::remove(targetProcessedPath);
            emit importError(QString("无法保存缩略图: %1").arg(filePath));
            continue;
        }

        // 4. Create Page structure
        Page page;
        page.id = pageId;
        page.taskId = taskId;
        page.pageIndex = pageIndex;
        page.originalImagePath = targetSourcePath;
        page.processedImagePath = targetProcessedPath;
        page.thumbnailPath = targetThumbPath;
        page.status = PageStatus::Pending;
        page.createdAt = QDateTime::currentDateTime().toString(Qt::ISODate);
        page.updatedAt = page.createdAt;

        createdPages.append(page);
        emit importProgress(i + 1, total);
    }

    emit importFinished(static_cast<int>(createdPages.size()));
    Logger::instance().info("ImageService", QString("Imported %1 images for task %2").arg(createdPages.size()).arg(taskId));
    return createdPages;
}

} // namespace HandwritingOCR
