// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import Foundation

enum TextureFillError: Error {
    case openRegion
    case boundary
    case tooLarge
}

struct TextureRegion: Sendable {
    let width: Int
    let height: Int
    let origin: MapPoint
    let pixelSize: Double
    private let mask: [UInt8]
    let minX: Int
    let maxX: Int
    let minY: Int
    let maxY: Int

    var lower: MapPoint { origin + MapPoint(x: Double(minX) * pixelSize, y: Double(minY) * pixelSize) }
    var upper: MapPoint { origin + MapPoint(x: Double(maxX + 1) * pixelSize, y: Double(maxY + 1) * pixelSize) }

    /// Four-connected flood fill keeps diagonal barrier pixels watertight.
    /// A region reaching the raster edge is rejected instead of filling outside.
    static func find(width: Int, height: Int, barriers: [UInt8], seedX: Int, seedY: Int,
                     origin: MapPoint, pixelSize: Double) throws -> Self {
        guard width > 2, height > 2, width <= 2048, height <= 2048,
              barriers.count == width * height, (0..<width).contains(seedX),
              (0..<height).contains(seedY), pixelSize > 0 else { throw TextureFillError.tooLarge }
        let seed = seedY * width + seedX
        guard barriers[seed] == 0 else { throw TextureFillError.boundary }
        var mask = barriers
        mask[seed] = 2
        var queue = [seed]
        queue.reserveCapacity(min(width * height, 262_144))
        var cursor = 0
        var minX = seedX, maxX = seedX, minY = seedY, maxY = seedY
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1
            let x = index % width, y = index / width
            if x == 0 || y == 0 || x == width - 1 || y == height - 1 { throw TextureFillError.openRegion }
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
            if mask[index - 1] == 0 { mask[index - 1] = 2; queue.append(index - 1) }
            if mask[index + 1] == 0 { mask[index + 1] = 2; queue.append(index + 1) }
            if mask[index - width] == 0 { mask[index - width] = 2; queue.append(index - width) }
            if mask[index + width] == 0 { mask[index + width] = 2; queue.append(index + width) }
        }
        return Self(width: width, height: height, origin: origin, pixelSize: pixelSize,
                    mask: mask, minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    func contains(_ point: MapPoint, clearance: Double = 0) -> Bool {
        func inside(_ point: MapPoint) -> Bool {
            let x = Int(floor((point.x - origin.x) / pixelSize))
            let y = Int(floor((point.y - origin.y) / pixelSize))
            return (0..<width).contains(x) && (0..<height).contains(y) && mask[y * width + x] == 2
        }
        guard inside(point) else { return false }
        guard clearance > 0 else { return true }
        for dx in [-clearance, 0, clearance] {
            for dy in [-clearance, 0, clearance] {
                if !inside(point + MapPoint(x: dx, y: dy)) { return false }
            }
        }
        return true
    }
}
