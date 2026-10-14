// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import Foundation

@MainActor
enum AppStrings {
    // Keep the prototype in Spanish regardless of the device language for now.
    // Source code uses English keys; translations live in language resources.
    private static let bundle: Bundle = {
        guard let path = Bundle.main.path(forResource: "es", ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else { return .main }
        return localizedBundle
    }()

    static func text(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
}
