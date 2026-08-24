#include "PageListModel.h"

namespace HandwritingOCR {

PageListModel::PageListModel(QObject* parent) : QAbstractListModel(parent) {}

int PageListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_pages.size());
}

QVariant PageListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_pages.size()) {
        return QVariant();
    }

    const auto& page = m_pages[index.row()];
    switch (role) {
        case IdRole:                 return page.id;
        case TaskIdRole:             return page.taskId;
        case PageIndexRole:          return page.pageIndex;
        case OriginalImagePathRole:  return page.originalImagePath;
        case ProcessedImagePathRole: return page.processedImagePath;
        case ThumbnailPathRole:      return page.thumbnailPath;
        case OcrResultPathRole:      return page.ocrResultPath;
        case EditedTextRole:         return page.editedText;
        case StatusRole:             return pageStatusToString(page.status);
        case CreatedAtRole:          return page.createdAt;
        case UpdatedAtRole:          return page.updatedAt;
        case TotalCharsRole:         return page.ocrResult.totalCharacters();
        case LowConfidenceCountRole: return page.ocrResult.lowConfidenceCount();
        default:                     return QVariant();
    }
}

QHash<int, QByteArray> PageListModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[IdRole] = "id";
    roles[TaskIdRole] = "taskId";
    roles[PageIndexRole] = "pageIndex";
    roles[OriginalImagePathRole] = "originalImagePath";
    roles[ProcessedImagePathRole] = "processedImagePath";
    roles[ThumbnailPathRole] = "thumbnailPath";
    roles[OcrResultPathRole] = "ocrResultPath";
    roles[EditedTextRole] = "editedText";
    roles[StatusRole] = "status";
    roles[CreatedAtRole] = "createdAt";
    roles[UpdatedAtRole] = "updatedAt";
    roles[TotalCharsRole] = "totalCharacters";
    roles[LowConfidenceCountRole] = "lowConfidenceCount";
    return roles;
}

void PageListModel::setPages(const QVector<Page>& pages) {
    beginResetModel();
    m_pages = pages;
    endResetModel();
}

void PageListModel::addPage(const Page& page) {
    beginInsertRows(QModelIndex(), static_cast<int>(m_pages.size()), static_cast<int>(m_pages.size()));
    m_pages.append(page);
    endInsertRows();
}

void PageListModel::updatePage(const Page& page) {
    for (int i = 0; i < m_pages.size(); ++i) {
        if (m_pages[i].id == page.id) {
            m_pages[i] = page;
            QModelIndex idx = index(i, 0);
            emit dataChanged(idx, idx);
            break;
        }
    }
}

void PageListModel::removePage(const QString& pageId) {
    for (int i = 0; i < m_pages.size(); ++i) {
        if (m_pages[i].id == pageId) {
            beginRemoveRows(QModelIndex(), i, i);
            m_pages.removeAt(i);
            endRemoveRows();
            break;
        }
    }
}

void PageListModel::removePageAt(int index) {
    if (index >= 0 && index < m_pages.size()) {
        beginRemoveRows(QModelIndex(), index, index);
        m_pages.removeAt(index);
        endRemoveRows();
    }
}

Page* PageListModel::getPagePtr(int index) {
    if (index >= 0 && index < m_pages.size()) {
        return &m_pages[index];
    }
    return nullptr;
}

Page* PageListModel::getPageById(const QString& pageId) {
    for (auto& page : m_pages) {
        if (page.id == pageId) {
            return &page;
        }
    }
    return nullptr;
}

} // namespace HandwritingOCR
