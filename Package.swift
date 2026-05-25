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
        .testTarget(
            name: "CodexUsageCoreTests",
            dependencies: ["CodexUsageCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)

