// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PhotosExporterLib",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "PhotosExporterLib", targets: ["PhotosExporterLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.3"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.59.1"),
    ],
    targets: [
        .target(
            name: "PhotosExporterLib",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "PhotosExporterLibTests",
            dependencies: ["PhotosExporterLib"],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
