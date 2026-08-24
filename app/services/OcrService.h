#pragma once

#include "../models/OcrResult.h"
#include "../infrastructure/ocr/IOcrProvider.h"
#include "../infrastructure/ocr/PaddleOcrProvider.h"
#include <QObject>
#include <QString>
#include <QProcess>
#include <QElapsedTimer>
#include <QTimer>
#include <memory>
#include <atomic>

namespace HandwritingOCR {

class OcrService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool isProcessing READ isProcessing NOTIFY isProcessingChanged)
    Q_PROPERTY(bool isWorkerRunning READ isWorkerRunning NOTIFY workerStatusChanged)
    Q_PROPERTY(QString workerStatusMessage READ workerStatusMessage NOTIFY workerStatusChanged)
    Q_PROPERTY(int currentProgress READ currentProgress NOTIFY progressChanged)
    Q_PROPERTY(int totalProgress READ totalProgress NOTIFY progressChanged)
    Q_PROPERTY(double elapsedSeconds READ elapsedSeconds NOTIFY progressTicker)
    Q_PROPERTY(QString progressText READ progressText NOTIFY progressChanged)
    Q_PROPERTY(double lastDuration READ lastDuration NOTIFY finishedDurationChanged)

public:
    static OcrService& instance();

    void init();

    bool isProcessing() const { return m_isProcessing; }
    bool isWorkerRunning() const { return m_isWorkerRunning; }
    QString workerStatusMessage() const { return m_workerStatusMessage; }
    int currentProgress() const { return m_currentProgress; }
    int totalProgress() const { return m_totalProgress; }
    double elapsedSeconds() const { return m_elapsedSeconds; }
    QString progressText() const { return m_progressText; }
    double lastDuration() const { return m_lastDuration; }

    Q_INVOKABLE void checkWorkerHealth();
    Q_INVOKABLE void startWorkerProcess();
    Q_INVOKABLE void stopWorkerProcess();

    // Start recognition for current page or entire task
    Q_INVOKABLE void recognizeCurrentPage();
    Q_INVOKABLE void recognizeCurrentTask();
    Q_INVOKABLE void cancelRecognition();

signals:
    void isProcessingChanged();
    void workerStatusChanged();
    void progressChanged(int current, int total);
    void progressTicker();
    void finishedDurationChanged();
    void pageOcrCompleted(const QString& pageId);
    void taskOcrCompleted(const QString& taskId);
    void ocrError(const QString& errorMessage);

private slots:
    void onTick();

private:
    explicit OcrService(QObject* parent = nullptr);
    ~OcrService() override;
    OcrService(const OcrService&) = delete;
    OcrService& operator=(const OcrService&) = delete;

    void setProcessing(bool val);
    void setWorkerStatus(bool running, const QString& msg);
    void setProgress(int current, int total, const QString& statusText = "");
    void startProgressTimer();
    void stopProgressTimer();

    std::unique_ptr<IOcrProvider> m_provider;
    QProcess* m_workerProcess = nullptr;
    QElapsedTimer m_elapsedTimer;
    QTimer* m_tickerTimer = nullptr;

    bool m_isProcessing = false;
    bool m_isWorkerRunning = false;
    QString m_workerStatusMessage = "未启动";
    int m_currentProgress = 0;
    int m_totalProgress = 0;
    double m_elapsedSeconds = 0.0;
    double m_lastDuration = 0.0;
    QString m_progressText;
    std::atomic<bool> m_cancelRequested{false};
};

} // namespace HandwritingOCR
