//
//  FirestoreService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import FirebaseFirestore

protocol URLSessionDataProviding: Sendable {
    func fetchData(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionDataProviding {
    func fetchData(from url: URL) async throws -> (Data, URLResponse) {
        try await data(from: url)
    }
}

protocol ShareArchiveClientProtocol: Sendable {
    func fetchArchivedNews(newsId: String, region: ContentRegion) async throws -> ArchivedNewsSnapshot?
}

enum ShareArchiveError: Error, Sendable {
    case invalidURL
    case invalidResponse
    case requestFailed(Int)
}

struct NeutralNewsLookupResult {
    let news: NeutralNews
    let relatedNews: [News]
}

struct ArchivedNewsSnapshot: Decodable, Sendable {
    let id: String
    let neutralTitle: String
    let neutralDescription: String
    let categoryId: String
    let relevance: Int?
    let date: String?
    let createdAt: String?
    let updatedAt: String?
    let imageUrl: String
    let imageMedium: String
    let group: Int?
    let sourceIds: [String]
    let sources: [ArchivedSourceSnapshot]

    enum CodingKeys: String, CodingKey {
        case id
        case neutralTitle = "neutral_title"
        case neutralDescription = "neutral_description"
        case categoryId = "category_id"
        case relevance
        case date
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case imageUrl = "image_url"
        case imageMedium = "image_medium"
        case group
        case sourceIds = "source_ids"
        case sources
    }
}

struct ArchivedSourceSnapshot: Decodable, Sendable {
    let id: String
    let title: String
    let descriptionShort: String
    let publisher: String
    let link: String
    let pubDate: String?
    let imageUrl: String?
    let neutralScore: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case descriptionShort = "description_short"
        case publisher
        case link
        case pubDate = "pub_date"
        case imageUrl = "image_url"
        case neutralScore = "neutral_score"
    }
}

struct ShareArchiveClient: ShareArchiveClientProtocol {
    private let baseURL: URL
    private let session: any URLSessionDataProviding
    private let decoder = JSONDecoder()

    init(
        baseURL: URL = URL(string: "https://share.getfacts.app")!,
        session: any URLSessionDataProviding = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchArchivedNews(newsId: String, region: ContentRegion) async throws -> ArchivedNewsSnapshot? {
        let pathPrefix = region == .us ? "/api/us/news/" : "/api/news/"
        guard let encodedNewsId = newsId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: pathPrefix + encodedNewsId, relativeTo: baseURL)?.absoluteURL else {
            throw ShareArchiveError.invalidURL
        }

        let (data, response) = try await session.fetchData(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShareArchiveError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            return nil
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ShareArchiveError.requestFailed(httpResponse.statusCode)
        }

        return try decoder.decode(ArchivedNewsSnapshot.self, from: data)
    }
}

@MainActor
final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private let regionProvider: ContentRegionProviding
    private let archiveClient: any ShareArchiveClientProtocol
    private let inQueryChunkSize = 10
    
    private enum Collection {
        #if DEBUG
        static let reports = "reports_dev"
        #else
        static let reports = "reports"
        #endif
        
        static func neutralNews(for region: ContentRegion) -> String {
            switch region {
            case .us:
                return "neutral_news_us"
            case .es:
                return "neutral_news"
            }
        }
        
        static func news(for region: ContentRegion) -> String {
            switch region {
            case .us:
                return "news_us"
            case .es:
                return "news"
            }
        }
    }
    
    init(
        regionProvider: ContentRegionProviding = ContentRegionProvider(),
        archiveClient: any ShareArchiveClientProtocol = ShareArchiveClient()
    ) {
        self.regionProvider = regionProvider
        self.archiveClient = archiveClient
    }
    
    // MARK: - Neutral News Methods
    
    func fetchNeutralNews(for day: DayInfo) async throws -> [NeutralNews] {
        let start = Calendar.current.startOfDay(for: day.date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let region = resolvedRegion(from: nil)
        
        let snapshot = try await db.collection(Collection.neutralNews(for: region))
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("date", isLessThan: Timestamp(date: end))
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> NeutralNews? in
            Self.decodeNeutralNews(from: doc.data(), documentID: doc.documentID)
        }
    }

    func fetchNeutralNews(newsId: String, region: ContentRegion? = nil) async throws -> NeutralNews? {
        let region = resolvedRegion(from: region)
        if let news = try await fetchNeutralNewsFromFirestore(newsId: newsId, region: region) {
            return news
        }

        guard let archivedSnapshot = try await archiveClient.fetchArchivedNews(
            newsId: newsId,
            region: region
        ) else {
            return nil
        }

        return Self.decodeArchivedNewsSnapshot(archivedSnapshot)?.news
    }

    func fetchNeutralNewsLookup(newsId: String, region: ContentRegion? = nil) async throws -> NeutralNewsLookupResult? {
        let region = resolvedRegion(from: region)
        if let news = try await fetchNeutralNewsFromFirestore(newsId: newsId, region: region) {
            let relatedNews = (try? await fetchNews(newsIds: news.sourceIds, region: region)) ?? []
            return NeutralNewsLookupResult(news: news, relatedNews: relatedNews)
        }

        guard let archivedSnapshot = try await archiveClient.fetchArchivedNews(
            newsId: newsId,
            region: region
        ) else {
            return nil
        }

        return Self.decodeArchivedNewsSnapshot(archivedSnapshot)
    }

    private func fetchNeutralNewsFromFirestore(newsId: String, region: ContentRegion) async throws -> NeutralNews? {
        let document = try await db.collection(Collection.neutralNews(for: region))
            .document(newsId)
            .getDocument()

        guard let data = document.data() else {
            return nil
        }

        return Self.decodeNeutralNews(from: data, documentID: document.documentID)
    }
    
    
    // MARK: - Reports Methods
    
    func submitReport(for news: NeutralNews, problemType: Problem) async throws {
        let reportData: [String: Any] = [
            "news_id": news.id,
            "news_title": news.neutralTitle,
            "group": news.group,
            "problem_type": problemType.firestoreValue,
            "problem_title": problemType.localizedTitle,
            "date": Timestamp(date: Date.now)
        ]
        
#if DEBUG
        print("📤 Submitting report data: \(reportData)")
#endif
        let docRef = try await db.collection(Collection.reports).addDocument(data: reportData)
#if DEBUG
        print("📄 Report created with ID: \(docRef.documentID)")
#endif
    }
    
    // MARK: - News Methods
    
    func fetchNews(for day: DayInfo) async throws -> [News] {
        let start = Calendar.current.startOfDay(for: day.date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let region = resolvedRegion(from: nil)
        
        let snapshot = try await db.collection(Collection.news(for: region))
            .whereField("pub_date", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("pub_date", isLessThan: Timestamp(date: end))
            .whereField("group", isGreaterThan: -1)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> News? in
            Self.decodeNews(from: doc.data(), documentID: doc.documentID)
        }
    }

    func fetchNews(newsIds: [String], region: ContentRegion? = nil) async throws -> [News] {
        var seenIds = Set<String>()
        let orderedIds = newsIds.filter { seenIds.insert($0).inserted }
        guard !orderedIds.isEmpty else { return [] }

        let resolvedRegion = resolvedRegion(from: region)
        let chunks = orderedIds.chunked(into: inQueryChunkSize)
        var fetchedNewsById: [String: News] = [:]

        for chunk in chunks {
            let snapshot = try await db.collection(Collection.news(for: resolvedRegion))
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for document in snapshot.documents {
                guard let news = Self.decodeNews(from: document.data(), documentID: document.documentID) else {
                    continue
                }
                fetchedNewsById[news.id] = news
            }
        }

        return orderedIds.compactMap { fetchedNewsById[$0] }
    }
    
    // MARK: - Private Parsing Methods

    private func resolvedRegion(from region: ContentRegion?) -> ContentRegion {
        region ?? regionProvider.currentRegion
    }
    
    nonisolated static func decodeNeutralNews(from data: [String: Any], documentID: String) -> NeutralNews? {
        guard let neutralTitle = data["neutral_title"] as? String,
              let neutralDescription = data["neutral_description"] as? String,
              let category = (data["category_id"] as? String) ?? (data["category"] as? String),
              let relevance = data["relevance"] as? Int,
              let imageUrl = data["image_url"] as? String,
              let imageMedium = data["image_medium"] as? String,
              let date = data["date"] as? Timestamp,
              let createdAt = data["created_at"] as? Timestamp,
              let updatedAt = data["updated_at"] as? Timestamp,
              let group = data["group"] as? Int,
              let sourceIds = data["source_ids"] as? [String]
        else { return nil }

        return NeutralNews(
            id: documentID,
            neutralTitle: neutralTitle,
            neutralDescription: neutralDescription,
            category: category,
            relevance: relevance,
            imageUrl: imageUrl,
            imageMedium: imageMedium,
            date: date.dateValue(),
            createdAt: createdAt.dateValue(),
            updatedAt: updatedAt.dateValue(),
            group: group,
            sourceIds: sourceIds
        )
    }
    
    nonisolated static func decodeNews(from data: [String: Any], documentID: String) -> News? {
        guard let title = data["title"] as? String,
              let description = data["description_short"] as? String,
              let group = data["group"] as? Int,
              let category = (data["category_id"] as? String) ?? (data["category"] as? String),
              let link = data["link"] as? String,
              let pubDate = data["pub_date"] as? Timestamp,
              let createdAt = data["created_at"] as? Timestamp,
              let updatedAt = data["updated_at"] as? Timestamp,
              let neutralScore = data["neutral_score"] as? Int,
              let publisher = data["publisher"] as? String
        else { return nil }

        let scrappedDescription = data["scrapped_description"] as? String
        let imageUrl = data["image_url"] as? String
        let embedding = data["embedding"] as? [Double] ?? []

        return News(
            id: documentID,
            title: title,
            description: description,
            scrappedDescription: scrappedDescription,
            category: category,
            imageUrl: imageUrl,
            link: link,
            pubDate: pubDate.dateValue(),
            createdAt: createdAt.dateValue(),
            updatedAt: updatedAt.dateValue(),
            publisher: publisher,
            neutralScore: neutralScore,
            group: group,
            embedding: embedding
        )
    }

    nonisolated static func decodeArchivedNewsSnapshot(_ snapshot: ArchivedNewsSnapshot) -> NeutralNewsLookupResult? {
        guard let date = parseArchiveDate(snapshot.date),
              let createdAt = parseArchiveDate(snapshot.createdAt),
              let updatedAt = parseArchiveDate(snapshot.updatedAt) else {
            return nil
        }

        let group = snapshot.group ?? Int(snapshot.id) ?? 0
        let neutralNews = NeutralNews(
            id: snapshot.id,
            neutralTitle: snapshot.neutralTitle,
            neutralDescription: snapshot.neutralDescription,
            category: snapshot.categoryId,
            relevance: snapshot.relevance ?? 0,
            imageUrl: snapshot.imageUrl,
            imageMedium: snapshot.imageMedium,
            date: date,
            createdAt: createdAt,
            updatedAt: updatedAt,
            group: group,
            sourceIds: snapshot.sourceIds
        )

        let relatedNews = snapshot.sources.compactMap { source -> News? in
            guard let pubDate = parseArchiveDate(source.pubDate) else {
                return nil
            }

            return News(
                id: source.id,
                title: source.title,
                description: source.descriptionShort,
                scrappedDescription: nil,
                category: snapshot.categoryId,
                imageUrl: source.imageUrl,
                link: source.link,
                pubDate: pubDate,
                createdAt: pubDate,
                updatedAt: pubDate,
                publisher: source.publisher,
                neutralScore: source.neutralScore ?? 0,
                group: group,
                embedding: []
            )
        }

        return NeutralNewsLookupResult(news: neutralNews, relatedNews: relatedNews)
    }

    private nonisolated static func parseArchiveDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let internetFormatter = ISO8601DateFormatter()
        internetFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = internetFormatter.date(from: value) {
            return date
        }

        internetFormatter.formatOptions = [.withInternetDateTime]
        if let date = internetFormatter.date(from: value) {
            return date
        }

        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }

        var chunks: [[Element]] = []
        chunks.reserveCapacity((count + size - 1) / size)

        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<end]))
            index = end
        }

        return chunks
    }
}
