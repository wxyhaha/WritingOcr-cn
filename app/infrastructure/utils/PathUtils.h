#pragma once
#include <QString>
#include <QStringList>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QProcessEnvironment>

namespace HandwritingOCR {

class PathUtils {
public:
    /**
     * @brief Checks if a python executable path is valid and not a 0-byte WindowsApps dummy alias.
     */
    static bool isValidPythonExe(const QString& path) {
        if (path.trimmed().isEmpty()) return false;
        if (path.contains("WindowsApps", Qt::CaseInsensitive)) return false;
        QFileInfo fi(path);
        if (!fi.exists() || !fi.isFile() || fi.size() == 0) return false;
        return true;
    }

    /**
     * @brief Finds the full absolute path of a resource by checking the executable directory
     * and walking up parent directories (up to 5 levels) to locate source or build assets.
     */
    static QString findResourcePath(const QString& relativeSubPath) {
        QString appDir = QCoreApplication::applicationDirPath();
        QDir currentDir(appDir);

        for (int i = 0; i < 5; ++i) {
            QString candidate = currentDir.filePath(relativeSubPath);
            if (QFile::exists(candidate) || QDir(candidate).exists()) {
                return QDir::cleanPath(candidate);
            }
            if (!currentDir.cdUp()) {
                break;
            }
        }
        return QDir::cleanPath(QDir(appDir).filePath(relativeSubPath));
    }

    /**
     * @brief Dynamically locates the best available real Python interpreter on the system.
     * Filters out 0-byte Microsoft Store WindowsApps aliases (which fail with error 9009).
     */
    static QString findPythonExecutable(QStringList* prefixArgs = nullptr) {
        if (prefixArgs) prefixArgs->clear();

        // 1. Environment variable override
        QString envPy = QProcessEnvironment::systemEnvironment().value("PYTHON_EXECUTABLE");
        if (isValidPythonExe(envPy)) {
            return QDir::toNativeSeparators(envPy);
        }

        // 2. Search user %LOCALAPPDATA%/Programs/Python/Python* (Standard Python.org Windows install)
        QString localAppData = QProcessEnvironment::systemEnvironment().value("LOCALAPPDATA");
        if (!localAppData.isEmpty()) {
            QDir pyProgramsDir(localAppData + "/Programs/Python");
            if (pyProgramsDir.exists()) {
                QStringList entries = pyProgramsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::Reversed);
                for (const QString& entry : entries) {
                    QString pyExe = pyProgramsDir.filePath(entry + "/python.exe");
                    if (isValidPythonExe(pyExe)) {
                        return QDir::toNativeSeparators(pyExe);
                    }
                }
            }
        }

        // 3. Search root C:/Python* or D:/Python*
        for (const QString& driveRoot : QStringList() << "C:/" << "D:/") {
            QDir rootDir(driveRoot);
            if (rootDir.exists()) {
                QStringList rootPyDirs = rootDir.entryList(QStringList() << "Python*", QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::Reversed);
                for (const QString& entry : rootPyDirs) {
                    QString pyExe = rootDir.filePath(entry + "/python.exe");
                    if (isValidPythonExe(pyExe)) {
                        return QDir::toNativeSeparators(pyExe);
                    }
                }
            }
        }

        // 4. Windows Python launcher 'py'
        QString pyLauncher = QStandardPaths::findExecutable("py");
        if (isValidPythonExe(pyLauncher)) {
            if (prefixArgs) prefixArgs->append("-3");
            return QDir::toNativeSeparators(pyLauncher);
        }

        // 5. Real 'python' in system PATH (excluding WindowsApps dummy)
        QString pathPy = QStandardPaths::findExecutable("python");
        if (isValidPythonExe(pathPy)) {
            return QDir::toNativeSeparators(pathPy);
        }

        // 6. Real 'python3' in system PATH (excluding WindowsApps dummy)
        QString pathPy3 = QStandardPaths::findExecutable("python3");
        if (isValidPythonExe(pathPy3)) {
            return QDir::toNativeSeparators(pathPy3);
        }

        // 7. Fallback to 'py' launcher or 'python'
        if (!pyLauncher.isEmpty()) {
            if (prefixArgs) prefixArgs->append("-3");
            return "py";
        }
        return "python";
    }
};

} // namespace HandwritingOCR
