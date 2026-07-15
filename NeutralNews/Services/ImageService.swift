//
//  ImageService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import SwiftUI

private actor DominantColorCache {
    struct Components: Sendable {
        let red: Double
        let green: Double
        let blue: Double

        var color: Color {
            Color(red: red, green: green, blue: blue)
        }
    }

    private var storage: [String: Components] = [:]

    func color(for key: String) -> Components? {
        storage[key]
    }

    func set(_ color: Components, for key: String) {
        storage[key] = color
    }
}

private enum DominantColorConfiguration {
    static let downsamplePixelSize: Double = 128
}

@MainActor
final class ImageService {
    static let shared = ImageService()
    
    private let colorCache = DominantColorCache()
    private let processingQueue = DispatchQueue(label: "imageservice.processing", qos: .utility)
    private let urlSession: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        self.urlSession = URLSession(configuration: configuration)
    }
    
    func getDominantColor(from urlString: String?) async -> Color {
        guard let urlString = urlString else { return .nnBackground }
        
        if let cachedColor = await colorCache.color(for: urlString) {
            return cachedColor.color
        }
        
        if let cachedImageColor = await extractColorFromCachedImage(urlString: urlString) {
            await colorCache.set(cachedImageColor, for: urlString)
            return cachedImageColor.color
        }
        
        guard let url = URL(string: urlString) else { return .nnBackground }
        
        do {
            let (data, _) = try await urlSession.data(from: url)
            guard let color = await extractColorComponents(from: data) else { return .nnBackground }

            await colorCache.set(color, for: urlString)
            return color.color
        } catch {
            return .nnBackground
        }
    }
    
    private func extractColorFromCachedImage(urlString: String) async -> DominantColorCache.Components? {
        guard let url = URL(string: urlString) else { return nil }

        let request = URLRequest(url: url)
        if let cachedResponse = CachedAsyncImageHelper.urlSession.configuration.urlCache?.cachedResponse(for: request) {
            return await extractColorComponents(from: cachedResponse.data)
        }

        return nil
    }
    
    private func extractColorComponents(from data: Data) async -> DominantColorCache.Components? {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                continuation.resume(returning: Self.processDominantColor(from: data))
            }
        }
    }
    
    private nonisolated static func processDominantColor(from data: Data) -> DominantColorCache.Components? {
        guard let image = data.downsampledImage(maxPixelSize: DominantColorConfiguration.downsamplePixelSize),
              let cgImage = image.cgImage else {
            return nil
        }

        return extractDominantColor(from: cgImage)
    }

    private nonisolated static func extractDominantColor(from cgImage: CGImage) -> DominantColorCache.Components? {
        let originalWidth = cgImage.width
        let originalHeight = cgImage.height
        
        let width = min(10, originalWidth)
        let height = min(10, originalHeight)
        
        guard width > 0, height > 0 else { return nil }
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return nil }
        
        var r = 0, g = 0, b = 0
        let pixelCount = width * height
        
        for i in stride(from: 0, to: pixelCount * 4, by: 4) {
            r += Int(data.load(fromByteOffset: i, as: UInt8.self))
            g += Int(data.load(fromByteOffset: i + 1, as: UInt8.self))
            b += Int(data.load(fromByteOffset: i + 2, as: UInt8.self))
        }
        
        return DominantColorCache.Components(
            red: Double(r) / Double(255 * pixelCount),
            green: Double(g) / Double(255 * pixelCount),
            blue: Double(b) / Double(255 * pixelCount)
        )
    }
}
