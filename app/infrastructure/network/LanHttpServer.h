#pragma once

#include <QTcpServer>
#include <QTcpSocket>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QMap>
#include <functional>

namespace HandwritingOCR {

class LanHttpServer : public QTcpServer {
    Q_OBJECT

public:
    explicit LanHttpServer(QObject* parent = nullptr);
    ~LanHttpServer() override;

    bool start(const QString& host, quint16 port);
    void stop();

    void setSessionToken(const QString& token) { m_sessionToken = token; }
    QString sessionToken() const { return m_sessionToken; }

    void setWebRootDir(const QString& dir) { m_webRootDir = dir; }

signals:
    void filesReceived(const QStringList& tempFilePaths);
    void uploadProgressChanged(int receivedCount, int totalCount);

protected:
    void incomingConnection(qintptr socketDescriptor) override;

private slots:
    void onClientReadyRead();
    void onClientDisconnected();

private:
    struct HttpRequest {
        QString method;
        QString path;
        QString query;
        QMap<QString, QString> queryParams;
        QMap<QString, QString> headers;
        QByteArray body;
        bool isComplete = false;
        qint64 expectedContentLength = 0;
        QByteArray rawBuffer;
    };

    void processRequest(QTcpSocket* socket, const HttpRequest& req);
    void sendResponse(QTcpSocket* socket, int statusCode, const QString& statusText,
                      const QString& contentType, const QByteArray& body);

    void handleServeStatic(QTcpSocket* socket, const QString& filePath, const QString& contentType);
    void handleUploadApi(QTcpSocket* socket, const HttpRequest& req);
    void handleStatusApi(QTcpSocket* socket, const HttpRequest& req);

    QMap<QTcpSocket*, HttpRequest> m_clientRequests;
    QString m_sessionToken;
    QString m_webRootDir;
    int m_receivedCount = 0;
};

} // namespace HandwritingOCR
