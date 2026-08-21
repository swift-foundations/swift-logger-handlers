// swift-tools-version: 6.4

// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-logger-handlers open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-logger-handlers
// project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "swift-logger-handlers",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Logger Handlers",
            targets: ["Logger Handlers"]
        ),
        .library(
            name: "Logger Handlers Foundation Integration",
            targets: ["Logger Handlers Foundation Integration"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4")
    ],
    targets: [
        .target(
            name: "Logger Handlers",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .target(
            name: "Logger Handlers Foundation Integration",
            dependencies: [
                "Logger Handlers",
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "Logger Handlers Tests",
            dependencies: [
                "Logger Handlers",
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "Logger Handlers Foundation Integration Tests",
            dependencies: [
                "Logger Handlers",
                "Logger Handlers Foundation Integration",
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
