#include "OcrService.h"
#include "TaskService.h"
#include "SettingsService.h"
#include "ImageService.h"
#include "../infrastructure/logging/Logger.h"
#include <QtConcurrent/QtConcurrent>
#include <QCoreApplication>
#include <QDir>
#include <QTimer>

namespace HandwritingOCR {

OcrService& OcrService::instance() {
    static OcrService s_instance;
    return s_instance;
}

OcrService::OcrService(QObject* parent) : QObject(parent) {
    m_provider = std::make_unique<PaddleOcrProvider>(SettingsService::instance().ocrWorkerUrl());

    connect(&SettingsService::instance(), &SettingsService::settingsChanged, this, [this]() {
        if (auto paddle = dynamic_cast<PaddleOcrProvider*>(m_provider.get())) {
            paddle->setBaseUrl(SettingsService::instance().ocrWorkerUrl());
        }
        checkWorkerHealth();
    });
}

OcrService::~OcrService() {
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

    if (!m_workerProcess) {
        m_workerProcess = new QProcess(this);
        connect(m_workerProcess, &QProcess::readyReadStandardOutput, this, [this]() {
            QByteArray out = m_workerProcess->readAllStandardOutput();
            Logger::instance().debug("OCRWorkerProcess", QString::fromUtf8(out).trimmed());
        });
        connect(m_workerProcess, &QProcess::readyReadStandardError, this, [this]() {
            QByteArray err = m_workerProcess->readAllStandardError();
            Logger::instance().debug("OCRWorkerProcess", QString::fromUtf8(err).trimmed());
        });
    }

    QString appDir = QCoreApplication::applicationDirPath();
    QString scriptPath = QDir(appDir).filePath("ocr-worker/main.py");
    if (!QFile::exists(scriptPath)) {
        scriptPath = "d:/otherCode/WritingOcr-cn/ocr-worker/main.py";
    }

    QString pythonExe = "py";
    QStringList args;
    args << "-3.13" << scriptPath;

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
    m_currentProgress = 0;
    m_totalProgress = 1;
    emit progressChanged(0, 1);

    QtConcurrent::run([this, pageId, imgPath]() {
        OcrRequest req;
        req.imagePath = imgPath;
        req.lang = "ch";

        QString errMsg;
        auto resultOpt = m_provider->recognize(req, &errMsg);

        QMetaObject::invokeMethod(this, [this, pageId, resultOpt, errMsg]() {
            setProcessing(false);
            if (resultOpt.has_value()) {
                auto result = *resultOpt;
                result.pageId = pageId;
                TaskService::instance().updatePageOcrResult(pageId, result);
                emit pageOcrCompleted(pageId);
                m_currentProgress = 1;
                emit progressChanged(1, 1);
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
    m_totalProgress = total;
    m_currentProgress = 0;
    emit progressChanged(0, total);

    QtConcurrent::run([this, taskId, pages, total]() {
        for (int i = 0; i < total; ++i) {
            if (m_cancelRequested) {
                Logger::instance().info("OcrService", "Batch OCR cancelled by user.");
                break;
            }

            const auto& page = pages[i];
            QString imgPath = page.processedImagePath.isEmpty() ? page.originalImagePath : page.processedImagePath;

            OcrRequest req;
            req.imagePath = imgPath;
            req.lang = "ch";

            QString errMsg;
            auto resOpt = m_provider->recognize(req, &errMsg);

            if (resOpt.has_value()) {
                auto result = *resOpt;
                result.pageId = page.id;
                QMetaObject::invokeMethod(this, [this, pageId = page.id, result, i, total]() {
                    TaskService::instance().updatePageOcrResult(pageId, result);
                    emit pageOcrCompleted(pageId);
                    m_currentProgress = i + 1;
                    emit progressChanged(i + 1, total);
                }, Qt::BlockingQueuedConnection);
            } else {
                Logger::instance().error("OcrService", QString("Page %1 recognition failed: %2").arg(page.id, errMsg));
            }
        }

        QMetaObject::invokeMethod(this, [this, taskId]() {
            setProcessing(false);
            emit taskOcrCompleted(taskId);
        }, Qt::QueuedConnection);
    });
}

} // namespace HandwritingOCR
