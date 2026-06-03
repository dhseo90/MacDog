# MacDog 유틸리티 코어 정리 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `MenuBarController`와 `UsagePopoverView`를 사용자-visible 동작 변경 없이 작은 책임 단위로 나눠 이후 Mac 상주 유틸리티 기능을 안전하게 추가할 수 있게 만든다.

**Architecture:** `UsagePopoverView`는 shell과 tab routing만 유지하고, module별 panel과 chart/helper view를 별도 Swift 파일로 옮긴다. `MenuBarController`는 AppKit status item/popover 생명주기 소유권을 유지하되, cache refresh 실행과 popover placement 계산을 순수/작은 협력 타입으로 추출한다. 기존 `UsageMonitorState`, `PetAction`, `PetMenuModel`, Codex JSON/cache schema는 변경하지 않는다.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SwiftPM, XCTest.

---

## 범위와 경계

- Apple Developer Program, Developer ID, notarization, App Group provisioning, App Store Connect가 필요한 항목은 제외한다.
- WidgetKit 실제 UI 검수는 제외한다.
- `codex-usage status --json`, app-owned cache schema, WidgetKit cache contract는 변경하지 않는다.
- 새 Codex bucket을 기본 UI에 추가하지 않는다.
- UI 재설계, 새 캐릭터 세트, DMG 설치 검수, helper 설치/삭제, LaunchAgent 변경은 제외한다.
- PR 생성은 이 계획 실행 범위 밖이다.

## 파일 구조

- Modify: `Sources/MacDog/UsagePopoverView.swift`
  - shell, header, tab rail, tab routing만 남긴다.
- Create: `Sources/MacDog/Popover/MacDogPopoverModule.swift`
  - `MacDogPopoverModule`, `MacDogPopoverLayout`, `CodexUsagePanelLayout`, `MacResourcesPanelLayout`를 이동한다.
- Create: `Sources/MacDog/Popover/CodexUsagePanel.swift`
  - Codex usage tab, usage row, pressure banner, remaining bar, weekly history block 연결을 담당한다.
- Create: `Sources/MacDog/Popover/MacResourcesPanel.swift`
  - Mac resources tab과 sparkline view를 담당한다.
- Create: `Sources/MacDog/Popover/SleepPreventionPanel.swift`
  - 잠들지 않기 tab과 관련 preferences binding을 담당한다.
- Create: `Sources/MacDog/Popover/SettingsPanel.swift`
  - 설정 tab, 캐릭터 preview, privileged helper status content를 담당한다.
- Create: `Sources/MacDog/Popover/BatteryPanel.swift`
  - 배터리 tab을 담당한다.
- Create: `Sources/MacDog/Popover/PopoverSharedViews.swift`
  - `PopoverFormSection`, `PopoverTabArtwork`, `ResourceMetricBlock` 같은 공통 view를 담당한다.
- Create: `Sources/MacDog/Popover/WeeklyRemainingHistoryViews.swift`
  - weekly remaining history graph/view/model을 담당한다.
- Create: `Sources/MacDog/MenuBar/UsageCacheRefreshCoordinator.swift`
  - bundled `codex-usage status --write-cache` 실행 조건과 process 실행을 담당한다.
- Create: `Sources/MacDog/MenuBar/UsagePopoverPlacement.swift`
  - popover anchor/preferred edge/window frame 계산을 담당한다.
- Modify: `Sources/MacDog/MenuBarController.swift`
  - cache refresh와 placement 계산 호출부를 새 타입으로 위임한다.
- Modify: `Tests/MacDogTests/UsageMonitorStateTests.swift`
  - 이동된 public/internal 타입 접근 경로가 바뀌지 않았는지 확인한다.
- Create: `Tests/MacDogTests/UsagePopoverPlacementTests.swift`
  - desktop pet/menu bar popover placement 계산을 순수 테스트로 검증한다.
- Create: `Tests/MacDogTests/UsageCacheRefreshCoordinatorTests.swift`
  - widget bundle 유무에 따른 arguments와 retry cadence를 검증한다.

## 작업 1: Popover module/layout 타입 분리

**Files:**

- Modify: `Sources/MacDog/UsagePopoverView.swift`
- Create: `Sources/MacDog/Popover/MacDogPopoverModule.swift`
- Test: `Tests/MacDogTests/UsageMonitorStateTests.swift`

- [ ] **Step 1: 현재 module/layout 테스트를 확인한다**

Run:

```bash
swift test --filter UsageMonitorStateTests
```

Expected:

```text
UsageMonitorStateTests passed
```

- [ ] **Step 2: `MacDogPopoverModule.swift`를 만든다**

Create `Sources/MacDog/Popover/MacDogPopoverModule.swift` with:

```swift
import SwiftUI

enum MacDogPopoverModule: String, CaseIterable, Identifiable {
    case codex
    case mac
    case sleep
    case battery
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex:
            "Codex 사용량"
        case .mac:
            "활성 자원"
        case .sleep:
            "잠들지 않기"
        case .battery:
            "배터리"
        case .settings:
            "설정"
        }
    }

    var tabLabel: String {
        switch self {
        case .codex:
            "Codex"
        case .mac:
            "Mac"
        case .sleep:
            "잠들지\n않기"
        case .battery:
            "배터리"
        case .settings:
            "설정"
        }
    }

    var systemImage: String {
        MacDogCharacterProfile.codexPup.popoverTabs.artwork(for: self).systemImage
    }

    var artworkName: String {
        MacDogCharacterProfile.codexPup.popoverTabs.artwork(for: self).resourceName
    }

    var usesScrollableContent: Bool {
        switch self {
        case .codex, .mac, .sleep, .battery, .settings:
            false
        }
    }
}

enum MacDogPopoverLayout {
    static let outerSize = CGSize(width: 370, height: 408)
    static let outerPadding: CGFloat = 10
    static let contentSurfaceSize = CGSize(width: 278, height: 388)
    static let contentPadding: CGFloat = 12
    static let contentStackSpacing: CGFloat = 8
    static let headerHeight: CGFloat = 34
    static let dividerHeight: CGFloat = 1
    static let shellCornerRadius: CGFloat = 12
    static let shellBackgroundColor = Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.96)

    static var nonScrollableContentHeight: CGFloat {
        contentSurfaceSize.height
            - (contentPadding * 2)
            - headerHeight
            - dividerHeight
            - (contentStackSpacing * 2)
    }
}

enum CodexUsagePanelLayout {
    static let weeklyGraphHeight: CGFloat = 74
    static let weeklyGraphYAxisWidth: CGFloat = 28
    static let weeklyGraphAxisSpacing: CGFloat = 5
    static let weeklyGraphTimelineHeight: CGFloat = 13

    static var weeklyGraphPlotStartX: CGFloat {
        weeklyGraphYAxisWidth + weeklyGraphAxisSpacing
    }
}

enum MacResourcesPanelLayout {
    static let verticalSpacing: CGFloat = 8
    static let sparklineHeight: CGFloat = 30
    static let trendBlockHeight: CGFloat = 68
    static let storageBlockHeight: CGFloat = 54
    static let networkBlockHeight: CGFloat = 56

    static var estimatedContentHeight: CGFloat {
        (trendBlockHeight * 2)
            + storageBlockHeight
            + networkBlockHeight
            + (MacDogPopoverLayout.dividerHeight * 3)
            + (verticalSpacing * 6)
    }
}
```

- [ ] **Step 3: `UsagePopoverView.swift`에서 이동한 타입을 삭제한다**

Remove only these declarations from `Sources/MacDog/UsagePopoverView.swift`:

```swift
enum MacDogPopoverModule
enum MacDogPopoverLayout
enum CodexUsagePanelLayout
enum MacResourcesPanelLayout
```

- [ ] **Step 4: 이동 후 테스트를 실행한다**

Run:

```bash
swift test --filter UsageMonitorStateTests --filter PopoverMetricsRefreshPolicyTests --filter MacDogCharacterProfileTests
```

Expected:

```text
0 failures
```

- [ ] **Step 5: 커밋한다**

```bash
git add Sources/MacDog/UsagePopoverView.swift Sources/MacDog/Popover/MacDogPopoverModule.swift Tests/MacDogTests/UsageMonitorStateTests.swift
git commit -m "refactor: split popover module layout types"
```

## 작업 2: Codex usage panel과 weekly chart 분리

**Files:**

- Modify: `Sources/MacDog/UsagePopoverView.swift`
- Create: `Sources/MacDog/Popover/CodexUsagePanel.swift`
- Create: `Sources/MacDog/Popover/WeeklyRemainingHistoryViews.swift`
- Test: `Tests/MacDogTests/UsageMonitorStateTests.swift`

- [ ] **Step 1: chart 관련 테스트를 먼저 실행한다**

Run:

```bash
swift test --filter UsageMonitorStateTests
```

Expected:

```text
0 failures
```

- [ ] **Step 2: `CodexUsagePanel`을 만든다**

Create `Sources/MacDog/Popover/CodexUsagePanel.swift` and move the current Codex tab content into this shape:

```swift
import CodexUsageCore
import SwiftUI

struct CodexUsagePanel: View {
    let state: UsageMonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let limit = state.codexLimit {
                VStack(alignment: .leading, spacing: 12) {
                    UsageRow(title: "5시간", window: limit.fiveHour)
                    UsageRow(title: "주간", window: limit.weekly)
                }

                Divider()

                WeeklyRemainingHistoryBlock(
                    history: state.weeklyUsageHistory,
                    weeklyWindow: limit.weekly,
                    currentReport: state.report,
                    currentTimestamp: state.cacheSnapshot?.cachedAt ?? state.report?.generatedAt
                )

                if let message = state.highUsageMessage {
                    PressureBanner(message: message, phase: state.phase)
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    metadataRow("플랜", limit.planType ?? "알 수 없음")
                    metadataRow("갱신", state.lastUpdatedSummary)
                    resetMetadataRow(limit.weekly)
                }
            } else if state.isRefreshing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("사용량 새로고침 중...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(state.errorMessage ?? "사용량을 확인할 수 없음")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = state.errorMessage, !state.isRefreshing {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    private func metadataRow(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }

    private func resetMetadataRow(_ window: UsageWindowReport?) -> some View {
        metadataRow("초기화", resetMetadataValue(window))
    }

    private func resetMetadataValue(_ window: UsageWindowReport?) -> String {
        let summary = UsageWindowStatus.resetSummary(
            resetsAt: window?.resetsAt,
            now: resetSummaryNow
        )
        if summary.hasPrefix("초기화까지 ") {
            return String(summary.dropFirst("초기화까지 ".count))
        }
        if summary.hasPrefix("초기화 ") {
            return String(summary.dropFirst("초기화 ".count))
        }
        return summary
    }

    private var resetSummaryNow: Date {
        guard let report = state.report,
              report.source == "demo"
        else {
            return Date()
        }
        return Date(timeIntervalSince1970: TimeInterval(report.generatedAt))
    }
}
```

- [ ] **Step 3: weekly chart 타입을 이동한다**

Create `Sources/MacDog/Popover/WeeklyRemainingHistoryViews.swift` and move these declarations from `UsagePopoverView.swift` without changing behavior:

```swift
WeeklyRemainingHistoryBlock
WeeklyRemainingTimelineLabels
WeeklyRemainingHistoryGraph
WeeklyRemainingHistoryYAxisLabels
WeeklyRemainingHistoryPlot
WeeklyRemainingHistoryLabelPlacement
WeeklyRemainingHistoryChart
WeeklyRemainingHistoryPoint
WeeklyRemainingHistoryDayMarker
PressureBanner
UsageRow
RemainingUsageBar
```

- [ ] **Step 4: `UsagePopoverView` routing을 바꾼다**

In `UsagePopoverView.tabContent`, replace the `.codex` case with:

```swift
case .codex:
    CodexUsagePanel(state: state)
```

Remove the old `codexUsageContent`, metadata helpers, weekly chart declarations, `PressureBanner`, `UsageRow`, and `RemainingUsageBar` from `UsagePopoverView.swift`.

- [ ] **Step 5: chart 테스트를 실행한다**

Run:

```bash
swift test --filter UsageMonitorStateTests
```

Expected:

```text
0 failures
```

- [ ] **Step 6: 커밋한다**

```bash
git add Sources/MacDog/UsagePopoverView.swift Sources/MacDog/Popover/CodexUsagePanel.swift Sources/MacDog/Popover/WeeklyRemainingHistoryViews.swift Tests/MacDogTests/UsageMonitorStateTests.swift
git commit -m "refactor: split codex popover panel"
```

## 작업 3: Mac resources panel 분리

**Files:**

- Modify: `Sources/MacDog/UsagePopoverView.swift`
- Create: `Sources/MacDog/Popover/MacResourcesPanel.swift`
- Test: `Tests/MacDogTests/UsageMonitorStateTests.swift`

- [ ] **Step 1: sparkline 테스트를 실행한다**

Run:

```bash
swift test --filter UsageMonitorStateTests
```

Expected:

```text
0 failures
```

- [ ] **Step 2: `MacResourcesPanel.swift`를 만든다**

Create `Sources/MacDog/Popover/MacResourcesPanel.swift` and move these declarations from `UsagePopoverView.swift`:

```swift
MacResourcesPanel
ResourceTrendBlock
CompactResourceMetricBlock
SparklineView
SparklineScale
```

Keep the current `SparklineScale` behavior:

```swift
struct SparklineScale: Equatable {
    static let lowerBound: Double = 0
    static let upperBound: Double = 100

    init(values: [Double]) {
        _ = values
    }

    func normalized(_ value: Double) -> Double {
        let clampedValue = min(max(value, 0), 100)
        let span = Self.upperBound - Self.lowerBound
        guard span > 0 else { return 0.5 }
        return min(max((clampedValue - Self.lowerBound) / span, 0), 1)
    }
}
```

- [ ] **Step 3: `UsagePopoverView.swift`에서 이동한 타입을 삭제한다**

Remove only the moved Mac resources declarations. The `.mac` tab route remains:

```swift
case .mac:
    MacResourcesPanel(
        snapshot: state.systemMetrics,
        history: state.systemMetricsHistory
    )
```

- [ ] **Step 4: 테스트를 실행한다**

Run:

```bash
swift test --filter UsageMonitorStateTests --filter PopoverMetricsRefreshPolicyTests
```

Expected:

```text
0 failures
```

- [ ] **Step 5: 커밋한다**

```bash
git add Sources/MacDog/UsagePopoverView.swift Sources/MacDog/Popover/MacResourcesPanel.swift Tests/MacDogTests/UsageMonitorStateTests.swift
git commit -m "refactor: split mac resources popover panel"
```

## 작업 4: Sleep, Settings, Battery panel 분리

**Files:**

- Modify: `Sources/MacDog/UsagePopoverView.swift`
- Create: `Sources/MacDog/Popover/SleepPreventionPanel.swift`
- Create: `Sources/MacDog/Popover/SettingsPanel.swift`
- Create: `Sources/MacDog/Popover/BatteryPanel.swift`
- Create: `Sources/MacDog/Popover/PopoverSharedViews.swift`
- Test: `Tests/MacDogTests/PrivilegedHelperPopoverActionTests.swift`
- Test: `Tests/MacDogTests/PopoverScreenshotRendererTests.swift`

- [ ] **Step 1: 관련 테스트를 먼저 실행한다**

Run:

```bash
swift test --filter PrivilegedHelperPopoverActionTests --filter PopoverScreenshotRendererTests
```

Expected:

```text
PopoverScreenshotRendererTests is skipped unless MACDOG_RENDER_README_SCREENSHOTS=1
0 failures
```

- [ ] **Step 2: shared view 파일을 만든다**

Create `Sources/MacDog/Popover/PopoverSharedViews.swift` and move these declarations:

```swift
PopoverFormSection
PopoverTabArtwork
ResourceMetricBlock
```

Keep `PopoverFormSection` generic:

```swift
struct PopoverFormSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 15)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content
        }
    }
}
```

- [ ] **Step 3: `SleepPreventionPanel.swift`를 만든다**

Create `Sources/MacDog/Popover/SleepPreventionPanel.swift` and move `SleepPreventionPanel` without behavior changes. Preserve all current `@AppStorage` keys and `RunnerPreferences` setter calls.

- [ ] **Step 4: `SettingsPanel.swift`를 만든다**

Create `Sources/MacDog/Popover/SettingsPanel.swift` and move these declarations:

```swift
SettingsPanel
CharacterSelectionRow
CharacterPreview
SettingsCategoryHeader
PrivilegedHelperStatusContent
```

Keep helper actions routed through:

```swift
onAction(action.action)
```

- [ ] **Step 5: `BatteryPanel.swift`를 만든다**

Create `Sources/MacDog/Popover/BatteryPanel.swift` and move `BatteryPanel`.

- [ ] **Step 6: `UsagePopoverView.swift`에서 이동한 타입을 삭제한다**

The tab routes remain:

```swift
case .sleep:
    SleepPreventionPanel(
        sleepPreventionStatus: state.sleepPreventionStatus,
        sleepPreventionTriggerStatus: state.sleepPreventionTriggerStatus,
        onAction: onAction,
        onPreferencesChanged: onPreferencesChanged
    )
case .battery:
    BatteryPanel(snapshot: state.systemMetrics)
case .settings:
    SettingsPanel(
        privilegedHelperInstallSnapshot: state.privilegedHelperInstallSnapshot,
        onAction: onAction,
        onPreferencesChanged: onPreferencesChanged
    )
```

- [ ] **Step 7: 테스트를 실행한다**

Run:

```bash
swift test --filter PrivilegedHelperPopoverActionTests --filter UsageMonitorStateTests --filter PopoverScreenshotRendererTests
```

Expected:

```text
0 failures
```

- [ ] **Step 8: 커밋한다**

```bash
git add Sources/MacDog/UsagePopoverView.swift Sources/MacDog/Popover/SleepPreventionPanel.swift Sources/MacDog/Popover/SettingsPanel.swift Sources/MacDog/Popover/BatteryPanel.swift Sources/MacDog/Popover/PopoverSharedViews.swift Tests/MacDogTests/PrivilegedHelperPopoverActionTests.swift Tests/MacDogTests/UsageMonitorStateTests.swift Tests/MacDogTests/PopoverScreenshotRendererTests.swift
git commit -m "refactor: split utility popover panels"
```

## 작업 5: usage cache refresh 조율 추출

**Files:**

- Modify: `Sources/MacDog/MenuBarController.swift`
- Create: `Sources/MacDog/MenuBar/UsageCacheRefreshCoordinator.swift`
- Create: `Tests/MacDogTests/UsageCacheRefreshCoordinatorTests.swift`

- [ ] **Step 1: 실패하는 coordinator 테스트를 작성한다**

Create `Tests/MacDogTests/UsageCacheRefreshCoordinatorTests.swift` with:

```swift
import XCTest
@testable import MacDog

final class UsageCacheRefreshCoordinatorTests: XCTestCase {
    func testArgumentsWriteCacheWithoutWidgetMirrorByDefault() {
        let arguments = UsageCacheRefreshCoordinator.arguments(
            requestTimeout: 10,
            isWidgetBundled: false
        )

        XCTAssertEqual(arguments, [
            "status",
            "--write-cache",
            "--timeout",
            "10"
        ])
    }

    func testArgumentsMirrorCacheWhenWidgetIsBundled() {
        let arguments = UsageCacheRefreshCoordinator.arguments(
            requestTimeout: 10,
            isWidgetBundled: true
        )

        XCTAssertEqual(arguments, [
            "status",
            "--write-cache",
            "--mirror-cache",
            "--timeout",
            "10"
        ])
    }

    func testRetryIntervalBlocksDenseAttempts() {
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(UsageCacheRefreshCoordinator.shouldAttemptRefresh(
            lastAttempt: Date(timeIntervalSince1970: 95),
            now: now,
            minimumRetryInterval: 10
        ))
        XCTAssertTrue(UsageCacheRefreshCoordinator.shouldAttemptRefresh(
            lastAttempt: Date(timeIntervalSince1970: 80),
            now: now,
            minimumRetryInterval: 10
        ))
        XCTAssertTrue(UsageCacheRefreshCoordinator.shouldAttemptRefresh(
            lastAttempt: nil,
            now: now,
            minimumRetryInterval: 10
        ))
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

Run:

```bash
swift test --filter UsageCacheRefreshCoordinatorTests
```

Expected:

```text
FAIL: cannot find UsageCacheRefreshCoordinator
```

- [ ] **Step 3: coordinator를 구현한다**

Create `Sources/MacDog/MenuBar/UsageCacheRefreshCoordinator.swift` with:

```swift
import Foundation

enum UsageCacheRefreshCoordinator {
    static func bundledCodexUsageURL(bundleURL: URL = Bundle.main.bundleURL) -> URL? {
        let url = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("codex-usage")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    static func arguments(requestTimeout: TimeInterval, isWidgetBundled: Bool) -> [String] {
        var arguments = [
            "status",
            "--write-cache",
            "--timeout",
            String(Int(requestTimeout))
        ]
        if isWidgetBundled {
            arguments.insert("--mirror-cache", at: 2)
        }
        return arguments
    }

    static func shouldAttemptRefresh(
        lastAttempt: Date?,
        now: Date = Date(),
        minimumRetryInterval: TimeInterval
    ) -> Bool {
        guard let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= minimumRetryInterval
    }

    static func isWidgetBundled(relativeTo codexUsageURL: URL) -> Bool {
        let bundleURL = codexUsageURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let widgetURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("PlugIns", isDirectory: true)
            .appendingPathComponent("MacDogWidgetExtension.appex", isDirectory: true)
        return FileManager.default.fileExists(atPath: widgetURL.path)
    }

    nonisolated static func run(codexUsageURL: URL) async {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = codexUsageURL
            process.arguments = arguments(
                requestTimeout: CodexUsageCacheRefreshPolicy.requestTimeout,
                isWidgetBundled: isWidgetBundled(relativeTo: codexUsageURL)
            )
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            do {
                try process.run()
                let deadline = Date().addingTimeInterval(CodexUsageCacheRefreshPolicy.processTimeout)
                while process.isRunning && Date() < deadline {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                if process.isRunning {
                    process.terminate()
                }
            } catch {
                return
            }
        }.value
    }
}
```

- [ ] **Step 4: `MenuBarController` 호출부를 바꾼다**

Replace `bundledCodexUsageURL()`, `runUsageCacheRefresh`, `isWidgetBundled`, and `shouldAttemptUsageCacheRefresh` usage with:

```swift
guard UsageCacheRefreshCoordinator.shouldAttemptRefresh(
    lastAttempt: lastUsageCacheRefreshAttempt,
    minimumRetryInterval: CodexUsageCacheRefreshPolicy.minimumRetryInterval
) else { return }
guard let codexUsageURL = UsageCacheRefreshCoordinator.bundledCodexUsageURL() else { return }

lastUsageCacheRefreshAttempt = Date()
usageCacheRefreshTask = Task { [weak self] in
    await UsageCacheRefreshCoordinator.run(codexUsageURL: codexUsageURL)
    await MainActor.run {
        guard let self else { return }
        self.usageCacheRefreshTask = nil
        self.refreshUsage(allowLiveRefresh: false)
    }
}
```

- [ ] **Step 5: 테스트를 실행한다**

Run:

```bash
swift test --filter UsageCacheRefreshCoordinatorTests --filter CodexUsageCacheRefreshPolicyTests
```

Expected:

```text
0 failures
```

- [ ] **Step 6: 커밋한다**

```bash
git add Sources/MacDog/MenuBarController.swift Sources/MacDog/MenuBar/UsageCacheRefreshCoordinator.swift Tests/MacDogTests/UsageCacheRefreshCoordinatorTests.swift
git commit -m "refactor: extract usage cache refresh coordinator"
```

## 작업 6: popover placement 계산 추출

**Files:**

- Modify: `Sources/MacDog/MenuBarController.swift`
- Create: `Sources/MacDog/MenuBar/UsagePopoverPlacement.swift`
- Create: `Tests/MacDogTests/UsagePopoverPlacementTests.swift`

- [ ] **Step 1: placement 테스트를 작성한다**

Create `Tests/MacDogTests/UsagePopoverPlacementTests.swift` with:

```swift
import AppKit
import XCTest
@testable import MacDog

final class UsagePopoverPlacementTests: XCTestCase {
    func testMenuBarFrameCentersBelowSourceAndClampsToScreen() {
        let frame = UsagePopoverPlacement.menuBar.positionedFrame(
            popoverSize: NSSize(width: 370, height: 408),
            sourceFrame: NSRect(x: 500, y: 860, width: 32, height: 22),
            screenFrame: NSRect(x: 0, y: 0, width: 1000, height: 900)
        )

        XCTAssertEqual(frame.origin.x, 331, accuracy: 0.1)
        XCTAssertEqual(frame.origin.y, 448, accuracy: 0.1)
    }

    func testDesktopPetOnLeftShowsPopoverOnRight() {
        let frame = UsagePopoverPlacement.desktopPet.positionedFrame(
            popoverSize: NSSize(width: 370, height: 408),
            sourceFrame: NSRect(x: 80, y: 300, width: 96, height: 102),
            screenFrame: NSRect(x: 0, y: 0, width: 1200, height: 800)
        )

        XCTAssertEqual(frame.origin.x, 184, accuracy: 0.1)
    }

    func testDesktopPetOnRightShowsPopoverOnLeft() {
        let frame = UsagePopoverPlacement.desktopPet.positionedFrame(
            popoverSize: NSSize(width: 370, height: 408),
            sourceFrame: NSRect(x: 1000, y: 300, width: 96, height: 102),
            screenFrame: NSRect(x: 0, y: 0, width: 1200, height: 800)
        )

        XCTAssertEqual(frame.origin.x, 622, accuracy: 0.1)
    }
}
```

- [ ] **Step 2: 테스트 실패를 확인한다**

Run:

```bash
swift test --filter UsagePopoverPlacementTests
```

Expected:

```text
FAIL: cannot find UsagePopoverPlacement
```

- [ ] **Step 3: placement 타입을 구현한다**

Create `Sources/MacDog/MenuBar/UsagePopoverPlacement.swift` with:

```swift
import AppKit

enum UsagePopoverPlacement {
    case menuBar
    case desktopPet

    var defaultPreferredEdge: NSRectEdge {
        switch self {
        case .menuBar:
            return .maxY
        case .desktopPet:
            return .maxX
        }
    }

    func anchorRect(in sourceBounds: NSRect) -> NSRect {
        guard self == .menuBar else {
            return sourceBounds
        }

        let width = min(sourceBounds.width, 24)
        return NSRect(
            x: (sourceBounds.width - width) / 2,
            y: sourceBounds.minY,
            width: width,
            height: sourceBounds.height
        )
    }

    func preferredEdge(sourceFrame: NSRect, screenFrame: NSRect) -> NSRectEdge {
        guard self == .desktopPet else {
            return defaultPreferredEdge
        }
        return shouldShowDesktopPopoverOnRight(sourceFrame: sourceFrame, screenFrame: screenFrame) ? .maxX : .minX
    }

    func positionedFrame(
        popoverSize: NSSize,
        sourceFrame: NSRect,
        screenFrame: NSRect
    ) -> NSRect {
        var frame = NSRect(origin: .zero, size: popoverSize)
        switch self {
        case .menuBar:
            frame.origin.x = sourceFrame.midX - frame.width / 2
            frame.origin.y = max(screenFrame.minY + 8, sourceFrame.minY - frame.height - 4)
        case .desktopPet:
            let padding: CGFloat = 8
            let showOnRight = shouldShowDesktopPopoverOnRight(sourceFrame: sourceFrame, screenFrame: screenFrame)
            frame.origin.x = showOnRight
                ? sourceFrame.maxX + padding
                : sourceFrame.minX - frame.width - padding
            frame.origin.y = sourceFrame.midY - frame.height / 2
        }
        frame.origin.x = min(max(frame.origin.x, screenFrame.minX + 8), screenFrame.maxX - frame.width - 8)
        frame.origin.y = min(max(frame.origin.y, screenFrame.minY + 8), screenFrame.maxY - frame.height - 8)
        return frame
    }

    private func shouldShowDesktopPopoverOnRight(sourceFrame: NSRect, screenFrame: NSRect) -> Bool {
        sourceFrame.midX <= screenFrame.midX
    }
}
```

- [ ] **Step 4: `MenuBarController` placement 호출부를 위임한다**

Update `popoverAnchorRect`, `preferredEdge`, and `positionPopoverWindow` to call `UsagePopoverPlacement`.

For `positionPopoverWindow`, keep AppKit window lookup in `MenuBarController` and move only frame math:

```swift
let positionedFrame = placement.positionedFrame(
    popoverSize: popoverWindow.frame.size,
    sourceFrame: sourceFrame,
    screenFrame: screen.visibleFrame
)
popoverWindow.setFrame(positionedFrame, display: true)
```

- [ ] **Step 5: 테스트를 실행한다**

Run:

```bash
swift test --filter UsagePopoverPlacementTests --filter FloatingPetMotionBoundsTests
```

Expected:

```text
0 failures
```

- [ ] **Step 6: 커밋한다**

```bash
git add Sources/MacDog/MenuBarController.swift Sources/MacDog/MenuBar/UsagePopoverPlacement.swift Tests/MacDogTests/UsagePopoverPlacementTests.swift
git commit -m "refactor: extract popover placement logic"
```

## 작업 7: 최종 검증과 PR 직전 정리

**Files:**

- Modify: `Docs/V120UtilityCoreRefactor.md` if execution evidence needs to be recorded.

- [ ] **Step 1: focused tests를 실행한다**

Run:

```bash
swift test --filter UsageMonitorStateTests --filter PetMenuModelTests --filter PopoverMetricsRefreshPolicyTests --filter CodexUsageCacheRefreshPolicyTests --filter UsageCacheRefreshCoordinatorTests --filter UsagePopoverPlacementTests
```

Expected:

```text
0 failures
```

- [ ] **Step 2: 전체 테스트를 실행한다**

Run:

```bash
swift test --no-parallel
```

Expected:

```text
0 failures
```

- [ ] **Step 3: 계약 검증을 실행한다**

Run:

```bash
./script/verify_app_privacy_boundaries.sh
./script/verify_cache_contract.sh
git diff --check
```

Expected:

```text
App privacy boundary verification ok
Cache contract verification ok
git diff --check exits 0
```

- [ ] **Step 4: 문서 lint를 실행한다**

Run:

```bash
npx --yes markdownlint-cli2@0.22.1
```

Expected:

```text
Summary: 0 error(s)
```

If sandbox DNS fails, rerun the same command with explicit approval and report both the sandbox failure and the approved result.

- [ ] **Step 5: PR은 만들지 않고 상태만 보고한다**

Run:

```bash
git status --short --branch
git log --oneline -8
```

Expected:

```text
working tree clean
latest commits are on v1.2.0
```

Do not run `gh pr create` and do not create a GitHub PR in this step.
