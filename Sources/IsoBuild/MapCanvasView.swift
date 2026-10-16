// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import SwiftUI
import UIKit

struct CanvasRepresentable: UIViewRepresentable {
    @ObservedObject var model: DrawingModel

    func makeUIView(context: Context) -> MapCanvasView {
        let view = MapCanvasView(model: model)
        model.canvas = view
        return view
    }

    func updateUIView(_ uiView: MapCanvasView, context: Context) { uiView.setNeedsDisplay() }
}

@MainActor
final class MapCanvasView: UIView, UIGestureRecognizerDelegate, UIPencilInteractionDelegate {
    private let model: DrawingModel
    private var zoom: Double = 1
    private var offset = MapPoint.zero
    private var hasPositioned = false
    private var activeTouch: UITouch?
    private var lastTimestamp: TimeInterval = -.infinity
    private var currentStroke: InkStroke?
    private var startNode: GridNode?
    private var endCandidate: GridNode?
    private var erasedIDs: Set<UUID> = []
    private var eraserPath: [MapPoint] = []
    private var previousEraserPoint: MapPoint?
    private var eraserPoint: MapPoint?
    private var textureTapOrigin: CGPoint?
    private var panOrigin = MapPoint.zero
    private var pinchWorld = MapPoint.zero
    private var pinchZoom: Double = 1
    private var pinchActive = false
    private var panNeedsRebase = false

    init(model: DrawingModel) {
        self.model = model
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        backgroundColor = UIColor(red: 0.985, green: 0.980, blue: 0.961, alpha: 1)
        isOpaque = true
        contentMode = .redraw
        accessibilityLabel = AppStrings.text("Isometric canvas")
        accessibilityHint = AppStrings.text("Draw with Apple Pencil. Use two fingers to pan and zoom.")
        addInteraction(UIPencilInteraction(delegate: self))

        let pan = UIPanGestureRecognizer(target: self, action: #selector(panCanvas(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        pan.delegate = self
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinchCanvas(_:)))
        pinch.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        pinch.delegate = self
        addGestureRecognizer(pinch)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        handlePencilDoubleTap(preferredAction: UIPencilInteraction.preferredTapAction)
    }

    func handlePencilDoubleTap(preferredAction: UIPencilPreferredAction) {
        guard preferredAction != .ignore else { return }
        model.switchToPreviousTool()
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasPositioned && bounds.width > 0 {
            hasPositioned = true
            fitDrawing()
        }
    }

    private func worldPoint(_ location: CGPoint) -> MapPoint { (MapPoint(location) - offset) * (1 / zoom) }
    private func screenPoint(_ location: MapPoint) -> CGPoint { (location * zoom + offset).cgPoint }

    func fitDrawing() {
        guard activeTouch == nil else { return }
        if let rect = StrokeRenderer.bounds(of: model.document.strokes) {
            let inset = bounds.insetBy(dx: 80, dy: 80)
            zoom = min(2, max(0.25, min(inset.width / max(100, rect.width), inset.height / max(100, rect.height))))
            offset = MapPoint(x: bounds.midX - rect.midX * zoom, y: bounds.midY - rect.midY * zoom)
        } else {
            zoom = 1
            offset = MapPoint(x: bounds.midX, y: bounds.midY)
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        if model.showsGrid { drawGrid(in: context) }
        context.saveGState()
        context.translateBy(x: offset.x, y: offset.y)
        context.scaleBy(x: zoom, y: zoom)
        var strokes = strokesWithCurrentErasure()
        if let currentStroke { strokes.append(currentStroke) }
        StrokeRenderer.drawStack(strokes, in: context)
        context.restoreGState()
        drawAnchor(startNode, in: context, filled: true)
        drawAnchor(endCandidate, in: context, filled: false)
        if let eraserPoint {
            context.setStrokeColor(UIColor.systemGray.cgColor)
            context.setLineWidth(1)
            let center = screenPoint(eraserPoint)
            let radius = model.eraserSize.rawValue * zoom
            context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
    }

    private func drawGrid(in context: CGContext) {
        let grid = model.document.grid
        let corners = [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
                       CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY)]
        let coordinates = corners.map { grid.coordinates(worldPoint($0)) }
        let iMin = Int(floor(coordinates.map(\.i).min()!)) - 1
        let iMax = Int(ceil(coordinates.map(\.i).max()!)) + 1
        let jMin = Int(floor(coordinates.map(\.j).min()!)) - 1
        let jMax = Int(ceil(coordinates.map(\.j).max()!)) + 1
        let normal = UIColor(red: 0.66, green: 0.69, blue: 0.66, alpha: 0.6).cgColor
        let highlighted = UIColor(red: 0.12, green: 0.43, blue: 0.38, alpha: 0.75).cgColor
        for i in iMin...iMax {
            for j in jMin...jMax {
                let node = GridNode(i: i, j: j)
                let position = screenPoint(grid.point(node))
                guard bounds.insetBy(dx: -3, dy: -3).contains(position) else { continue }
                let eligible = startNode.map { $0.isAligned(with: node) } ?? false
                let radius: Double = eligible ? 2 : 1.2
                context.setFillColor(eligible ? highlighted : normal)
                context.fillEllipse(in: CGRect(x: position.x - radius, y: position.y - radius,
                                               width: radius * 2, height: radius * 2))
            }
        }
    }

    private func drawAnchor(_ node: GridNode?, in context: CGContext, filled: Bool) {
        guard let node else { return }
        let point = screenPoint(model.document.grid.point(node))
        let rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
        context.setStrokeColor(UIColor.systemTeal.cgColor)
        context.setFillColor(UIColor.systemTeal.cgColor)
        context.setLineWidth(1.5)
        if filled { context.fillEllipse(in: rect) } else { context.strokeEllipse(in: rect) }
    }

    private func accepts(_ touch: UITouch) -> Bool {
        #if targetEnvironment(simulator)
        return touch.type == .pencil || touch.type == .direct
        #else
        return touch.type == .pencil
        #endif
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, !model.isFilling, let touch = touches.first(where: accepts) else { return }
        activeTouch = touch
        model.isDrawing = true
        lastTimestamp = -.infinity
        let point = worldPoint(touch.location(in: self))
        if model.tool == .eraser {
            erase(at: point)
        } else if model.tool == .texture {
            textureTapOrigin = touch.location(in: self)
        } else {
            let grid = model.document.grid
            startNode = model.guided ? grid.nearbyNode(to: point, tolerance: 14 / zoom) : nil
            currentStroke = InkStroke(samples: [], width: model.penWidth,
                                      color: model.tool == .sketch ? .shadow : .ink,
                                      usesPressure: model.pressureEnabled,
                                      startAnchor: startNode.map { grid.point($0) }, endAnchor: nil,
                                      endpointBlend: 18 / zoom)
            append(touch, event: event)
        }
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        if model.tool == .eraser {
            for sample in event?.coalescedTouches(for: touch) ?? [touch] { erase(at: worldPoint(sample.location(in: self))) }
        } else if model.tool != .texture {
            append(touch, event: event)
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        if model.tool == .eraser {
            erase(at: worldPoint(touch.location(in: self)))
            if !erasedIDs.isEmpty {
                var next = model.document
                next.strokes = strokesWithCurrentErasure().filter { !$0.isFullyErased }
                next.formatVersion = 2
                model.commit(next)
            }
        } else if model.tool == .texture {
            let location = touch.location(in: self)
            let shouldFill = textureTapOrigin.map { hypot($0.x - location.x, $0.y - location.y) <= 12 } ?? false
            let point = worldPoint(location)
            resetInput()
            if shouldFill { model.fill(at: point) }
            return
        } else {
            append(touch, event: event)
            if var stroke = currentStroke, !stroke.samples.isEmpty {
                if let endCandidate, stroke.samples.count > 1 {
                    stroke.endAnchor = model.document.grid.point(endCandidate)
                }
                model.add(stroke)
            }
        }
        resetInput()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        // Cancelled strokes and eraser gestures never enter undo history or storage.
        resetInput()
    }

    private func append(_ touch: UITouch, event: UIEvent?) {
        for sample in event?.coalescedTouches(for: touch) ?? [touch] {
            guard sample.timestamp > lastTimestamp else { continue }
            lastTimestamp = sample.timestamp
            let pressure = sample.maximumPossibleForce > 0 ? sample.force / sample.maximumPossibleForce : 0.5
            currentStroke?.samples.append(InkSample(point: worldPoint(sample.location(in: self)), pressure: pressure))
        }
        if let startNode, let point = currentStroke?.samples.last?.point {
            endCandidate = model.document.grid.nearbyNode(to: point, tolerance: 14 / zoom, from: startNode)
        }
    }

    private func erase(at point: MapPoint) {
        let previous = previousEraserPoint ?? point
        let segment = ErasureSweep(points: [previous, point], radius: model.eraserSize.rawValue)
        for stroke in model.document.strokes where !erasedIDs.contains(stroke.id) {
            guard model.eraserTarget == .all || stroke.color == .shadow else { continue }
            if segment.intersects(stroke) { erasedIDs.insert(stroke.id) }
        }
        if eraserPath.last != point { eraserPath.append(point) }
        previousEraserPoint = point
        eraserPoint = point
    }

    private func strokesWithCurrentErasure() -> [InkStroke] {
        guard !eraserPath.isEmpty else { return model.document.strokes }
        let sweep = ErasureSweep(points: eraserPath, radius: model.eraserSize.rawValue)
        return model.document.strokes.map { stroke in
            guard erasedIDs.contains(stroke.id) else { return stroke }
            var result = stroke
            result.erasures.append(sweep)
            return result
        }
    }

    private func resetInput() {
        activeTouch = nil
        currentStroke = nil
        startNode = nil
        endCandidate = nil
        erasedIDs.removeAll()
        eraserPath.removeAll()
        previousEraserPoint = nil
        eraserPoint = nil
        textureTapOrigin = nil
        model.isDrawing = false
        setNeedsDisplay()
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { activeTouch == nil && !model.isFilling }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    @objc private func panCanvas(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            panOrigin = offset
            panNeedsRebase = false
        case .changed, .ended:
            let translation = gesture.translation(in: self)
            if pinchActive {
                panNeedsRebase = true
                return
            }
            if panNeedsRebase {
                panOrigin = offset - MapPoint(translation)
                panNeedsRebase = false
            }
            offset = panOrigin + MapPoint(translation)
            setNeedsDisplay()
        default: break
        }
    }

    @objc private func pinchCanvas(_ gesture: UIPinchGestureRecognizer) {
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began:
            pinchActive = true
            pinchWorld = worldPoint(location)
            pinchZoom = zoom
        case .changed, .ended:
            zoom = min(5, max(0.25, pinchZoom * gesture.scale))
            offset = MapPoint(location) - pinchWorld * zoom
            panNeedsRebase = true
            if gesture.state == .ended { pinchActive = false }
            setNeedsDisplay()
        case .cancelled, .failed: pinchActive = false
        default: break
        }
    }

    func exportImage() -> UIImage? {
        guard let drawingBounds = StrokeRenderer.bounds(of: model.document.strokes) else { return nil }
        let rect = drawingBounds.insetBy(dx: -24, dy: -24)
        let scale = min(2, 4096 / max(rect.width, rect.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: max(1, ceil(rect.width * scale)), height: max(1, ceil(rect.height * scale)))
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let context = renderer.cgContext
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -rect.minX, y: -rect.minY)
            StrokeRenderer.drawStack(model.document.strokes, in: context)
        }
    }
}
