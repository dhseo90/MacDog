# v1.6.0 Codex Usage & Reset Credits Implementation Plan

작성일: 2026-07-05
상태: 재작업 구현 완료 / 자동 검증 통과 / release smoke 미수행
실행 방식: task별 구현 후 focused test와 자체 리뷰

## 목표

잘못 병합된 v1.6.0 `Recovery Planner` 구현을 `Codex Usage & Reset Credits`로 재작업합니다.
release/tag/branch 재시도는 이 수정이 검증된 뒤 별도 단계로 진행합니다.

## Task 1: 문서 계약 교체

- `Docs/V160CodexRecoveryPlanner.md`를 새 컨셉으로 교체합니다.
- `ROADMAP.md`, `README.md`, `Docs/Scripts.md`, `Docs/V160ReleaseReadiness.md`에서 recovery/session plan 표현을 제거합니다.
- verifier가 새 계약을 검사하도록 바꿉니다.

검증:

```sh
git diff --check
```

## Task 2: reset credit 모델

- `RateLimitsResponse`에 `rateLimitResetCredits`를 추가합니다.
- `CodexUsageReport`에 사용자 초기화권 summary를 추가합니다.
- 상세 `credits[]`와 `expiresAt`은 optional forward-compatible 필드로 둡니다.
- fixture와 모델 테스트를 먼저 갱신해 실패를 확인한 뒤 구현합니다.

검증:

```sh
swift test --filter RateLimitModelsTests
swift test --filter CodexUsageReportTests
```

## Task 3: Recovery/Session 모델 제거

- `CodexUsageResetSchedule`와 `CodexUsageSessionPlan` 사용을 제거합니다.
- CLI 텍스트에서 `Recovery cards`를 제거합니다.
- `UsageMonitorState`의 schedule/session helper를 제거합니다.
- 메뉴 glance는 필요하면 기존 5시간/주간 window에서 직접 계산합니다.

검증:

```sh
swift test --filter CodexUsageReportTests
swift test --filter UsageMonitorStateTests
swift test --filter PetMenuModelTests
```

## Task 4: Codex 탭 UI 재구성

- `CodexRecoveryPlannerViews.swift`를 reset credit/usage section view로 교체하거나 삭제 후 새 파일을 둡니다.
- 5시간/주간 게이지는 한 번만 표시합니다.
- 초기화권 영역은 보유 장수와 장별 유효기간을 표시합니다.
- 그래프는 보조 섹션으로 낮추고 하단 여백을 확보합니다.
- screenshot renderer 테스트를 새 UI 계약으로 바꿉니다.

검증:

```sh
swift test --filter UsageMonitorStateTests
swift test --filter PopoverScreenshotRendererTests
```

## Task 5: v1.6 verifier와 focused 검증

- verifier가 새 source/test/docs 계약을 확인하게 합니다.
- `git diff --check`와 focused tests를 실행합니다.
- macOS 앱 변경이므로 가능하면 Xcode Debug build를 실행합니다.
- GUI smoke는 사용자가 별도로 승인한 경우에만 실행합니다.

검증:

```sh
git diff --check
script/verify_v160_codex_recovery_planner_contract.sh --self-test
swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```
