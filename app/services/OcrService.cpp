#include "OcrService.h"
#include "TaskService.h"
#include "SettingsService.h"
#include "ImageService.h"
#include "../infrastructure/logging/Logger.h"
#include <QtConcurrent/QtConcurrent>
#include <QCoreApplication>
#include <QDir>
#include <QTimer>
#include <QTcpSocket>

namespace HandwritingOCR {

OcrService& OcrService::instance() {
    static OcrService s_instance;
    return s_instance;
}

OcrService::OcrService(QObject* parent) : QObject(parent) {
    m_provider = std::make_unique<PaddleOcrProvider>(SettingsService::instance().ocrWorkerUrl());

    m_tickerTimer = new QTimer(this);
    connect(m_tickerTimer, &QTimer::timeout, this, &OcrService::onTick);

    connect(&SettingsService::instance(), &SettingsService::settingsChanged, this, [this]() {
        if (auto paddle = dynamic_cast<PaddleOcrProvider*>(m_provider.get())) {
            paddle->setBaseUrl(SettingsService::instance().ocrWorkerUrl());
        }
        checkWorkerHealth();
    });
}

OcrService::~OcrService() {
    stopProgressTimer();
    stopWorkerProcess();
}

void OcrService::init() {
    checkWorkerHealth();
    // If not running, start it automatically in the background
    QTimer::singleShot(1000, this, [this]() {
        if (!m_isWorkerRunning) {
            startWorkerProcess();
        }
    });
}

void OcrService::setProcessing(bool val) {
    if (m_isProcessing != val) {
        m_isProcessing = val;
        emit isProcessingChanged();
    }
}

void OcrService::setWorkerStatus(bool running, const QString& msg) {
    if (m_isWorkerRunning != running || m_workerStatusMessage != msg) {
        m_isWorkerRunning = running;
        m_workerStatusMessage = msg;
        emit workerStatusChanged();
    }
}

void OcrService::setProgress(int current, int total, const QString& statusText) {
    m_currentProgress = current;
    m_totalProgress = total;
    if (!statusText.isEmpty()) {
        m_progressText = statusText;
    }
    emit progressChanged(current, total);
}

void OcrService::startProgressTimer() {
    m_elapsedTimer.restart();
    m_elapsedSeconds = 0.0;
    emit progressTicker();
    if (!m_tickerTimer->isActive()) {
        m_tickerTimer->start(100);
    }
}

void OcrService::stopProgressTimer() {
    if (m_tickerTimer && m_tickerTimer->isActive()) {
        m_tickerTimer->stop();
    }
    if (m_elapsedTimer.isValid()) {
        m_lastDuration = m_elapsedTimer.elapsed() / 1000.0;
        m_elapsedSeconds = m_lastDuration;
        emit progressTicker();
        emit finishedDurationChanged();
    }
}

void OcrService::onTick() {
    if (m_isProcessing && m_elapsedTimer.isValid()) {
        m_elapsedSeconds = m_elapsedTimer.elapsed() / 1000.0;
        emit progressTicker();
    }
}

void OcrService::checkWorkerHealth() {
    QtConcurrent::run([this]() {
        QString msg;
        bool ok = m_provider && m_provider->checkAvailability(&msg);
        QMetaObject::invokeMethod(this, [this, ok, msg]() {
            setWorkerStatus(ok, msg);
        }, Qt::QueuedConnection);
    });
}

void OcrService::startWorkerProcess() {
    if (m_workerProcess && m_workerProcess->state() == QProcess::Running) {
        return;
    }

    // Check if another instance or process is already listening on port 8766
    QTcpSocket testSock;
    testSock.connectToHost("127.0.0.1", 8766);
    if (testSock.waitForConnected(300)) {
        testSock.disconnectFromHost();
        Logger::instance().info("OcrService", "OCR Worker service already active on port 8766.");
        checkWorkerHealth();
        return;
    }

    if (!m_workerProcess) {
        m_workerProcess = new QProcess(this);
        connect(m_workerProcess, &QProcess::readyReadStandardOutput, this, [this]() {
            QString out = QString::fromUtf8(m_workerProcess->readAllStandardOutput());
            Logger::instance().debug("OCRWorkerProcess", out.trimmed());
        });
        connect(m_workerProcess, &QProcess::readyReadStandardError, this, [this]() {
            QString err = QString::fromUtf8(m_workerProcess->readAllStandardError());
            Logger::instance().debug("OCRWorkerProcess", err.trimmed());
        });
        connect(m_workerProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this](int exitCode, QProcess::ExitStatus) {
            Logger::instance().info("OcrService", QString("OCR Worker process exited with code %1").arg(exitCode));
            setWorkerStatus(false, "OCR Worker 未启动");
        });
    }

    QString appDir = QCoreApplication::applicationDirPath();
    QString scriptPath = QDir(appDir).filePath("ocr-worker/main.py");
    if (!QFile::exists(scriptPath)) {
        // Look in source tree during development
        scriptPath = QDir(appDir).filePath("../../ocr-worker/main.py");
        if (!QFile::exists(scriptPath)) {
            scriptPath = "d:/otherCode/WritingOcr-cn/ocr-worker/main.py";
        }
    }

    QString pythonExe = "py";
    QStringList args;
    args << "-3.13" << scriptPath;

    // Check for direct python path
    if (QFile::exists("C:/Users/Administrator/AppData/Local/Programs/Python/Python313/python.exe")) {
        pythonExe = "C:/Users/Administrator/AppData/Local/Programs/Python/Python313/python.exe";
        args.clear();
        args << scriptPath;
    }

    QString scriptDir = QFileInfo(scriptPath).dir().absolutePath();
    m_workerProcess->setWorkingDirectory(scriptDir);

    Logger::instance().info("OcrService", QString("Launching OCR worker via %1 in %2: %3").arg(pythonExe, scriptDir, scriptPath));
    m_workerProcess->start(pythonExe, args);

    // Poll health after a short delay
    QTimer::singleShot(2500, this, &OcrService::checkWorkerHealth);
}

void OcrService::stopWorkerProcess() {
    if (m_workerProcess && m_workerProcess->state() == QProcess::Running) {
        m_workerProcess->terminate();
        if (!m_workerProcess->waitForFinished(2000)) {
            m_workerProcess->kill();
        }
        m_workerProcess->deleteLater();
        m_workerProcess = nullptr;
        setWorkerStatus(false, "OCR Worker 已停止");
    }
}

void OcrService::cancelRecognition() {
    m_cancelRequested = true;
    m_progressText = "正在取消识别...";
    emit progressChanged(m_currentProgress, m_totalProgress);
}

void OcrService::recognizeCurrentPage() {
    auto& taskService = TaskService::instance();
    if (!taskService.hasCurrentTask() || taskService.currentPageIndex() < 0) {
        emit ocrError("没有当前选中的页面可以识别。");
        return;
    }

    if (m_isProcessing) {
        emit ocrError("已有 OCR 识别任务正在进行中。");
        return;
    }

    Page* page = taskService.currentPagePtr();
    if (!page) return;

    QString pageId = page->id;
    QString imgPath = page->processedImagePath.isEmpty() ? page->originalImagePath : page->processedImagePath;

    if (!m_isWorkerRunning) {
        startWorkerProcess();
    }

    setProcessing(true);
    m_cancelRequested = false;
    setProgress(0, 1, "正在进行单页 OCR 识别...");
    startProgressTimer();

    bool filterPrinted = SettingsService::instance().filterPrintedText();

    QtConcurrent::run([this, pageId, imgPath, filterPrinted]() {
        OcrRequest req;
        req.imagePath = imgPath;
        req.lang = "ch";
        req.filterPrintedText = filterPrinted;

        QString errMsg;
        auto resultOpt = m_provider->recognize(req, &errMsg);

        QMetaObject::invokeMethod(this, [this, pageId, resultOpt, errMsg]() {
            stopProgressTimer();
            setProcessing(false);
            if (resultOpt.has_value()) {
                auto result = *resultOpt;
                result.pageId = pageId;
                TaskService::instance().updatePageOcrResult(pageId, result);
                emit pageOcrCompleted(pageId);
                setProgress(1, 1, QString("识别完成 (耗时 %1s)").arg(QString::number(m_lastDuration, 'f', 1)));
            } else {
                emit ocrError(errMsg.isEmpty() ? "OCR 识别失败" : errMsg);
            }
        }, Qt::QueuedConnection);
    });
}

void OcrService::recognizeCurrentTask() {
    auto& taskService = TaskService::instance();
    if (!taskService.hasCurrentTask()) {
        emit ocrError("没有当前任务。");
        return;
    }

    Task* task = taskService.currentTaskPtr();
    if (!task || task->pages.isEmpty()) {
        emit ocrError("当前任务中没有页面可以识别。");
        return;
    }

    if (m_isProcessing) {
        emit ocrError("已有 OCR 识别任务正在进行中。");
        return;
    }

    if (!m_isWorkerRunning) {
        startWorkerProcess();
    }

    setProcessing(true);
    m_cancelRequested = false;
    QString taskId = task->id;
    auto pages = task->pages;
    int total = static_cast<int>(pages.size());
    setProgress(0, total, QString("正在准备批量识别 (共 %1 页)...").arg(total));
    startProgressTimer();

    bool filterPrinted = SettingsService::instance().filterPrintedText();

    QtConcurrent::run([this, taskId, pages, total, filterPrinted]() {
        for (int i = 0; i < total; ++i) {
            if (m_cancelRequested) {
                Logger::instance().info("OcrService", "Batch OCR cancelled by user.");
                break;
            }

            const auto& page = pages[i];
            QString imgPath = page.processedImagePath.isEmpty() ? page.originalImagePath : page.processedImagePath;

            QMetaObject::invokeMethod(this, [this, i, total]() {
                setProgress(i, total, QString("正在识别第 %1/%2 页...").arg(i + 1).arg(total));
            }, Qt::BlockingQueuedConnection);

            OcrRequest req;
            req.imagePath = imgPath;
            req.lang = "ch";
            req.filterPrintedText = filterPrinted;

            QString errMsg;
            auto resOpt = m_provider->recognize(req, &errMsg);

            if (resOpt.has_value()) {
                auto result = *resOpt;
                result.pageId = page.id;
                QMetaObject::invokeMethod(this, [this, pageId = page.id, result, i, total]() {
                    TaskService::instance().updatePageOcrResult(pageId, result);
                    emit pageOcrCompleted(pageId);
                    setProgress(i + 1, total, QString("已完成 %1/%2 页").arg(i + 1).arg(total));
                }, Qt::BlockingQueuedConnection);
            } else {
                Logger::instance().error("OcrService", QString("Page %1 recognition failed: %2").arg(page.id, errMsg));
            }
        }

        QMetaObject::invokeMethod(this, [this, taskId]() {
            stopProgressTimer();
            setProcessing(false);
            emit taskOcrCompleted(taskId);
        }, Qt::QueuedConnection);
    });
}

} // namespace HandwritingOCR
