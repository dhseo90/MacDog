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
        .executable(
            name: "codex-usage-probe",
            targets: ["CodexUsageProbe"]
        ),
        .executable(
            name: "codex-usage",
            targets: ["CodexUsageCLI"]
        )
    ],
    targets: [
        .target(
            name: "CodexUsageCore"
        ),
        .executableTarget(
            name: "CodexUsageProbe",
            dependencies: ["CodexUsageCore"]
        ),
        .executableTarget(
            name: "CodexUsageCLI",
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
