#include "Logger.h"
#include <QFileInfo>
#include <QDir>
#include <QTextStream>

namespace HandwritingOCR {

Logger& Logger::instance() {
    static Logger s_instance;
    return s_instance;
}

Logger::~Logger() {
    if (m_logFile.isOpen()) {
        m_logFile.close();
    }
}

void Logger::init(const QString& logFilePath) {
    QMutexLocker locker(&m_mutex);
    if (m_initialized) return;

    if (!logFilePath.isEmpty()) {
        QFileInfo fi(logFilePath);
        QDir().mkpath(fi.absolutePath());
        m_logFile.setFileName(logFilePath);
        m_logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text);
    }
    m_initialized = true;
}

QString Logger::levelToString(LogLevel level) const {
    switch (level) {
        case LogLevel::Debug: return "DEBUG";
        case LogLevel::Info:  return "INFO";
        case LogLevel::Warn:  return "WARN";
        case LogLevel::Error: return "ERROR";
        default:              return "UNKNOWN";
    }
}

void Logger::log(LogLevel level, const QString& category, const QString& message) {
    QMutexLocker locker(&m_mutex);
    QString timeStr = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
    QString logLine = QString("[%1] [%2] [%3] %4\n")
                          .arg(timeStr)
                          .arg(levelToString(level), -5)
                          .arg(category)
                          .arg(message);

    std::cout << logLine.toLocal8Bit().constData();
    std::cout.flush();

    if (m_logFile.isOpen()) {
        QTextStream stream(&m_logFile);
        stream << logLine;
        stream.flush();
    }
}

} // namespace HandwritingOCR
