import Foundation

struct WidgetSnapshotStore: @unchecked Sendable {
    enum StoreError: Error {
        case appGroupUnavailable
    }

    private let directoryURL: URL?
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryURL: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotConstants.appGroupIdentifier), fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func readSnapshot() throws -> WidgetNewsSnapshot? {
        guard let fileURL else { throw StoreError.appGroupUnavailable }
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(WidgetNewsSnapshot.self, from: data)
    }

    func readFreshSnapshot(
        referenceDate: Date = .now,
        maxAge: TimeInterval = WidgetSnapshotConstants.snapshotFreshnessInterval
    ) throws -> WidgetNewsSnapshot? {
        guard let snapshot = try readSnapshot(),
              snapshot.isFresh(referenceDate: referenceDate, maxAge: maxAge) else {
            return nil
        }

        return snapshot
    }

    @discardableResult
    func writeSnapshot(_ snapshot: WidgetNewsSnapshot, skipUnchangedContent: Bool = true) throws -> Bool {
        guard let directoryURL, let fileURL else { throw StoreError.appGroupUnavailable }

        if let existingSnapshot = try readSnapshot(),
           skipUnchangedContent ? existingSnapshot.hasSameWidgetContent(as: snapshot) : existingSnapshot == snapshot {
            return false
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
        return true
    }

    private var fileURL: URL? {
        directoryURL?.appendingPathComponent(WidgetSnapshotConstants.fileName, isDirectory: false)
    }
}

private extension WidgetNewsSnapshot {
    func hasSameWidgetContent(as other: WidgetNewsSnapshot) -> Bool {
        region == other.region && items == other.items
    }
}
