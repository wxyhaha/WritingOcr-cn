#pragma once

#include <QString>
#include <QImage>
#include <QByteArray>

namespace HandwritingOCR {

class QrCodeGenerator {
public:
    // Generate a QImage containing the QR code for given text
    static QImage generateQrCodeImage(const QString& text, int targetSize = 256, int border = 2);

    // Generate SVG string for given text
    static QString generateQrCodeSvg(const QString& text, int border = 2);

    // Generate base64 Data URL (e.g. data:image/png;base64,...)
    static QString generateQrCodeDataUrl(const QString& text, int targetSize = 256);
};

} // namespace HandwritingOCR
