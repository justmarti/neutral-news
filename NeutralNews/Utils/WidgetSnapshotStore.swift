import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

struct ImageFocusPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
}

enum ImageFocusConfiguration {
    static let analysisMaxPixelSize: Double = 900

    static func cacheKey(for url: URL) -> String {
        "\(url.absoluteString)|\(Int(analysisMaxPixelSize))"
    }
}

struct ImageCropMetrics: Equatable, Sendable {
    let renderedSize: CGSize
    let offset: CGSize
}

enum ImageCrop {
    static func metrics(
        imageSize: CGSize,
        containerSize: CGSize,
        focusPoint: ImageFocusPoint?,
        fallbackScale: CGFloat = 1
    ) -> ImageCropMetrics {
        guard imageSize.width > 0,
              imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return ImageCropMetrics(renderedSize: containerSize, offset: .zero)
        }

        guard let focusPoint else {
            let scale = max(
                containerSize.width / imageSize.width,
                containerSize.height / imageSize.height
            ) * fallbackScale
            let renderedSize = CGSize(
                width: imageSize.width * scale,
                height: imageSize.height * scale
            )

            return ImageCropMetrics(renderedSize: renderedSize, offset: .zero)
        }

        let imageAspectRatio = imageSize.width / imageSize.height
        let targetAspectRatio = containerSize.width / containerSize.height

        let normalizedCropWidth: CGFloat
        let normalizedCropHeight: CGFloat

        if imageAspectRatio > targetAspectRatio {
            normalizedCropWidth = targetAspectRatio / imageAspectRatio
            normalizedCropHeight = 1
        } else {
            normalizedCropWidth = 1
            normalizedCropHeight = imageAspectRatio / targetAspectRatio
        }

        let focusX = clamp(CGFloat(focusPoint.x))
        let focusY = clamp(CGFloat(focusPoint.y))
        let cropOriginX = clamp(
            focusX - (normalizedCropWidth / 2),
            maxValue: 1 - normalizedCropWidth
        )
        let cropOriginY = clamp(
            focusY - (normalizedCropHeight / 2),
            maxValue: 1 - normalizedCropHeight
        )
        let scale = containerSize.width / (imageSize.width * normalizedCropWidth)
        let renderedWidth = imageSize.width * scale
        let renderedHeight = imageSize.height * scale
        let cropCenterX = cropOriginX + (normalizedCropWidth / 2)
        let cropCenterY = cropOriginY + (normalizedCropHeight / 2)

        return ImageCropMetrics(
            renderedSize: CGSize(width: renderedWidth, height: renderedHeight),
            offset: CGSize(
                width: (renderedWidth / 2) - (cropCenterX * renderedWidth),
                height: (renderedHeight / 2) - (cropCenterY * renderedHeight)
            )
        )
    }

    private static func clamp(_ value: CGFloat, maxValue: CGFloat = 1) -> CGFloat {
        min(max(value, 0), maxValue)
    }
}

actor ImageFocusCache {
    private enum Entry: Sendable {
        case hit(ImageFocusPoint)
        case miss
    }

    static let shared = ImageFocusCache()

    private var entries: [String: Entry] = [:]
    private var inFlightTasks: [String: Task<ImageFocusPoint?, Never>] = [:]

    func focusPoint(
        for key: String,
        image: CGImage,
        orientation: CGImagePropertyOrientation,
        priority: TaskPriority = .userInitiated
    ) async -> ImageFocusPoint? {
        if let entry = entries[key] {
            switch entry {
            case .hit(let focusPoint):
                return focusPoint
            case .miss:
                return nil
            }
        }

        if let task = inFlightTasks[key] {
            return await task.value
        }

        let task = Task(priority: priority) {
            await ImageFocusDetector.detectPrimarySubjectFocus(
                in: image,
                orientation: orientation,
                priority: priority
            )
        }
        inFlightTasks[key] = task

        let focusPoint = await task.value
        inFlightTasks[key] = nil
        entries[key] = focusPoint.map(Entry.hit) ?? .miss

        return focusPoint
    }
}

enum ImageFocusDetector {
    static func detectPrimarySubjectFocus(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        priority: TaskPriority
    ) async -> ImageFocusPoint? {
        await Task.detached(priority: priority) {
            detectPrimarySubjectFocusSynchronously(in: cgImage, orientation: orientation)
        }.value
    }

    private static func detectPrimarySubjectFocusSynchronously(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> ImageFocusPoint? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let face = selectPrimaryFace(from: request.results ?? []) else {
            return nil
        }

        return faceFocusPoint(for: face, in: cgImage, orientation: orientation)
    }

    private static func selectPrimaryFace(from observations: [VNFaceObservation]) -> VNFaceObservation? {
        let sortedFaces = observations.sorted { lhs, rhs in
            (lhs.boundingBox.width * lhs.boundingBox.height) > (rhs.boundingBox.width * rhs.boundingBox.height)
        }

        guard let primaryFace = sortedFaces.first else {
            return nil
        }

        let primaryArea = primaryFace.boundingBox.width * primaryFace.boundingBox.height
        guard primaryArea >= 0.025 else {
            return nil
        }

        if let secondaryFace = sortedFaces.dropFirst().first {
            let secondaryArea = secondaryFace.boundingBox.width * secondaryFace.boundingBox.height
            if secondaryArea / primaryArea > 0.72 {
                return nil
            }
        }

        return primaryFace
    }

    private static func faceFocusPoint(
        for observation: VNFaceObservation,
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> ImageFocusPoint {
        if let eyeFocusPoint = eyeFocusPoint(for: observation, in: cgImage, orientation: orientation) {
            return eyeFocusPoint
        }

        let box = observation.boundingBox
        return ImageFocusPoint(
            x: clamp(box.midX),
            y: clamp(1 - (box.origin.y + box.height) + (box.height * 0.38))
        )
    }

    private static func eyeFocusPoint(
        for observation: VNFaceObservation,
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> ImageFocusPoint? {
        let request = VNDetectFaceLandmarksRequest()
        request.inputFaceObservations = [observation]
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let landmarksObservation = request.results?.first,
              let landmarks = landmarksObservation.landmarks,
              let leftEye = averagePoint(in: landmarks.leftEye),
              let rightEye = averagePoint(in: landmarks.rightEye) else {
            return nil
        }

        let box = landmarksObservation.boundingBox
        let imageX = box.origin.x + (((leftEye.x + rightEye.x) / 2) * box.width)
        let averageEyeY = (leftEye.y + rightEye.y) / 2
        let imageY = 1 - (box.origin.y + (averageEyeY * box.height)) + (box.height * 0.1)

        return ImageFocusPoint(x: clamp(imageX), y: clamp(imageY))
    }

    private static func averagePoint(in region: VNFaceLandmarkRegion2D?) -> CGPoint? {
        guard let region, region.pointCount > 0 else {
            return nil
        }

        let total = region.normalizedPoints.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }

        return CGPoint(
            x: total.x / CGFloat(region.pointCount),
            y: total.y / CGFloat(region.pointCount)
        )
    }

    private static func clamp(_ value: CGFloat) -> Double {
        Double(min(max(value, 0), 1))
    }
}

actor WidgetSnapshotStore {
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

actor WidgetImageStore {
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

    func readFocusPoint(for item: WidgetNewsItem) -> ImageFocusPoint? {
        guard let fileURL = focusFileURL(for: item),
              let data = try? Data(contentsOf: fileURL),
              let record = try? JSONDecoder().decode(WidgetImageFocusRecord.self, from: data) else {
            return nil
        }

        return record.focusPoint
    }

    func hasFocusRecord(for item: WidgetNewsItem) -> Bool {
        guard let fileURL = focusFileURL(for: item) else { return false }
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

    @discardableResult
    func writeFocusPoint(_ focusPoint: ImageFocusPoint?, for item: WidgetNewsItem) throws -> Bool {
        guard let directoryURL, let fileURL = focusFileURL(for: item) else {
            throw WidgetSnapshotStore.StoreError.appGroupUnavailable
        }

        guard !fileManager.fileExists(atPath: fileURL.path) else {
            return false
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(WidgetImageFocusRecord(focusPoint: focusPoint))
        try data.write(to: fileURL, options: [.atomic])
        return true
    }

    private func fileURL(for item: WidgetNewsItem) -> URL? {
        directoryURL?.appendingPathComponent("\(fileName(for: item)).jpg", isDirectory: false)
    }

    private func focusFileURL(for item: WidgetNewsItem) -> URL? {
        directoryURL?.appendingPathComponent("\(fileName(for: item)).focus.json", isDirectory: false)
    }

    private func fileName(for item: WidgetNewsItem) -> String {
        item.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? item.id
    }
}

private struct WidgetImageFocusRecord: Codable {
    let focusPoint: ImageFocusPoint?
}

enum WidgetImageCache {
    private static let maxImageBytes = 8 * 1024 * 1024
    private static let maxPixelSize = ImageFocusConfiguration.analysisMaxPixelSize
    private static let compressionQuality = 0.82
    private static let maxConcurrentPreparations = 2

    static func cacheImages(for snapshot: WidgetNewsSnapshot, store: WidgetImageStore) async -> Bool {
        var itemsToPrepare: [WidgetNewsItem] = []

        for item in snapshot.items {
            guard item.imageURL != nil else { continue }

            let hasImageData = await store.hasImageData(for: item)
            let hasFocusRecord = await store.hasFocusRecord(for: item)
            if !hasImageData || !hasFocusRecord {
                itemsToPrepare.append(item)
            }
        }

        guard !itemsToPrepare.isEmpty else { return false }

        return await withTaskGroup(of: Bool.self) { group in
            var nextIndex = 0
            for _ in 0..<min(maxConcurrentPreparations, itemsToPrepare.count) {
                let item = itemsToPrepare[nextIndex]
                nextIndex += 1
                group.addTask {
                    await prepareImage(for: item, store: store)
                }
            }

            var didPrepareImage = false
            while let result = await group.next() {
                didPrepareImage = result || didPrepareImage

                guard nextIndex < itemsToPrepare.count, !Task.isCancelled else { continue }

                let item = itemsToPrepare[nextIndex]
                nextIndex += 1
                group.addTask {
                    await prepareImage(for: item, store: store)
                }
            }

            return didPrepareImage
        }
    }

    private static func prepareImage(for item: WidgetNewsItem, store: WidgetImageStore) async -> Bool {
        if let cachedImageData = await store.readImageData(for: item),
           let cachedImage = image(from: cachedImageData) {
            return await cacheFocusPoint(for: item, image: cachedImage, store: store)
        }

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

            let didWriteImage = (try? await store.writeImageData(imageData, for: item)) ?? false
            let didWriteFocus = await cacheFocusPoint(for: item, image: image, store: store)
            return didWriteImage || didWriteFocus
        } catch {
            return false
        }
    }

    private static func cacheFocusPoint(
        for item: WidgetNewsItem,
        image: CGImage,
        store: WidgetImageStore
    ) async -> Bool {
        let hasFocusRecord = await store.hasFocusRecord(for: item)
        guard hasFocusRecord == false else { return false }

        let key = item.imageURL.map(ImageFocusConfiguration.cacheKey(for:)) ?? item.id
        let focusPoint = await ImageFocusCache.shared.focusPoint(
            for: key,
            image: image,
            orientation: .up,
            priority: .utility
        )

        return (try? await store.writeFocusPoint(focusPoint, for: item)) ?? false
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

    private static func image(from data: Data) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
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
