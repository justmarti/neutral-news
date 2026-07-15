import CoreGraphics
import Foundation
import Testing
@testable import NeutralNews

@Suite("Image Focus Tests")
struct ImageFocusTests {
    @Test("Uses one shared analysis identity across image surfaces")
    func usesSharedAnalysisIdentity() throws {
        let url = try #require(URL(string: "https://example.com/image.jpg"))

        #expect(ImageFocusConfiguration.analysisMaxPixelSize == 900)
        #expect(ImageFocusConfiguration.cacheKey(for: url) == "https://example.com/image.jpg|900")
    }

    @Test("Keeps a right-edge focal point inside a square crop")
    func keepsRightEdgeFocusInsideCrop() {
        let metrics = ImageCrop.metrics(
            imageSize: CGSize(width: 2_000, height: 1_000),
            containerSize: CGSize(width: 100, height: 100),
            focusPoint: ImageFocusPoint(x: 0.85, y: 0.5)
        )

        #expect(metrics.renderedSize == CGSize(width: 200, height: 100))
        #expect(metrics.offset == CGSize(width: -50, height: 0))
    }

    @Test("Keeps a lower focal point inside a square crop")
    func keepsLowerFocusInsideCrop() {
        let metrics = ImageCrop.metrics(
            imageSize: CGSize(width: 1_000, height: 2_000),
            containerSize: CGSize(width: 100, height: 100),
            focusPoint: ImageFocusPoint(x: 0.5, y: 0.85)
        )

        #expect(metrics.renderedSize == CGSize(width: 100, height: 200))
        #expect(metrics.offset == CGSize(width: 0, height: -50))
    }

    @Test("Centers the image when no focal point is available")
    func centersImageWithoutFocusPoint() {
        let metrics = ImageCrop.metrics(
            imageSize: CGSize(width: 2_000, height: 1_000),
            containerSize: CGSize(width: 100, height: 100),
            focusPoint: nil
        )

        #expect(metrics.renderedSize == CGSize(width: 200, height: 100))
        #expect(metrics.offset == .zero)
    }
}
