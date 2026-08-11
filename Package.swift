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
        .package(url: "https://github.com/iosdevbyul/WakTrainerCoreModels", branch: "main")
    ],
    targets: [
        .target(
            name: "WakTrainerServiceHealthKit",
            dependencies: [
                .product(name: "WakTrainerCoreModels", package: "WakTrainerCoreModels")
            ]
        )
    ]
)
