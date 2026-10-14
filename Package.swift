// swift-tools-version: 6.0
// Copyright (C) 2026 gsanz.dev
// Licensed under GNU GPL version 3 only, with the additional notice-preservation
// term in ATTRIBUTION.md. See LICENSE and ATTRIBUTION.md.

import PackageDescription

let package = Package(
    name: "IsoBuildCore",
    products: [.library(name: "IsoCore", targets: ["IsoCore"])],
    targets: [
        .target(name: "IsoCore"),
        .testTarget(name: "IsoCoreTests", dependencies: ["IsoCore"])
    ]
)
