# v1.2.3 유틸리티 코어 정리

## 목적

v1.2.3은 v1.2.0에서 문서화한 유틸리티 코어 정리 계획을 실제 코드에 반영하는 작업입니다. 사용자-visible 동작, `codex-usage status --json` schema, app-owned cache schema, app-server 해석 계약은 유지하고, 이후 MacDog 유틸리티 기능을 추가할 때 건드려야 하는 파일 표면을 줄입니다.

## 실제 구현 점검

2026-06-04 작업 전후 실제 구현을 기준으로 확인한 내용은 다음과 같습니다.

- `UsagePopoverView`는 popover shell, tab rail, module routing, Codex/Mac/Sleep/Battery/Settings panel, weekly chart/helper view가 한 파일에 섞여 있었습니다.
- `MenuBarController`는 status item, popover 표시, usage cache refresh, local metrics refresh, sleep prevention sync, helper prompt, desktop pet 연결을 함께 소유하고 있었습니다.
- `dist/release` 로컬 산출물에는 `MacDog-1.1.0`과 `MacDog-1.2.0` DMG/checksum만 확인됐습니다. 이 로컬 점검만으로 v1.2.1/v1.2.2 GitHub Release asset, download URL, published release 상태를 완료로 볼 수 없습니다.

## 구현 범위

이번 v1.2.3 코어 정리는 아래 범위 안에서만 진행합니다.

1. `UsagePopoverView`를 popover shell과 module routing으로 축소합니다.
2. Codex, Mac resources, Sleep prevention, Battery, Settings panel을 module별 파일로 분리합니다.
3. weekly remaining chart와 shared popover controls를 별도 파일로 분리합니다.
4. usage cache refresh command/throttle/bundle lookup/runner를 작은 타입으로 분리합니다.
5. popover anchor, preferred edge, window frame 계산을 `UsagePopoverPlacementResolver`로 분리합니다.
6. 관련 focused tests로 기존 계약을 고정합니다.

## 제외 범위

- 새 Codex bucket 기본 UI 추가
- `status --json` schema 변경
- app-owned cache schema 변경
- WidgetKit 실제 UI 검수
- GUI 앱 실행과 menu bar popover 육안 검수
- DMG 생성, Finder drag-and-drop 설치 검수, LaunchAgent 등록, helper 설치/삭제
- GitHub release draft/publish, release asset download URL 검증
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning

## 검증 기록

실행한 verification은 다음과 같습니다.

- `swift test --filter PrivilegedHelperPopoverActionTests --filter UsageMonitorStateTests --filter PopoverScreenshotRendererTests --filter ChargeLimitSupportSnapshotTests`: 52 tests executed, 2 skipped, 0 failures
- `swift test --filter CodexUsageCacheRefreshPolicyTests --filter UsagePopoverPlacementTests`: 7 tests executed, 0 failures
- `git diff --check`: passed
- `swift test`: 253 tests executed, 2 skipped, 0 failures
- `xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO`: `BUILD SUCCEEDED`

코어 정리 구현 단계의 GUI 실행, 설치 검수, GitHub release asset download 검증은 이 문서에서 완료 증거로 기록하지 않습니다. v1.2.3 release 종료 증거는 아래 릴리즈 운영 메모에 별도로 분리해 기록합니다.

## v1.2.3 릴리즈 운영 메모

v1.2.3 GitHub Release는 코어 정리 완료와 별도로 release 운영 절차를 수행해 닫았습니다. 확인한 release 종료 증거는 다음과 같습니다.

- PR #5 `codex-v1.2.3-utility-core-cleanup`과 PR #6 `codex-v1.2.3-release-dmg-fix`를 `main`에 merge했습니다.
- 최신 release head는 `595a118`입니다.
- Release Candidate workflow run `26954573104`와 Draft Release workflow run `26954777833`이 success였습니다.
- GitHub Release `v1.2.3`은 `isDraft=false`, `isPrerelease=false`, `targetCommitish=595a1182f7fe20b60bfbac4f3fb61df6fba7138a` 상태입니다.
- published asset `MacDog-1.2.3.dmg`와 `MacDog-1.2.3.dmg.sha256`를 다운로드해 checksum과 `hdiutil verify`를 확인했습니다.
- Finder에서 published DMG를 열어 `MacDog.app`과 `Applications` symlink만 표시되는 것을 확인했고, 실제 drag-and-drop 설치 smoke를 수행했습니다.
- 설치본 `/Applications/MacDog.app`은 `CFBundleShortVersionString=1.2.3`이고 실행 프로세스는 `/Applications/MacDog.app/Contents/MacOS/MacDog` 기준입니다.
- 설치본 `codex-usage`로 `verify_usage_fetch_cache_contract.sh`를 통과했고, release smoke cleanup/final-state 검증도 통과했습니다.

signed/notarized stable release와 WidgetKit App Group 검수는 Apple Developer Program 사용 가능 상태가 별도 milestone으로 승인되기 전까지 v1.2.3 완료 조건에 넣지 않습니다.
