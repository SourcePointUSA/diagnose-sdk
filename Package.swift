// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPDiagnose",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "SPDiagnose",
            targets: ["SPDiagnose", "SPDiagnoseObjc"]
        ),
    ], 
    dependencies: [],
    targets: [
        .target(
            name: "SPDiagnoseObjc",
            dependencies: [],
            path: "Sources/objc",
            cSettings: [ .headerSearchPath("./")]
        ),
        .target(
            name: "SPDiagnose",
            path: "Sources",
            exclude: ["objc"]
        ),
        .testTarget(
            name: "SPDiagnoseTests",
            dependencies: ["SPDiagnose"],
            path: "Tests"
        ),
    ]
)
