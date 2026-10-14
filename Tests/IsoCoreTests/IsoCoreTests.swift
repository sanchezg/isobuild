// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import XCTest
@testable import IsoCore

final class IsoCoreTests: XCTestCase {
    func testBothGridsSnapOnlyAlongTheirThreeAxes() {
        for angle in GridAngle.allCases {
            let grid = IsoGrid(angle: angle)
            let origin = GridNode(i: -2, j: 3)
            for destination in [GridNode(i: -2, j: 7), GridNode(i: 2, j: 3), GridNode(i: 2, j: 7)] {
                let near = grid.point(destination) + MapPoint(x: 3, y: -2)
                XCTAssertEqual(grid.nearbyNode(to: near, tolerance: 8, from: origin), destination)
            }
            let offAxis = GridNode(i: 1, j: 4)
            XCTAssertNil(grid.nearbyNode(to: grid.point(offAxis), tolerance: 2, from: origin))
            XCTAssertNil(grid.nearbyNode(to: grid.point(origin), tolerance: 2, from: origin))
        }
    }

    func testNearestNodesRoundTripInNegativeWorldCoordinates() {
        for angle in GridAngle.allCases {
            let grid = IsoGrid(angle: angle)
            for i in -12...12 {
                for j in -12...12 {
                    let node = GridNode(i: i, j: j)
                    XCTAssertEqual(grid.nearbyNode(to: grid.point(node), tolerance: 0.01), node)
                }
            }
        }
    }

    func testSnapToleranceScalesWithZoom() {
        let grid = IsoGrid()
        let node = GridNode(i: 0, j: 0)
        let near = MapPoint(x: 8, y: 0)
        XCTAssertEqual(grid.nearbyNode(to: near, tolerance: 14), node)
        XCTAssertNil(grid.nearbyNode(to: near, tolerance: 14 / 2))
    }

    func testEndpointCorrectionPreservesOriginalAndWavyMiddle() {
        let raw = (0...100).map { index in
            InkSample(point: MapPoint(x: Double(index), y: sin(Double(index) / 4) * 2), pressure: Double(index) / 100)
        }
        let stroke = InkStroke(samples: raw, width: 1.6, color: .ink, usesPressure: false,
                               startAnchor: MapPoint(x: -2, y: 1), endAnchor: MapPoint(x: 103, y: -1))
        let rendered = stroke.renderedSamples()
        XCTAssertEqual(rendered.first?.point, stroke.startAnchor)
        XCTAssertEqual(rendered.last?.point, stroke.endAnchor)
        XCTAssertEqual(Array(rendered[25...75]), Array(raw[25...75]))
        XCTAssertEqual(stroke.samples, raw)
        XCTAssertEqual(rendered.map(\.pressure), raw.map(\.pressure))
    }

    func testFreeAndUnsnappedEndRemainUntouched() {
        let samples = [InkSample(point: .zero, pressure: 0.2), InkSample(point: .init(x: 3, y: 7), pressure: 0.8)]
        var stroke = InkStroke(samples: samples, width: 1, color: .ink, usesPressure: false)
        XCTAssertEqual(stroke.renderedSamples(), samples)
        stroke.startAnchor = .init(x: 1, y: 1)
        XCTAssertEqual(stroke.renderedSamples().last, samples.last)
        XCTAssertEqual(stroke.width(at: 0), stroke.width(at: 1))
        stroke.usesPressure = true
        XCTAssertLessThan(stroke.width(at: 0), stroke.width(at: 1))
    }

    func testEraserFindsSegmentInteriorsRatherThanOnlySamplePoints() {
        let stroke = InkStroke(samples: [InkSample(point: .zero, pressure: 0.5),
                                        InkSample(point: .init(x: 100, y: 100), pressure: 0.5)],
                               width: 2, color: .ink, usesPressure: false)
        XCTAssertTrue(stroke.intersects(.init(x: 50, y: 51), tolerance: 3))
        XCTAssertFalse(stroke.intersects(.init(x: 10, y: 80), tolerance: 3))
    }

    func testStationaryPencilContactSnapsWithoutLosingPressure() {
        let samples = [InkSample(point: .init(x: 2, y: 3), pressure: 0.4),
                       InkSample(point: .init(x: 2, y: 3), pressure: 0.6)]
        let stroke = InkStroke(samples: samples, width: 1.6, color: .ink, usesPressure: true, startAnchor: .zero)
        XCTAssertEqual(stroke.renderedSamples().map(\.point), [.zero, .zero])
        XCTAssertEqual(stroke.renderedSamples().map(\.pressure), [0.4, 0.6])
        XCTAssertEqual(stroke.samples, samples)
    }

    func testDocumentRoundTripPreservesEditableRawStrokeAndAnchors() throws {
        var document = MapDocument()
        document.grid.angle = .fortyFive
        document.strokes = [InkStroke(samples: [InkSample(point: .init(x: -4, y: 8), pressure: 0.7)],
                                     width: 1.6, color: .shadow, usesPressure: true, startAnchor: .zero)]
        let decoded = try JSONDecoder().decode(MapDocument.self, from: JSONEncoder().encode(document))
        XCTAssertEqual(decoded, document)
        XCTAssertNoThrow(try decoded.validate())
        var invalid = document
        invalid.formatVersion = 2
        XCTAssertThrowsError(try invalid.validate())
    }
}
