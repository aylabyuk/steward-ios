// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StewardCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "StewardCore", targets: ["StewardCore"])
    ],
    targets: [
        .target(name: "StewardCore"),
        .testTarget(
            name: "StewardCoreTests",
            dependencies: ["StewardCore"]
        )
    ]
)
