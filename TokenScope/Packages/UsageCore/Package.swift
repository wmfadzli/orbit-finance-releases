// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "UsageCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "UsageCore", targets: ["UsageCore"]),
        .executable(name: "usagescope", targets: ["usagescope"]),
    ],
    targets: [
        .target(
            name: "UsageCore"
        ),
        .executableTarget(
            name: "usagescope",
            dependencies: ["UsageCore"]
        ),
        .testTarget(
            name: "UsageCoreTests",
            dependencies: ["UsageCore"]
        ),
    ]
)
