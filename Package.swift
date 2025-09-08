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
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "SSM",
            dependencies: [
                "LoadableValues",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
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
