#pragma once

#include "IOcrProvider.h"
#include <QString>
#include <QObject>

namespace HandwritingOCR {

class PaddleOcrProvider : public IOcrProvider {
public:
    explicit PaddleOcrProvider(const QString& workerBaseUrl = "http://127.0.0.1:8766");
    ~PaddleOcrProvider() override = default;

    void setBaseUrl(const QString& url) { m_baseUrl = url; }
    QString baseUrl() const { return m_baseUrl; }

    ProviderInfo info() const override;
    bool checkAvailability(QString* statusMessage = nullptr) override;
    std::optional<OcrResult> recognize(const OcrRequest& request, QString* errorMsg = nullptr) override;

private:
    QString m_baseUrl;
};

} // namespace HandwritingOCR
