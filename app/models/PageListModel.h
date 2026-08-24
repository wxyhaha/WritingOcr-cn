#pragma once

#include "Page.h"
#include <QAbstractListModel>
#include <QVector>

namespace HandwritingOCR {

class PageListModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum PageRoles {
        IdRole = Qt::UserRole + 1,
        TaskIdRole,
        PageIndexRole,
        OriginalImagePathRole,
        ProcessedImagePathRole,
        ThumbnailPathRole,
        OcrResultPathRole,
        EditedTextRole,
        StatusRole,
        CreatedAtRole,
        UpdatedAtRole,
        TotalCharsRole,
        LowConfidenceCountRole
    };

    explicit PageListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setPages(const QVector<Page>& pages);
    void addPage(const Page& page);
    void updatePage(const Page& page);
    void removePage(const QString& pageId);
    void removePageAt(int index);
    const QVector<Page>& pages() const { return m_pages; }
    Page* getPagePtr(int index);
    Page* getPageById(const QString& pageId);

private:
    QVector<Page> m_pages;
};

} // namespace HandwritingOCR
