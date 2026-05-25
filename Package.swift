// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MyCodex",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CodexUsageCore",
            targets: ["CodexUsageCore"]
        ),
        .library(
            name: "CodexUsageWidget",
            targets: ["CodexUsageWidget"]
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
            name: "CodexUsageMonitor",
            targets: ["CodexUsageMonitor"]
        )
    ],
    targets: [
        .target(
            name: "CodexUsageCore"
        ),
        .target(
            name: "CodexUsageWidget",
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
            name: "CodexUsageMonitor",
            dependencies: ["CodexUsageCore"]
        ),
        .testTarget(
            name: "CodexUsageCoreTests",
            dependencies: ["CodexUsageCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
