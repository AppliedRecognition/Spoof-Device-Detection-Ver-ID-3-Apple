// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SpoofDeviceDetection",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SpoofDeviceDetection",
            targets: ["SpoofDeviceDetection"]),
        .library(
            name: "SpoofDeviceDetectionCore",
            targets: ["SpoofDeviceDetectionCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/AppliedRecognition/Ver-ID-Common-Types-Apple.git", "2.0.0"..<"4.0.0"),
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", .upToNextMajor(from: "9.1.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SpoofDeviceDetection",
            dependencies: [
                "SpoofDeviceDetectionCore"
            ]),
        .target(
            name: "SpoofDeviceDetectionCore",
            dependencies: [
                .product(
                    name: "VerIDCommonTypes",
                    package: "Ver-ID-Common-Types-Apple"
                )
            ]),
        .testTarget(
            name: "SpoofDeviceDetectionTests",
            dependencies: [
                "SpoofDeviceDetection",
                .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs")
            ],
            resources: [
                .process("Resources")
            ])
    ]
)
