// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import SwiftUI
import UIKit

enum DrawingTool { case ink, shadow, eraser }

@MainActor
final class DrawingModel: ObservableObject {
    @Published private(set) var document = MapDocument()
    @Published var guided = true
    @Published var tool: DrawingTool = .ink
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

    init() {
        storageURL = URL.documentsDirectory.appendingPathComponent("map-v1.json")
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let loaded = try JSONDecoder().decode(MapDocument.self, from: Data(contentsOf: storageURL))
            try loaded.validate()
            document = loaded
        } catch {
            recoveryRequired = true
            saveFailed = true
            errorMessage = AppStrings.text("The saved map could not be opened. The original file is preserved. Changes in this session will not be saved; you can export them as PNG.")
        }
    }

    func commit(_ newDocument: MapDocument) {
        guard newDocument != document else { return }
        undoHistory.append(document)
        if undoHistory.count > 100 { undoHistory.removeFirst() }
        redoHistory.removeAll()
        document = newDocument
        save()
    }

    func add(_ stroke: InkStroke) {
        var next = document
        next.strokes.append(stroke)
        commit(next)
    }

    func remove(ids: Set<UUID>) {
        var next = document
        next.strokes.removeAll { ids.contains($0.id) }
        commit(next)
    }

    func setGrid(angle: GridAngle? = nil, spacing: Double? = nil) {
        guard document.strokes.isEmpty, !isDrawing else { return }
        var next = document
        if let angle { next.grid.angle = angle }
        if let spacing { next.grid.spacing = spacing }
        commit(next)
    }

    func undo() {
        guard !isDrawing, let previous = undoHistory.popLast() else { return }
        redoHistory.append(document)
        document = previous
        save()
    }

    func redo() {
        guard !isDrawing, let next = redoHistory.popLast() else { return }
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
        guard !isDrawing, let image = canvas?.exportImage(), let data = image.pngData() else { return nil }
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
