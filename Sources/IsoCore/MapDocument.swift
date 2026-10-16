// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import Foundation

struct InkSample: Codable, Equatable, Sendable {
    var point: MapPoint
    /// Normalized hardware pressure, kept even when fixed width is selected.
    var pressure: Double
}

enum InkColor: String, Codable, Sendable {
    case ink
    case shadow
}

struct InkStroke: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var samples: [InkSample]
    var width: Double
    var color: InkColor
    var usesPressure: Bool
    var startAnchor: MapPoint?
    var endAnchor: MapPoint?
    var endpointBlend: Double = 18
    var erasures: [ErasureSweep] = []
    var texture: TexturePattern? = nil

    enum CodingKeys: String, CodingKey {
        case id, samples, width, color, usesPressure, startAnchor, endAnchor, endpointBlend, erasures, texture
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        samples = try values.decode([InkSample].self, forKey: .samples)
        width = try values.decode(Double.self, forKey: .width)
        color = try values.decode(InkColor.self, forKey: .color)
        usesPressure = try values.decode(Bool.self, forKey: .usesPressure)
        startAnchor = try values.decodeIfPresent(MapPoint.self, forKey: .startAnchor)
        endAnchor = try values.decodeIfPresent(MapPoint.self, forKey: .endAnchor)
        endpointBlend = try values.decodeIfPresent(Double.self, forKey: .endpointBlend) ?? 18
        erasures = try values.decodeIfPresent([ErasureSweep].self, forKey: .erasures) ?? []
        texture = try values.decodeIfPresent(TexturePattern.self, forKey: .texture)
    }

    init(id: UUID = UUID(), samples: [InkSample], width: Double, color: InkColor,
         usesPressure: Bool, startAnchor: MapPoint? = nil, endAnchor: MapPoint? = nil,
         endpointBlend: Double = 18, erasures: [ErasureSweep] = [], texture: TexturePattern? = nil) {
        self.id = id
        self.samples = samples
        self.width = width
        self.color = color
        self.usesPressure = usesPressure
        self.startAnchor = startAnchor
        self.endAnchor = endAnchor
        self.endpointBlend = endpointBlend
        self.erasures = erasures
        self.texture = texture
    }

    /// Original samples are immutable. Corrections fade in the small end regions;
    /// the middle is unchanged, with no straightening or synthetic wobble.
    func renderedSamples() -> [InkSample] {
        guard let first = samples.first, let last = samples.last else { return [] }
        guard samples.count > 1 else {
            return [InkSample(point: startAnchor ?? first.point, pressure: first.pressure)]
        }
        var distances = [Double](repeating: 0, count: samples.count)
        for index in 1..<samples.count {
            distances[index] = distances[index - 1] + samples[index - 1].point.distance(to: samples[index].point)
        }
        let total = distances.last ?? 0
        guard total > 0 else {
            return samples.map { InkSample(point: startAnchor ?? $0.point, pressure: $0.pressure) }
        }
        let blend = max(0.001, min(endpointBlend, total * 0.35))
        let startDelta = (startAnchor ?? first.point) - first.point
        let endDelta = (endAnchor ?? last.point) - last.point
        return samples.enumerated().map { index, sample in
            let startWeight = pow(max(0, 1 - distances[index] / blend), 2)
            let endWeight = pow(max(0, 1 - (total - distances[index]) / blend), 2)
            return InkSample(point: sample.point + startDelta * startWeight + endDelta * endWeight,
                             pressure: sample.pressure)
        }
    }

    func width(at pressure: Double) -> Double {
        usesPressure ? width * (0.55 + min(1, max(0, pressure)) * 1.4) : width
    }

    func intersects(_ point: MapPoint, tolerance: Double) -> Bool {
        let rendered = renderedSamples()
        guard let first = rendered.first else { return false }
        if rendered.count == 1 {
            return first.point.distance(to: point) <= tolerance + width(at: first.pressure) / 2
        }
        for index in 1..<rendered.count {
            let a = rendered[index - 1]
            let b = rendered[index]
            let vector = b.point - a.point
            let lengthSquared = vector.x * vector.x + vector.y * vector.y
            let relative = point - a.point
            let t = lengthSquared == 0 ? 0 : min(1, max(0, (relative.x * vector.x + relative.y * vector.y) / lengthSquared))
            let nearest = a.point + vector * t
            if nearest.distance(to: point) <= tolerance + max(width(at: a.pressure), width(at: b.pressure)) / 2 {
                return true
            }
        }
        return false
    }
}

struct MapDocument: Codable, Equatable, Sendable {
    var formatVersion = 2
    var grid = IsoGrid()
    var strokes: [InkStroke] = []

    func validate() throws {
        guard (1...2).contains(formatVersion), grid.spacing.isFinite, (20...100).contains(grid.spacing),
              strokes.allSatisfy({ stroke in
                  !stroke.samples.isEmpty && stroke.width.isFinite && (0.1...20).contains(stroke.width) &&
                  stroke.endpointBlend.isFinite && stroke.endpointBlend > 0 &&
                  stroke.erasures.allSatisfy { $0.isValid } &&
                  [stroke.startAnchor, stroke.endAnchor].compactMap { $0 }.allSatisfy { $0.x.isFinite && $0.y.isFinite } &&
                  stroke.samples.allSatisfy { $0.point.x.isFinite && $0.point.y.isFinite && $0.pressure.isFinite }
              }) else { throw DocumentError.invalidData }
    }

    enum DocumentError: Error { case invalidData }
}
