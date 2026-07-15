//
//  ImageFocusResolver.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 15/7/26.
//

import UIKit
import Vision

@MainActor
enum ImageFocusResolver {
    static func cachedImage(for url: URL) -> UIImage? {
        CachedAsyncImageHelper.cachedUIImage(
            url: url,
            maxPixelSize: ImageFocusConfiguration.analysisMaxPixelSize
        )
    }

    static func loadImage(for url: URL) async throws -> UIImage {
        try await CachedAsyncImageHelper.loadUIImage(
            url: url,
            maxPixelSize: ImageFocusConfiguration.analysisMaxPixelSize
        )
    }

    static func prepareImage(for url: URL) async -> Bool {
        do {
            let image = try await loadImage(for: url)
            _ = await focusPoint(for: url, image: image)
            return true
        } catch {
            return false
        }
    }

    static func focusPoint(
        for url: URL,
        priority: TaskPriority = .userInitiated
    ) async -> ImageFocusPoint? {
        do {
            let image = try await loadImage(for: url)
            return await focusPoint(for: url, image: image, priority: priority)
        } catch {
            return nil
        }
    }

    static func focusPoint(
        for url: URL,
        image: UIImage,
        priority: TaskPriority = .userInitiated
    ) async -> ImageFocusPoint? {
        guard let cgImage = image.cgImage else { return nil }

        return await ImageFocusCache.shared.focusPoint(
            for: ImageFocusConfiguration.cacheKey(for: url),
            image: cgImage,
            orientation: image.imageOrientation.cgImagePropertyOrientation,
            priority: priority
        )
    }
}

private extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .upMirrored:
            return .upMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}
