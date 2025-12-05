//
//  Data+Downsampling.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/11/25.
//

import UIKit

extension Data {
    /// Downsamples image data to reduce memory footprint while maintaining visual quality
    /// - Parameter maxPixelSize: Maximum pixel dimension for the downsampled image (default: 1500px)
    /// - Returns: A downsampled UIImage, or nil if downsampling fails
    func downsampledImage(maxPixelSize: Double = 1500.0) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(self as CFData, imageSourceOptions) else {
            return nil
        }

        // 1500px is sufficient for any iPhone display @3x (max ~430pt × 3 = 1290px)
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }

        return UIImage(cgImage: downsampledImage)
    }
}
