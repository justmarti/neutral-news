import Foundation

protocol WidgetBriefingNews {
    var id: String { get }
    var neutralTitle: String { get }
    var imageUrl: String { get }
    var date: Date { get }
    var relevance: Int { get }
}

enum WidgetBriefingBuilder {
    private static let briefingLimit = 12
    private static let briefingWindow: TimeInterval = 24 * 60 * 60

    static func buildSnapshot<NewsItem: WidgetBriefingNews>(
        from news: [NewsItem],
        region: String,
        referenceDate: Date = .now
    ) -> WidgetNewsSnapshot? {
        let windowStart = referenceDate.addingTimeInterval(-briefingWindow)
        let items = news
            .filter { $0.date >= windowStart && $0.date <= referenceDate }
            .sorted { lhs, rhs in
                if lhs.relevance != rhs.relevance {
                    return lhs.relevance > rhs.relevance
                }

                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }

                return lhs.id < rhs.id
            }
            .prefix(briefingLimit)
            .map { news in
                WidgetNewsItem(
                    id: news.id,
                    title: news.neutralTitle,
                    imageURL: URL(string: news.imageUrl),
                    date: news.date,
                    relevance: news.relevance
                )
            }

        guard !items.isEmpty else { return nil }

        return WidgetNewsSnapshot(
            generatedAt: referenceDate,
            region: region,
            items: Array(items)
        )
    }
}
