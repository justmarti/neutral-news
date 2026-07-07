import Foundation
import ImageIO
import UniformTypeIdentifiers

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
        guard let snapshot = try readSnapshot() else {
            return nil
        }

        guard snapshot.isFresh(referenceDate: referenceDate, maxAge: maxAge) else { return nil }

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

struct WidgetImageStore: @unchecked Sendable {
    private let directoryURL: URL?
    private let fileManager: FileManager

    init(
        directoryURL: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotConstants.appGroupIdentifier),
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL?.appendingPathComponent("daily-briefing-widget-images", isDirectory: true)
        self.fileManager = fileManager
    }

    func readImageData(for item: WidgetNewsItem) -> Data? {
        guard let fileURL = fileURL(for: item) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    func hasImageData(for item: WidgetNewsItem) -> Bool {
        guard let fileURL = fileURL(for: item) else { return false }
        return fileManager.fileExists(atPath: fileURL.path)
    }

    @discardableResult
    func writeImageData(_ data: Data, for item: WidgetNewsItem) throws -> Bool {
        guard let directoryURL, let fileURL = fileURL(for: item) else {
            throw WidgetSnapshotStore.StoreError.appGroupUnavailable
        }

        guard !fileManager.fileExists(atPath: fileURL.path) else {
            return false
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic])
        return true
    }

    private func fileURL(for item: WidgetNewsItem) -> URL? {
        let fileName = item.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? item.id
        return directoryURL?.appendingPathComponent("\(fileName).jpg", isDirectory: false)
    }
}

enum WidgetImageCache {
    private static let maxImageBytes = 8 * 1024 * 1024
    private static let maxPixelSize: Double = 900
    private static let compressionQuality = 0.82

    static func cacheImages(for snapshot: WidgetNewsSnapshot, store: WidgetImageStore) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            for item in snapshot.items {
                guard item.imageURL != nil, !store.hasImageData(for: item) else { continue }

                group.addTask {
                    await cacheImage(for: item, store: store)
                }
            }

            var didWriteImage = false
            for await result in group {
                didWriteImage = result || didWriteImage
            }

            return didWriteImage
        }
    }

    private static func cacheImage(for item: WidgetNewsItem, store: WidgetImageStore) async -> Bool {
        guard let imageURL = item.imageURL else { return false }

        do {
            var request = URLRequest(url: imageURL)
            request.timeoutInterval = 4
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  data.count <= maxImageBytes,
                  let image = downsampledImage(from: data),
                  let imageData = encodedJPEGData(from: image) else {
                return false
            }

            return (try? store.writeImageData(imageData, for: item)) ?? false
        } catch {
            return false
        }
    }

    private static func downsampledImage(from data: Data) -> CGImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions)
    }

    private static func encodedJPEGData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options = [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return data as Data
    }
}

private extension WidgetNewsSnapshot {
    func hasSameWidgetContent(as other: WidgetNewsSnapshot) -> Bool {
        region == other.region && items == other.items
    }
}
