#include "LanHttpServer.h"
#include "../logging/Logger.h"
#include <QUrl>
#include <QUrlQuery>
#include <QFileInfo>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QUuid>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QBuffer>
#include <QImageReader>

namespace HandwritingOCR {

namespace {
constexpr qint64 MaxHeaderBytes = 64 * 1024;
constexpr qint64 MaxRequestBytes = 100 * 1024 * 1024;
constexpr qint64 MaxImageBytes = 15 * 1024 * 1024;
constexpr int MaxUploadCount = 10;
constexpr int MaxImageDimension = 20000;
constexpr qint64 MaxImagePixels = 100'000'000;
}

LanHttpServer::LanHttpServer(QObject* parent) : QTcpServer(parent) {}

LanHttpServer::~LanHttpServer() {
    stop();
}

bool LanHttpServer::start(const QString& host, quint16 port) {
    stop();
    QHostAddress address = host.isEmpty() ? QHostAddress::AnyIPv4 : QHostAddress(host);
    if (!listen(address, port)) {
        Logger::instance().error("LanHttpServer", QString("Failed to listen on %1:%2: %3").arg(host).arg(port).arg(errorString()));
        return false;
    }
    m_receivedCount = 0;
    Logger::instance().info("LanHttpServer", QString("LAN Server listening on %1:%2").arg(serverAddress().toString()).arg(serverPort()));
    return true;
}

void LanHttpServer::stop() {
    if (isListening()) {
        close();
        Logger::instance().info("LanHttpServer", "LAN Server stopped.");
    }
    m_clientRequests.clear();
}

void LanHttpServer::incomingConnection(qintptr socketDescriptor) {
    QTcpSocket* socket = new QTcpSocket(this);
    if (socket->setSocketDescriptor(socketDescriptor)) {
        connect(socket, &QTcpSocket::readyRead, this, &LanHttpServer::onClientReadyRead);
        connect(socket, &QTcpSocket::disconnected, this, &LanHttpServer::onClientDisconnected);
        m_clientRequests[socket] = HttpRequest();
    } else {
        delete socket;
    }
}

void LanHttpServer::onClientReadyRead() {
    QTcpSocket* socket = qobject_cast<QTcpSocket*>(sender());
    if (!socket || !m_clientRequests.contains(socket)) return;

    HttpRequest& req = m_clientRequests[socket];
    if (req.isComplete) return;
    req.rawBuffer.append(socket->readAll());

    // If headers not yet parsed, find header delimiter "\r\n\r\n"
    if (req.method.isEmpty()) {
        int headerEnd = req.rawBuffer.indexOf("\r\n\r\n");
        if (headerEnd == -1) {
            if (req.rawBuffer.size() > MaxHeaderBytes) {
                sendResponse(socket, 431, "Request Header Fields Too Large", "text/plain", "Request headers too large");
            }
            return; // Wait for full headers
        }

        if (headerEnd > MaxHeaderBytes) {
            sendResponse(socket, 431, "Request Header Fields Too Large", "text/plain", "Request headers too large");
            return;
        }

        QByteArray headerBytes = req.rawBuffer.left(headerEnd);
        req.rawBuffer.remove(0, headerEnd + 4);

        QString headerStr = QString::fromUtf8(headerBytes);
        QStringList lines = headerStr.split("\r\n");
        if (lines.isEmpty()) {
            socket->close();
            return;
        }

        // Request line: GET /upload?t=123 HTTP/1.1
        QStringList reqLine = lines[0].split(" ");
        if (reqLine.size() >= 2) {
            req.method = reqLine[0].toUpper();
            QUrl url(reqLine[1]);
            req.path = url.path();
            req.query = url.query();

            QUrlQuery query(url);
            auto queryItems = query.queryItems();
            for (const auto& item : queryItems) {
                req.queryParams[item.first] = item.second;
            }
        }

        // Headers
        for (int i = 1; i < lines.size(); ++i) {
            int colonIdx = lines[i].indexOf(':');
            if (colonIdx != -1) {
                QString key = lines[i].left(colonIdx).trimmed().toLower();
                QString val = lines[i].mid(colonIdx + 1).trimmed();
                req.headers[key] = val;
            }
        }

        if (req.headers.contains("content-length")) {
            bool ok = false;
            req.expectedContentLength = req.headers["content-length"].toLongLong(&ok);
            if (!ok || req.expectedContentLength < 0 || req.expectedContentLength > MaxRequestBytes) {
                sendResponse(socket, 413, "Payload Too Large", "text/plain", "Upload payload is too large");
                return;
            }
        } else if (req.method == "POST") {
            sendResponse(socket, 411, "Length Required", "text/plain", "Content-Length is required");
            return;
        }
    }

    if (req.rawBuffer.size() > MaxRequestBytes) {
        sendResponse(socket, 413, "Payload Too Large", "text/plain", "Upload payload is too large");
        return;
    }

    // Check body completeness
    if (req.rawBuffer.size() >= req.expectedContentLength) {
        req.body = req.rawBuffer.left(req.expectedContentLength);
        req.isComplete = true;
        processRequest(socket, req);
    }
}

void LanHttpServer::onClientDisconnected() {
    QTcpSocket* socket = qobject_cast<QTcpSocket*>(sender());
    if (socket) {
        m_clientRequests.remove(socket);
        socket->deleteLater();
    }
}

void LanHttpServer::sendResponse(QTcpSocket* socket, int statusCode, const QString& statusText,
                                 const QString& contentType, const QByteArray& body) {
    if (!socket || socket->state() != QAbstractSocket::ConnectedState) return;

    QByteArray response;
    response.append(QString("HTTP/1.1 %1 %2\r\n").arg(statusCode).arg(statusText).toUtf8());
    response.append("Server: HandwritingOCR-LAN\r\n");
    response.append("X-Content-Type-Options: nosniff\r\n");
    response.append("Referrer-Policy: no-referrer\r\n");
    response.append("Content-Security-Policy: default-src 'self'; img-src 'self' blob:; style-src 'self'; script-src 'self'\r\n");
    response.append(QString("Content-Type: %1\r\n").arg(contentType).toUtf8());
    response.append(QString("Content-Length: %1\r\n").arg(body.size()).toUtf8());
    response.append("Connection: close\r\n\r\n");
    response.append(body);

    socket->write(response);
    socket->flush();
    socket->disconnectFromHost();
}

void LanHttpServer::processRequest(QTcpSocket* socket, const HttpRequest& req) {
    if (req.method == "OPTIONS") {
        sendResponse(socket, 204, "No Content", "text/plain", QByteArray());
        return;
    }

    if (req.path == "/" || req.path == "/upload" || req.path == "/index.html") {
        handleServeStatic(socket, "index.html", "text/html; charset=utf-8");
    } else if (req.path == "/styles.css") {
        handleServeStatic(socket, "styles.css", "text/css; charset=utf-8");
    } else if (req.path == "/upload.js") {
        handleServeStatic(socket, "upload.js", "application/javascript; charset=utf-8");
    } else if (req.path == "/api/upload" && req.method == "POST") {
        handleUploadApi(socket, req);
    } else if (req.path == "/api/status" && req.method == "GET") {
        handleStatusApi(socket, req);
    } else {
        sendResponse(socket, 404, "Not Found", "text/plain", "404 Not Found");
    }
}

void LanHttpServer::handleServeStatic(QTcpSocket* socket, const QString& fileName, const QString& contentType) {
    QString fullPath = QDir(m_webRootDir).filePath(fileName);
    QFile file(fullPath);
    if (file.open(QIODevice::ReadOnly)) {
        QByteArray data = file.readAll();
        sendResponse(socket, 200, "OK", contentType, data);
    } else {
        // Fallback default built-in response if file is missing
        sendResponse(socket, 404, "Not Found", "text/plain", "File not found");
    }
}

void LanHttpServer::handleStatusApi(QTcpSocket* socket, const HttpRequest& req) {
    QString token = req.queryParams.value("t");
    if (token.isEmpty()) {
        token = req.headers.value("x-session-token");
    }

    bool validToken = (!m_sessionToken.isEmpty() && token == m_sessionToken);

    QJsonObject res;
    res["validToken"] = validToken;
    res["receivedCount"] = m_receivedCount;
    res["maxAllowed"] = MaxUploadCount;

    QJsonDocument doc(res);
    sendResponse(socket, 200, "OK", "application/json", doc.toJson(QJsonDocument::Compact));
}

void LanHttpServer::handleUploadApi(QTcpSocket* socket, const HttpRequest& req) {
    // 1. Validate Token
    QString token = req.queryParams.value("t");
    if (token.isEmpty()) {
        token = req.headers.value("x-session-token");
    }

    if (m_sessionToken.isEmpty() || token != m_sessionToken) {
        QJsonObject err;
        err["success"] = false;
        err["error"] = "Invalid or expired session token";
        sendResponse(socket, 403, "Forbidden", "application/json", QJsonDocument(err).toJson());
        return;
    }

    if (m_receivedCount >= MaxUploadCount) {
        QJsonObject err;
        err["success"] = false;
        err["error"] = "The current upload session already contains 10 images";
        sendResponse(socket, 409, "Conflict", "application/json", QJsonDocument(err).toJson());
        return;
    }

    // 2. Parse Content-Type multipart boundary
    QString contentType = req.headers.value("content-type");
    if (!contentType.startsWith("multipart/form-data", Qt::CaseInsensitive)) {
        QJsonObject err;
        err["success"] = false;
        err["error"] = "Content-Type must be multipart/form-data";
        sendResponse(socket, 400, "Bad Request", "application/json", QJsonDocument(err).toJson());
        return;
    }

    int boundaryIdx = contentType.indexOf("boundary=", 0, Qt::CaseInsensitive);
    if (boundaryIdx == -1) {
        QJsonObject err;
        err["success"] = false;
        err["error"] = "Missing multipart boundary";
        sendResponse(socket, 400, "Bad Request", "application/json", QJsonDocument(err).toJson());
        return;
    }

    QString boundaryValue = contentType.mid(boundaryIdx + 9).section(';', 0, 0).trimmed();
    if (boundaryValue.startsWith('"') && boundaryValue.endsWith('"')) {
        boundaryValue = boundaryValue.mid(1, boundaryValue.size() - 2);
    }
    if (boundaryValue.isEmpty() || boundaryValue.size() > 200) {
        sendResponse(socket, 400, "Bad Request", "application/json", "{\"success\":false,\"error\":\"Invalid multipart boundary\"}");
        return;
    }
    QByteArray boundary = "--" + boundaryValue.toUtf8();
    QString tempBaseDir = QDir(QStandardPaths::writableLocation(QStandardPaths::TempLocation)).filePath("HandwritingOCR_Uploads");
    QDir().mkpath(tempBaseDir);

    QStringList savedFilePaths;
    bool limitExceeded = false;
    const QByteArray& body = req.body;
    int pos = 0;

    while (pos < body.size()) {
        int partStart = body.indexOf(boundary, pos);
        if (partStart == -1) break;
        partStart += boundary.size();

        // Check if end boundary
        if (body.mid(partStart, 2) == "--") break;

        // Skip CRLF
        if (body.mid(partStart, 2) == "\r\n") partStart += 2;

        int nextBoundary = body.indexOf(boundary, partStart);
        if (nextBoundary == -1) break;

        QByteArray partData = body.mid(partStart, nextBoundary - partStart);
        pos = nextBoundary;

        // Split part headers and part body
        int headerEnd = partData.indexOf("\r\n\r\n");
        if (headerEnd == -1) continue;

        QString partHeaderStr = QString::fromUtf8(partData.left(headerEnd));
        QByteArray fileContent = partData.mid(headerEnd + 4);

        // Remove trailing \r\n before boundary
        if (fileContent.endsWith("\r\n")) {
            fileContent.chop(2);
        }

        // Extract filename from Content-Disposition
        if (partHeaderStr.contains("filename=")) {
            if (m_receivedCount + savedFilePaths.size() >= MaxUploadCount) {
                limitExceeded = true;
                break;
            }

            if (fileContent.isEmpty() || fileContent.size() > MaxImageBytes) {
                continue;
            }

            int fnStart = partHeaderStr.indexOf("filename=\"");
            QString filename;
            if (fnStart != -1) {
                fnStart += 10;
                int fnEnd = partHeaderStr.indexOf("\"", fnStart);
                if (fnEnd != -1) {
                    filename = partHeaderStr.mid(fnStart, fnEnd - fnStart);
                }
            } else {
                fnStart = partHeaderStr.indexOf("filename=");
                if (fnStart != -1) {
                    filename = partHeaderStr.mid(fnStart + 9).split("\r\n")[0].trimmed();
                }
            }

            // Security: Sanitize filename to prevent path traversal
            QBuffer imageBuffer(&fileContent);
            imageBuffer.open(QIODevice::ReadOnly);
            QImageReader reader(&imageBuffer);
            reader.setDecideFormatFromContent(true);
            const QByteArray detectedFormat = reader.format().toLower();
            const QSize imageSize = reader.size();
            if (!reader.canRead()
                || !QList<QByteArray>{"jpg", "jpeg", "png", "webp", "bmp"}.contains(detectedFormat)
                || !imageSize.isValid()
                || imageSize.width() > MaxImageDimension
                || imageSize.height() > MaxImageDimension
                || static_cast<qint64>(imageSize.width()) * imageSize.height() > MaxImagePixels) {
                continue;
            }
            const QString safeExt = detectedFormat == "jpeg" ? "jpg" : QString::fromLatin1(detectedFormat);

            QString uniqueName = QString("upload_%1_%2.%3")
                                     .arg(QDateTime::currentDateTime().toString("yyyyMMdd_hhmmss"))
                                     .arg(QUuid::createUuid().toString(QUuid::WithoutBraces).left(8), safeExt);
            QString destPath = QDir(tempBaseDir).filePath(uniqueName);

            QFile outFile(destPath);
            if (outFile.open(QIODevice::WriteOnly)) {
                outFile.write(fileContent);
                outFile.close();
                savedFilePaths.append(destPath);
            }
        }
    }

    if (limitExceeded) {
        for (const auto& path : savedFilePaths) QFile::remove(path);
        QJsonObject resp;
        resp["success"] = false;
        resp["error"] = "Uploading these files would exceed the 10-image session limit";
        sendResponse(socket, 413, "Payload Too Large", "application/json", QJsonDocument(resp).toJson());
        return;
    }

    if (!savedFilePaths.isEmpty()) {
        m_receivedCount += savedFilePaths.size();
        emit filesReceived(savedFilePaths);
        emit uploadProgressChanged(m_receivedCount, MaxUploadCount);

        QJsonObject resp;
        resp["success"] = true;
        resp["count"] = savedFilePaths.size();
        resp["totalReceived"] = m_receivedCount;
        sendResponse(socket, 200, "OK", "application/json", QJsonDocument(resp).toJson());
    } else {
        QJsonObject resp;
        resp["success"] = false;
        resp["error"] = "No valid image files found in upload payload";
        sendResponse(socket, 400, "Bad Request", "application/json", QJsonDocument(resp).toJson());
    }
}

} // namespace HandwritingOCR
