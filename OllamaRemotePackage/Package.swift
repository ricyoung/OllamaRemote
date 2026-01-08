// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OllamaRemoteFeature",
    platforms: [.iOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OllamaRemoteFeature",
            targets: ["OllamaRemoteFeature"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/LiYanan2004/MarkdownView.git", branch: "main"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm/", from: "2.29.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OllamaRemoteFeature",
            dependencies: [
                .product(name: "MarkdownView", package: "MarkdownView"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
            ]
        ),
        .testTarget(
            name: "OllamaRemoteFeatureTests",
            dependencies: [
                "OllamaRemoteFeature"
            ]
        ),
    ]
)
