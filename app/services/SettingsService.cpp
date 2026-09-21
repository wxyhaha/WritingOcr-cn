#include "SettingsService.h"
#include "StorageService.h"
#include "../infrastructure/database/DatabaseManager.h"
#include "../infrastructure/logging/Logger.h"
#include <QUrl>

namespace HandwritingOCR {

SettingsService& SettingsService::instance() {
    static SettingsService s_instance;
    return s_instance;
}

SettingsService::SettingsService(QObject* parent) : QObject(parent) {
    m_storageDir = StorageService::instance().getBaseStorageDir();
}

void SettingsService::load() {
    auto& db = DatabaseManager::instance();
    m_ocrEngine = db.getSetting("ocrEngine", "PaddleOCR");
    m_lowConfidenceThreshold = db.getSetting("lowConfidenceThreshold", "0.75").toDouble();
    if (m_lowConfidenceThreshold <= 0.0 || m_lowConfidenceThreshold > 1.0) {
        m_lowConfidenceThreshold = 0.75;
    }
    m_autoEnhance = db.getSetting("autoEnhance", "0") == "1";
    m_filterPrintedText = db.getSetting("filterPrintedText", "1") == "1";
    const QString defaultOcrWorkerUrl =
        QStringLiteral("http://127.0.0.1:%1").arg(DefaultNetworkPorts::OcrWorker);
    m_ocrWorkerUrl = db.getSetting("ocrWorkerUrl", defaultOcrWorkerUrl);

    // Older releases used ports reserved by Windows networking components.
    // Migrate only loopback OCR URLs so an intentionally configured remote
    // worker is left untouched.
    QUrl configuredOcrUrl(m_ocrWorkerUrl);
    const QString configuredHost = configuredOcrUrl.host().toLower();
    const bool isLoopbackOcrHost = configuredHost == "127.0.0.1"
        || configuredHost == "localhost"
        || configuredHost == "::1";
    if (configuredOcrUrl.isValid()
        && isLoopbackOcrHost
        && configuredOcrUrl.port() == DefaultNetworkPorts::LegacyOcrWorker) {
        configuredOcrUrl.setPort(DefaultNetworkPorts::OcrWorker);
        m_ocrWorkerUrl = configuredOcrUrl.toString();
        db.setSetting("ocrWorkerUrl", m_ocrWorkerUrl);
        Logger::instance().info("SettingsService", QString("Migrated local OCR worker URL to %1").arg(m_ocrWorkerUrl));
    }

    m_lanUploadEnabled = db.getSetting("lanUploadEnabled", "1") == "1";
    m_lanUploadPort = db.getSetting("lanUploadPort", QString::number(DefaultNetworkPorts::LanUpload)).toInt();
    if (m_lanUploadPort <= 1024 || m_lanUploadPort > 65535
        || m_lanUploadPort == DefaultNetworkPorts::LegacyLanUpload) {
        m_lanUploadPort = DefaultNetworkPorts::LanUpload;
        db.setSetting("lanUploadPort", QString::number(m_lanUploadPort));
        Logger::instance().info("SettingsService", QString("Migrated LAN upload port to %1").arg(m_lanUploadPort));
    }
    m_storageDir = db.getSetting("storageDir", StorageService::instance().getBaseStorageDir());
    if (!m_storageDir.trimmed().isEmpty()
        && QDir::cleanPath(m_storageDir) != QDir::cleanPath(StorageService::instance().getBaseStorageDir())) {
        StorageService::instance().setBaseStorageDir(m_storageDir);
    }
    m_theme = db.getSetting("theme", "Light");

    emit settingsChanged();
}

void SettingsService::setOcrEngine(const QString& val) {
    if (m_ocrEngine != val) {
        m_ocrEngine = val;
        DatabaseManager::instance().setSetting("ocrEngine", val);
        emit settingsChanged();
    }
}

void SettingsService::setLowConfidenceThreshold(double val) {
    val = qBound(0.01, val, 1.0);
    if (qAbs(m_lowConfidenceThreshold - val) > 0.001) {
        m_lowConfidenceThreshold = val;
        DatabaseManager::instance().setSetting("lowConfidenceThreshold", QString::number(val, 'f', 2));
        emit settingsChanged();
    }
}

void SettingsService::setAutoEnhance(bool val) {
    if (m_autoEnhance != val) {
        m_autoEnhance = val;
        DatabaseManager::instance().setSetting("autoEnhance", val ? "1" : "0");
        emit settingsChanged();
    }
}

void SettingsService::setFilterPrintedText(bool val) {
    if (m_filterPrintedText != val) {
        m_filterPrintedText = val;
        DatabaseManager::instance().setSetting("filterPrintedText", val ? "1" : "0");
        emit settingsChanged();
    }
}

void SettingsService::setOcrWorkerUrl(const QString& val) {
    const QString normalized = val.trimmed();
    if (normalized.isEmpty()) return;
    if (m_ocrWorkerUrl != normalized) {
        m_ocrWorkerUrl = normalized;
        DatabaseManager::instance().setSetting("ocrWorkerUrl", normalized);
        emit settingsChanged();
    }
}

void SettingsService::setLanUploadEnabled(bool val) {
    if (m_lanUploadEnabled != val) {
        m_lanUploadEnabled = val;
        DatabaseManager::instance().setSetting("lanUploadEnabled", val ? "1" : "0");
        emit settingsChanged();
    }
}

void SettingsService::setLanUploadPort(int val) {
    if (val <= 1024 || val > 65535) return;
    if (m_lanUploadPort != val) {
        m_lanUploadPort = val;
        DatabaseManager::instance().setSetting("lanUploadPort", QString::number(val));
        emit settingsChanged();
    }
}

void SettingsService::setStorageDir(const QString& val) {
    if (m_storageDir != val) {
        m_storageDir = val;
        DatabaseManager::instance().setSetting("storageDir", val);
        StorageService::instance().setBaseStorageDir(val);
        emit settingsChanged();
    }
}

void SettingsService::setTheme(const QString& val) {
    if (m_theme != val) {
        m_theme = val;
        DatabaseManager::instance().setSetting("theme", val);
        emit settingsChanged();
    }
}

} // namespace HandwritingOCR
