#include "OcrBlockListModel.h"

namespace HandwritingOCR {

OcrBlockListModel::OcrBlockListModel(QObject* parent) : QAbstractListModel(parent) {}

int OcrBlockListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_blocks.size());
}

QVariant OcrBlockListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_blocks.size()) {
        return QVariant();
    }

    const auto& block = m_blocks[index.row()];
    switch (role) {
        case IdRole:              return block.id;
        case PageIdRole:          return block.pageId;
        case TextRole:            return block.text;
        case ConfidenceRole:      return block.confidence;
        case BboxXRole:           return block.bbox.x;
        case BboxYRole:           return block.bbox.y;
        case BboxWidthRole:       return block.bbox.width;
        case BboxHeightRole:      return block.bbox.height;
        case LineIndexRole:       return block.lineIndex;
        case BlockIndexRole:      return block.blockIndex;
        case TypeRole:            return block.type;
        case StatusRole:          return block.status;
        case IsLowConfidenceRole: return block.isLowConfidence(m_threshold);
        case IsSelectedRole:      return index.row() == m_selectedIndex;
        default:                  return QVariant();
    }
}

QHash<int, QByteArray> OcrBlockListModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[IdRole] = "id";
    roles[PageIdRole] = "pageId";
    roles[TextRole] = "text";
    roles[ConfidenceRole] = "confidence";
    roles[BboxXRole] = "bboxX";
    roles[BboxYRole] = "bboxY";
    roles[BboxWidthRole] = "bboxWidth";
    roles[BboxHeightRole] = "bboxHeight";
    roles[LineIndexRole] = "lineIndex";
    roles[BlockIndexRole] = "blockIndex";
    roles[TypeRole] = "type";
    roles[StatusRole] = "status";
    roles[IsLowConfidenceRole] = "isLowConfidence";
    roles[IsSelectedRole] = "isSelected";
    return roles;
}

void OcrBlockListModel::setBlocks(const QVector<OcrBlock>& blocks) {
    beginResetModel();
    m_blocks = blocks;
    m_selectedIndex = -1;
    endResetModel();
    emit selectedIndexChanged();
    emit statsChanged();
}

void OcrBlockListModel::setSelectedIndex(int index) {
    if (m_selectedIndex != index) {
        int oldIndex = m_selectedIndex;
        m_selectedIndex = index;

        if (oldIndex >= 0 && oldIndex < m_blocks.size()) {
            QModelIndex idx = this->index(oldIndex, 0);
            emit dataChanged(idx, idx, {IsSelectedRole});
        }
        if (m_selectedIndex >= 0 && m_selectedIndex < m_blocks.size()) {
            QModelIndex idx = this->index(m_selectedIndex, 0);
            emit dataChanged(idx, idx, {IsSelectedRole});
        }

        emit selectedIndexChanged();
    }
}

void OcrBlockListModel::setLowConfidenceThreshold(double threshold) {
    if (qAbs(m_threshold - threshold) > 0.001) {
        m_threshold = threshold;
        if (!m_blocks.isEmpty()) {
            QModelIndex topLeft = index(0, 0);
            QModelIndex bottomRight = index(m_blocks.size() - 1, 0);
            emit dataChanged(topLeft, bottomRight, {IsLowConfidenceRole});
        }
        emit lowConfidenceThresholdChanged();
        emit statsChanged();
    }
}

int OcrBlockListModel::lowConfidenceCount() const {
    int count = 0;
    for (const auto& b : m_blocks) {
        if (b.isLowConfidence(m_threshold)) {
            count++;
        }
    }
    return count;
}

int OcrBlockListModel::findNextLowConfidenceIndex(int startIndex) const {
    if (m_blocks.isEmpty()) return -1;

    int searchStart = (startIndex + 1) % m_blocks.size();
    for (int i = 0; i < m_blocks.size(); ++i) {
        int idx = (searchStart + i) % m_blocks.size();
        if (m_blocks[idx].isLowConfidence(m_threshold)) {
            return idx;
        }
    }
    return -1;
}

int OcrBlockListModel::findPreviousLowConfidenceIndex(int startIndex) const {
    if (m_blocks.isEmpty()) return -1;

    int total = m_blocks.size();
    int searchStart = (startIndex - 1 + total) % total;
    for (int i = 0; i < total; ++i) {
        int idx = (searchStart - i + total) % total;
        if (m_blocks[idx].isLowConfidence(m_threshold)) {
            return idx;
        }
    }
    return -1;
}

QVariantMap OcrBlockListModel::getBlockMap(int index) const {
    QVariantMap map;
    if (index >= 0 && index < m_blocks.size()) {
        const auto& b = m_blocks[index];
        map["id"] = b.id;
        map["text"] = b.text;
        map["confidence"] = b.confidence;
        map["bboxX"] = b.bbox.x;
        map["bboxY"] = b.bbox.y;
        map["bboxWidth"] = b.bbox.width;
        map["bboxHeight"] = b.bbox.height;
        map["lineIndex"] = b.lineIndex;
        map["blockIndex"] = b.blockIndex;
        map["isLowConfidence"] = b.isLowConfidence(m_threshold);
    }
    return map;
}

} // namespace HandwritingOCR
