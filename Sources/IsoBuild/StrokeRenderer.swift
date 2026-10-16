// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import UIKit

extension MapPoint {
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
    init(_ point: CGPoint) { self.init(x: point.x, y: point.y) }
}

@MainActor
enum StrokeRenderer {
    static func drawStack(_ strokes: [InkStroke], in context: CGContext) {
        // Draft marks stay below finished ink even when the sketch is edited later.
        for color in [InkColor.shadow, .ink] {
            for stroke in strokes where stroke.color == color { draw(stroke, in: context) }
        }
    }

    static func draw(_ stroke: InkStroke, in context: CGContext) {
        let samples = stroke.renderedSamples()
        guard let first = samples.first else { return }
        context.saveGState()
        if !stroke.erasures.isEmpty { context.beginTransparencyLayer(auxiliaryInfo: nil) }
        defer {
            if !stroke.erasures.isEmpty {
                context.setBlendMode(.clear)
                for sweep in stroke.erasures {
                    guard let first = sweep.points.first else { continue }
                    context.setLineWidth(sweep.radius * 2)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)
                    context.setFillColor(UIColor.black.cgColor)
                    context.setStrokeColor(UIColor.black.cgColor)
                    if sweep.points.count == 1 {
                        context.fillEllipse(in: CGRect(x: first.x - sweep.radius, y: first.y - sweep.radius,
                                                       width: sweep.radius * 2, height: sweep.radius * 2))
                    } else {
                        context.beginPath()
                        context.move(to: first.cgPoint)
                        for point in sweep.points.dropFirst() { context.addLine(to: point.cgPoint) }
                        context.strokePath()
                    }
                }
                context.setBlendMode(.normal)
                context.endTransparencyLayer()
            }
            context.restoreGState()
        }
        let color: UIColor = stroke.color == .ink
            ? UIColor(white: 0.12, alpha: 1)
            : UIColor(white: 0.60, alpha: 1)
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        if samples.count == 1 || samples.allSatisfy({ $0.point == first.point }) {
            let width = stroke.width(at: first.pressure)
            context.fillEllipse(in: CGRect(x: first.point.x - width / 2, y: first.point.y - width / 2,
                                           width: width, height: width))
        } else if !stroke.usesPressure {
            context.setLineWidth(stroke.width)
            context.beginPath()
            context.move(to: first.point.cgPoint)
            for sample in samples.dropFirst() { context.addLine(to: sample.point.cgPoint) }
            context.strokePath()
        } else {
            for index in 1..<samples.count {
                let a = samples[index - 1]
                let b = samples[index]
                context.setLineWidth(stroke.width(at: (a.pressure + b.pressure) / 2))
                context.beginPath()
                context.move(to: a.point.cgPoint)
                context.addLine(to: b.point.cgPoint)
                context.strokePath()
            }
        }
    }

    static func bounds(of strokes: [InkStroke]) -> CGRect? {
        var rect: CGRect = .null
        for stroke in strokes {
            for sample in stroke.renderedSamples() {
                let radius = stroke.width(at: sample.pressure) / 2
                rect = rect.union(CGRect(x: sample.point.x - radius, y: sample.point.y - radius,
                                         width: max(0.01, radius * 2), height: max(0.01, radius * 2)))
            }
        }
        return rect.isNull ? nil : rect
    }
}
