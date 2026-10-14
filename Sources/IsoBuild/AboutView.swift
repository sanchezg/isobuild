// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(AppStrings.text("Credits")) {
                    Text("IsoBuild").font(.title2.bold())
                    Text("Copyright © 2026 gsanz.dev")
                        .textSelection(.enabled)
                    Text(AppStrings.text("Original project copyright notice. Modified versions may identify their contributions separately."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section(AppStrings.text("Free software")) {
                    Text(AppStrings.text("GNU GPL version 3, with attribution notice preservation."))
                    Text(AppStrings.text("You may use, copy, modify, and redistribute this software under its license. It comes without warranty unless expressly stated otherwise."))
                        .font(.subheadline)
                    NavigationLink(AppStrings.text("Read GNU GPLv3")) {
                        LegalTextView(title: "GNU GPLv3", resource: "LICENSE", fileExtension: nil)
                    }
                    NavigationLink(AppStrings.text("Read attribution condition")) {
                        LegalTextView(title: AppStrings.text("Attribution"), resource: "ATTRIBUTION", fileExtension: "md")
                    }
                }
                Section(AppStrings.text("Source code for this version")) {
                    if let source = Bundle.main.url(forResource: "IsoBuild-Source", withExtension: "zip") {
                        ShareLink(item: source) {
                            Label(AppStrings.text("Save or share source code"), systemImage: "doc.zipper")
                        }
                        Text(AppStrings.text("The app includes a ZIP with the source for this build, the Xcode project, and instructions to modify and build it."))
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text(AppStrings.text("The source archive was not found in this build."))
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(AppStrings.text("About IsoBuild"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.text("Close")) { dismiss() }
                }
            }
        }
    }
}

private struct LegalTextView: View {
    let title: String
    let resource: String
    let fileExtension: String?

    private var text: String {
        guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return AppStrings.text("The legal text could not be opened in this build.")
        }
        return contents
    }

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
