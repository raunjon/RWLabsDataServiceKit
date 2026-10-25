// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RWLabsDataServiceKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RWLabsDataServiceKit",
            targets: ["RWLabsDataServiceKit"]),
        .library(
            name: "RWLabsFoundation",
            targets: ["RWLabsFoundation"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RWLabsDataServiceKit",
            dependencies: ["RWLabsFoundation"]),
        .testTarget(
            name: "RWLabsDataServiceKitTests",
            dependencies: ["RWLabsDataServiceKit"]),
        // Formatting and convenience helpers; independent of the networking library
        .target(
            name: "RWLabsFoundation",
            dependencies: []),
        .testTarget(
            name: "RWLabsFoundationTests",
            dependencies: ["RWLabsFoundation"]),
    ],
    swiftLanguageModes: [.v5]
)
