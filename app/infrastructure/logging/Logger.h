#pragma once

#include <QString>
#include <QFile>
#include <QMutex>
#include <QDateTime>
#include <iostream>

namespace HandwritingOCR {

enum class LogLevel {
    Debug,
    Info,
    Warn,
    Error
};

class Logger {
public:
    static Logger& instance();

    void init(const QString& logFilePath = QString());
    void log(LogLevel level, const QString& category, const QString& message);

    void debug(const QString& category, const QString& message) { log(LogLevel::Debug, category, message); }
    void info(const QString& category, const QString& message) { log(LogLevel::Info, category, message); }
    void warn(const QString& category, const QString& message) { log(LogLevel::Warn, category, message); }
    void error(const QString& category, const QString& message) { log(LogLevel::Error, category, message); }

private:
    Logger() = default;
    ~Logger();
    Logger(const Logger&) = delete;
    Logger& operator=(const Logger&) = delete;

    QString levelToString(LogLevel level) const;

    QFile m_logFile;
    QMutex m_mutex;
    bool m_initialized = false;
};

} // namespace HandwritingOCR
