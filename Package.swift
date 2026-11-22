// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Crucial",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Crucial", targets: ["Crucial"])
    ],
    targets: [
        .executableTarget(
            name: "Crucial",
            path: "Sources/Crucial"
        )
    ]
)
