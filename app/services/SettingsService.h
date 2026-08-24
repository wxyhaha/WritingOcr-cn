#pragma once

#include <QObject>
#include <QString>

namespace HandwritingOCR {

class SettingsService : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString ocrEngine READ ocrEngine WRITE setOcrEngine NOTIFY settingsChanged)
    Q_PROPERTY(double lowConfidenceThreshold READ lowConfidenceThreshold WRITE setLowConfidenceThreshold NOTIFY settingsChanged)
    Q_PROPERTY(bool autoEnhance READ autoEnhance WRITE setAutoEnhance NOTIFY settingsChanged)
    Q_PROPERTY(QString ocrWorkerUrl READ ocrWorkerUrl WRITE setOcrWorkerUrl NOTIFY settingsChanged)
    Q_PROPERTY(bool lanUploadEnabled READ lanUploadEnabled WRITE setLanUploadEnabled NOTIFY settingsChanged)
    Q_PROPERTY(int lanUploadPort READ lanUploadPort WRITE setLanUploadPort NOTIFY settingsChanged)
    Q_PROPERTY(QString storageDir READ storageDir WRITE setStorageDir NOTIFY settingsChanged)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY settingsChanged)

public:
    static SettingsService& instance();

    void load();

    QString ocrEngine() const { return m_ocrEngine; }
    void setOcrEngine(const QString& val);

    double lowConfidenceThreshold() const { return m_lowConfidenceThreshold; }
    void setLowConfidenceThreshold(double val);

    bool autoEnhance() const { return m_autoEnhance; }
    void setAutoEnhance(bool val);

    QString ocrWorkerUrl() const { return m_ocrWorkerUrl; }
    void setOcrWorkerUrl(const QString& val);

    bool lanUploadEnabled() const { return m_lanUploadEnabled; }
    void setLanUploadEnabled(bool val);

    int lanUploadPort() const { return m_lanUploadPort; }
    void setLanUploadPort(int val);

    QString storageDir() const { return m_storageDir; }
    void setStorageDir(const QString& val);

    QString theme() const { return m_theme; }
    void setTheme(const QString& val);

signals:
    void settingsChanged();

private:
    explicit SettingsService(QObject* parent = nullptr);
    ~SettingsService() override = default;
    SettingsService(const SettingsService&) = delete;
    SettingsService& operator=(const SettingsService&) = delete;

    QString m_ocrEngine = "PaddleOCR";
    double m_lowConfidenceThreshold = 0.75;
    bool m_autoEnhance = false;
    QString m_ocrWorkerUrl = "http://127.0.0.1:8766";
    bool m_lanUploadEnabled = true;
    int m_lanUploadPort = 8765;
    QString m_storageDir;
    QString m_theme = "Light";
};

} // namespace HandwritingOCR
