// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Crucial",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CrucialCore", targets: ["CrucialCore"]),
        .executable(name: "Crucial", targets: ["Crucial"])
    ],
    targets: [
        .target(
            name: "CrucialCore",
            path: "Sources/CrucialCore"
        ),
        .executableTarget(
            name: "Crucial",
            dependencies: ["CrucialCore"],
            path: "Sources/CrucialApp"
        ),
        .testTarget(
            name: "CrucialTests",
            dependencies: ["CrucialCore"],
            path: "Tests/CrucialTests"
        )
    ]
)
