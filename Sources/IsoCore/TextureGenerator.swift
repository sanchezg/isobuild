// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import Foundation

enum TexturePattern: String, Codable, CaseIterable, Sendable {
    case stone, brick, wood, tiles

    var title: String {
        switch self {
        case .stone: "Stone"
        case .brick: "Brick"
        case .wood: "Wood"
        case .tiles: "Tiles"
        }
    }
}

enum TextureGenerator {
    static func removingExistingTexture(from document: MapDocument, in region: TextureRegion) -> MapDocument {
        var result = document
        result.strokes = document.strokes.flatMap { stroke -> [InkStroke] in
            guard stroke.texture != nil else { return [stroke] }
            let samples = stroke.renderedSamples()
            guard samples.contains(where: { region.contains($0.point) }) else { return [stroke] }
            var fragments: [InkStroke] = []
            var outside: [InkSample] = []
            func flush() {
                if outside.count > 1 {
                    var fragment = stroke
                    fragment.id = UUID()
                    fragment.samples = outside
                    fragment.startAnchor = nil
                    fragment.endAnchor = nil
                    fragments.append(fragment)
                }
                outside.removeAll(keepingCapacity: true)
            }
            for sample in samples {
                if region.contains(sample.point) { flush() } else { outside.append(sample) }
            }
            flush()
            return fragments
        }
        return result
    }

    /// Generate vector marks once, then clip them to the detected region.
    /// Stable, low-frequency irregularities give each joint a drawn appearance.
    static func strokes(pattern: TexturePattern, region: TextureRegion, grid: IsoGrid) throws -> [InkStroke] {
        let lo = region.lower, hi = region.upper
        let corners = [lo, hi, MapPoint(x: lo.x, y: hi.y), MapPoint(x: hi.x, y: lo.y)]
        let coordinates = corners.map { grid.coordinates($0) }
        let uMin = Int(floor(coordinates.map(\.i).min()!)) - 1
        let uMax = Int(ceil(coordinates.map(\.i).max()!)) + 1
        let vMin = Int(floor(coordinates.map(\.j).min()!)) - 1
        let vMax = Int(ceil(coordinates.map(\.j).max()!)) + 1
        guard (uMax - uMin) * (vMax - vMin) <= 12_000 else { throw TextureFillError.tooLarge }
        var result: [InkStroke] = []
        var generatedSamples = 0

        func world(_ u: Double, _ v: Double) -> MapPoint {
            .init(x: (u - v) * grid.dx, y: (u + v) * grid.dy)
        }
        func noise(_ key: Double) -> Double { sin(key * 12.9898 + 78.233) }

        func addLine(_ a: MapPoint, _ b: MapPoint, seed: Double, width: Double = 0.65, amplitude: Double = 0.8) throws {
            let count = max(2, Int(ceil(a.distance(to: b) / min(1.2, region.pixelSize))))
            generatedSamples += count
            guard generatedSamples <= 600_000 else { throw TextureFillError.tooLarge }
            var fragment: [InkSample] = []
            func flush() {
                if fragment.count > 1 {
                    result.append(InkStroke(samples: fragment, width: width, color: .ink,
                                            usesPressure: false, texture: pattern))
                }
                fragment.removeAll(keepingCapacity: true)
            }
            for index in 0...count {
                let t = Double(index) / Double(count)
                let base = a + (b - a) * t
                let wave = sin(t * .pi * 2 + seed) * amplitude
                let point = base + MapPoint(x: wave * 0.55, y: sin(t * .pi * 3 + seed * 1.7) * amplitude)
                if region.contains(point, clearance: width / 2 + region.pixelSize * 0.5) {
                    fragment.append(InkSample(point: point, pressure: 0.5))
                } else { flush() }
            }
            flush()
        }

        for v in vMin...vMax {
            for u in uMin...uMax {
                let x = Double(u), y = Double(v)
                let seed = x * 71 + y * 113
                switch pattern {
                case .tiles:
                    try addLine(world(x + 0.04, y + 0.04), world(x + 0.96, y + 0.04), seed: seed)
                    try addLine(world(x + 0.04, y + 0.04), world(x + 0.04, y + 0.96), seed: seed + 3)
                    if noise(seed) > 0.7 {
                        try addLine(world(x + 0.72, y + 0.68), world(x + 0.84, y + 0.78), seed: seed, width: 0.45)
                    }
                case .brick:
                    let stagger = v.isMultiple(of: 2) ? 0.0 : 0.5
                    try addLine(world(x + stagger, y), world(x + 1 + stagger, y), seed: seed)
                    try addLine(world(x + stagger, y), world(x + stagger, y + 1), seed: seed + 2)
                case .stone:
                    // Shared perturbed vertices make irregular, connected flagstones.
                    func vertex(_ u: Double, _ v: Double) -> MapPoint {
                        world(u + noise(u * 17 + v * 31) * 0.18, v + noise(u * 23 - v * 19) * 0.18)
                    }
                    try addLine(vertex(x, y), vertex(x + 1, y), seed: seed, amplitude: 0.6)
                    try addLine(vertex(x, y), vertex(x, y + 1), seed: seed + 4, amplitude: 0.6)
                    if noise(seed + 2) > 0.25 {
                        let center = world(x + 0.48, y + 0.5)
                        try addLine(center, center + MapPoint(x: 4, y: -3), seed: seed + 6, width: 0.45)
                    }
                case .wood:
                    try addLine(world(x, y), world(x + 1, y), seed: seed)
                    if u.isMultiple(of: 3) {
                        try addLine(world(x, y), world(x, y + 1), seed: seed + 2)
                    }
                    for grain in [0.28, 0.65] {
                        try addLine(world(x + 0.12, y + grain), world(x + 0.87, y + grain + 0.04),
                                    seed: seed + grain * 13, width: 0.4, amplitude: 1.1)
                    }
                }
            }
        }
        return result
    }
}
