#include "LanUploadService.h"
#include "SettingsService.h"
#include "../infrastructure/logging/Logger.h"
#include "../infrastructure/network/QrCodeGenerator.h"
#include <QNetworkInterface>
#include <QRandomGenerator>
#include <QCoreApplication>
#include <QDir>
#include <QUuid>

namespace HandwritingOCR {

LanUploadService& LanUploadService::instance() {
    static LanUploadService s_instance;
    return s_instance;
}

LanUploadService::LanUploadService(QObject* parent) : QObject(parent) {
    m_server = new LanHttpServer(this);
    connect(m_server, &LanHttpServer::filesReceived, this, &LanUploadService::onFilesReceived);
    connect(m_server, &LanHttpServer::uploadProgressChanged, this, &LanUploadService::onUploadProgressChanged);
}

LanUploadService::~LanUploadService() {
    stopServer();
}

void LanUploadService::init() {
    m_port = SettingsService::instance().lanUploadPort();
    scanAvailableIps();
    m_lanIp = findBestLanIp();
    refreshSessionToken();

    // Set web directory path
    QString appDir = QCoreApplication::applicationDirPath();
    QString webDir = QDir(appDir).filePath("web-upload");
    if (!QDir(webDir).exists()) {
        webDir = QDir(appDir).filePath("../../web-upload");
        if (!QDir(webDir).exists()) {
            webDir = "d:/otherCode/WritingOcr-cn/web-upload";
        }
    }
    m_server->setWebRootDir(webDir);

    if (SettingsService::instance().lanUploadEnabled()) {
        startServer(m_port);
    }
}

void LanUploadService::scanAvailableIps() {
    m_availableIps.clear();

    const auto interfaces = QNetworkInterface::allInterfaces();
    for (const auto& iface : interfaces) {
        if (!(iface.flags() & QNetworkInterface::IsUp) ||
            !(iface.flags() & QNetworkInterface::IsRunning) ||
            (iface.flags() & QNetworkInterface::IsLoopBack)) {
            continue;
        }

        QString ifaceName = iface.humanReadableName().toLower();
        // Skip virtual network adapters and proxy tunnels
        if (ifaceName.contains("vethernet") || ifaceName.contains("virtual") ||
            ifaceName.contains("vmware") || ifaceName.contains("wsl") ||
            ifaceName.contains("meta") || ifaceName.contains("clash") ||
            ifaceName.contains("tun") || ifaceName.contains("tap") ||
            ifaceName.contains("tailscale") || ifaceName.contains("zerotier")) {
            continue;
        }

        const auto entries = iface.addressEntries();
        for (const auto& entry : entries) {
            if (entry.ip().protocol() == QAbstractSocket::IPv4Protocol && !entry.ip().isLoopback()) {
                QString ipStr = entry.ip().toString();
                // Filter out non-LAN and auto-config IPs
                if (ipStr.startsWith("169.254.") || ipStr.startsWith("198.18.") || ipStr.startsWith("127.")) {
                    continue;
                }
                if (!m_availableIps.contains(ipStr)) {
                    m_availableIps.append(ipStr);
                }
            }
        }
    }

    if (m_availableIps.isEmpty()) {
        m_availableIps.append("127.0.0.1");
    }

    emit ipsChanged();
}

QString LanUploadService::findBestLanIp() const {
    if (m_availableIps.isEmpty()) return "127.0.0.1";

    // Priority 1: 192.168.x.x (Most common home/office Wi-Fi and Ethernet)
    for (const auto& ip : m_availableIps) {
        if (ip.startsWith("192.168.")) return ip;
    }

    // Priority 2: 10.x.x.x
    for (const auto& ip : m_availableIps) {
        if (ip.startsWith("10.")) return ip;
    }

    // Priority 3: 172.16~31.x.x
    for (const auto& ip : m_availableIps) {
        if (ip.startsWith("172.")) return ip;
    }

    return m_availableIps.first();
}

void LanUploadService::setLanIp(const QString& ip) {
    if (m_lanIp != ip && !ip.isEmpty()) {
        m_lanIp = ip;
        regenerateQrCode();
        emit serverStatusChanged();
        emit urlChanged();
    }
}

bool LanUploadService::startServer(int port) {
    m_port = port;
    scanAvailableIps();
    if (!m_availableIps.contains(m_lanIp)) {
        m_lanIp = findBestLanIp();
    }

    bool ok = m_server->start("", static_cast<quint16>(m_port));
    regenerateQrCode();
    emit serverStatusChanged();
    return ok;
}

void LanUploadService::stopServer() {
    m_server->stop();
    emit serverStatusChanged();
}

QString LanUploadService::uploadUrl() const {
    return QString("http://%1:%2/?t=%3").arg(m_lanIp).arg(m_port).arg(m_sessionToken);
}

void LanUploadService::refreshSessionToken() {
    // Generate 12-char random alphanumeric token
    const QString chars = "abcdefghijklmnopqrstuvwxyz0123456789";
    m_sessionToken.clear();
    for (int i = 0; i < 12; ++i) {
        int index = QRandomGenerator::global()->bounded(chars.length());
        m_sessionToken.append(chars.at(index));
    }

    m_server->setSessionToken(m_sessionToken);
    regenerateQrCode();
    emit tokenChanged();
    emit urlChanged();
}

void LanUploadService::resetReceivedCount() {
    m_receivedCount = 0;
    emit progressChanged(0, 0);
}

void LanUploadService::regenerateQrCode() {
    QString url = uploadUrl();
    m_qrCodeDataUrl = QrCodeGenerator::generateQrCodeDataUrl(url);
    Logger::instance().info("LanUploadService", QString("Generated QR Code for URL: %1").arg(url));
    emit qrCodeChanged();
}

void LanUploadService::onFilesReceived(const QStringList& tempFilePaths) {
    m_receivedCount += tempFilePaths.size();
    Logger::instance().info("LanUploadService", QString("Received %1 images via mobile upload.").arg(tempFilePaths.size()));
    emit imagesUploaded(tempFilePaths);
}

void LanUploadService::onUploadProgressChanged(int current, int total) {
    emit progressChanged(current, total);
}

} // namespace HandwritingOCR
