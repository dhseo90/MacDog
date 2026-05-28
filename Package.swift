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
        .library(
            name: "MacDogPrivilegedHelperSupport",
            targets: ["MacDogPrivilegedHelperSupport"]
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
        ),
        .executable(
            name: "MacDogPrivilegedHelper",
            targets: ["MacDogPrivilegedHelper"]
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
        .target(
            name: "MacDogPrivilegedHelperSupport"
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
            dependencies: [
                "CodexUsageCore",
                "MacDogPowerUIBridge",
                "MacDogPrivilegedHelperSupport"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "MacDogPowerUIBridge",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "MacDogPrivilegedHelper",
            dependencies: ["MacDogPrivilegedHelperSupport"]
        ),
        .testTarget(
            name: "CodexUsageCoreTests",
            dependencies: ["CodexUsageCore", "MacDogWidget"],
            resources: [
                .process("Fixtures")
            ]
        ),
        .testTarget(
            name: "MacDogTests",
            dependencies: [
                "MacDog",
                "MacDogPrivilegedHelperSupport"
            ]
        ),
        .testTarget(
            name: "MacDogPrivilegedHelperSupportTests",
            dependencies: ["MacDogPrivilegedHelperSupport"]
        )
    ]
)
