// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import XCTest
@testable import IsoCore

final class Release2Tests: XCTestCase {
    private func line(_ color: InkColor = .ink) -> InkStroke {
        InkStroke(samples: [InkSample(point: .init(x: 10, y: 50), pressure: 0.2),
                            InkSample(point: .init(x: 100, y: 50), pressure: 0.8)],
                  width: 3.2, color: color, usesPressure: true)
    }

    func testSketchErasurePreservesFiberAndRawPressureSamples() throws {
        let sketch = line(.shadow), fiber = line()
        var document = MapDocument()
        document.strokes = [sketch, fiber]
        let sweep = ErasureSweep(points: [.init(x: 55, y: 20), .init(x: 55, y: 80)], radius: 6)
        let result = document.erasing(sweep, target: .sketch)
        XCTAssertEqual(result.strokes[0].erasures, [sweep])
        XCTAssertEqual(result.strokes[0].samples, sketch.samples)
        XCTAssertEqual(result.strokes[1], fiber)
        XCTAssertTrue(document.strokes[0].erasures.isEmpty)
        XCTAssertTrue(sweep.covers(.init(x: 55, y: 50)))
        XCTAssertFalse(sweep.covers(.init(x: 20, y: 50)))
        XCTAssertNoThrow(try result.validate())
    }

    func testAllErasureIncludesTexturesAndDetectsFastCrossings() {
        var textured = line()
        textured.texture = .wood
        var document = MapDocument()
        document.strokes = [line(.shadow), line(), textured]
        let sweep = ErasureSweep(points: [.init(x: 50, y: -100), .init(x: 50, y: 200)], radius: 2)
        let result = document.erasing(sweep, target: .all)
        XCTAssertTrue(result.strokes.allSatisfy { $0.erasures == [sweep] })
        XCTAssertEqual(result.strokes.map(\.samples), document.strokes.map(\.samples))
        let distant = ErasureSweep(points: [.init(x: 150, y: 100)], radius: 6)
        XCTAssertEqual(document.erasing(distant, target: .all), document)
    }

    func testCompleteErasureRemovesEmptyStrokesWithoutRemovingUncoveredWidth() {
        var document = MapDocument()
        var stroke = line()
        stroke.usesPressure = false
        stroke.width = 20
        document.strokes = [stroke]
        let thin = ErasureSweep(points: [.init(x: 0, y: 50), .init(x: 110, y: 50)], radius: 6)
        XCTAssertEqual(document.erasing(thin, target: .all).strokes.count, 1)
        let wide = ErasureSweep(points: thin.points, radius: 12)
        XCTAssertTrue(document.erasing(wide, target: .all).strokes.isEmpty)
        XCTAssertEqual(document.strokes, [stroke])
    }

    func testReleaseOneDocumentDecodesWithoutNewFields() throws {
        let stroke = line(.shadow)
        let encoded = try JSONEncoder().encode(stroke)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "erasures")
        object.removeValue(forKey: "texture")
        let legacy: [String: Any] = ["formatVersion": 1,
                                   "grid": ["angle": 30, "spacing": 40], "strokes": [object]]
        let loaded = try JSONDecoder().decode(MapDocument.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(loaded.strokes.first?.samples, stroke.samples)
        XCTAssertEqual(loaded.strokes.first?.color, .shadow)
        XCTAssertEqual(loaded.strokes.first?.erasures, [])
        XCTAssertNil(loaded.strokes.first?.texture)
        XCTAssertNoThrow(try loaded.validate())
    }

    func testErasureMasksAndTextureMetadataSurviveReopening() throws {
        var document = MapDocument()
        var stroke = line()
        stroke.texture = .stone
        document.strokes = [stroke]
        document = document.erasing(.init(points: [.init(x: 50, y: 50)], radius: 6), target: .all)
        let reopened = try JSONDecoder().decode(MapDocument.self, from: JSONEncoder().encode(document))
        XCTAssertEqual(reopened, document)
        XCTAssertNoThrow(try reopened.validate())
    }

    private func region(withHole: Bool = true) throws -> TextureRegion {
        let size = 160
        var barriers = [UInt8](repeating: 0, count: size * size)
        for i in 10...150 {
            barriers[10 * size + i] = 1; barriers[150 * size + i] = 1
            barriers[i * size + 10] = 1; barriers[i * size + 150] = 1
        }
        if withHole {
            for i in 60...100 {
                barriers[60 * size + i] = 1; barriers[100 * size + i] = 1
                barriers[i * size + 60] = 1; barriers[i * size + 100] = 1
            }
        }
        return try TextureRegion.find(width: size, height: size, barriers: barriers, seedX: 30, seedY: 30,
                                      origin: .zero, pixelSize: 1)
    }

    func testBucketRejectsOpenAreasAndProtectsEnclosedHoles() throws {
        let region = try region()
        XCTAssertTrue(region.contains(.init(x: 30, y: 30)))
        XCTAssertFalse(region.contains(.init(x: 80, y: 80)))
        XCTAssertFalse(region.contains(.init(x: 4, y: 4)))
        XCTAssertThrowsError(try TextureRegion.find(width: 20, height: 20,
                                                   barriers: [UInt8](repeating: 0, count: 400),
                                                   seedX: 10, seedY: 10, origin: .zero, pixelSize: 1))
    }

    func testEveryTextureStaysInsideRegionAndPreservesHoles() throws {
        let region = try region()
        for pattern in TexturePattern.allCases {
            let strokes = try TextureGenerator.strokes(pattern: pattern, region: region, grid: IsoGrid())
            XCTAssertFalse(strokes.isEmpty, pattern.rawValue)
            XCTAssertTrue(strokes.allSatisfy { $0.color == .ink && $0.texture == pattern })
            for sample in strokes.flatMap(\.samples) {
                XCTAssertTrue(region.contains(sample.point), pattern.rawValue)
            }
            var document = MapDocument()
            document.strokes = strokes
            XCTAssertNoThrow(try document.validate())
            XCTAssertTrue(TextureGenerator.removingExistingTexture(from: document, in: region).strokes.isEmpty)
        }
    }

    func testRetexturingPreservesOriginalDrawingAndOutOfRegionMarks() throws {
        let region = try region(withHole: false)
        var outside = line()
        outside.samples = outside.samples.map { .init(point: $0.point + MapPoint(x: 300, y: 0), pressure: $0.pressure) }
        outside.texture = .brick
        var document = MapDocument()
        document.strokes = [line(.shadow), line(), outside]
        XCTAssertEqual(TextureGenerator.removingExistingTexture(from: document, in: region), document)
    }
}
