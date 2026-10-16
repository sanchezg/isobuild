// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import UIKit

@MainActor
enum TextureFillResolver {
    static func region(at point: MapPoint, strokes: [InkStroke]) throws -> TextureRegion {
        let boundaries = strokes.filter { $0.texture == nil }
        guard !boundaries.isEmpty else { throw TextureFillError.openRegion }
        let boundaryBounds = StrokeRenderer.bounds(of: boundaries)
        // Expand around the tap so unrelated distant rooms do not lower resolution.
        for side in [512.0, 1024, 2048, 4096] {
            let scale = min(2, 2048 / side)
            let size = Int(side * scale)
            let origin = point - MapPoint(x: side / 2, y: side / 2)
            var pixels = [UInt8](repeating: 0, count: size * size * 4)
            let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(data: buffer.baseAddress, width: size, height: size,
                                              bitsPerComponent: 8, bytesPerRow: size * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                // Bitmap rows start at the top; canvas world coordinates grow down.
                context.translateBy(x: 0, y: Double(size))
                context.scaleBy(x: scale, y: -scale)
                context.translateBy(x: -origin.x, y: -origin.y)
                StrokeRenderer.drawStack(boundaries, in: context)
                return true
            }
            guard rendered else { throw TextureFillError.tooLarge }
            let barriers = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] > 12 ? UInt8(1) : 0 }
            do {
                return try TextureRegion.find(width: size, height: size, barriers: barriers,
                                              seedX: size / 2, seedY: size / 2, origin: origin, pixelSize: 1 / scale)
            } catch TextureFillError.openRegion {
                let rasterBounds = CGRect(x: origin.x, y: origin.y, width: side, height: side)
                if let boundaryBounds, rasterBounds.insetBy(dx: 2, dy: 2).contains(boundaryBounds) {
                    throw TextureFillError.openRegion
                }
                continue
            }
        }
        throw TextureFillError.openRegion
    }
}
