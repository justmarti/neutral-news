//
//  ImageService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 2/7/25.
//

import Foundation
import SwiftUI

final class ImageService {
    static let shared = ImageService()
    
    private init() {}
    
    @MainActor
    func getDominantColor(from urlString: String?) async -> Color {
        guard let urlString = urlString, let url = URL(string: urlString) else { return .gray }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data), let cgImage = image.cgImage else { return .gray }
            
            return extractDominantColor(from: cgImage)
        } catch {
            return .gray
        }
    }
    
    private func extractDominantColor(from cgImage: CGImage) -> Color {
        let originalWidth = cgImage.width
        let originalHeight = cgImage.height
        
        let width = min(10, originalWidth)
        let height = min(10, originalHeight)
        
        guard width > 0, height > 0 else { return .gray }
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .gray
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return .gray }
        
        var r = 0, g = 0, b = 0
        let pixelCount = width * height
        
        for i in stride(from: 0, to: pixelCount * 4, by: 4) {
            r += Int(data.load(fromByteOffset: i, as: UInt8.self))
            g += Int(data.load(fromByteOffset: i + 1, as: UInt8.self))
            b += Int(data.load(fromByteOffset: i + 2, as: UInt8.self))
        }
        
        return Color(
            red: Double(r) / Double(255 * pixelCount),
            green: Double(g) / Double(255 * pixelCount),
            blue: Double(b) / Double(255 * pixelCount)
        )
    }
}
