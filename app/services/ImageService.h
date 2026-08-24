#pragma once

#include "../models/Page.h"
#include <QObject>
#include <QString>
#include <QStringList>
#include <QImage>
#include <QFuture>

namespace HandwritingOCR {

class ImageService : public QObject {
    Q_OBJECT

public:
    static ImageService& instance();

    // Import local image files into a task
    // Returns list of successfully created pages
    QVector<Page> importImages(const QString& taskId, const QStringList& filePaths, bool autoEnhance = false);

    // Preprocessing single image
    bool preprocessImage(const QString& sourcePath, const QString& outputPath, bool autoEnhance = false);

    // Create thumbnail
    bool generateThumbnail(const QString& imagePath, const QString& thumbnailPath, int maxDimension = 260);

    // Read and correct EXIF orientation
    QImage loadAndCorrectExif(const QString& filePath);

    // Basic enhancement for handwriting without damaging strokes
    QImage applyModerateEnhancement(const QImage& input);

    // Validate if file is supported image
    static bool isSupportedImageFile(const QString& filePath);

signals:
    void importProgress(int current, int total);
    void importFinished(int totalImported);
    void importError(const QString& message);

private:
    explicit ImageService(QObject* parent = nullptr);
    ~ImageService() override = default;
    ImageService(const ImageService&) = delete;
    ImageService& operator=(const ImageService&) = delete;
};

} // namespace HandwritingOCR
