#include "QrCodeGenerator.h"
#include <QPainter>
#include <QBuffer>
#include <vector>
#include <cstdint>
#include <string>
#include <stdexcept>
#include <algorithm>
#include <sstream>

namespace HandwritingOCR {

namespace QrDetail {

enum class Ecc { LOW, MEDIUM, QUARTILE, HIGH };

class BitBuffer : public std::vector<bool> {
public:
    void appendBits(std::uint32_t val, int len) {
        for (int i = len - 1; i >= 0; i--) {
            this->push_back(((val >> i) & 1) != 0);
        }
    }
};

class QrSegment {
public:
    enum class Mode { NUMERIC, ALPHANUMERIC, BYTE, KANJI, ECI };

    Mode mode;
    int numChars;
    std::vector<bool> data;

    QrSegment(Mode md, int numCh, const std::vector<bool>& dt)
        : mode(md), numChars(numCh), data(dt) {}

    static QrSegment makeBytes(const std::vector<uint8_t>& data) {
        BitBuffer bb;
        for (uint8_t b : data) {
            bb.appendBits(b, 8);
        }
        return QrSegment(Mode::BYTE, static_cast<int>(data.size()), bb);
    }
};

class QrCode {
public:
    int size;
    std::vector<std::vector<bool>> modules;

    static QrCode encodeText(const char* text, Ecc ecc) {
        std::vector<uint8_t> bytes;
        for (const char* p = text; *p != '\0'; ++p) {
            bytes.push_back(static_cast<uint8_t>(*p));
        }
        std::vector<QrSegment> segs = { QrSegment::makeBytes(bytes) };
        return encodeSegments(segs, ecc);
    }

    static QrCode encodeSegments(const std::vector<QrSegment>& segs, Ecc ecc,
                                 int minVersion = 1, int maxVersion = 10, int mask = -1) {
        for (int version = minVersion; version <= maxVersion; ++version) {
            int dataCapacityBits = getNumDataCodewords(version, ecc) * 8;
            int dataUsedBits = getTotalBits(segs, version);
            if (dataUsedBits != -1 && dataUsedBits <= dataCapacityBits) {
                return QrCode(version, ecc, segs, mask);
            }
        }
        throw std::length_error("Data too long for QR Code");
    }

    bool getModule(int x, int y) const {
        return (x >= 0 && x < size && y >= 0 && y < size) && modules[y][x];
    }

private:
    int version;
    Ecc errorCorrectionLevel;

    QrCode(int ver, Ecc ecc, const std::vector<QrSegment>& segs, int msk)
        : version(ver), errorCorrectionLevel(ecc) {
        size = ver * 4 + 17;
        modules = std::vector<std::vector<bool>>(size, std::vector<bool>(size, false));
        std::vector<std::vector<bool>> isFunction(size, std::vector<bool>(size, false));

        drawFunctionPatterns(isFunction);
        const std::vector<uint8_t> allCodewords = addEccAndInterleave(segs);
        drawCodewords(allCodewords, isFunction);

        if (msk < 0) {
            long minPenalty = 1000000000L;
            int bestMask = 0;
            for (int i = 0; i < 8; ++i) {
                applyMask(i, isFunction);
                drawFormatBits(i);
                long penalty = getPenaltyScore();
                if (penalty < minPenalty) {
                    minPenalty = penalty;
                    bestMask = i;
                }
                applyMask(i, isFunction); // Undoes mask
            }
            msk = bestMask;
        }
        applyMask(msk, isFunction);
        drawFormatBits(msk);
    }

    void drawFunctionPatterns(std::vector<std::vector<bool>>& isFunction) {
        for (int i = 0; i < size; ++i) {
            setFunctionModule(6, i, i % 2 == 0, isFunction);
            setFunctionModule(i, 6, i % 2 == 0, isFunction);
        }
        drawFinderPattern(3, 3, isFunction);
        drawFinderPattern(size - 4, 3, isFunction);
        drawFinderPattern(3, size - 4, isFunction);

        const std::vector<int> alignPatPos = getAlignmentPatternPositions();
        size_t numAlign = alignPatPos.size();
        for (size_t i = 0; i < numAlign; i++) {
            for (size_t j = 0; j < numAlign; j++) {
                if (!((i == 0 && j == 0) || (i == 0 && j == numAlign - 1) || (i == numAlign - 1 && j == 0))) {
                    drawAlignmentPattern(alignPatPos[i], alignPatPos[j], isFunction);
                }
            }
        }
        for (int i = 0; i < 9; i++) {
            setFunctionModule(8, i, false, isFunction);
            setFunctionModule(i, 8, false, isFunction);
        }
        for (int i = 0; i < 8; i++) {
            setFunctionModule(size - 1 - i, 8, false, isFunction);
            setFunctionModule(8, size - 1 - i, false, isFunction);
        }
        setFunctionModule(8, size - 8, true, isFunction);
    }

    void drawFinderPattern(int x, int y, std::vector<std::vector<bool>>& isFunction) {
        for (int dy = -4; dy <= 4; dy++) {
            for (int dx = -4; dx <= 4; dx++) {
                int dist = std::max(std::abs(dx), std::abs(dy));
                int xx = x + dx, yy = y + dy;
                if (xx >= 0 && xx < size && yy >= 0 && yy < size) {
                    setFunctionModule(xx, yy, dist != 2 && dist != 4, isFunction);
                }
            }
        }
    }

    void drawAlignmentPattern(int x, int y, std::vector<std::vector<bool>>& isFunction) {
        for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
                setFunctionModule(x + dx, y + dy, std::max(std::abs(dx), std::abs(dy)) != 1, isFunction);
            }
        }
    }

    void setFunctionModule(int x, int y, bool isBlack, std::vector<std::vector<bool>>& isFunction) {
        modules[y][x] = isBlack;
        isFunction[y][x] = true;
    }

    void drawFormatBits(int msk) {
        int data = 0;
        switch (errorCorrectionLevel) {
            case Ecc::LOW:      data = 1; break;
            case Ecc::MEDIUM:   data = 0; break;
            case Ecc::QUARTILE: data = 3; break;
            case Ecc::HIGH:     data = 2; break;
        }
        data = (data << 3) | msk;
        int rem = data;
        for (int i = 0; i < 10; i++) rem = (rem << 1) ^ ((rem >> 9) * 0x537);
        int bits = ((data << 10) | rem) ^ 0x5412;

        for (int i = 0; i <= 5; i++) modules[8][i] = ((bits >> i) & 1) != 0;
        modules[8][7] = ((bits >> 6) & 1) != 0;
        modules[8][8] = ((bits >> 7) & 1) != 0;
        modules[7][8] = ((bits >> 8) & 1) != 0;
        for (int i = 9; i < 15; i++) modules[14 - i][8] = ((bits >> i) & 1) != 0;

        for (int i = 0; i < 8; i++) modules[size - 1 - i][8] = ((bits >> i) & 1) != 0;
        for (int i = 8; i < 15; i++) modules[8][size - 15 + i] = ((bits >> i) & 1) != 0;
    }

    std::vector<int> getAlignmentPatternPositions() const {
        if (version == 1) return {};
        int numAlign = version / 7 + 2;
        int step = (version == 32) ? 26 : (version * 4 + numAlign * 2 + 1) / (numAlign * 2 - 2) * 2;
        std::vector<int> result(numAlign);
        result[0] = 6;
        for (int i = numAlign - 1, pos = size - 7; i >= 1; i--, pos -= step) {
            result[i] = pos;
        }
        return result;
    }

    static int getNumDataCodewords(int ver, Ecc ecc) {
        const int NUM_DATA_CODEWORDS[4][41] = {
            {-1, 19, 34, 55, 80, 108, 136, 156, 194, 232, 274, 324, 370, 428, 461, 523, 589, 647, 721, 795},
            {-1, 16, 28, 44, 64,  86, 108, 124, 154, 180, 216, 254, 290, 334, 365, 415, 453, 507, 563, 627},
            {-1, 13, 22, 34, 48,  62,  76,  88, 110, 132, 154, 180, 206, 244, 261, 295, 325, 367, 397, 445},
            {-1,  9, 16, 26, 36,  46,  60,  66,  86, 100, 122, 140, 158, 180, 197, 223, 253, 283, 313, 341}
        };
        int eccIndex = 0;
        if (ecc == Ecc::MEDIUM) eccIndex = 1;
        else if (ecc == Ecc::QUARTILE) eccIndex = 2;
        else if (ecc == Ecc::HIGH) eccIndex = 3;
        return (ver <= 19) ? NUM_DATA_CODEWORDS[eccIndex][ver] : 100;
    }

    static int getTotalBits(const std::vector<QrSegment>& segs, int version) {
        int result = 0;
        for (const auto& seg : segs) {
            int ccbits = (version <= 9) ? 8 : 16;
            result += 4 + ccbits + static_cast<int>(seg.data.size());
        }
        return result;
    }

    std::vector<uint8_t> addEccAndInterleave(const std::vector<QrSegment>& segs) const {
        BitBuffer bb;
        for (const auto& seg : segs) {
            bb.appendBits(0x4, 4); // Mode BYTE
            int ccbits = (version <= 9) ? 8 : 16;
            bb.appendBits(static_cast<uint32_t>(seg.numChars), ccbits);
            for (bool bit : seg.data) bb.push_back(bit);
        }

        int capacityBits = getNumDataCodewords(version, errorCorrectionLevel) * 8;
        bb.appendBits(0, std::min(4, capacityBits - static_cast<int>(bb.size())));
        bb.appendBits(0, (8 - static_cast<int>(bb.size()) % 8) % 8);
        for (uint8_t padByte = 0xEC; static_cast<int>(bb.size()) < capacityBits; padByte ^= 0xEC ^ 0x11) {
            bb.appendBits(padByte, 8);
        }

        std::vector<uint8_t> dataCodewords(bb.size() / 8);
        for (size_t i = 0; i < bb.size(); i++) {
            dataCodewords[i >> 3] |= (bb[i] ? 1 : 0) << (7 - (i & 7));
        }

        // RS Error Correction calculation
        int numEccCodewords = getNumRawDataModules(version) / 8 - getNumDataCodewords(version, errorCorrectionLevel);
        auto ecc = reedSolomonComputeDivisor(numEccCodewords);
        auto rs = reedSolomonComputeRemainder(dataCodewords, ecc);

        std::vector<uint8_t> result = dataCodewords;
        result.insert(result.end(), rs.begin(), rs.end());
        return result;
    }

    static int getNumRawDataModules(int ver) {
        int size = ver * 4 + 17;
        int numFunc = 3 * 64 + (size - 16) * 2 - 1;
        if (ver >= 2) numFunc += 25;
        return size * size - numFunc;
    }

    static std::vector<uint8_t> reedSolomonComputeDivisor(int degree) {
        std::vector<uint8_t> result(degree, 0);
        result[degree - 1] = 1;
        uint8_t root = 1;
        for (int i = 0; i < degree; i++) {
            for (size_t j = 0; j < result.size(); j++) {
                result[j] = reedSolomonMultiply(result[j], root);
                if (j + 1 < result.size()) result[j] ^= result[j + 1];
            }
            root = reedSolomonMultiply(root, 0x02);
        }
        return result;
    }

    static std::vector<uint8_t> reedSolomonComputeRemainder(const std::vector<uint8_t>& data, const std::vector<uint8_t>& divisor) {
        std::vector<uint8_t> result(divisor.size(), 0);
        for (uint8_t b : data) {
            uint8_t factor = b ^ result[0];
            result.erase(result.begin());
            result.push_back(0);
            for (size_t i = 0; i < divisor.size(); i++) {
                result[i] ^= reedSolomonMultiply(divisor[i], factor);
            }
        }
        return result;
    }

    static uint8_t reedSolomonMultiply(uint8_t x, uint8_t y) {
        int z = 0;
        for (int i = 7; i >= 0; i--) {
            z = (z << 1) ^ ((z >> 7) * 0x11D);
            z ^= ((y >> i) & 1) * x;
        }
        return static_cast<uint8_t>(z);
    }

    void drawCodewords(const std::vector<uint8_t>& data, const std::vector<std::vector<bool>>& isFunction) {
        size_t bitIndex = 0;
        for (int right = size - 1; right >= 1; right -= 2) {
            if (right == 6) right = 5;
            for (int vert = 0; vert < size; vert++) {
                for (int j = 0; j < 2; j++) {
                    int x = right - j;
                    bool upward = ((right + 1) & 2) == 0;
                    int y = upward ? size - 1 - vert : vert;
                    if (!isFunction[y][x] && bitIndex < data.size() * 8) {
                        bool dark = ((data[bitIndex >> 3] >> (7 - (bitIndex & 7))) & 1) != 0;
                        modules[y][x] = dark;
                        bitIndex++;
                    }
                }
            }
        }
    }

    void applyMask(int msk, const std::vector<std::vector<bool>>& isFunction) {
        for (int y = 0; y < size; y++) {
            for (int x = 0; x < size; x++) {
                if (!isFunction[y][x]) {
                    bool invert = false;
                    switch (msk) {
                        case 0: invert = (x + y) % 2 == 0; break;
                        case 1: invert = y % 2 == 0; break;
                        case 2: invert = x % 3 == 0; break;
                        case 3: invert = (x + y) % 3 == 0; break;
                        case 4: invert = (x / 3 + y / 2) % 2 == 0; break;
                        case 5: invert = (x * y) % 2 + (x * y) % 3 == 0; break;
                        case 6: invert = ((x * y) % 2 + (x * y) % 3) % 2 == 0; break;
                        case 7: invert = ((x + y) % 2 + (x * y) % 3) % 2 == 0; break;
                    }
                    modules[y][x] = modules[y][x] ^ invert;
                }
            }
        }
    }

    long getPenaltyScore() const {
        long result = 0;
        for (int y = 0; y < size; y++) {
            bool runColor = false;
            int runVal = 0;
            for (int x = 0; x < size; x++) {
                if (modules[y][x] == runColor) {
                    runVal++;
                    if (runVal == 5) result += 3;
                    else if (runVal > 5) result++;
                } else {
                    runColor = modules[y][x];
                    runVal = 1;
                }
            }
        }
        return result;
    }
};

} // namespace QrDetail

QImage QrCodeGenerator::generateQrCodeImage(const QString& text, int targetSize, int border) {
    try {
        auto qr = QrDetail::QrCode::encodeText(text.toUtf8().constData(), QrDetail::Ecc::MEDIUM);
        int qrSize = qr.size;
        int totalSize = qrSize + border * 2;
        int scale = std::max(1, targetSize / totalSize);
        int finalSize = totalSize * scale;

        QImage image(finalSize, finalSize, QImage::Format_RGB32);
        image.fill(Qt::white);

        QPainter painter(&image);
        painter.setPen(Qt::NoPen);
        painter.setBrush(Qt::black);

        for (int y = 0; y < qrSize; ++y) {
            for (int x = 0; x < qrSize; ++x) {
                if (qr.getModule(x, y)) {
                    painter.drawRect((x + border) * scale, (y + border) * scale, scale, scale);
                }
            }
        }
        return image;
    } catch (...) {
        QImage errImg(targetSize, targetSize, QImage::Format_RGB32);
        errImg.fill(Qt::white);
        return errImg;
    }
}

QString QrCodeGenerator::generateQrCodeSvg(const QString& text, int border) {
    try {
        auto qr = QrDetail::QrCode::encodeText(text.toUtf8().constData(), QrDetail::Ecc::MEDIUM);
        int qrSize = qr.size;
        int totalSize = qrSize + border * 2;

        std::stringstream ss;
        ss << "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 " << totalSize << " " << totalSize << "\" stroke=\"none\">\n";
        ss << "<rect width=\"100%\" height=\"100%\" fill=\"#ffffff\"/>\n";
        ss << "<path d=\"";
        for (int y = 0; y < qrSize; ++y) {
            for (int x = 0; x < qrSize; ++x) {
                if (qr.getModule(x, y)) {
                    ss << "M" << (x + border) << "," << (y + border) << "h1v1h-1z ";
                }
            }
        }
        ss << "\" fill=\"#000000\"/>\n</svg>\n";
        return QString::fromStdString(ss.str());
    } catch (...) {
        return QString();
    }
}

QString QrCodeGenerator::generateQrCodeDataUrl(const QString& text, int targetSize) {
    QImage img = generateQrCodeImage(text, targetSize);
    QByteArray ba;
    QBuffer buffer(&ba);
    buffer.open(QIODevice::WriteOnly);
    img.save(&buffer, "PNG");
    return QString("data:image/png;base64,%1").arg(QString::fromLatin1(ba.toBase64()));
}

} // namespace HandwritingOCR
