# v1.6.0 Codex Recovery Planner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build v1.6.0 Codex Recovery Planner so the Codex tab shows reset recovery cards, session risk, reset-aware notifications, menu glance text, and CLI reset summaries without breaking existing JSON or cache contracts.

**Architecture:** Add small CodexUsageCore value models for reset schedule and session planning, then project them into the existing MacDog app state and Codex tab. Keep the first tab named `Codex`; do not add a Dashboard tab. UI work stays in a new focused SwiftUI file so `CodexUsagePanel.swift` does not become the planner implementation.

**Tech Stack:** Swift 6, SwiftPM, XCTest, SwiftUI, AppKit status item, UserNotifications, shell verifier scripts, markdownlint-cli2.

---

## Source Design Map

Create these files:

- `Sources/CodexUsageCore/Usage/CodexUsageResetSchedule.swift`
  - Builds reset card data from `CodexUsageReport` and optional `CodexUsageCacheSnapshot`.
- `Sources/CodexUsageCore/Usage/CodexUsageSessionPlan.swift`
  - Builds 1시간, 3시간, reset까지 session risk summaries from current pace.
- `Sources/MacDog/Popover/CodexRecoveryPlannerViews.swift`
  - SwiftUI views for recovery cards and session plan controls.
- `Tests/CodexUsageCoreTests/CodexUsageResetScheduleTests.swift`
  - Unit tests for card sorting, trust state, advanced bucket separation, protocol drift.
- `Tests/CodexUsageCoreTests/CodexUsageSessionPlanTests.swift`
  - Unit tests for safe/watch/risky/unavailable session outcomes.
- `Docs/V160CodexRecoveryPlanner.md`
  - Product and implementation boundary document for v1.6.0.
- `Docs/V160ReleaseReadiness.md`
  - Release readiness and manual smoke boundary for v1.6.0.
- `script/verify_v160_codex_recovery_planner_contract.sh`
  - Source guard and focused-test bundle for v1.6.0.

Modify these files:

- `README.md`
  - Add current release roadmap note only after implementation closes.
- `ROADMAP.md`
  - Add v1.6.0 roadmap and ordered issue list.
- `Docs/Scripts.md`
  - Document the v1.6 verifier.
- `Sources/CodexUsageCore/Usage/CodexUsageFormatter.swift`
  - Add text reset summary only; do not change `json(from:)`.
- `Sources/CodexUsageCLI/main.swift`
  - Help text remains compatible; no new required option.
- `Sources/MacDog/UsageMonitorState.swift`
  - Expose computed schedule/session plan helpers.
- `Sources/MacDog/Popover/CodexUsagePanel.swift`
  - Insert recovery cards and session plan block.
- `Sources/MacDog/MenuBarController.swift`
  - Add next reset text to tooltip.
- `Sources/MacDog/PetMenuModel.swift`
  - Add a non-action reset glance command title.
- `Sources/MacDog/UsageNotificationPolicy.swift`
  - Keep reset dedupe by `resetsAt`; strengthen recovery wording.
- `Sources/MacDog/UsageNotificationDelivery.swift`
  - Rename reset notification copy to recovery copy.
- `Sources/MacDog/UsageNotificationSettings.swift`
  - Align settings copy with recovery wording.
- `Sources/MacDog/MacDogDemoData.swift`
  - Ensure README/demo Codex tab has stable 5시간 and 주간 reset cards.
- `Tests/CodexUsageCoreTests/CodexUsageReportTests.swift`
  - Add formatter reset summary assertions.
- `Tests/MacDogTests/UsageMonitorStateTests.swift`
  - Add schedule/session helper coverage.
- `Tests/MacDogTests/UsageNotificationPolicyTests.swift`
  - Add stale/error and recovery dedupe coverage.
- `Tests/MacDogTests/PetMenuModelTests.swift`
  - Add next reset glance coverage.
- `Tests/MacDogTests/PopoverScreenshotRendererTests.swift`
  - Keep screenshot renderer compatible with the new Codex tab layout.

## Execution Rules

- Work task order is strict.
- Do not start P1 tasks until Task 1 through Task 5 pass and are committed.
- Do not change `codex-usage status --json` schema.
- Do not change `usage.json`, `usage-weekly-history.json`, or `usage-reset-window-history.json` schemas.
- Do not read `~/.codex/auth.json`.
- Do not store or print token, refresh token, cookie, session material, auth header, or raw app-server response.
- Do not run GUI apps, install scripts, helper install/delete, LaunchAgent changes, long watch tests, release packaging, signing, notarization, push, or WidgetKit UI checks without explicit user approval.
- Every task commit must include only that task's files.

## Task 1: v1.6 Baseline Docs and Roadmap

**Files:**

- Create: `Docs/V160CodexRecoveryPlanner.md`
- Create: `Docs/V160ReleaseReadiness.md`
- Modify: `ROADMAP.md`
- Modify: `Docs/Scripts.md`
- Test: `script/verify_v160_codex_recovery_planner_contract.sh`

- [ ] **Step 1: Write the v1.6 product boundary document**

Create `Docs/V160CodexRecoveryPlanner.md` with this initial structure:

```markdown
# v1.6.0 Codex Recovery Planner

상태: 구현 예정 / 설계 승인 완료
작성일: 2026-07-05
대상 버전: `1.6.0`

## 목표

v1.6.0은 Codex 탭을 "언제 회복되는지 보고 다음 작업을 정하는 화면"으로 확장합니다.
첫 탭 이름은 계속 `Codex`로 유지하고, 새 Dashboard 탭은 만들지 않습니다.

## 포함 범위

- Codex reset schedule 모델
- Codex 탭 회복 카드
- 작업 세션 계획
- 회복 기준 알림 문구
- 메뉴바 tooltip과 펫 메뉴 glance
- CLI reset schedule 텍스트 요약
- v1.6 focused tests와 verifier

## 제외 범위

- `codex-usage status --json` schema breaking change
- 기존 cache/history schema breaking change
- raw app-server response 저장
- auth token, refresh token, cookie, session material, auth header 읽기, 출력, 저장
- 공식 사용량과 로컬 SQLite 추정치 혼합 표시
- 가격 tier 추정
- 새 Dashboard 탭
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning이 필요한 기능
- WidgetKit 실제 UI 완료 조건

## 완료 기준

- Codex 탭에 5시간/주간 회복 카드가 표시됩니다.
- 각 카드에 초기화 날짜, 남은 시간, 사용률, 잔여율, 신뢰 상태가 표시됩니다.
- 가장 빠른 reset이 다음 회복으로 강조됩니다.
- session plan은 safe, watch, risky, unavailable 상태를 분리합니다.
- 추가 bucket은 기본 UI에 섞이지 않고 advanced/debug 경계로 남습니다.
- `status --json`과 기존 cache/history schema가 breaking change 없이 유지됩니다.
- 실제 UI 확인을 하지 않았다면 `UI 확인 미수행`으로 보고합니다.
```

- [ ] **Step 2: Write the v1.6 release readiness document**

Create `Docs/V160ReleaseReadiness.md` with this initial structure:

````markdown
# v1.6.0 릴리즈 준비 감사

상태: 구현 예정 / release smoke 미수행
작성일: 2026-07-05
대상 버전: `1.6.0`

## 릴리즈 전 자동검증

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v160_codex_recovery_planner_contract.sh --self-test
swift test --filter CodexUsageResetScheduleTests
swift test --filter CodexUsageSessionPlanTests
swift test --filter UsageMonitorStateTests
swift test --filter UsageNotificationPolicyTests
swift test --filter PetMenuModelTests
swift test --filter PopoverScreenshotRendererTests
swift test
```

macOS 앱 UI 변경이 있으므로 release head 확정 전 Xcode Debug build도 통과시킵니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

## 수동 UI smoke

실제 menu bar popover를 열지 않았다면 `UI 확인 미수행`으로 보고합니다.

- Codex 탭 회복 카드가 겹치지 않는지 확인합니다.
- 다음 회복 강조가 보이는지 확인합니다.
- 1시간, 3시간, reset까지 session plan 선택이 동작하는지 확인합니다.
- 현재/지난/비교 그래프가 아래로 밀려도 읽을 수 있는지 확인합니다.
- 메뉴바 tooltip 또는 펫 메뉴에 다음 초기화 glance가 보이는지 확인합니다.

## 미수행 보고 형식

```text
미실행:
- GUI 실행: 실행하지 않음
- live fetch smoke: 실행하지 않음
- published DMG 재다운로드 검증: 실행하지 않음
- Finder drag-and-drop 설치 smoke: 실행하지 않음
- WidgetKit 실제 UI: 실행하지 않음
- 장시간 테스트: 실행하지 않음
```
````

- [ ] **Step 3: Add ROADMAP v1.6 section**

Modify `ROADMAP.md` after the v1.5.0 section and before `RunCat UI 참고 방향`.

Add this section:

```markdown
## v1.6.0: Codex Recovery Planner

`v1.6.0`은 Codex 탭을 "현재 사용량 확인"에서 "회복 일정과 다음 작업 판단"으로 확장합니다.
세부 범위는 [Docs/V160CodexRecoveryPlanner.md](Docs/V160CodexRecoveryPlanner.md)에 둡니다.
릴리즈 준비와 수동 smoke 경계는 [Docs/V160ReleaseReadiness.md](Docs/V160ReleaseReadiness.md)에 둡니다.

v1.6.0 구현 범위:

1. reset schedule 모델을 추가합니다.
2. Codex 탭에 5시간/주간 회복 카드를 표시합니다.
3. 가장 빠른 reset을 다음 회복으로 강조합니다.
4. stale/error/waiting 상태를 과장 없이 표시합니다.
5. 작업 세션 계획을 1시간, 3시간, reset까지 기준으로 보여줍니다.
6. reset 30분 전 알림을 회복 관점 문구로 정리합니다.
7. 메뉴바 tooltip 또는 펫 메뉴에 다음 초기화 glance를 표시합니다.
8. CLI 텍스트 출력에 reset schedule 요약을 추가합니다.
9. v1.6 verifier, focused tests, README/Docs closure를 완료합니다.

v1.6.0 제외 경계:

- `codex-usage status --json` schema breaking change
- 기존 app-owned cache와 history 파일 schema breaking change
- raw app-server response, raw log line, auth token, cookie, session material, auth header 저장 또는 출력
- `Plus`/`Pro $100`/`Pro $200` 가격 tier 추정
- 공식 Codex 사용량과 로컬 SQLite 추정치 혼합 표시
- 새 Dashboard 탭
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning이 필요한 기능
- WidgetKit 실제 UI 완료 조건 포함
- 사용자 명시 요청 없는 장시간 테스트, GUI 앱 실행, 설치/LaunchAgent/helper 변경, push
```

- [ ] **Step 4: Create verifier script skeleton**

Create `script/verify_v160_codex_recovery_planner_contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

require_file() {
  [[ -f "$1" ]] || {
    echo "missing required file: $1" >&2
    exit 1
  }
}

require_text() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if ! /usr/bin/grep -Eq "$pattern" "$file"; then
    echo "missing $label in $file" >&2
    exit 1
  fi
}

if [[ "${1:-}" != "--self-test" ]]; then
  echo "usage: $0 --self-test" >&2
  exit 2
fi

require_file "Docs/V160CodexRecoveryPlanner.md"
require_file "Docs/V160ReleaseReadiness.md"
require_file "Sources/CodexUsageCore/Usage/CodexUsageResetSchedule.swift"
require_file "Sources/CodexUsageCore/Usage/CodexUsageSessionPlan.swift"
require_file "Sources/MacDog/Popover/CodexRecoveryPlannerViews.swift"
require_file "Tests/CodexUsageCoreTests/CodexUsageResetScheduleTests.swift"
require_file "Tests/CodexUsageCoreTests/CodexUsageSessionPlanTests.swift"

require_text 'status --json.*breaking change' "Docs/V160CodexRecoveryPlanner.md" "JSON boundary"
require_text 'Dashboard 탭' "Docs/V160CodexRecoveryPlanner.md" "Dashboard exclusion"
require_text 'auth token|session material' "Docs/V160CodexRecoveryPlanner.md" "auth redaction boundary"
require_text 'CodexUsageResetSchedule' "Sources/CodexUsageCore/Usage/CodexUsageResetSchedule.swift" "reset schedule model"
require_text 'CodexUsageSessionPlan' "Sources/CodexUsageCore/Usage/CodexUsageSessionPlan.swift" "session plan model"
require_text 'status --json' "Sources/CodexUsageCore/Usage/CodexUsageFormatter.swift" "formatter JSON boundary note"

echo "v1.6 recovery planner contract ok"
```

- [ ] **Step 5: Document verifier in Scripts**

Add a row to `Docs/Scripts.md` under read-only verification:

```markdown
| `script/verify_v160_codex_recovery_planner_contract.sh --self-test` | v1.6.0 Codex Recovery Planner 계약 자체검증 | live app-server, GUI 앱, 설치, LaunchAgent, push 없이 reset schedule/session plan source, 문서 경계, focused Swift tests 연결을 확인합니다. |
```

- [ ] **Step 6: Run doc checks**

Run:

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
```

Expected: both commands exit 0.

- [ ] **Step 7: Commit Task 1**

```sh
git add ROADMAP.md Docs/Scripts.md Docs/V160CodexRecoveryPlanner.md Docs/V160ReleaseReadiness.md script/verify_v160_codex_recovery_planner_contract.sh
git commit -m "docs: add v1.6 recovery planner roadmap"
```

## Task 2: Reset Schedule Core Model

**Files:**

- Create: `Sources/CodexUsageCore/Usage/CodexUsageResetSchedule.swift`
- Create: `Tests/CodexUsageCoreTests/CodexUsageResetScheduleTests.swift`
- Test: `Tests/CodexUsageCoreTests/CodexUsageReportTests.swift`

- [ ] **Step 1: Write failing reset schedule tests**

Create `Tests/CodexUsageCoreTests/CodexUsageResetScheduleTests.swift`:

```swift
import XCTest
@testable import CodexUsageCore

final class CodexUsageResetScheduleTests: XCTestCase {
    func testBuildsFreshPrimaryEntriesSortedByResetTime() throws {
        let now = 1_800_000_000
        let report = Self.report(
            fiveHourUsedPercent: 42,
            fiveHourResetsAt: now + 3_600,
            weeklyUsedPercent: 64,
            weeklyResetsAt: now + 604_800
        )
        let snapshot = Self.snapshot(cachedAt: now, staleAfterSeconds: 120, report: report)

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.state, .ok)
        XCTAssertEqual(schedule.primaryEntries.map(\.title), ["5시간", "주간"])
        XCTAssertEqual(schedule.primaryEntries.map(\.remainingSeconds), [3_600, 604_800])
        XCTAssertEqual(schedule.primaryEntries.map(\.trustState), [.fresh, .fresh])
        XCTAssertEqual(schedule.primaryEntries.map(\.isNextRecovery), [true, false])
        XCTAssertEqual(schedule.summaryText, "회복 카드 2장 · 다음 5시간 1시간 후")
    }

    func testMarksEntriesStaleWhenCacheIsStale() throws {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(
            cachedAt: now - 300,
            staleAfterSeconds: 120,
            report: Self.report(
                fiveHourUsedPercent: 42,
                fiveHourResetsAt: now + 3_600,
                weeklyUsedPercent: 64,
                weeklyResetsAt: now + 604_800
            )
        )

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.state, .stale)
        XCTAssertEqual(Set(schedule.entries.map(\.trustState)), [.stale])
        XCTAssertEqual(schedule.trustSummary, "마지막 확인 기준")
    }

    func testKeepsAdditionalBucketsInAdvancedEntries() throws {
        let now = 1_800_000_000
        let codex = Self.limit(
            id: "codex",
            fiveHourUsedPercent: 20,
            fiveHourResetsAt: now + 3_600,
            weeklyUsedPercent: 35,
            weeklyResetsAt: now + 604_800
        )
        let extra = Self.limit(
            id: "codex_bengalfox",
            fiveHourUsedPercent: 70,
            fiveHourResetsAt: now + 1_800,
            weeklyUsedPercent: 80,
            weeklyResetsAt: now + 86_400
        )
        let report = CodexUsageReport(
            generatedAt: now,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: nil,
            limits: ["codex": codex, "codex_bengalfox": extra]
        )

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            report: report,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.primaryEntries.map(\.limitId), ["codex", "codex"])
        XCTAssertEqual(schedule.advancedEntries.map(\.limitId), ["codex_bengalfox", "codex_bengalfox"])
        XCTAssertEqual(schedule.advancedEntries.map(\.scope), [.advanced, .advanced])
    }

    func testReportsProtocolDriftWhenRequiredCodexWindowsAreMissing() throws {
        let now = 1_800_000_000
        let incomplete = UsageLimitReport(
            limitId: "codex",
            limitName: "Codex",
            primary: UsageWindowReport(
                kind: .fiveHour,
                usedPercent: 12,
                remainingPercent: 88,
                windowDurationMins: 300,
                resetsAt: now + 3_600
            ),
            secondary: nil,
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
        let report = CodexUsageReport(
            generatedAt: now,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: nil,
            limits: ["codex": incomplete]
        )

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            report: report,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.state, .protocolDrift)
        XCTAssertTrue(schedule.primaryEntries.isEmpty)
        XCTAssertEqual(schedule.summaryText, "필수 5시간/주간 window 확인 필요")
    }

    func testReportsErrorStateButUsesLastSuccessReportWhenPresent() throws {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(
                fiveHourUsedPercent: 42,
                fiveHourResetsAt: now + 3_600,
                weeklyUsedPercent: 64,
                weeklyResetsAt: now + 604_800
            ),
            error: CodexUsageCacheError(message: "network unavailable", recordedAt: now)
        )

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.state, .error)
        XCTAssertEqual(Set(schedule.entries.map(\.trustState)), [.error])
        XCTAssertEqual(schedule.trustSummary, "오류 상태 함께 표시")
        XCTAssertFalse(schedule.primaryEntries.isEmpty)
    }

    private static func snapshot(
        cachedAt: Int,
        staleAfterSeconds: Int,
        report: CodexUsageReport?,
        error: CodexUsageCacheError? = nil
    ) -> CodexUsageCacheSnapshot {
        CodexUsageCacheSnapshot(
            cachedAt: cachedAt,
            staleAfterSeconds: staleAfterSeconds,
            report: report,
            error: error
        )
    }

    private static func report(
        fiveHourUsedPercent: Double,
        fiveHourResetsAt: Int,
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int
    ) -> CodexUsageReport {
        CodexUsageReport(
            generatedAt: 0,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: nil,
            limits: [
                "codex": limit(
                    id: "codex",
                    fiveHourUsedPercent: fiveHourUsedPercent,
                    fiveHourResetsAt: fiveHourResetsAt,
                    weeklyUsedPercent: weeklyUsedPercent,
                    weeklyResetsAt: weeklyResetsAt
                )
            ]
        )
    }

    private static func limit(
        id: String,
        fiveHourUsedPercent: Double,
        fiveHourResetsAt: Int,
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int
    ) -> UsageLimitReport {
        UsageLimitReport(
            limitId: id,
            limitName: id,
            primary: UsageWindowReport(
                kind: .fiveHour,
                usedPercent: fiveHourUsedPercent,
                remainingPercent: 100 - fiveHourUsedPercent,
                windowDurationMins: 300,
                resetsAt: fiveHourResetsAt
            ),
            secondary: UsageWindowReport(
                kind: .weekly,
                usedPercent: weeklyUsedPercent,
                remainingPercent: 100 - weeklyUsedPercent,
                windowDurationMins: 10_080,
                resetsAt: weeklyResetsAt
            ),
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
swift test --filter CodexUsageResetScheduleTests
```

Expected: FAIL because `CodexUsageResetScheduleBuilder` is not defined.

- [ ] **Step 3: Implement reset schedule model**

Create `Sources/CodexUsageCore/Usage/CodexUsageResetSchedule.swift`:

```swift
import Foundation

public enum CodexUsageResetScheduleState: String, Equatable, Sendable {
    case ok
    case waiting
    case stale
    case error
    case protocolDrift
}

public enum CodexUsageResetScheduleTrustState: String, Equatable, Sendable {
    case fresh
    case stale
    case error
    case waiting
}

public enum CodexUsageResetScheduleEntryScope: String, Equatable, Sendable {
    case primary
    case advanced
}

public struct CodexUsageResetSchedule: Equatable, Sendable {
    public let state: CodexUsageResetScheduleState
    public let entries: [CodexUsageResetScheduleEntry]

    public init(
        state: CodexUsageResetScheduleState,
        entries: [CodexUsageResetScheduleEntry]
    ) {
        self.state = state
        self.entries = entries
    }

    public var primaryEntries: [CodexUsageResetScheduleEntry] {
        entries.filter { $0.scope == .primary }
    }

    public var advancedEntries: [CodexUsageResetScheduleEntry] {
        entries.filter { $0.scope == .advanced }
    }

    public var nextRecovery: CodexUsageResetScheduleEntry? {
        primaryEntries.first { $0.isNextRecovery }
    }

    public var trustSummary: String {
        switch state {
        case .ok:
            return "최신 기준"
        case .waiting:
            return "사용량 데이터 대기"
        case .stale:
            return "마지막 확인 기준"
        case .error:
            return "오류 상태 함께 표시"
        case .protocolDrift:
            return "프로토콜 확인 필요"
        }
    }

    public var summaryText: String {
        switch state {
        case .protocolDrift:
            return "필수 5시간/주간 window 확인 필요"
        case .waiting:
            return "회복 일정 대기"
        case .ok, .stale, .error:
            guard let nextRecovery else {
                return "회복 카드 \(primaryEntries.count)장"
            }
            return "회복 카드 \(primaryEntries.count)장 · 다음 \(nextRecovery.title) \(Self.relativeTime(nextRecovery.remainingSeconds))"
        }
    }

    private static func relativeTime(_ seconds: Int?) -> String {
        guard let seconds else { return "시각 확인 불가" }
        if seconds <= 0 { return "곧" }
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours > 0, minutes > 0 {
            return "\(hours)시간 \(minutes)분 후"
        }
        if hours > 0 {
            return "\(hours)시간 후"
        }
        return "\(max(minutes, 1))분 후"
    }
}

public struct CodexUsageResetScheduleEntry: Equatable, Identifiable, Sendable {
    public let id: String
    public let limitId: String
    public let limitName: String?
    public let title: String
    public let kind: UsageWindowKind
    public let scope: CodexUsageResetScheduleEntryScope
    public let windowDurationMins: Int?
    public let resetsAt: Int?
    public let remainingSeconds: Int?
    public let usedPercent: Double
    public let remainingPercent: Double
    public let trustState: CodexUsageResetScheduleTrustState
    public let isNextRecovery: Bool

    public init(
        id: String,
        limitId: String,
        limitName: String?,
        title: String,
        kind: UsageWindowKind,
        scope: CodexUsageResetScheduleEntryScope,
        windowDurationMins: Int?,
        resetsAt: Int?,
        remainingSeconds: Int?,
        usedPercent: Double,
        remainingPercent: Double,
        trustState: CodexUsageResetScheduleTrustState,
        isNextRecovery: Bool
    ) {
        self.id = id
        self.limitId = limitId
        self.limitName = limitName
        self.title = title
        self.kind = kind
        self.scope = scope
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
        self.remainingSeconds = remainingSeconds
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.trustState = trustState
        self.isNextRecovery = isNextRecovery
    }
}

public struct CodexUsageResetScheduleBuilder: Sendable {
    public init() {}

    public func schedule(
        snapshot: CodexUsageCacheSnapshot?,
        now: Date = Date()
    ) -> CodexUsageResetSchedule {
        schedule(
            report: snapshot?.report,
            cacheState: cacheState(snapshot: snapshot, now: now),
            now: now
        )
    }

    public func schedule(
        report: CodexUsageReport?,
        now: Date = Date()
    ) -> CodexUsageResetSchedule {
        schedule(report: report, cacheState: .ok, now: now)
    }

    private func schedule(
        report: CodexUsageReport?,
        cacheState: CodexUsageResetScheduleState,
        now: Date
    ) -> CodexUsageResetSchedule {
        guard let report else {
            return CodexUsageResetSchedule(state: cacheState == .error ? .error : .waiting, entries: [])
        }
        guard let codex = report.limits["codex"], codex.hasRequiredCodexUsageWindows else {
            return CodexUsageResetSchedule(state: .protocolDrift, entries: [])
        }

        let trustState = trustState(for: cacheState)
        let primary = entries(
            limitId: "codex",
            limit: codex,
            scope: .primary,
            trustState: trustState,
            now: now
        )
        let advanced = report.limits
            .filter { $0.key != "codex" }
            .sorted { $0.key < $1.key }
            .flatMap { key, limit in
                entries(
                    limitId: key,
                    limit: limit,
                    scope: .advanced,
                    trustState: trustState,
                    now: now
                )
            }

        let markedPrimary = markNextRecovery(primary)
        return CodexUsageResetSchedule(
            state: cacheState,
            entries: markedPrimary + advanced
        )
    }

    private func entries(
        limitId: String,
        limit: UsageLimitReport,
        scope: CodexUsageResetScheduleEntryScope,
        trustState: CodexUsageResetScheduleTrustState,
        now: Date
    ) -> [CodexUsageResetScheduleEntry] {
        [limit.fiveHour, limit.weekly]
            .compactMap(\.self)
            .compactMap { window in
                makeEntry(
                    limitId: limitId,
                    limitName: limit.limitName,
                    window: window,
                    scope: scope,
                    trustState: trustState,
                    isNextRecovery: false,
                    now: now
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.resetsAt, rhs.resetsAt) {
                case let (.some(left), .some(right)):
                    return left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.title < rhs.title
                }
            }
    }

    private func makeEntry(
        limitId: String,
        limitName: String?,
        window: UsageWindowReport,
        scope: CodexUsageResetScheduleEntryScope,
        trustState: CodexUsageResetScheduleTrustState,
        isNextRecovery: Bool,
        now: Date
    ) -> CodexUsageResetScheduleEntry? {
        let title = title(for: window)
        let remainingSeconds = window.resetsAt.map {
            max(0, $0 - Int(now.timeIntervalSince1970))
        }
        let id = [
            limitId,
            window.kind.rawValue,
            window.resetsAt.map(String.init) ?? "unknown"
        ].joined(separator: ".")
        return CodexUsageResetScheduleEntry(
            id: id,
            limitId: limitId,
            limitName: limitName,
            title: title,
            kind: window.kind,
            scope: scope,
            windowDurationMins: window.windowDurationMins,
            resetsAt: window.resetsAt,
            remainingSeconds: remainingSeconds,
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            trustState: trustState,
            isNextRecovery: isNextRecovery
        )
    }

    private func markNextRecovery(
        _ entries: [CodexUsageResetScheduleEntry]
    ) -> [CodexUsageResetScheduleEntry] {
        guard let firstID = entries.first?.id else { return entries }
        return entries.map { entry in
            CodexUsageResetScheduleEntry(
                id: entry.id,
                limitId: entry.limitId,
                limitName: entry.limitName,
                title: entry.title,
                kind: entry.kind,
                scope: entry.scope,
                windowDurationMins: entry.windowDurationMins,
                resetsAt: entry.resetsAt,
                remainingSeconds: entry.remainingSeconds,
                usedPercent: entry.usedPercent,
                remainingPercent: entry.remainingPercent,
                trustState: entry.trustState,
                isNextRecovery: entry.id == firstID
            )
        }
    }

    private func title(for window: UsageWindowReport) -> String {
        switch window.kind {
        case .fiveHour:
            return "5시간"
        case .weekly:
            return "주간"
        case .other:
            return window.windowDurationMins.map { "\($0)분" } ?? "기타"
        }
    }

    private func cacheState(
        snapshot: CodexUsageCacheSnapshot?,
        now: Date
    ) -> CodexUsageResetScheduleState {
        guard let snapshot else { return .ok }
        if snapshot.error != nil { return .error }
        if snapshot.isStale(now: now) { return .stale }
        return snapshot.report == nil ? .waiting : .ok
    }

    private func trustState(
        for state: CodexUsageResetScheduleState
    ) -> CodexUsageResetScheduleTrustState {
        switch state {
        case .ok:
            return .fresh
        case .stale:
            return .stale
        case .error:
            return .error
        case .waiting, .protocolDrift:
            return .waiting
        }
    }
}
```

- [ ] **Step 4: Run reset schedule tests**

Run:

```sh
swift test --filter CodexUsageResetScheduleTests
```

Expected: PASS.

- [ ] **Step 5: Run existing report tests**

Run:

```sh
swift test --filter CodexUsageReportTests
```

Expected: PASS.

- [ ] **Step 6: Commit Task 2**

```sh
git add Sources/CodexUsageCore/Usage/CodexUsageResetSchedule.swift Tests/CodexUsageCoreTests/CodexUsageResetScheduleTests.swift
git commit -m "feat: add codex reset schedule model"
```

## Task 3: Session Plan Core Model

**Files:**

- Create: `Sources/CodexUsageCore/Usage/CodexUsageSessionPlan.swift`
- Create: `Tests/CodexUsageCoreTests/CodexUsageSessionPlanTests.swift`
- Test: `Tests/CodexUsageCoreTests/UsagePaceProjectionTests.swift`

- [ ] **Step 1: Write failing session plan tests**

Create `Tests/CodexUsageCoreTests/CodexUsageSessionPlanTests.swift`:

```swift
import XCTest
@testable import CodexUsageCore

final class CodexUsageSessionPlanTests: XCTestCase {
    func testBuildsSafeOneHourPlanFromProjectedPace() throws {
        let now = 1_800_000_000
        let resetsAt = now + 6 * 60 * 60
        let snapshot = Self.snapshot(
            cachedAt: now,
            report: Self.report(weeklyUsedPercent: 40, weeklyResetsAt: resetsAt)
        )
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 35,
            resetsAt: resetsAt
        )

        let plan = CodexUsageSessionPlanBuilder().plan(
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            duration: .oneHour,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(plan.state, .safe)
        XCTAssertEqual(plan.duration, .oneHour)
        XCTAssertEqual(plan.projectedUsedPercentAtEnd, 45)
        XCTAssertEqual(plan.title, "1시간 작업 여유")
    }

    func testBuildsWatchPlanNearHighUsageThreshold() throws {
        let now = 1_800_000_000
        let resetsAt = now + 6 * 60 * 60
        let snapshot = Self.snapshot(
            cachedAt: now,
            report: Self.report(weeklyUsedPercent: 78, weeklyResetsAt: resetsAt)
        )
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 73,
            resetsAt: resetsAt
        )

        let plan = CodexUsageSessionPlanBuilder().plan(
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            duration: .oneHour,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(plan.state, .watch)
        XCTAssertEqual(plan.projectedUsedPercentAtEnd, 83)
        XCTAssertEqual(plan.title, "1시간 작업 주의")
    }

    func testBuildsRiskyPlanNearLimitThreshold() throws {
        let now = 1_800_000_000
        let resetsAt = now + 6 * 60 * 60
        let snapshot = Self.snapshot(
            cachedAt: now,
            report: Self.report(weeklyUsedPercent: 94, weeklyResetsAt: resetsAt)
        )
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 89,
            resetsAt: resetsAt
        )

        let plan = CodexUsageSessionPlanBuilder().plan(
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            duration: .oneHour,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(plan.state, .risky)
        XCTAssertEqual(plan.projectedUsedPercentAtEnd, 99)
        XCTAssertEqual(plan.title, "1시간 작업 위험")
    }

    func testUsesResetRemainingSecondsForUntilResetDuration() throws {
        let now = 1_800_000_000
        let resetsAt = now + 2 * 60 * 60
        let snapshot = Self.snapshot(
            cachedAt: now,
            report: Self.report(weeklyUsedPercent: 50, weeklyResetsAt: resetsAt)
        )
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 45,
            resetsAt: resetsAt
        )

        let plan = CodexUsageSessionPlanBuilder().plan(
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            duration: .untilReset,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(plan.durationSeconds, 7_200)
        XCTAssertEqual(plan.projectedUsedPercentAtEnd, 60)
    }

    func testSeparatesUnavailableStates() throws {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(
            cachedAt: now - 300,
            report: Self.report(weeklyUsedPercent: 40, weeklyResetsAt: now + 3_600),
            staleAfterSeconds: 120
        )

        let plan = CodexUsageSessionPlanBuilder().plan(
            snapshot: snapshot,
            weeklyHistory: .empty,
            duration: .oneHour,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(plan.state, .unavailable)
        XCTAssertEqual(plan.title, "작업 계획 대기")
    }

    private static func snapshot(
        cachedAt: Int,
        report: CodexUsageReport,
        staleAfterSeconds: Int = 120
    ) -> CodexUsageCacheSnapshot {
        CodexUsageCacheSnapshot(
            cachedAt: cachedAt,
            staleAfterSeconds: staleAfterSeconds,
            report: report,
            error: nil
        )
    }

    private static func weeklySample(
        recordedAt: Int,
        usedPercent: Double,
        resetsAt: Int
    ) -> CodexUsageWeeklyHistorySample {
        CodexUsageWeeklyHistorySample(
            recordedAt: recordedAt,
            usedPercent: usedPercent,
            remainingPercent: 100 - usedPercent,
            resetsAt: resetsAt,
            windowDurationMins: 10_080
        )
    }

    private static func report(
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int
    ) -> CodexUsageReport {
        let fiveHour = UsageWindowReport(
            kind: .fiveHour,
            usedPercent: 12,
            remainingPercent: 88,
            windowDurationMins: 300,
            resetsAt: weeklyResetsAt - 7 * 24 * 60 * 60 + 5 * 60 * 60
        )
        let weekly = UsageWindowReport(
            kind: .weekly,
            usedPercent: weeklyUsedPercent,
            remainingPercent: 100 - weeklyUsedPercent,
            windowDurationMins: 10_080,
            resetsAt: weeklyResetsAt
        )
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: "Codex",
            primary: fiveHour,
            secondary: weekly,
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
        return CodexUsageReport(
            generatedAt: 0,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: nil,
            limits: ["codex": limit]
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
swift test --filter CodexUsageSessionPlanTests
```

Expected: FAIL because `CodexUsageSessionPlanBuilder` is not defined.

- [ ] **Step 3: Implement session plan model**

Create `Sources/CodexUsageCore/Usage/CodexUsageSessionPlan.swift`:

```swift
import Foundation

public enum CodexUsageSessionPlanDuration: String, CaseIterable, Equatable, Identifiable, Sendable {
    case oneHour
    case threeHours
    case untilReset

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .oneHour:
            return "1시간"
        case .threeHours:
            return "3시간"
        case .untilReset:
            return "reset까지"
        }
    }
}

public enum CodexUsageSessionPlanState: String, Equatable, Sendable {
    case safe
    case watch
    case risky
    case unavailable
}

public struct CodexUsageSessionPlan: Equatable, Sendable {
    public let duration: CodexUsageSessionPlanDuration
    public let durationSeconds: Int?
    public let state: CodexUsageSessionPlanState
    public let currentUsedPercent: Double?
    public let projectedUsedPercentAtEnd: Double?
    public let usedPercentPerHour: Double?
    public let sampleCount: Int

    public init(
        duration: CodexUsageSessionPlanDuration,
        durationSeconds: Int?,
        state: CodexUsageSessionPlanState,
        currentUsedPercent: Double?,
        projectedUsedPercentAtEnd: Double?,
        usedPercentPerHour: Double?,
        sampleCount: Int
    ) {
        self.duration = duration
        self.durationSeconds = durationSeconds
        self.state = state
        self.currentUsedPercent = currentUsedPercent
        self.projectedUsedPercentAtEnd = projectedUsedPercentAtEnd
        self.usedPercentPerHour = usedPercentPerHour
        self.sampleCount = sampleCount
    }

    public var title: String {
        switch state {
        case .safe:
            return "\(duration.label) 작업 여유"
        case .watch:
            return "\(duration.label) 작업 주의"
        case .risky:
            return "\(duration.label) 작업 위험"
        case .unavailable:
            return "작업 계획 대기"
        }
    }

    public var detail: String {
        guard let projectedUsedPercentAtEnd else {
            return "샘플이 더 쌓이면 예상 사용률을 표시합니다."
        }
        return "예상 사용률 \(Self.percent(projectedUsedPercentAtEnd))%"
    }

    private static func percent(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

public struct CodexUsageSessionPlanBuilder: Sendable {
    public init() {}

    public func plan(
        snapshot: CodexUsageCacheSnapshot?,
        weeklyHistory: CodexUsageWeeklyHistory,
        duration: CodexUsageSessionPlanDuration,
        now: Date = Date()
    ) -> CodexUsageSessionPlan {
        guard let snapshot else {
            return unavailable(duration: duration)
        }

        let projection = CodexUsagePaceProjectionBuilder().projection(
            snapshot: snapshot,
            weeklyHistory: weeklyHistory,
            now: now
        )
        guard projection.state == .projected,
              let currentUsedPercent = projection.currentUsedPercent,
              let usedPercentPerHour = projection.usedPercentPerHour
        else {
            return CodexUsageSessionPlan(
                duration: duration,
                durationSeconds: nil,
                state: .unavailable,
                currentUsedPercent: projection.currentUsedPercent,
                projectedUsedPercentAtEnd: nil,
                usedPercentPerHour: nil,
                sampleCount: projection.sampleCount
            )
        }

        let durationSeconds = durationSeconds(for: duration, projection: projection)
        let projected = min(
            max(
                currentUsedPercent + (usedPercentPerHour / 3_600) * Double(durationSeconds),
                0
            ),
            100
        )

        return CodexUsageSessionPlan(
            duration: duration,
            durationSeconds: durationSeconds,
            state: state(forProjectedUsedPercent: projected),
            currentUsedPercent: currentUsedPercent,
            projectedUsedPercentAtEnd: projected,
            usedPercentPerHour: usedPercentPerHour,
            sampleCount: projection.sampleCount
        )
    }

    private func durationSeconds(
        for duration: CodexUsageSessionPlanDuration,
        projection: CodexUsagePaceProjection
    ) -> Int {
        switch duration {
        case .oneHour:
            return 3_600
        case .threeHours:
            return 10_800
        case .untilReset:
            return projection.remainingSeconds ?? 0
        }
    }

    private func state(
        forProjectedUsedPercent projected: Double
    ) -> CodexUsageSessionPlanState {
        switch projected {
        case ..<80:
            return .safe
        case 80..<95:
            return .watch
        default:
            return .risky
        }
    }

    private func unavailable(
        duration: CodexUsageSessionPlanDuration
    ) -> CodexUsageSessionPlan {
        CodexUsageSessionPlan(
            duration: duration,
            durationSeconds: nil,
            state: .unavailable,
            currentUsedPercent: nil,
            projectedUsedPercentAtEnd: nil,
            usedPercentPerHour: nil,
            sampleCount: 0
        )
    }
}
```

- [ ] **Step 4: Run session plan tests**

Run:

```sh
swift test --filter CodexUsageSessionPlanTests
swift test --filter UsagePaceProjectionTests
```

Expected: both commands PASS.

- [ ] **Step 5: Commit Task 3**

```sh
git add Sources/CodexUsageCore/Usage/CodexUsageSessionPlan.swift Tests/CodexUsageCoreTests/CodexUsageSessionPlanTests.swift
git commit -m "feat: add codex session planning model"
```

## Task 4: Formatter and CLI Reset Summary

**Files:**

- Modify: `Sources/CodexUsageCore/Usage/CodexUsageFormatter.swift`
- Modify: `Sources/CodexUsageCLI/main.swift`
- Modify: `Tests/CodexUsageCoreTests/CodexUsageReportTests.swift`

- [ ] **Step 1: Add failing formatter test**

Add this test to `Tests/CodexUsageCoreTests/CodexUsageReportTests.swift`:

```swift
func testFormatsResetScheduleInTextReportWithoutChangingJSON() throws {
    let response = try loadFixture()
    let report = try CodexUsageReportBuilder(dateProvider: {
        Date(timeIntervalSince1970: 1_779_700_000)
    }).build(from: response)
    let formatter = CodexUsageFormatter(
        timeZone: TimeZone(secondsFromGMT: 9 * 60 * 60)!,
        locale: Locale(identifier: "en_US_POSIX"),
        now: { Date(timeIntervalSince1970: 1_779_700_000) }
    )

    let text = formatter.text(from: report)
    let json = String(decoding: try formatter.json(from: report), as: UTF8.self)

    XCTAssertTrue(text.contains("Recovery cards: 2"))
    XCTAssertTrue(text.contains("Next reset:"))
    XCTAssertTrue(text.contains("Weekly reset:"))
    XCTAssertFalse(json.contains("Recovery cards"))
    XCTAssertFalse(json.contains("Next reset"))
}
```

- [ ] **Step 2: Run formatter test to verify it fails**

Run:

```sh
swift test --filter CodexUsageReportTests/testFormatsResetScheduleInTextReportWithoutChangingJSON
```

Expected: FAIL because `CodexUsageFormatter` has no `now` initializer argument and no reset summary lines.

- [ ] **Step 3: Extend formatter initializer and text output**

Modify `Sources/CodexUsageCore/Usage/CodexUsageFormatter.swift`.

Update the struct properties and initializer:

```swift
public struct CodexUsageFormatter: Sendable {
    private let timeZone: TimeZone
    private let locale: Locale
    private let now: @Sendable () -> Date

    public init(
        timeZone: TimeZone = .current,
        locale: Locale = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.timeZone = timeZone
        self.locale = locale
        self.now = now
    }
```

Add these lines in `text(from:)` after the `Plan:` line and before limit status:

```swift
let schedule = CodexUsageResetScheduleBuilder().schedule(report: report, now: now())
lines.append(contentsOf: resetScheduleLines(from: schedule))
```

Add helper methods inside `CodexUsageFormatter`:

```swift
private func resetScheduleLines(
    from schedule: CodexUsageResetSchedule
) -> [String] {
    guard !schedule.primaryEntries.isEmpty else {
        return ["Recovery cards: 0"]
    }

    var lines = ["Recovery cards: \(schedule.primaryEntries.count)"]
    if let next = schedule.nextRecovery {
        lines.append("Next reset: \(next.title) \(formatResetEntry(next))")
    }
    if let weekly = schedule.primaryEntries.first(where: { $0.kind == .weekly }) {
        lines.append("Weekly reset: \(formatResetEntry(weekly))")
    }
    return lines
}

private func formatResetEntry(
    _ entry: CodexUsageResetScheduleEntry
) -> String {
    let reset = entry.resetsAt.map(formatEpoch) ?? "unknown"
    let remaining = entry.remainingSeconds.map(formatDuration) ?? "remaining unknown"
    return "\(reset) (\(remaining))"
}

private func formatDuration(_ seconds: Int) -> String {
    if seconds <= 0 {
        return "now"
    }
    let hours = seconds / 3_600
    let minutes = (seconds % 3_600) / 60
    if hours > 0, minutes > 0 {
        return "in \(hours)h \(minutes)m"
    }
    if hours > 0 {
        return "in \(hours)h"
    }
    return "in \(max(minutes, 1))m"
}
```

- [ ] **Step 4: Update CLI help copy**

Modify `Sources/CodexUsageCLI/main.swift` help text command description:

```swift
static let help = """
Usage:
  codex-usage status [--json] [--write-cache] [--mirror-cache] [--cache-path PATH] [--timeout SECONDS] [--watch SECONDS]
  codex-usage doctor

Commands:
  status   Print current Codex usage and reset schedule.
  doctor   Check Codex CLI and app-server usage access.
"""
```

- [ ] **Step 5: Run formatter and CLI tests**

Run:

```sh
swift test --filter CodexUsageReportTests
swift test --filter CodexUsageResetScheduleTests
```

Expected: both commands PASS.

- [ ] **Step 6: Commit Task 4**

```sh
git add Sources/CodexUsageCore/Usage/CodexUsageFormatter.swift Sources/CodexUsageCLI/main.swift Tests/CodexUsageCoreTests/CodexUsageReportTests.swift
git commit -m "feat: show codex reset schedule in cli text"
```

## Task 5: App State, Tooltip, and Pet Menu Glance

**Files:**

- Modify: `Sources/MacDog/UsageMonitorState.swift`
- Modify: `Sources/MacDog/MenuBarController.swift`
- Modify: `Sources/MacDog/PetMenuModel.swift`
- Modify: `Tests/MacDogTests/UsageMonitorStateTests.swift`
- Modify: `Tests/MacDogTests/PetMenuModelTests.swift`

- [ ] **Step 1: Add failing UsageMonitorState tests**

Add these tests to `Tests/MacDogTests/UsageMonitorStateTests.swift`:

```swift
func testCodexResetScheduleUsesCacheTrustState() throws {
    let now = 1_800_000_000
    let state = UsageMonitorState(
        report: Self.report(fiveHourResetsAt: now + 3_600, weeklyResetsAt: now + 604_800),
        cacheSnapshot: CodexUsageCacheSnapshot(
            cachedAt: now - 300,
            staleAfterSeconds: 120,
            report: Self.report(fiveHourResetsAt: now + 3_600, weeklyResetsAt: now + 604_800),
            error: nil
        ),
        errorMessage: nil
    )

    let schedule = state.codexResetSchedule(now: Date(timeIntervalSince1970: TimeInterval(now)))

    XCTAssertEqual(schedule.state, .stale)
    XCTAssertEqual(schedule.primaryEntries.map(\.title), ["5시간", "주간"])
}

func testNextResetTooltipSummary() throws {
    let now = 1_800_000_000
    let state = UsageMonitorState(
        report: Self.report(fiveHourResetsAt: now + 3_600, weeklyResetsAt: now + 604_800),
        cacheSnapshot: nil,
        errorMessage: nil
    )

    XCTAssertEqual(
        state.nextResetGlance(now: Date(timeIntervalSince1970: TimeInterval(now))),
        "다음 초기화: 5시간 1시간 후"
    )
}
```

Add helper if `UsageMonitorStateTests` does not already have one:

```swift
private static func report(
    fiveHourResetsAt: Int,
    weeklyResetsAt: Int
) -> CodexUsageReport {
    let limit = UsageLimitReport(
        limitId: "codex",
        limitName: "Codex",
        primary: UsageWindowReport(
            kind: .fiveHour,
            usedPercent: 42,
            remainingPercent: 58,
            windowDurationMins: 300,
            resetsAt: fiveHourResetsAt
        ),
        secondary: UsageWindowReport(
            kind: .weekly,
            usedPercent: 64,
            remainingPercent: 36,
            windowDurationMins: 10_080,
            resetsAt: weeklyResetsAt
        ),
        credits: nil,
        planType: "pro",
        rateLimitReachedType: nil
    )
    return CodexUsageReport(
        generatedAt: 0,
        source: "test",
        planType: "pro",
        credits: nil,
        rateLimitReachedType: nil,
        limits: ["codex": limit]
    )
}
```

- [ ] **Step 2: Add failing pet menu test**

Add to `Tests/MacDogTests/PetMenuModelTests.swift`:

```swift
func testMenuModelIncludesNextResetGlanceWhenProvided() {
    let preferences = RunnerPreferences(defaults: defaults)
    let model = PetMenuModel(
        preferences: preferences,
        surface: .menuBar,
        nextResetGlance: "다음 초기화: 5시간 1시간 후"
    )

    XCTAssertTrue(model.commands.contains(PetMenuCommand(
        title: "다음 초기화: 5시간 1시간 후",
        action: .showUsageDetails,
        isEnabled: false
    )))
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```sh
swift test --filter UsageMonitorStateTests
swift test --filter PetMenuModelTests
```

Expected: FAIL because `codexResetSchedule`, `nextResetGlance`, and the new `PetMenuModel` initializer are not defined.

- [ ] **Step 4: Add UsageMonitorState helpers**

Modify `Sources/MacDog/UsageMonitorState.swift`:

```swift
func codexResetSchedule(now: Date = Date()) -> CodexUsageResetSchedule {
    if let cacheSnapshot {
        return CodexUsageResetScheduleBuilder().schedule(snapshot: cacheSnapshot, now: now)
    }
    return CodexUsageResetScheduleBuilder().schedule(report: report, now: now)
}

func codexSessionPlan(
    duration: CodexUsageSessionPlanDuration,
    now: Date = Date()
) -> CodexUsageSessionPlan {
    CodexUsageSessionPlanBuilder().plan(
        snapshot: cacheSnapshot,
        weeklyHistory: weeklyUsageHistory,
        duration: duration,
        now: now
    )
}

func nextResetGlance(now: Date = Date()) -> String? {
    let schedule = codexResetSchedule(now: now)
    guard let next = schedule.nextRecovery else { return nil }
    return "다음 초기화: \(next.title) \(Self.relativeDuration(next.remainingSeconds))"
}

private static func relativeDuration(_ seconds: Int?) -> String {
    guard let seconds else { return "시각 확인 불가" }
    if seconds <= 0 { return "곧" }
    let hours = seconds / 3_600
    let minutes = (seconds % 3_600) / 60
    if hours > 0, minutes > 0 {
        return "\(hours)시간 \(minutes)분 후"
    }
    if hours > 0 {
        return "\(hours)시간 후"
    }
    return "\(max(minutes, 1))분 후"
}
```

- [ ] **Step 5: Add pet menu glance**

Modify `Sources/MacDog/PetMenuModel.swift`.

Change initializer signature:

```swift
init(
    preferences: RunnerPreferences,
    surface: PetSurface,
    nextResetGlance: String? = nil
) {
```

Change entries construction to insert the disabled glance after `사용량 상세 보기`:

```swift
var entries: [PetMenuEntry] = [
    .command(PetMenuCommand(title: "사용량 상세 보기", action: .showUsageDetails))
]
if let nextResetGlance {
    entries.append(.command(PetMenuCommand(
        title: nextResetGlance,
        action: .showUsageDetails,
        isEnabled: false
    )))
}
entries.append(contentsOf: [
    .command(PetMenuCommand(title: "캐시 다시 읽기", action: .refreshNow)),
    .separator,
    .submenu(Self.speedSubmenu(preferences: preferences)),
    .command(PetMenuCommand(
        title: "움직임 줄이기",
        action: .setReducedMotion(!preferences.reducedMotion),
        isSelected: preferences.reducedMotion
    )),
    .command(PetMenuCommand(
        title: "애니메이션 일시 정지",
        action: .setAnimationPaused(!preferences.animationPaused),
        isSelected: preferences.animationPaused
    )),
    .submenu(Self.sleepModeSubmenu(preferences: preferences)),
    .submenu(Self.sleepDurationSubmenu(preferences: preferences)),
    .submenu(Self.sleepPolicySubmenu(preferences: preferences)),
    .submenu(Self.sleepTriggerSubmenu(preferences: preferences)),
    .command(PetMenuCommand(title: "배터리 설정 열기", action: .openBatterySettings)),
    .separator,
    .command(Self.surfaceSwitchCommand(preferences: preferences, surface: surface)),
    .separator,
    .command(PetMenuCommand(title: "코덱스 사용량 종료", action: .quit))
])
self.title = "코덱스 펫"
self.entries = entries
```

- [ ] **Step 6: Wire tooltip and menu model**

Modify `Sources/MacDog/MenuBarController.swift` where tooltip and menu are built.

When setting tooltip in `applyState`, use:

```swift
statusItem.button?.toolTip = [
    state.toolTip,
    state.nextResetGlance()
]
.compactMap(\.self)
.joined(separator: "\n")
```

When creating `PetMenuModel`, pass:

```swift
PetMenuModel(
    preferences: preferences,
    surface: surface,
    nextResetGlance: state.nextResetGlance()
)
```

- [ ] **Step 7: Run app state tests**

Run:

```sh
swift test --filter UsageMonitorStateTests
swift test --filter PetMenuModelTests
```

Expected: both commands PASS.

- [ ] **Step 8: Commit Task 5**

```sh
git add Sources/MacDog/UsageMonitorState.swift Sources/MacDog/MenuBarController.swift Sources/MacDog/PetMenuModel.swift Tests/MacDogTests/UsageMonitorStateTests.swift Tests/MacDogTests/PetMenuModelTests.swift
git commit -m "feat: add next reset app glance"
```

## Task 6: Codex Tab Recovery Planner UI

**Files:**

- Create: `Sources/MacDog/Popover/CodexRecoveryPlannerViews.swift`
- Modify: `Sources/MacDog/Popover/CodexUsagePanel.swift`
- Modify: `Sources/MacDog/MacDogDemoData.swift`
- Modify: `Tests/MacDogTests/PopoverScreenshotRendererTests.swift`

- [ ] **Step 1: Add UI file with recovery card views**

Create `Sources/MacDog/Popover/CodexRecoveryPlannerViews.swift`:

```swift
import CodexUsageCore
import SwiftUI

struct CodexRecoveryPlannerBlock: View {
    let schedule: CodexUsageResetSchedule
    let plan: CodexUsageSessionPlan
    let selectedDuration: Binding<CodexUsageSessionPlanDuration>

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CodexRecoveryCardsBlock(schedule: schedule)
            CodexSessionPlanBlock(plan: plan, selectedDuration: selectedDuration)
        }
    }
}

private struct CodexRecoveryCardsBlock: View {
    let schedule: CodexUsageResetSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("회복 일정")
                    .font(.caption.weight(.semibold))
                Text(schedule.summaryText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 0)
                Text(schedule.trustSummary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
            }

            if schedule.primaryEntries.isEmpty {
                Text(schedule.summaryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    ForEach(schedule.primaryEntries) { entry in
                        CodexRecoveryCard(entry: entry)
                    }
                }
            }
        }
    }

    private var tint: Color {
        switch schedule.state {
        case .ok:
            return .green
        case .waiting:
            return .secondary
        case .stale, .protocolDrift:
            return .orange
        case .error:
            return .red
        }
    }
}

private struct CodexRecoveryCard: View {
    let entry: CodexUsageResetScheduleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: entry.isNextRecovery ? "arrow.clockwise.circle.fill" : "clock")
                    .font(.caption2.weight(.semibold))
                Text(entry.title)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
            }
            Text(resetText)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            Text("잔여 \(UsageMonitorState.percent(entry.remainingPercent))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((entry.isNextRecovery ? Color.accentColor : Color.secondary).opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke((entry.isNextRecovery ? Color.accentColor : Color.secondary).opacity(0.22), lineWidth: 1)
        )
    }

    private var resetText: String {
        guard let resetsAt = entry.resetsAt else { return "초기화 시각 확인 불가" }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateFormat = "M월 d일 HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(resetsAt)))
    }
}

private struct CodexSessionPlanBlock: View {
    let plan: CodexUsageSessionPlan
    let selectedDuration: Binding<CodexUsageSessionPlanDuration>

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                Text(plan.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
            Picker("", selection: selectedDuration) {
                ForEach(CodexUsageSessionPlanDuration.allCases) { duration in
                    Text(duration.label).tag(duration)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)
            .labelsHidden()
            .frame(width: 138)
        }
    }

    private var tint: Color {
        switch plan.state {
        case .safe:
            return .green
        case .watch:
            return .orange
        case .risky:
            return .red
        case .unavailable:
            return .secondary
        }
    }
}
```

- [ ] **Step 2: Insert planner block into CodexUsagePanel**

Modify `Sources/MacDog/Popover/CodexUsagePanel.swift`.

Add state:

```swift
@State private var selectedPlanDuration: CodexUsageSessionPlanDuration = .oneHour
```

Insert after `CodexUsageDataStatusBlock(status: state.codexDataStatus)`:

```swift
CodexRecoveryPlannerBlock(
    schedule: state.codexResetSchedule(now: resetSummaryNow),
    plan: state.codexSessionPlan(duration: selectedPlanDuration, now: resetSummaryNow),
    selectedDuration: $selectedPlanDuration
)
```

- [ ] **Step 3: Update demo data for stable cards**

Modify `Sources/MacDog/MacDogDemoData.swift` only if the screenshot becomes crowded or reset cards show unstable dates.

Use this five-hour reset in `report(now:)`:

```swift
resetsAt: now + 7_200
```

Use the existing weekly reset:

```swift
resetsAt: weeklyResetTimestamp(now: now)
```

- [ ] **Step 4: Run focused UI build tests**

Run:

```sh
swift test --filter PopoverScreenshotRendererTests
swift test --filter UsageMonitorStateTests
```

Expected: tests compile and pass or screenshot tests skip when env vars are not set.

- [ ] **Step 5: Commit Task 6**

```sh
git add Sources/MacDog/Popover/CodexRecoveryPlannerViews.swift Sources/MacDog/Popover/CodexUsagePanel.swift Sources/MacDog/MacDogDemoData.swift Tests/MacDogTests/PopoverScreenshotRendererTests.swift
git commit -m "feat: add codex recovery cards UI"
```

## Task 7: Recovery-Aware Notification Copy

**Files:**

- Modify: `Sources/MacDog/UsageNotificationPolicy.swift`
- Modify: `Sources/MacDog/UsageNotificationDelivery.swift`
- Modify: `Sources/MacDog/UsageNotificationSettings.swift`
- Modify: `Tests/MacDogTests/UsageNotificationPolicyTests.swift`
- Create: `Tests/MacDogTests/UsageNotificationDeliveryTests.swift`
- Test: `Tests/MacDogTests/UsageNotificationSettingsTests.swift`

- [ ] **Step 1: Add failing notification policy test for stale cache skip**

Add to `Tests/MacDogTests/UsageNotificationPolicyTests.swift`:

```swift
func testDispatcherSkipsRecoveryNotificationsForStaleCache() async {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let state = Self.state(
        fiveHourUsedPercent: 88,
        fiveHourResetsAt: 1_800_001_800,
        weeklyUsedPercent: 64,
        weeklyResetsAt: 1_800_604_800
    )
    let staleSnapshot = CodexUsageCacheSnapshot(
        cachedAt: 1_799_999_000,
        staleAfterSeconds: 120,
        report: state.report,
        error: nil
    )
    let staleState = UsageMonitorState(
        report: state.report,
        cacheSnapshot: staleSnapshot,
        errorMessage: nil
    )
    let dispatcher = UsageNotificationDispatcher(
        authorizationClient: StaticUsageNotificationAuthorizationClient(status: .authorized),
        deliveryClient: RecordingUsageNotificationDeliveryClient(),
        dedupeStore: MemoryUsageNotificationDedupeStore(),
        now: { now }
    )

    let result = await dispatcher.dispatch(
        for: staleState,
        settings: UsageNotificationDeliverySettings(
            usageNotificationsEnabled: true,
            resetSoonNotificationsEnabled: true
        )
    )

    XCTAssertEqual(result.skipReason, .staleOrUnavailableCache)
}
```

Add these private test helpers to the same test file:

```swift
@MainActor
private final class RecordingUsageNotificationDeliveryClient: UsageNotificationDelivering {
    private(set) var delivered: [UsageNotificationContent] = []

    func deliver(_ content: UsageNotificationContent) async throws {
        delivered.append(content)
    }
}

private final class MemoryUsageNotificationDedupeStore: UsageNotificationDedupeStoring {
    private var ledger = UsageNotificationDedupeLedger()

    func loadLedger() -> UsageNotificationDedupeLedger {
        ledger
    }

    func saveLedger(_ ledger: UsageNotificationDedupeLedger) {
        self.ledger = ledger
    }
}
```

- [ ] **Step 2: Add failing notification copy assertion**

Add or update the delivery content test:

```swift
func testResetSoonNotificationUsesRecoveryCopy() {
    let candidate = UsageNotificationCandidate(
        event: .resetSoon,
        window: .fiveHour,
        usedPercent: 88,
        resetsAt: 1_800_001_800
    )

    XCTAssertEqual(candidate.notificationContent.title, "Codex 회복 임박")
    XCTAssertTrue(candidate.notificationContent.body.contains("5시간 한도가 곧 회복됩니다."))
}
```

Create `Tests/MacDogTests/UsageNotificationDeliveryTests.swift` with `@testable import MacDog`.
Make the `UsageNotificationCandidate.notificationContent` extension internal in Step 4.

- [ ] **Step 3: Run notification tests to verify failure**

Run:

```sh
swift test --filter UsageNotificationPolicyTests
swift test --filter UsageNotificationDeliveryTests
swift test --filter UsageNotificationSettingsTests
```

Expected: copy assertion FAIL until notification title/body are changed.

- [ ] **Step 4: Update recovery notification copy**

Modify `Sources/MacDog/UsageNotificationDelivery.swift`.

Change:

```swift
private extension UsageNotificationCandidate {
```

to:

```swift
extension UsageNotificationCandidate {
```

Change reset title:

```swift
case .resetSoon:
    "Codex 회복 임박"
```

Change reset body:

```swift
case .resetSoon:
    let reset = resetsAt.map { " 초기화 시각 \(Self.formatResetTime($0))" } ?? ""
    return "\(window.label) 한도가 곧 회복됩니다.\(reset)"
```

Add helper inside the private extension:

```swift
private static func formatResetTime(_ epoch: Int) -> String {
    let formatter = DateFormatter()
    formatter.locale = .current
    formatter.timeZone = .current
    formatter.dateFormat = "M월 d일 HH:mm"
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(epoch)))
}
```

- [ ] **Step 5: Update settings copy**

Modify `Sources/MacDog/UsageNotificationSettings.swift`.

Change authorized detail:

```swift
return resetSoonNotificationsEnabled
    ? "80%, 95%, 한도 도달, 회복 30분 전 기준을 확인합니다."
    : "80%, 95%, 한도 도달 기준을 확인합니다."
```

Change visible titles:

```swift
var visibleControlTitles: [String] {
    ["Codex 사용량 알림", "회복 30분 전 알림"]
}
```

- [ ] **Step 6: Run notification tests**

Run:

```sh
swift test --filter UsageNotificationPolicyTests
swift test --filter UsageNotificationDeliveryTests
swift test --filter UsageNotificationSettingsTests
```

Expected: all PASS.

- [ ] **Step 7: Commit Task 7**

```sh
git add Sources/MacDog/UsageNotificationPolicy.swift Sources/MacDog/UsageNotificationDelivery.swift Sources/MacDog/UsageNotificationSettings.swift Tests/MacDogTests/UsageNotificationPolicyTests.swift Tests/MacDogTests/UsageNotificationDeliveryTests.swift Tests/MacDogTests/UsageNotificationSettingsTests.swift
git commit -m "feat: refine codex recovery notifications"
```

## Task 8: Verification, Documentation, and Release Closure

**Files:**

- Modify: `script/verify_v160_codex_recovery_planner_contract.sh`
- Modify: `README.md`
- Modify: `ROADMAP.md`
- Modify: `Docs/V160CodexRecoveryPlanner.md`
- Modify: `Docs/V160ReleaseReadiness.md`
- Modify: `Docs/Scripts.md`
- Optional after explicit screenshot rendering approval: `Docs/Images/README/PopoverTabs/macdog-popover-codex.png`

- [ ] **Step 1: Finish verifier script**

Update `script/verify_v160_codex_recovery_planner_contract.sh` to run focused tests:

```bash
echo "==> Running v1.6 focused Swift tests"
swift test --filter CodexUsageResetScheduleTests
swift test --filter CodexUsageSessionPlanTests
swift test --filter UsageMonitorStateTests
swift test --filter UsageNotificationPolicyTests
swift test --filter PetMenuModelTests
swift test --filter PopoverScreenshotRendererTests
echo "v1.6 recovery planner contract ok"
```

Keep the source guard checks from Task 1.

- [ ] **Step 2: Run verifier self-test**

Run:

```sh
./script/verify_v160_codex_recovery_planner_contract.sh --self-test
```

Expected: PASS and output includes `v1.6 recovery planner contract ok`.

- [ ] **Step 3: Update README feature list after implementation**

Modify `README.md` current release or roadmap wording only after the code is implemented.

Add this bullet under 주요 기능:

```markdown
- Codex 회복 계획: 5시간/주간 초기화 카드, 다음 회복 시점, 작업 세션별 예상 사용률을 Codex 탭에서 확인합니다.
```

Do not mark v1.6.0 as the current GitHub Release until release publishing is actually complete.

- [ ] **Step 4: Update v1.6 docs with actual verification evidence**

In `Docs/V160CodexRecoveryPlanner.md`, change status:

```markdown
상태: P0-P2 구현 완료 / 자동 검증 완료 / 실제 UI smoke 미수행
```

Only use `실제 UI smoke 수행` if a menu bar popover was actually opened and inspected.

In `Docs/V160ReleaseReadiness.md`, add the exact commands that passed under `릴리즈 전 자동검증`.

- [ ] **Step 5: Run full required checks**

Run:

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v160_codex_recovery_planner_contract.sh --self-test
swift test --filter CodexUsageResetScheduleTests
swift test --filter CodexUsageSessionPlanTests
swift test --filter UsageMonitorStateTests
swift test --filter UsageNotificationPolicyTests
swift test --filter PetMenuModelTests
swift test --filter PopoverScreenshotRendererTests
swift test
```

Expected: all commands PASS.

- [ ] **Step 6: Run Xcode Debug build**

Run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

- [ ] **Step 7: Report UI status honestly**

If no GUI was opened, include:

```text
미실행:
- GUI 실행: 실행하지 않음
- UI 확인: 미수행
- 장시간 테스트: 실행하지 않음
```

If GUI smoke was explicitly approved and performed, include exact viewed surfaces and results.

- [ ] **Step 8: Commit Task 8**

```sh
git add README.md ROADMAP.md Docs/Scripts.md Docs/V160CodexRecoveryPlanner.md Docs/V160ReleaseReadiness.md script/verify_v160_codex_recovery_planner_contract.sh Docs/Images/README/PopoverTabs/macdog-popover-codex.png
git commit -m "docs: close v1.6 recovery planner implementation"
```

## Plan Self-Review

Spec coverage:

- Reset schedule model: Task 2.
- Recovery cards UI: Task 6.
- Next recovery emphasis: Task 2 and Task 6.
- stale/error/waiting trust display: Task 2 and Task 6.
- Session plan: Task 3 and Task 6.
- Recovery notification copy: Task 7.
- Menu tooltip and pet menu glance: Task 5.
- CLI text summary without `status --json` breakage: Task 4.
- v1.6 docs and verifier: Task 1 and Task 8.
- Release readiness and UI honesty: Task 8.

Placeholder scan:

- The plan intentionally contains no forbidden placeholder markers.
- Every code task includes concrete test names, file paths, commands, and expected outcomes.

Type consistency:

- `CodexUsageResetScheduleBuilder`, `CodexUsageResetSchedule`, and `CodexUsageResetScheduleEntry` are introduced in Task 2 before app/UI use.
- `CodexUsageSessionPlanBuilder`, `CodexUsageSessionPlan`, and `CodexUsageSessionPlanDuration` are introduced in Task 3 before UI use.
- `UsageMonitorState.codexResetSchedule(now:)`, `UsageMonitorState.codexSessionPlan(duration:now:)`, and `UsageMonitorState.nextResetGlance(now:)` are introduced in Task 5 before `CodexUsagePanel` and `MenuBarController` consume them.

## Execution Handoff

Plan complete and saved to `Docs/superpowers/plans/2026-07-05-v160-codex-recovery-planner.md`. Two execution options:

1. **Subagent-Driven (recommended)** - Dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
