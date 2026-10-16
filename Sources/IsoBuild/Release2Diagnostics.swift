// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

#if DEBUG
import UIKit

/// Opt-in simulator checks. Uses temporary storage and never opens the user's map.
@MainActor
enum Release2Diagnostics {
    private enum Failure: Error { case check(String) }

    static func run() -> MapDocument {
        var checks: [String] = []
        func expect(_ condition: Bool, _ name: String) throws {
            guard condition else { throw Failure.check(name) }
            checks.append(name)
        }
        do {
            let fiber = stroke([.init(x: 20, y: 100), .init(x: 180, y: 100)], width: 20)
            var sketch = fiber
            sketch.id = UUID()
            sketch.color = .shadow
            let sweep = ErasureSweep(points: [.init(x: 100, y: 100)], radius: 6)
            var document = MapDocument()
            document.strokes = [sketch, fiber]
            let selective = raster(document.erasing(sweep, target: .sketch).strokes)
            try expect(pixel(selective, 100, 100) < 80, "Sketch eraser preserves overlapping fiber")
            let all = document.erasing(sweep, target: .all)
            let partial = raster(all.strokes)
            try expect(pixel(partial, 100, 100) > 245, "Eraser clears covered pixels")
            try expect(pixel(partial, 100, 109) < 80, "Eraser preserves uncovered width of thick strokes")
            try expect(pixel(partial, 60, 100) < 80, "Eraser preserves distant stroke segments")
            let repeated = raster(all.erasing(sweep, target: .all).strokes)
            try expect(pixel(repeated, 100, 100) > 245, "Overlapping erasures never restore pixels")
            var cutFiber = fiber
            cutFiber.erasures = [sweep]
            let revealed = raster([cutFiber, sketch])
            try expect((140...165).contains(pixel(revealed, 100, 100)), "Transparency reveals underlying sketch instead of painting white")

            let outline = stroke([.init(x: 20, y: 30), .init(x: 180, y: 30), .init(x: 180, y: 150),
                                  .init(x: 20, y: 150), .init(x: 20, y: 30)])
            let hole = stroke([.init(x: 90, y: 70), .init(x: 130, y: 70), .init(x: 130, y: 110),
                               .init(x: 90, y: 110), .init(x: 90, y: 70)])
            let region = try TextureFillResolver.region(at: .init(x: 40, y: 60), strokes: [outline, hole])
            try expect(region.contains(.init(x: 40, y: 120)), "Raster and world coordinates agree")
            try expect(!region.contains(.init(x: 110, y: 90)), "Bucket respects enclosed holes")
            var open = outline
            open.erasures = [.init(points: [.init(x: 70, y: 30), .init(x: 100, y: 30)], radius: 4)]
            var rejected = false
            do { _ = try TextureFillResolver.region(at: .init(x: 40, y: 60), strokes: [open]) }
            catch TextureFillError.openRegion { rejected = true }
            try expect(rejected, "Bucket detects an outline opened with the partial eraser")

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("release2-check-\(UUID().uuidString).json")
            defer { try? FileManager.default.removeItem(at: url) }
            let model = DrawingModel(storageURL: url)
            model.commit(document)
            model.commit(all)
            model.undo()
            try expect(model.document == document, "Undo restores a complete eraser gesture")
            model.redo()
            try expect(model.document == all, "Redo restores partial erasures")
            try expect(DrawingModel(storageURL: url).document == all, "Saved partial erasures survive reopening")

            let canvas = MapCanvasView(model: model)
            try expect(canvas.interactions.contains { ($0 as? UIPencilInteraction)?.delegate === canvas },
                       "Canvas registers its Pencil interaction delegate")
            model.eraserTarget = .all
            model.eraserSize = .large
            model.penWidth = 3.2
            model.texturePattern = .wood
            let pressureEnabled = model.pressureEnabled
            canvas.handlePencilDoubleTap(preferredAction: .switchPrevious)
            try expect(model.tool == .eraser, "First double-tap switches fiber to eraser")
            canvas.handlePencilDoubleTap(preferredAction: .switchPrevious)
            try expect(model.tool == .fiber, "Repeated double-tap returns to the previous tool")
            model.tool = .sketch
            model.tool = .eraser
            model.tool = .eraser
            canvas.handlePencilDoubleTap(preferredAction: .switchEraser)
            try expect(model.tool == .sketch, "Selecting the same tool preserves distinct tool history")
            model.tool = .texture
            canvas.handlePencilDoubleTap(preferredAction: .switchPrevious)
            try expect(model.tool == .sketch, "Selecting a third tool updates the alternating pair")
            model.isDrawing = true
            canvas.handlePencilDoubleTap(preferredAction: .switchPrevious)
            try expect(model.tool == .sketch, "Double-tap cannot change an active stroke's tool")
            model.isDrawing = false
            model.isFilling = true
            canvas.handlePencilDoubleTap(preferredAction: .switchPrevious)
            try expect(model.tool == .sketch, "Double-tap cannot change tools during a fill")
            model.isFilling = false
            canvas.handlePencilDoubleTap(preferredAction: .ignore)
            try expect(model.tool == .sketch, "Disabled system double-tap leaves the tool unchanged")
            canvas.handlePencilDoubleTap(preferredAction: .switchPrevious)
            try expect(model.tool == .texture, "Ignored double-taps preserve tool history")
            try expect(model.eraserTarget == .all && model.eraserSize == .large && model.penWidth == 3.2 &&
                       model.texturePattern == .wood && model.pressureEnabled == pressureEnabled,
                       "Tool switching preserves eraser, pen, pressure, and texture settings")
            try expect(model.document == all && model.undoHistory.count == 2 && model.redoHistory.isEmpty,
                       "Tool switching does not alter the document or undo history")

            let preview = try makePreview()
            try preview.validate()
            writeReport(["status": "passed", "checks": checks])
            return preview
        } catch {
            writeReport(["status": "failed", "checks": checks, "failure": String(describing: error)])
            return MapDocument()
        }
    }

    private static func writeReport(_ report: [String: Any]) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("release2-checks.json")
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func stroke(_ points: [MapPoint], width: Double = 1.6) -> InkStroke {
        .init(samples: points.map { .init(point: $0, pressure: 0.5) }, width: width, color: .ink, usesPressure: false)
    }

    private static func raster(_ strokes: [InkStroke]) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 200 * 200 * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 200, height: 200, bitsPerComponent: 8,
                                    bytesPerRow: 800, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
            StrokeRenderer.drawStack(strokes, in: context)
        }
        return bytes
    }

    private static func pixel(_ bytes: [UInt8], _ x: Int, _ y: Int) -> Int { Int(bytes[(y * 200 + x) * 4]) }

    private static func makePreview() throws -> MapDocument {
        var document = MapDocument()
        let grid = document.grid
        let origins = [MapPoint(x: -180, y: -270), .init(x: 180, y: -270),
                       .init(x: -180, y: 0), .init(x: 180, y: 0)]
        for (index, pattern) in TexturePattern.allCases.enumerated() {
            let origin = origins[index]
            let nodes = [GridNode(i: 0, j: 0), .init(i: 4, j: 0), .init(i: 4, j: 4), .init(i: 0, j: 4), .init(i: 0, j: 0)]
            let vertices = nodes.map { grid.point($0) + origin }
            var outline: [MapPoint] = []
            for (a, b) in zip(vertices, vertices.dropFirst()) {
                for step in 0..<60 {
                    let t = Double(step) / 60
                    outline.append(a + (b - a) * t + MapPoint(x: sin(t * .pi * 4) * 0.65, y: sin(t * .pi * 6) * 0.55))
                }
            }
            outline.append(vertices[0])
            var sketch = stroke(outline.map { $0 + MapPoint(x: 4, y: -3) })
            sketch.color = .shadow
            document.strokes.append(sketch)
            document.strokes.append(stroke(outline, width: 2.4))
            let region = try TextureFillResolver.region(at: origin + grid.point(.init(i: 2, j: 2)), strokes: document.strokes)
            document.strokes.append(contentsOf: try TextureGenerator.strokes(pattern: pattern, region: region, grid: grid))
        }
        var gray = stroke([.init(x: -260, y: 290), .init(x: 260, y: 290)], width: 5)
        gray.color = .shadow
        document.strokes.append(gray)
        document.strokes.append(stroke([.init(x: -260, y: 315), .init(x: 260, y: 315)], width: 5))
        document = document.erasing(.init(points: [.init(x: -80, y: 275), .init(x: -80, y: 330)], radius: 14), target: .sketch)
        document = document.erasing(.init(points: [.init(x: 80, y: 275), .init(x: 80, y: 330)], radius: 14), target: .all)
        return document
    }
}
#endif
