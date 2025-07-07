// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SSM",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
        .tvOS(.v26),
    ],
    products: [
        .library(
            name: "SSM",
            targets: ["SSM"]
        ),
        .library(
            name: "LoadableValues",
            type: .static,
            targets: ["LoadableValues"]
        ),
    ],
    targets: [
        .target(
            name: "SSM",
            dependencies: ["LoadableValues"]
        ),
        .target(name: "LoadableValues"),
        .testTarget(
            name: "SSMTests",
            dependencies: ["SSM"]
        ),
        .testTarget(
            name: "LoadableValuesTests",
            dependencies: ["LoadableValues"]
        ),
    ]
)
