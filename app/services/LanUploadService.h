#pragma once

#include "../infrastructure/network/LanHttpServer.h"
#include <QObject>
#include <QString>
#include <QStringList>
#include <QImage>

namespace HandwritingOCR {

class LanUploadService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY serverStatusChanged)
    Q_PROPERTY(QString lanIp READ lanIp NOTIFY serverStatusChanged)
    Q_PROPERTY(int port READ port NOTIFY serverStatusChanged)
    Q_PROPERTY(QString sessionToken READ sessionToken NOTIFY tokenChanged)
    Q_PROPERTY(QString uploadUrl READ uploadUrl NOTIFY urlChanged)
    Q_PROPERTY(QString qrCodeDataUrl READ qrCodeDataUrl NOTIFY qrCodeChanged)
    Q_PROPERTY(int receivedImageCount READ receivedImageCount NOTIFY progressChanged)

public:
    static LanUploadService& instance();

    void init();
    bool startServer(int port = 8765);
    void stopServer();

    bool isRunning() const { return m_server && m_server->isListening(); }
    QString lanIp() const { return m_lanIp; }
    int port() const { return m_port; }
    QString sessionToken() const { return m_sessionToken; }
    QString uploadUrl() const;
    QString qrCodeDataUrl() const { return m_qrCodeDataUrl; }
    int receivedImageCount() const { return m_receivedCount; }

    Q_INVOKABLE void refreshSessionToken();
    Q_INVOKABLE void resetReceivedCount();

signals:
    void serverStatusChanged();
    void tokenChanged();
    void urlChanged();
    void qrCodeChanged();
    void progressChanged(int current, int total);
    void imagesUploaded(const QStringList& filePaths);

private slots:
    void onFilesReceived(const QStringList& tempFilePaths);
    void onUploadProgressChanged(int current, int total);

private:
    explicit LanUploadService(QObject* parent = nullptr);
    ~LanUploadService() override;
    LanUploadService(const LanUploadService&) = delete;
    LanUploadService& operator=(const LanUploadService&) = delete;

    QString findLocalLanIp() const;
    void regenerateQrCode();

    LanHttpServer* m_server = nullptr;
    QString m_lanIp;
    int m_port = 8765;
    QString m_sessionToken;
    QString m_qrCodeDataUrl;
    int m_receivedCount = 0;
};

} // namespace HandwritingOCR
