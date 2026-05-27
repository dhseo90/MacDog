// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacDog",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CodexUsageCore",
            targets: ["CodexUsageCore"]
        ),
        .library(
            name: "MacDogWidget",
            targets: ["MacDogWidget"]
        ),
        .executable(
            name: "codex-usage-probe",
            targets: ["CodexUsageProbe"]
        ),
        .executable(
            name: "codex-usage",
            targets: ["CodexUsageCLI"]
        ),
        .executable(
            name: "MacDog",
            targets: ["MacDog"]
        )
    ],
    targets: [
        .target(
            name: "CodexUsageCore"
        ),
        .target(
            name: "MacDogWidget",
            dependencies: ["CodexUsageCore"]
        ),
        .executableTarget(
            name: "CodexUsageProbe",
            dependencies: ["CodexUsageCore"]
        ),
        .executableTarget(
            name: "CodexUsageCLI",
            dependencies: ["CodexUsageCore"]
        ),
        .executableTarget(
            name: "MacDog",
            dependencies: ["CodexUsageCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CodexUsageCoreTests",
            dependencies: ["CodexUsageCore", "MacDogWidget"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
