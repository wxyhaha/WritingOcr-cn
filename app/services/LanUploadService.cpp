#include "LanUploadService.h"
#include "SettingsService.h"
#include "TaskService.h"
#include "ImageService.h"
#include "../infrastructure/network/QrCodeGenerator.h"
#include "../infrastructure/logging/Logger.h"
#include <QNetworkInterface>
#include <QUuid>
#include <QCoreApplication>
#include <QDir>

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
    m_lanIp = findLocalLanIp();
    refreshSessionToken();

    // Set web directory path
    QString appDir = QCoreApplication::applicationDirPath();
    QString webDir = QDir(appDir).filePath("web-upload");
    if (!QDir(webDir).exists()) {
        // Look in source tree if running from build folder
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

QString LanUploadService::findLocalLanIp() const {
    const auto interfaces = QNetworkInterface::allInterfaces();
    for (const auto& iface : interfaces) {
        if (!(iface.flags() & QNetworkInterface::IsUp) ||
            !(iface.flags() & QNetworkInterface::IsRunning) ||
            (iface.flags() & QNetworkInterface::IsLoopBack)) {
            continue;
        }

        // Filter out virtual adapters if possible
        QString humanName = iface.humanReadableName().toLower();
        if (humanName.contains("vethernet") || humanName.contains("virtual") || humanName.contains("vmware") || humanName.contains("wsl")) {
            continue;
        }

        const auto entries = iface.addressEntries();
        for (const auto& entry : entries) {
            if (entry.ip().protocol() == QAbstractSocket::IPv4Protocol && !entry.ip().isLoopback()) {
                QString ipStr = entry.ip().toString();
                if (ipStr.startsWith("192.168.") || ipStr.startsWith("10.") || ipStr.startsWith("172.")) {
                    return ipStr;
                }
            }
        }
    }

    // Fallback: search all IPv4 addresses
    const auto allAddresses = QNetworkInterface::allAddresses();
    for (const auto& addr : allAddresses) {
        if (addr.protocol() == QAbstractSocket::IPv4Protocol && !addr.isLoopback()) {
            return addr.toString();
        }
    }

    return "127.0.0.1";
}

bool LanUploadService::startServer(int port) {
    m_port = port;
    m_lanIp = findLocalLanIp();
    bool ok = m_server->start("0.0.0.0", static_cast<quint16>(m_port));
    regenerateQrCode();
    emit serverStatusChanged();
    return ok;
}

void LanUploadService::stopServer() {
    m_server->stop();
    emit serverStatusChanged();
}

QString LanUploadService::uploadUrl() const {
    return QString("http://%1:%2/upload?t=%3").arg(m_lanIp).arg(m_port).arg(m_sessionToken);
}

void LanUploadService::refreshSessionToken() {
    m_sessionToken = QUuid::createUuid().toString(QUuid::WithoutBraces).left(12);
    m_server->setSessionToken(m_sessionToken);
    regenerateQrCode();
    emit tokenChanged();
    emit urlChanged();
}

void LanUploadService::resetReceivedCount() {
    m_receivedCount = 0;
    emit progressChanged(0, 10);
}

void LanUploadService::regenerateQrCode() {
    QString url = uploadUrl();
    m_qrCodeDataUrl = QrCodeGenerator::generateQrCodeDataUrl(url, 280);
    emit qrCodeChanged();
}

void LanUploadService::onFilesReceived(const QStringList& tempFilePaths) {
    Logger::instance().info("LanUploadService", QString("Received %1 uploaded images").arg(tempFilePaths.size()));
    m_receivedCount += tempFilePaths.size();

    // If there is an active task, import images directly into it
    auto& taskService = TaskService::instance();
    if (!taskService.hasCurrentTask()) {
        taskService.createNewTask();
    }

    QString currentTaskId = taskService.currentTaskId();
    bool autoEnhance = SettingsService::instance().autoEnhance();
    auto newPages = ImageService::instance().importImages(currentTaskId, tempFilePaths, autoEnhance);

    for (const auto& page : newPages) {
        taskService.addPageToCurrentTask(page);
    }

    emit imagesUploaded(tempFilePaths);
}

void LanUploadService::onUploadProgressChanged(int current, int total) {
    m_receivedCount = current;
    emit progressChanged(current, total);
}

} // namespace HandwritingOCR
