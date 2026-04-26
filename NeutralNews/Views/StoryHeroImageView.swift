//
//  StoryHeroImageView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 4/10/26.
//

import SwiftUI
import Vision

struct StoryHeroImageView: View {
    let imageUrl: String
    let reservedBottomHeight: CGFloat
    let storyFocusPoint: StoryFocusPoint?

    private let fallbackSharpScale: CGFloat = 1.03
    @Environment(\.displayScale) private var displayScale
    @State private var loadedUIImage: UIImage?
    @State private var loadedImageIdentifier: String?
    @State private var displayFocusPoint: StoryFocusPoint?
    @State private var displayFocusPointImageIdentifier: String?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let extraBottomCrop: CGFloat = 0
            let topInset: CGFloat = 65
            let availableSharpHeight = size.height - reservedBottomHeight - extraBottomCrop - topInset
            let sharpHeight = max(availableSharpHeight, 0)
            let resolvedUIImage = resolvedUIImage(size: size)
            let currentImageIdentifier = imageLoadIdentifier(size: size)
            let effectiveFocusPoint =
                displayFocusPointImageIdentifier == currentImageIdentifier
                ? displayFocusPoint
                : storyFocusPoint
            let heroContainerSize = CGSize(width: size.width, height: sharpHeight)
            let backgroundContainerSize = CGSize(width: size.width, height: size.height)
            let heroMetrics = resolvedUIImage.map {
                storyImageMetrics(
                    uiImage: $0,
                    containerSize: heroContainerSize,
                    focusPoint: effectiveFocusPoint
                )
            }
            let backgroundMetrics = resolvedUIImage.map {
                storyImageMetrics(
                    uiImage: $0,
                    containerSize: backgroundContainerSize,
                    focusPoint: effectiveFocusPoint
                )
            }
            let fallbackBackground = LinearGradient(
                colors: [.black.opacity(0.85), .gray.opacity(0.55), .black.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                Group {
                    if let uiImage = resolvedUIImage,
                       let backgroundMetrics {
                        renderedStoryImage(
                            uiImage: uiImage,
                            metrics: backgroundMetrics,
                            containerSize: size
                        )
                        .blur(radius: 28)
                        .saturation(0.95)
                        .opacity(1)
                    } else {
                        fallbackBackground
                            .frame(width: size.width, height: size.height)
                    }
                }
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        Group {
                            if let uiImage = resolvedUIImage,
                               let heroMetrics {
                                renderedStoryImage(
                                    uiImage: uiImage,
                                    metrics: heroMetrics,
                                    containerSize: heroContainerSize
                                )
                            } else {
                                ShimmerView()
                                    .frame(width: size.width, height: sharpHeight)
                            }
                        }
                        .task(id: imageLoadIdentifier(size: size)) {
                            guard let url = URL(string: imageUrl) else {
                                loadedUIImage = nil
                                loadedImageIdentifier = nil
                                displayFocusPoint = nil
                                displayFocusPointImageIdentifier = nil
                                return
                            }

                            let imageIdentifier = imageLoadIdentifier(size: size)
                            let maxPixelSize = imageLoadMaxPixelSize(size: size)
                            let initialFocusPoint = await initialDisplayFocusPoint(for: imageIdentifier)

                            guard !Task.isCancelled else { return }

                            loadedUIImage = nil
                            loadedImageIdentifier = imageIdentifier
                            displayFocusPoint = initialFocusPoint
                            displayFocusPointImageIdentifier = imageIdentifier

                            if let cachedImage = CachedAsyncImageHelper.cachedUIImage(
                                url: url,
                                maxPixelSize: maxPixelSize
                            ) {
                                loadedUIImage = cachedImage
                                loadedImageIdentifier = imageIdentifier
                                return
                            }

                            do {
                                let image = try await CachedAsyncImageHelper.loadUIImage(
                                    url: url,
                                    maxPixelSize: maxPixelSize
                                )
                                if loadedImageIdentifier == imageIdentifier {
                                    loadedUIImage = image
                                }
                            } catch {
                                if loadedImageIdentifier == imageIdentifier {
                                    loadedUIImage = nil
                                }
                            }
                        }
                        .task(id: visionTaskIdentifier(size: size)) {
                            let visionIdentifier = imageLoadIdentifier(size: size)

                            guard let uiImage = resolvedUIImage else {
                                return
                            }

                            if await StoryFaceFocusCache.shared.entry(for: visionIdentifier) != nil {
                                return
                            }

                            let refinedFocusPoint = await StoryFaceFocusDetector.detectPrimarySubjectFocus(in: uiImage)

                            if let refinedFocusPoint {
                                await StoryFaceFocusCache.shared.set(.hit(refinedFocusPoint), for: visionIdentifier)
                            } else {
                                await StoryFaceFocusCache.shared.set(.miss, for: visionIdentifier)
                            }
                        }
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.08),
                                    .init(color: .black, location: 0.84),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .frame(width: size.width, height: sharpHeight)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, topInset)
                .allowsHitTesting(false)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.02), location: 0),
                        .init(color: .clear, location: 0.2),
                        .init(color: .clear, location: 0.6),
                        .init(color: .black.opacity(0.18), location: 0.82),
                        .init(color: .black.opacity(0.34), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }

    private func imageLoadIdentifier(size: CGSize) -> String {
        "\(imageUrl)|\(Int(imageLoadMaxPixelSize(size: size).rounded()))"
    }

    private func visionTaskIdentifier(size: CGSize) -> String {
        let imageIdentifier = imageLoadIdentifier(size: size)
        let hasResolvedImage = resolvedUIImage(size: size) != nil ? "ready" : "pending"
        return "\(imageIdentifier)|\(hasResolvedImage)"
    }

    private func imageLoadMaxPixelSize(size: CGSize) -> Double {
        Double(max(size.width, size.height) * displayScale)
    }

    private func resolvedUIImage(size: CGSize) -> UIImage? {
        let imageIdentifier = imageLoadIdentifier(size: size)

        guard loadedImageIdentifier == imageIdentifier else {
            return nil
        }

        return loadedUIImage
    }

    private func initialDisplayFocusPoint(for imageIdentifier: String) async -> StoryFocusPoint? {
        guard let cachedEntry = await StoryFaceFocusCache.shared.entry(for: imageIdentifier) else {
            return storyFocusPoint
        }

        switch cachedEntry {
        case .hit(let focusPoint):
            return focusPoint
        case .miss:
            return storyFocusPoint
        }
    }

    @ViewBuilder
    private func renderedStoryImage(
        uiImage: UIImage,
        metrics: StoryImageMetrics,
        containerSize: CGSize,
        verticalOffsetAdjustment: CGFloat = 0
    ) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .frame(
                width: metrics.renderedSize.width,
                height: metrics.renderedSize.height
            )
            .offset(
                x: metrics.offset.width,
                y: metrics.offset.height + verticalOffsetAdjustment
            )
            .frame(width: containerSize.width, height: containerSize.height)
            .clipped()
    }

    private func storyImageMetrics(
        uiImage: UIImage,
        containerSize: CGSize,
        focusPoint: StoryFocusPoint?
    ) -> StoryImageMetrics {
        let imageSize = uiImage.size
        if let focusPoint {
            return focusCropMetrics(
                imageSize: imageSize,
                focusPoint: focusPoint,
                containerSize: containerSize
            )
        }

        guard imageSize.width > 0,
              imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return StoryImageMetrics(renderedSize: containerSize, offset: .zero)
        }

        let scale = max(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        ) * fallbackSharpScale
        let renderedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        let offset = CGSize(
            width: (containerSize.width - renderedSize.width) / 2,
            height: (containerSize.height - renderedSize.height) / 2
        )

        return StoryImageMetrics(renderedSize: renderedSize, offset: offset)
    }

    private func focusCropMetrics(
        imageSize: CGSize,
        focusPoint: StoryFocusPoint,
        containerSize: CGSize
    ) -> StoryImageMetrics {
        guard imageSize.width > 0,
              imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return StoryImageMetrics(renderedSize: containerSize, offset: .zero)
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

        let focusX = clamp(CGFloat(focusPoint.x), minValue: 0, maxValue: 1)
        let focusY = clamp(CGFloat(focusPoint.y), minValue: 0, maxValue: 1)

        let cropOriginX = clamp(
            focusX - (normalizedCropWidth / 2),
            minValue: 0,
            maxValue: 1 - normalizedCropWidth
        )
        let cropOriginY = clamp(
            focusY - (normalizedCropHeight / 2),
            minValue: 0,
            maxValue: 1 - normalizedCropHeight
        )

        let scale = containerSize.width / (imageSize.width * normalizedCropWidth)

        let renderedWidth = imageSize.width * scale
        let renderedHeight = imageSize.height * scale

        let cropCenterX = cropOriginX + (normalizedCropWidth / 2)
        let cropCenterY = cropOriginY + (normalizedCropHeight / 2)

        let offsetX = (renderedWidth / 2) - (cropCenterX * renderedWidth)
        let offsetY = (renderedHeight / 2) - (cropCenterY * renderedHeight)

        return StoryImageMetrics(
            renderedSize: CGSize(width: renderedWidth, height: renderedHeight),
            offset: CGSize(width: offsetX, height: offsetY)
        )
    }

    private func clamp(_ value: CGFloat, minValue: CGFloat, maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}

private struct StoryImageMetrics {
    let renderedSize: CGSize
    let offset: CGSize
}

private actor StoryFaceFocusCache {
    enum Entry: Sendable {
        case hit(StoryFocusPoint)
        case miss
    }

    static let shared = StoryFaceFocusCache()

    private var entries: [String: Entry] = [:]

    func entry(for key: String) -> Entry? {
        entries[key]
    }

    func set(_ entry: Entry, for key: String) {
        entries[key] = entry
    }
}

private enum StoryFaceFocusDetector {
    static func detectPrimarySubjectFocus(in image: UIImage) async -> StoryFocusPoint? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: detectPrimarySubjectFocus(
                    in: cgImage,
                    orientation: image.imageOrientation.cgImagePropertyOrientation
                ))
            }
        }
    }

    private static func detectPrimarySubjectFocus(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> StoryFocusPoint? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results else {
            return nil
        }

        guard let face = selectPrimaryFace(from: observations) else {
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
    ) -> StoryFocusPoint {
        if let eyeFocusPoint = eyeFocusPoint(
            for: observation,
            in: cgImage,
            orientation: orientation
        ) {
            return eyeFocusPoint
        }

        let box = observation.boundingBox
        let x = box.midX
        let topY = 1 - (box.origin.y + box.height)
        let y = topY + (box.height * 0.38)

        return StoryFocusPoint(
            x: clamp(x),
            y: clamp(y)
        )
    }

    private static func eyeFocusPoint(
        for observation: VNFaceObservation,
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> StoryFocusPoint? {
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

        let averageEyeX = (leftEye.x + rightEye.x) / 2
        let averageEyeY = (leftEye.y + rightEye.y) / 2
        let box = landmarksObservation.boundingBox

        let imageX = box.origin.x + (averageEyeX * box.width)
        let imageYBottom = box.origin.y + (averageEyeY * box.height)
        let imageYTop = 1 - imageYBottom + (box.height * 0.1)

        return StoryFocusPoint(
            x: clamp(imageX),
            y: clamp(imageYTop)
        )
    }

    private static func averagePoint(in region: VNFaceLandmarkRegion2D?) -> CGPoint? {
        guard let region, region.pointCount > 0 else {
            return nil
        }

        let points = region.normalizedPoints
        let total = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }

        return CGPoint(
            x: total.x / CGFloat(points.count),
            y: total.y / CGFloat(points.count)
        )
    }

    private static func clamp(_ value: CGFloat) -> Double {
        Double(min(max(value, 0), 1))
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
