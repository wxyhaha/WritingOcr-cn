#pragma once

#include "IOcrProvider.h"
#include <QString>
#include <QObject>
#include <QMutex>

namespace HandwritingOCR {

class PaddleOcrProvider : public IOcrProvider {
public:
    explicit PaddleOcrProvider(const QString& workerBaseUrl = "http://127.0.0.1:18766");
    ~PaddleOcrProvider() override = default;

    void setBaseUrl(const QString& url);
    QString baseUrl() const;
    void setAuthToken(const QString& token);

    ProviderInfo info() const override;
    bool checkAvailability(QString* statusMessage = nullptr) override;
    std::optional<OcrResult> recognize(const OcrRequest& request, QString* errorMsg = nullptr) override;

private:
    QString m_baseUrl;
    QString m_authToken;
    mutable QMutex m_configMutex;
};

} // namespace HandwritingOCR
