#include "PaddleOcrProvider.h"
#include "../logging/Logger.h"
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QTimer>
#include <QUrl>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUuid>
#include <QDateTime>

namespace HandwritingOCR {

PaddleOcrProvider::PaddleOcrProvider(const QString& workerBaseUrl)
    : m_baseUrl(workerBaseUrl) {}

ProviderInfo PaddleOcrProvider::info() const {
    ProviderInfo inf;
    inf.name = "PaddleOCR";
    inf.version = "PP-OCRv5";
    inf.description = "Baidu PaddleOCR local inference worker";
    return inf;
}

bool PaddleOcrProvider::checkAvailability(QString* statusMessage) {
    QNetworkAccessManager manager;
    QUrl url(m_baseUrl + "/health");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QNetworkReply* reply = manager.get(request);
    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);

    timer.start(3000); // 3 seconds timeout for health check
    loop.exec();

    if (timer.isActive()) {
        timer.stop();
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            reply->deleteLater();
            if (doc.isObject()) {
                QString status = doc.object().value("status").toString();
                if (status == "ready") {
                    if (statusMessage) *statusMessage = "OCR Worker 就绪 (PP-OCRv5)";
                    return true;
                } else {
                    if (statusMessage) *statusMessage = "OCR Worker 正在初始化模型...";
                    return true; // Server is running, model loading
                }
            }
        }
    }

    if (statusMessage) {
        *statusMessage = QString("无法连接到 OCR Worker (%1): %2").arg(m_baseUrl, reply->errorString());
    }
    reply->abort();
    reply->deleteLater();
    return false;
}

std::optional<OcrResult> PaddleOcrProvider::recognize(const OcrRequest& request, QString* errorMsg) {
    QNetworkAccessManager manager;
    QUrl url(m_baseUrl + "/ocr");
    QNetworkRequest netReq(url);
    netReq.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QJsonObject reqObj;
    reqObj["image_path"] = request.imagePath;
    reqObj["lang"] = request.lang;
    reqObj["filter_printed_text"] = request.filterPrintedText;
    QByteArray body = QJsonDocument(reqObj).toJson(QJsonDocument::Compact);

    QNetworkReply* reply = manager.post(netReq, body);
    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);

    timer.start(120000); // 120s timeout for OCR recognition
    loop.exec();

    if (!timer.isActive()) {
        reply->abort();
        reply->deleteLater();
        if (errorMsg) *errorMsg = "OCR 识别超时 (超过120秒)";
        Logger::instance().error("PaddleOcrProvider", "OCR request timed out.");
        return std::nullopt;
    }
    timer.stop();

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->errorString();
        QByteArray respBody = reply->readAll();
        reply->deleteLater();
        if (errorMsg) *errorMsg = QString("OCR Worker 响应错误: %1 (%2)").arg(err, QString::fromUtf8(respBody));
        Logger::instance().error("PaddleOcrProvider", QString("OCR Worker error: %1").arg(err));
        return std::nullopt;
    }

    QByteArray respData = reply->readAll();
    reply->deleteLater();

    QJsonDocument doc = QJsonDocument::fromJson(respData);
    if (!doc.isObject()) {
        if (errorMsg) *errorMsg = "OCR Worker 返回了非法的 JSON 响应";
        return std::nullopt;
    }

    QJsonObject obj = doc.object();
    OcrResult result;
    result.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    result.engine = obj.value("engine").toString("PaddleOCR");
    result.engineVersion = obj.value("engine_version").toString("PP-OCRv5");
    result.createdAt = QDateTime::currentDateTime().toString(Qt::ISODate);
    result.imageWidth = obj.value("imageWidth").toInt();
    result.imageHeight = obj.value("imageHeight").toInt();
    result.rawText = obj.value("rawText").toString();

    QJsonArray blocksArr = obj.value("blocks").toArray();
    for (const auto& bVal : blocksArr) {
        result.blocks.append(OcrBlock::fromJson(bVal.toObject()));
    }

    return result;
}

} // namespace HandwritingOCR
