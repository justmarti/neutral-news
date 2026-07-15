//
//  CachedAsyncImage.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 4/8/25.
//

import SwiftUI
import UIKit

fileprivate final class ImageCacheKey: NSObject {
    let urlString: String
    let pixelSize: Int

    init(url: URL, maxPixelSize: Double) {
        self.urlString = url.absoluteString
        self.pixelSize = max(1, Int(maxPixelSize.rounded()))
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(urlString)
        hasher.combine(pixelSize)
        return hasher.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ImageCacheKey else { return false }
        return urlString == other.urlString && pixelSize == other.pixelSize
    }
}

private extension UIImage {
    var decodedMemoryCost: Int {
        if let cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }

        let pixelWidth = Int(size.width * scale)
        let pixelHeight = Int(size.height * scale)
        return pixelWidth * pixelHeight * 4
    }
}

@MainActor
enum CachedAsyncImageHelper {
    private enum ImageLoadingError: Error {
        case invalidResponse
        case unexpectedStatusCode(Int)
    }

    private static let imageRequestTimeout: TimeInterval = 15
    private static let retryDelay: Duration = .milliseconds(500)

    static let urlSession: URLSession = {
        let cache = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            diskPath: "news_image_cache"
        )
        
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = imageRequestTimeout
        return URLSession(configuration: configuration)
    }()
    
    fileprivate static let decodedImageCache: NSCache<ImageCacheKey, UIImage> = {
        let cache = NSCache<ImageCacheKey, UIImage>()
        cache.countLimit = 300
        cache.totalCostLimit = 150 * 1024 * 1024
        return cache
    }()

    static var defaultPixelSize: Double {
        Double(UIScreen.main.bounds.width * UIScreen.main.scale)
    }

    fileprivate static func cacheKey(for url: URL, maxPixelSize: Double) -> ImageCacheKey {
        ImageCacheKey(url: url, maxPixelSize: maxPixelSize)
    }

    static func cachedUIImage(url: URL, maxPixelSize: Double? = nil) -> UIImage? {
        let targetPixelSize = maxPixelSize ?? defaultPixelSize
        let key = cacheKey(for: url, maxPixelSize: targetPixelSize)
        return decodedImageCache.object(forKey: key)
    }

    static func prefetchImages(from urls: [URL], maxPixelSize: Double? = nil) async {
        guard !urls.isEmpty else { return }
        let targetPixelSize = maxPixelSize ?? defaultPixelSize

        for url in urls {
            if Task.isCancelled { return }
            let key = cacheKey(for: url, maxPixelSize: targetPixelSize)
            if decodedImageCache.object(forKey: key) != nil { continue }

            do {
                _ = try await loadUIImage(url: url, maxPixelSize: targetPixelSize)
            } catch {
                continue
            }

            await Task.yield()
        }
    }

    static func loadUIImage(url: URL, maxPixelSize: Double? = nil) async throws -> UIImage {
        let targetPixelSize = maxPixelSize ?? defaultPixelSize
        let key = cacheKey(for: url, maxPixelSize: targetPixelSize)

        if let cachedImage = decodedImageCache.object(forKey: key) {
            return cachedImage
        }

        let uiImage = try await downloadUIImage(from: url, maxPixelSize: targetPixelSize)

        decodedImageCache.setObject(uiImage, forKey: key, cost: uiImage.decodedMemoryCost)
        return uiImage
    }

    private static func downloadUIImage(from url: URL, maxPixelSize: Double) async throws -> UIImage {
        for attempt in 0...1 {
            do {
                let (data, response) = try await urlSession.data(from: url)
                try Task.checkCancellation()
                try validateImageResponse(response)

                guard let uiImage = await decodeUIImage(data, maxPixelSize: maxPixelSize) else {
                    throw URLError(.cannotDecodeContentData)
                }
                try Task.checkCancellation()
                return uiImage
            } catch {
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                try await Task.sleep(for: retryDelay)
            }
        }

        throw URLError(.unknown)
    }

    private static func validateImageResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageLoadingError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ImageLoadingError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }

    private static func shouldRetry(after error: Error) -> Bool {
        if let error = error as? URLError {
            switch error.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }

        if let error = error as? ImageLoadingError,
           case let .unexpectedStatusCode(statusCode) = error {
            return statusCode == 408 || statusCode == 429 || (500..<600).contains(statusCode)
        }

        return false
    }

    fileprivate static func decodeUIImage(_ data: Data, maxPixelSize: Double) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(
                    returning: data.downsampledImage(maxPixelSize: maxPixelSize)
                )
            }
        }
    }
}

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let maxPixelSize: Double?
    let content: (AsyncImagePhase) -> Content
    
    @State private var phase: AsyncImagePhase = .empty
    
    init(url: URL?, maxPixelSize: Double? = nil, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.content = content
    }
    
    var body: some View {
        content(phase)
            .task(id: cacheTaskIdentifier) {
                await loadImage()
            }
    }

    private var cacheTaskIdentifier: String {
        guard let url else { return "nil" }
        let targetPixelSize = maxPixelSize ?? CachedAsyncImageHelper.defaultPixelSize
        return "\(url.absoluteString)|\(Int(targetPixelSize.rounded()))"
    }

    private func loadImage() async {
        guard let url = url else {
            updatePhase(.failure(URLError(.badURL)))
            return
        }

        updatePhase(.empty)

        do {
            let uiImage = try await CachedAsyncImageHelper.loadUIImage(url: url, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            updatePhase(.success(Image(uiImage: uiImage)))
        } catch {
            guard !Task.isCancelled else { return }
            updatePhase(.failure(error))
        }
    }

    @MainActor
    private func updatePhase(_ newPhase: AsyncImagePhase) {
        phase = newPhase
    }
}
