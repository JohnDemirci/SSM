// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SSM",
	platforms: [
		.macOS(.v14),
		.iOS(.v17),
		.tvOS(.v17),
		.watchOS(.v9),
		.visionOS(.v1),
		.driverKit(.v21)
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
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SSM",
            dependencies: [
                "LoadableValues",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
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
