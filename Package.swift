// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPDiagnoseSDK",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "SPDiagnoseSDK",
            targets: ["SPDiagnoseSDK"]
        ),
    ], 
    dependencies: [],
    targets: [
        .target(
            name: "SPDiagnoseSDK", 
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "SPDiagnoseSDKTests",
            dependencies: ["SPDiagnoseSDK"],
            path: "Tests"
        ),
    ]
)
