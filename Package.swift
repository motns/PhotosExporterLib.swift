// swift-tools-version: 6.0
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
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.4.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
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
