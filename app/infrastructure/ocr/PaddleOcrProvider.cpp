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

void PaddleOcrProvider::setBaseUrl(const QString& url) {
    QMutexLocker locker(&m_configMutex);
    m_baseUrl = url;
}

QString PaddleOcrProvider::baseUrl() const {
    QMutexLocker locker(&m_configMutex);
    return m_baseUrl;
}

void PaddleOcrProvider::setAuthToken(const QString& token) {
    QMutexLocker locker(&m_configMutex);
    m_authToken = token;
}

ProviderInfo PaddleOcrProvider::info() const {
    ProviderInfo inf;
    inf.name = "PaddleOCR";
    inf.version = "PP-OCRv5";
    inf.description = "Baidu PaddleOCR local inference worker";
    return inf;
}

bool PaddleOcrProvider::checkAvailability(QString* statusMessage) {
    QString baseUrl;
    QString authToken;
    {
        QMutexLocker locker(&m_configMutex);
        baseUrl = m_baseUrl;
        authToken = m_authToken;
    }
    QNetworkAccessManager manager;
    QUrl url(baseUrl + "/health");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    if (!authToken.isEmpty()) request.setRawHeader("X-OCR-Token", authToken.toUtf8());

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
                } else if (status == "loading") {
                    if (statusMessage) *statusMessage = "OCR Worker 正在初始化模型...";
                    return false;
                } else {
                    if (statusMessage) *statusMessage = doc.object().value("error_detail").toString("OCR Worker 初始化失败");
                    return false;
                }
            }
        }
    }

    if (statusMessage) {
        *statusMessage = QString("无法连接到 OCR Worker (%1): %2").arg(baseUrl, reply->errorString());
    }
    reply->abort();
    reply->deleteLater();
    return false;
}

std::optional<OcrResult> PaddleOcrProvider::recognize(const OcrRequest& request, QString* errorMsg) {
    QString baseUrl;
    QString authToken;
    {
        QMutexLocker locker(&m_configMutex);
        baseUrl = m_baseUrl;
        authToken = m_authToken;
    }
    QNetworkAccessManager manager;
    QUrl url(baseUrl + "/ocr");
    QNetworkRequest netReq(url);
    netReq.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    if (!authToken.isEmpty()) netReq.setRawHeader("X-OCR-Token", authToken.toUtf8());

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
