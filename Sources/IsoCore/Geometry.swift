// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import Foundation

struct MapPoint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double

    static let zero = MapPoint(x: 0, y: 0)
    static func + (a: Self, b: Self) -> Self { .init(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: Self, b: Self) -> Self { .init(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: Self, b: Double) -> Self { .init(x: a.x * b, y: a.y * b) }
    func distance(to other: Self) -> Double { hypot(x - other.x, y - other.y) }
}

enum GridAngle: Int, Codable, CaseIterable, Sendable {
    case thirty = 30
    case fortyFive = 45
}

struct GridNode: Codable, Hashable, Sendable {
    var i: Int
    var j: Int

    func isAligned(with other: Self) -> Bool {
        let di = other.i - i
        let dj = other.j - j
        return self != other && (di == 0 || dj == 0 || di == dj)
    }
}

struct IsoGrid: Codable, Equatable, Sendable {
    var angle: GridAngle = .thirty
    var spacing: Double = 40

    var dx: Double { spacing * cos(Double(angle.rawValue) * .pi / 180) }
    var dy: Double { spacing * sin(Double(angle.rawValue) * .pi / 180) }

    func point(_ node: GridNode) -> MapPoint {
        .init(x: Double(node.i - node.j) * dx, y: Double(node.i + node.j) * dy)
    }

    func coordinates(_ point: MapPoint) -> (i: Double, j: Double) {
        ((point.y / dy + point.x / dx) / 2, (point.y / dy - point.x / dx) / 2)
    }

    /// Only eligible nodes inside a screen-space tolerance attract the endpoint.
    func nearbyNode(to location: MapPoint, tolerance: Double, from start: GridNode? = nil) -> GridNode? {
        let c = coordinates(location)
        let centerI = Int(c.i.rounded())
        let centerJ = Int(c.j.rounded())
        let radius = max(2, Int(ceil(tolerance / min(dx, dy))) + 1)
        var result: GridNode?
        var best = tolerance
        for i in (centerI - radius)...(centerI + radius) {
            for j in (centerJ - radius)...(centerJ + radius) {
                let node = GridNode(i: i, j: j)
                if let start, !node.isAligned(with: start) { continue }
                let distance = point(node).distance(to: location)
                if distance <= best {
                    best = distance
                    result = node
                }
            }
        }
        return result
    }
}
