// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import Foundation

enum EraserTarget: String, CaseIterable, Sendable {
    case sketch
    case all
}

enum EraserSize: Double, CaseIterable, Sendable {
    case small = 6
    case medium = 14
    case large = 26
}

struct ErasureSweep: Codable, Equatable, Sendable {
    var points: [MapPoint]
    var radius: Double

    var isValid: Bool {
        !points.isEmpty && points.allSatisfy(\.isFinite) && radius.isFinite && radius > 0
    }

    func covers(_ point: MapPoint) -> Bool {
        guard let first = points.first else { return false }
        if points.count == 1 { return point.distance(to: first) <= radius }
        return zip(points, points.dropFirst()).contains { point.distance(toSegmentFrom: $0, to: $1) <= radius }
    }

    func intersects(_ stroke: InkStroke) -> Bool {
        let samples = stroke.renderedSamples()
        guard let first = samples.first, let start = points.first else { return false }
        let strokeSegments = samples.count == 1 ? [(first, first)] : Array(zip(samples, samples.dropFirst()))
        let sweepSegments = points.count == 1 ? [(start, start)] : Array(zip(points, points.dropFirst()))
        for (a, b) in strokeSegments {
            let tolerance = radius + max(stroke.width(at: a.pressure), stroke.width(at: b.pressure)) / 2
            for (c, d) in sweepSegments {
                // Broad-phase rejection keeps long strokes and distant fills inexpensive.
                if max(a.point.x, b.point.x) + tolerance < min(c.x, d.x) ||
                    min(a.point.x, b.point.x) - tolerance > max(c.x, d.x) ||
                    max(a.point.y, b.point.y) + tolerance < min(c.y, d.y) ||
                    min(a.point.y, b.point.y) - tolerance > max(c.y, d.y) { continue }
                if MapPoint.segmentDistance(a.point, b.point, c, d) <= tolerance { return true }
            }
        }
        return false
    }
}

extension MapPoint {
    var isFinite: Bool { x.isFinite && y.isFinite }

    func distance(toSegmentFrom a: MapPoint, to b: MapPoint) -> Double {
        let vector = b - a
        let squared = vector.x * vector.x + vector.y * vector.y
        guard squared > 0 else { return distance(to: a) }
        let relative = self - a
        let t = min(1, max(0, (relative.x * vector.x + relative.y * vector.y) / squared))
        return distance(to: a + vector * t)
    }

    static func cross(_ a: MapPoint, _ b: MapPoint) -> Double { a.x * b.y - a.y * b.x }

    static func segmentDistance(_ a: MapPoint, _ b: MapPoint, _ c: MapPoint, _ d: MapPoint) -> Double {
        let ab = b - a
        let cd = d - c
        let denominator = cross(ab, cd)
        if abs(denominator) > 1e-10 {
            let t = cross(c - a, cd) / denominator
            let u = cross(c - a, ab) / denominator
            if (0...1).contains(t) && (0...1).contains(u) { return 0 }
        }
        return min(a.distance(toSegmentFrom: c, to: d), b.distance(toSegmentFrom: c, to: d),
                   c.distance(toSegmentFrom: a, to: b), d.distance(toSegmentFrom: a, to: b))
    }
}

extension MapDocument {
    func erasing(_ sweep: ErasureSweep, target: EraserTarget) -> MapDocument {
        guard sweep.isValid else { return self }
        var result = self
        for index in strokes.indices {
            let stroke = strokes[index]
            guard target == .all || stroke.color == .shadow else { continue }
            guard sweep.intersects(stroke) else { continue }
            result.strokes[index].erasures.append(sweep)
            result.formatVersion = 2
        }
        result.strokes.removeAll(where: \.isFullyErased)
        return result
    }
}

extension InkStroke {
    /// Remove an empty stroke only when every ink segment is provably contained
    /// in an eraser capsule, including its width and round caps.
    var isFullyErased: Bool {
        guard !erasures.isEmpty else { return false }
        let rendered = renderedSamples()
        guard let first = rendered.first else { return true }
        let segments = rendered.count == 1 ? [(first, first)] : Array(zip(rendered, rendered.dropFirst()))
        return segments.allSatisfy { a, b in
            let inkRadius = max(width(at: a.pressure), width(at: b.pressure)) / 2
            return erasures.contains { sweep in
                let available = sweep.radius - inkRadius
                guard available >= 0, let start = sweep.points.first else { return false }
                let capsules = sweep.points.count == 1 ? [(start, start)] : Array(zip(sweep.points, sweep.points.dropFirst()))
                return capsules.contains { c, d in
                    a.point.distance(toSegmentFrom: c, to: d) <= available &&
                    b.point.distance(toSegmentFrom: c, to: d) <= available
                }
            }
        }
    }
}
