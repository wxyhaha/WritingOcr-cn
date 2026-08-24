#pragma once

#include "OcrBlock.h"
#include <QAbstractListModel>
#include <QVector>

namespace HandwritingOCR {

class OcrBlockListModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int selectedIndex READ selectedIndex WRITE setSelectedIndex NOTIFY selectedIndexChanged)
    Q_PROPERTY(double lowConfidenceThreshold READ lowConfidenceThreshold WRITE setLowConfidenceThreshold NOTIFY lowConfidenceThresholdChanged)
    Q_PROPERTY(int lowConfidenceCount READ lowConfidenceCount NOTIFY statsChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY statsChanged)

public:
    enum BlockRoles {
        IdRole = Qt::UserRole + 1,
        PageIdRole,
        TextRole,
        ConfidenceRole,
        BboxXRole,
        BboxYRole,
        BboxWidthRole,
        BboxHeightRole,
        LineIndexRole,
        BlockIndexRole,
        TypeRole,
        StatusRole,
        HandwritingScoreRole,
        IsHandwritingRole,
        IsLowConfidenceRole,
        IsSelectedRole,
        CharStartRole,
        CharEndRole
    };

    explicit OcrBlockListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setBlocks(const QVector<OcrBlock>& blocks);
    const QVector<OcrBlock>& blocks() const { return m_blocks; }

    int selectedIndex() const { return m_selectedIndex; }
    void setSelectedIndex(int index);

    double lowConfidenceThreshold() const { return m_threshold; }
    void setLowConfidenceThreshold(double threshold);

    int lowConfidenceCount() const;
    int totalCount() const { return static_cast<int>(m_blocks.size()); }

    Q_INVOKABLE int findNextLowConfidenceIndex(int startIndex) const;
    Q_INVOKABLE int findPreviousLowConfidenceIndex(int startIndex) const;
    Q_INVOKABLE int findBlockIndexByCharOffset(int charOffset) const;
    Q_INVOKABLE int findBlockIndexForCursor(int charOffset, const QString& currentText) const;
    Q_INVOKABLE int getCharStart(int index) const;
    Q_INVOKABLE int getCharLength(int index) const;
    Q_INVOKABLE QVariantMap getBlockMap(int index) const;

signals:
    void selectedIndexChanged();
    void lowConfidenceThresholdChanged();
    void statsChanged();

private:
    QVector<OcrBlock> m_blocks;
    int m_selectedIndex = -1;
    double m_threshold = 0.75;
};

} // namespace HandwritingOCR
