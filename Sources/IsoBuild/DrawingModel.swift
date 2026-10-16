// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import SwiftUI
import UIKit

enum DrawingTool { case fiber, sketch, eraser, texture }

@MainActor
final class DrawingModel: ObservableObject {
    @Published private(set) var document = MapDocument()
    @Published var guided = true
    @Published var tool: DrawingTool = .fiber {
        didSet {
            if tool != oldValue { previousTool = oldValue }
        }
    }
    @Published var eraserTarget: EraserTarget = .sketch
    @Published var eraserSize: EraserSize = .medium
    @Published var texturePattern: TexturePattern = .stone
    @Published var isFilling = false
    @Published var penWidth: Double = 1.6
    @Published var pressureEnabled = UserDefaults.standard.bool(forKey: "pressureEnabled") {
        didSet { UserDefaults.standard.set(pressureEnabled, forKey: "pressureEnabled") }
    }
    @Published var showsGrid = true
    @Published var isDrawing = false
    @Published var errorMessage: String?
    @Published private(set) var saveFailed = false
    @Published private(set) var undoHistory: [MapDocument] = []
    @Published private(set) var redoHistory: [MapDocument] = []
    weak var canvas: MapCanvasView?

    private let storageURL: URL
    private var recoveryRequired = false
    private var previousTool: DrawingTool = .eraser

    init(storageURL overrideURL: URL? = nil) {
        #if DEBUG
        if overrideURL == nil && ProcessInfo.processInfo.arguments.contains("--release2-preview") {
            storageURL = FileManager.default.temporaryDirectory.appendingPathComponent("release2-preview-map.json")
            document = Release2Diagnostics.run()
            tool = ProcessInfo.processInfo.arguments.contains("--preview-eraser") ? .eraser : .texture
            return
        }
        #endif
        storageURL = overrideURL ?? URL.documentsDirectory.appendingPathComponent("map-v1.json")
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let loaded = try JSONDecoder().decode(MapDocument.self, from: Data(contentsOf: storageURL))
            try loaded.validate()
            if loaded.formatVersion == 1 {
                let backup = storageURL.deletingLastPathComponent().appendingPathComponent("map-release1-backup.json")
                if !FileManager.default.fileExists(atPath: backup.path) {
                    try FileManager.default.copyItem(at: storageURL, to: backup)
                }
            }
            document = loaded
        } catch {
            recoveryRequired = true
            saveFailed = true
            errorMessage = AppStrings.text("The saved map could not be opened. The original file is preserved. Changes in this session will not be saved; you can export them as PNG.")
        }
    }

    func switchToPreviousTool() {
        guard !isDrawing, !isFilling else { return }
        tool = previousTool
    }

    func commit(_ newDocument: MapDocument) {
        guard newDocument != document else { return }
        undoHistory.append(document)
        if undoHistory.count > 100 { undoHistory.removeFirst() }
        redoHistory.removeAll()
        document = newDocument
        document.formatVersion = 2
        save()
    }

    func add(_ stroke: InkStroke) {
        var next = document
        next.strokes.append(stroke)
        commit(next)
    }

    func fill(at point: MapPoint) {
        guard !isFilling else { return }
        isFilling = true
        Task { @MainActor in
            await Task.yield()
            defer { isFilling = false }
            do {
                let region = try TextureFillResolver.region(at: point, strokes: document.strokes)
                let strokes = try TextureGenerator.strokes(pattern: texturePattern, region: region, grid: document.grid)
                guard !strokes.isEmpty else {
                    errorMessage = AppStrings.text("This area is too small for the selected texture.")
                    return
                }
                var next = TextureGenerator.removingExistingTexture(from: document, in: region)
                next.strokes.append(contentsOf: strokes)
                next.formatVersion = 2
                commit(next)
            } catch TextureFillError.boundary {
                errorMessage = AppStrings.text("Tap inside a closed area, away from its outline.")
            } catch TextureFillError.tooLarge {
                errorMessage = AppStrings.text("This area is too large for one fill. Divide it into smaller closed areas.")
            } catch {
                errorMessage = AppStrings.text("The area is open. Close the outline with pencil or fiber, then tap inside again.")
            }
        }
    }

    func remove(ids: Set<UUID>) {
        var next = document
        next.strokes.removeAll { ids.contains($0.id) }
        commit(next)
    }

    func setGrid(angle: GridAngle? = nil, spacing: Double? = nil) {
        guard document.strokes.isEmpty, !isDrawing, !isFilling else { return }
        var next = document
        if let angle { next.grid.angle = angle }
        if let spacing { next.grid.spacing = spacing }
        commit(next)
    }

    func undo() {
        guard !isDrawing, !isFilling, let previous = undoHistory.popLast() else { return }
        redoHistory.append(document)
        document = previous
        save()
    }

    func redo() {
        guard !isDrawing, !isFilling, let next = redoHistory.popLast() else { return }
        undoHistory.append(document)
        document = next
        save()
    }

    func save() {
        guard !recoveryRequired else { return }
        do {
            try document.validate()
            try JSONEncoder().encode(document).write(to: storageURL, options: .atomic)
            saveFailed = false
        } catch {
            saveFailed = true
            errorMessage = AppStrings.text("The map could not be saved. Your drawing is still open. Free up space and use Retry saving, or export it as PNG.")
        }
    }

    func exportPNG() -> URL? {
        guard !isDrawing, !isFilling, let image = canvas?.exportImage(), let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("IsoBuild-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            errorMessage = AppStrings.text("The PNG could not be prepared. Try exporting it again.")
            return nil
        }
    }
}
