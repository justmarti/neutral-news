import Foundation

struct WidgetNewsSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let region: String
    let items: [WidgetNewsItem]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        generatedAt: Date,
        region: String,
        items: [WidgetNewsItem]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.region = region
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case generatedAt
        case region
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        self.generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        self.region = try container.decode(String.self, forKey: .region)
        self.items = try container.decode([WidgetNewsItem].self, forKey: .items)
    }
}

struct WidgetNewsItem: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let imageURL: URL?
    let date: Date
    let relevance: Int
}

enum WidgetSnapshotConstants {
    static let appGroupIdentifier = "group.dev.itram.news"
    static let fileName = "daily-briefing-widget.json"
    static let widgetKind = "DailyBriefingWidget"
    static let snapshotFreshnessInterval: TimeInterval = 36 * 60 * 60

    private static let remoteSnapshotBaseURL = URL(string: "https://share.getfacts.app/api")!

    static func remoteSnapshotURL(for region: String) -> URL {
        let normalizedRegion = region.uppercased()
        if normalizedRegion == "US" {
            return remoteSnapshotBaseURL
                .appendingPathComponent("us")
                .appendingPathComponent("widgets")
                .appendingPathComponent("daily-briefing")
        }

        return remoteSnapshotBaseURL
            .appendingPathComponent("widgets")
            .appendingPathComponent("daily-briefing")
    }
}

enum WidgetDeepLink {
    static func url(for item: WidgetNewsItem, region: String) -> URL? {
        let normalizedRegion = region.lowercased()
        let encodedID = item.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? item.id
        return URL(string: "neutralnews://\(normalizedRegion)/news/\(encodedID)")
    }

    static var appURL: URL? {
        URL(string: "neutralnews://")
    }
}

extension WidgetNewsSnapshot {
    func isFresh(
        referenceDate: Date = .now,
        maxAge: TimeInterval = WidgetSnapshotConstants.snapshotFreshnessInterval
    ) -> Bool {
        guard schemaVersion == Self.currentSchemaVersion, !items.isEmpty else { return false }
        let allowedClockSkew: TimeInterval = 5 * 60
        guard generatedAt <= referenceDate.addingTimeInterval(allowedClockSkew) else { return false }
        return referenceDate.timeIntervalSince(generatedAt) <= maxAge
    }
}

enum WidgetRegionPreferenceStore {
    static let storageKey = "content_region_preference"

    static func syncPreference(rawValue: String?) {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshotConstants.appGroupIdentifier) else { return }

        if let rawValue {
            defaults.set(rawValue, forKey: storageKey)
        } else {
            defaults.removeObject(forKey: storageKey)
        }
    }
}

enum WidgetRegionResolver {
    static func currentRegion(defaultRegion: String = "US") -> String {
        let rawPreference = UserDefaults(suiteName: WidgetSnapshotConstants.appGroupIdentifier)?
            .string(forKey: WidgetRegionPreferenceStore.storageKey)?
            .lowercased()

        switch rawPreference {
        case "es":
            return "ES"
        case "us":
            return "US"
        default:
            return localeRegion(defaultRegion: defaultRegion)
        }
    }

    private static func localeRegion(defaultRegion: String) -> String {
        let regionCode: String?

        if #available(iOS 16.0, *) {
            regionCode = Locale.autoupdatingCurrent.region?.identifier
        } else {
            regionCode = Locale.autoupdatingCurrent.regionCode
        }

        switch regionCode?.uppercased() {
        case "ES":
            return "ES"
        case "US":
            return "US"
        default:
            return defaultRegion
        }
    }
}

struct WidgetRemoteSnapshotClient: Sendable {
    typealias DataLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private static let maximumSnapshotBytes = 256_000
    private let dataLoader: DataLoader

    init(dataLoader: @escaping DataLoader = { request in
        try await URLSession.shared.data(for: request)
    }) {
        self.dataLoader = dataLoader
    }

    func fetchSnapshot(for region: String, referenceDate: Date = .now) async throws -> WidgetNewsSnapshot? {
        var request = URLRequest(url: WidgetSnapshotConstants.remoteSnapshotURL(for: region))
        request.timeoutInterval = 6
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("NeutralNewsWidget/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await dataLoader(request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              data.count <= Self.maximumSnapshotBytes else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(WidgetNewsSnapshot.self, from: data)
        guard snapshot.region.uppercased() == region.uppercased(),
              snapshot.isFresh(referenceDate: referenceDate) else {
            return nil
        }

        return snapshot
    }
}
