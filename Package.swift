// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WakTrainerServiceHealthKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "WakTrainerServiceHealthKit",
            targets: ["WakTrainerServiceHealthKit"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/iosdevbyul/WakTrainerCoreModels",
            branch: "main"
        )
    ],
    targets: [
        .target(
            name: "WakTrainerServiceHealthKit",
            dependencies: [
                .product(
                    name: "WakTrainerCoreModels",
                    package: "WakTrainerCoreModels"
                )
            ]
        ),
        .testTarget(
            name: "WakTrainerServiceHealthKitTests",
            dependencies: [
                "WakTrainerServiceHealthKit",
                .product(
                    name: "WakTrainerCoreModels",
                    package: "WakTrainerCoreModels"
                )
            ]
        )
    ]
)
