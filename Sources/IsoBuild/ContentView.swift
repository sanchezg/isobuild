// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import SwiftUI
import UIKit

private struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ContentView: View {
    @ObservedObject var model: DrawingModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSettings = false
    @State private var sharedFile: SharedFile?
    #if DEBUG
    @State private var showsAbout = ProcessInfo.processInfo.arguments.contains("--show-about")
    #else
    @State private var showsAbout = false
    #endif
    private let accent = Color(red: 0.12, green: 0.36, blue: 0.31)

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(.black.opacity(0.08)).frame(height: 1)
            ZStack(alignment: .bottom) {
                CanvasRepresentable(model: model)
                VStack(spacing: 12) {
                    if model.document.strokes.isEmpty {
                        Text(AppStrings.text("Place the Pencil on a dot and draw toward another"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                            .allowsHitTesting(false)
                    }
                    drawingTools
                }
                .padding(.bottom, 20)
            }
            footer
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.93))
        .tint(accent)
        .popover(isPresented: $showsSettings) { settings }
        .sheet(isPresented: $showsAbout) { AboutView() }
        .sheet(item: $sharedFile, onDismiss: cleanExports) { file in
            ShareSheet(url: file.url)
        }
        .alert("IsoBuild", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button(AppStrings.text("Got it")) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.save() }
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "square.3.layers.3d").font(.title2)
                Text("IsoBuild").font(.system(.title3, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(accent)
            Picker(AppStrings.text("Drawing mode"), selection: $model.guided) {
                Text(AppStrings.text("Guided")).tag(true)
                Text(AppStrings.text("Freehand")).tag(false)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            Spacer(minLength: 0)
            icon(AppStrings.text("Undo"), "arrow.uturn.backward", disabled: model.undoHistory.isEmpty) { model.undo() }
            icon(AppStrings.text("Redo"), "arrow.uturn.forward", disabled: model.redoHistory.isEmpty) { model.redo() }
            icon(AppStrings.text("Export PNG"), "square.and.arrow.up", disabled: model.document.strokes.isEmpty) {
                if let url = model.exportPNG() { sharedFile = SharedFile(url: url) }
            }
            icon(AppStrings.text("Settings"), "slider.horizontal.3") { showsSettings = true }
            icon(AppStrings.text("Credits and license"), "info.circle") { showsAbout = true }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .disabled(model.isDrawing)
    }

    private var drawingTools: some View {
        HStack(spacing: 8) {
            toolButton(AppStrings.text("Ink"), "pencil.tip", tool: .ink)
            toolButton(AppStrings.text("Gray shadow"), "highlighter", tool: .shadow)
            Divider().frame(height: 24).padding(.horizontal, 4)
            ForEach([0.8, 1.6, 3.2], id: \.self) { width in
                Button {
                    model.penWidth = width
                    if model.tool == .eraser { model.tool = .ink }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(model.penWidth == width ? accent.opacity(0.12) : .clear)
                        Capsule().fill(accent).frame(width: 22, height: width * 2)
                    }.frame(width: 40, height: 44)
                }
                .accessibilityLabel(width == 0.8 ? AppStrings.text("Thin stroke") : width == 1.6 ? AppStrings.text("Medium stroke") : AppStrings.text("Thick stroke"))
                .accessibilityAddTraits(model.penWidth == width ? .isSelected : [])
            }
            Divider().frame(height: 24).padding(.horizontal, 4)
            toolButton(AppStrings.text("Stroke eraser"), "eraser", tool: .eraser)
            icon(model.showsGrid ? AppStrings.text("Hide dots") : AppStrings.text("Show dots"), model.showsGrid ? "circle.grid.3x3.fill" : "circle.grid.3x3") {
                model.showsGrid.toggle()
            }
            icon(AppStrings.text("Fit drawing"), "viewfinder") { model.canvas?.fitDrawing() }
        }
        .buttonStyle(.plain)
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.black.opacity(0.06)))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .disabled(model.isDrawing)
    }

    private var footer: some View {
        HStack {
            Text("\(model.document.grid.angle.rawValue)° · \(model.guided ? AppStrings.text("Guided") : AppStrings.text("Freehand")) · \(model.pressureEnabled ? AppStrings.text("Pressure enabled") : AppStrings.text("Fixed width"))")
            Spacer()
            if model.saveFailed {
                Button(AppStrings.text("Retry saving")) { model.save() }
                    .foregroundStyle(.red)
            } else {
                Text(AppStrings.text("Automatic local saving")).foregroundStyle(.secondary)
            }
            Text(AppStrings.text("Two fingers: pan and zoom")).foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    private var settings: some View {
        Form {
            Section(AppStrings.text("Grid")) {
                Picker(AppStrings.text("Angle"), selection: Binding(get: { model.document.grid.angle }, set: { model.setGrid(angle: $0) })) {
                    Text("30°").tag(GridAngle.thirty)
                    Text("45°").tag(GridAngle.fortyFive)
                }
                .pickerStyle(.segmented)
                .disabled(!model.document.strokes.isEmpty)
                Picker(AppStrings.text("Spacing"), selection: Binding(get: { model.document.grid.spacing }, set: { model.setGrid(spacing: $0) })) {
                    Text(AppStrings.text("Small")).tag(28.0)
                    Text(AppStrings.text("Medium")).tag(40.0)
                    Text(AppStrings.text("Large")).tag(56.0)
                }
                .disabled(!model.document.strokes.isEmpty)
                if !model.document.strokes.isEmpty {
                    Text(AppStrings.text("The map must be empty to change the grid. Existing drawings keep their shape."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle(AppStrings.text("Show dots"), isOn: $model.showsGrid)
            }
            Section("Pencil") {
                Toggle(AppStrings.text("Pressure-sensitive width"), isOn: $model.pressureEnabled)
                Text(AppStrings.text("Applies to new strokes. Guided mode only adjusts endpoints near valid dots."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text(AppStrings.text("One stroke per contact. Use Freehand for cracks, curves, and details. The eraser removes whole strokes."))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 540)
    }

    private func toolButton(_ label: String, _ image: String, tool: DrawingTool) -> some View {
        Button { model.tool = tool } label: {
            Image(systemName: image).font(.system(size: 19))
                .frame(width: 44, height: 44)
                .background(model.tool == tool ? accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(model.tool == tool ? .isSelected : [])
    }

    private func icon(_ label: String, _ image: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: image).font(.system(size: 18))
                .frame(width: 40, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .disabled(disabled)
    }

    private func cleanExports() {
        let directory = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix("IsoBuild-") && file.pathExtension == "png" {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
