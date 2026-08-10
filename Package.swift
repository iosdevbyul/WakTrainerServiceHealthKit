// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WakTrainerServiceHealthKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v13)
    ],
    products: [
        .library(name: "WakTrainerServiceHealthKit", targets: ["WakTrainerServiceHealthKit"])
    ],
    dependencies: [
        .package(path: "../WakTrainerCoreModels")
    ],
    targets: [
        .target(
            name: "WakTrainerServiceHealthKit",
            dependencies: ["WakTrainerCoreModels"]
        )
    ]
)
