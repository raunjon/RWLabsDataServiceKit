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
    ],
    dependencies: [
        // Local checkout until RWLabsFoundation is on GitHub; then switch to
        // .package(url: "https://github.com/raunjon/RWLabsFoundation.git", from: "1.0.0")
        .package(path: "../RWLabsFoundation"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RWLabsDataServiceKit",
            dependencies: [.product(name: "RWLabsFoundation", package: "RWLabsFoundation")]),
        .testTarget(
            name: "RWLabsDataServiceKitTests",
            dependencies: [
                "RWLabsDataServiceKit",
                .product(name: "RWLabsFoundation", package: "RWLabsFoundation"),
            ]),
    ],
    swiftLanguageModes: [.v5]
)
