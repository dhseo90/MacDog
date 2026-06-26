# v1.4.0 릴리즈 준비 감사

상태: v1.4.0 재검증 완료 / remote tag와 asset 교체 대기 / published DMG 재설치 smoke 대기
작성일: 2026-06-27
기준 브랜치: `main`
대상 버전: `1.4.0`
Release tag: `v1.4.0`
Published release head: `7327977bb82d41d8f0571e231865ba3251a178c9`
Re-run verified head: `0714c750df3e5a67e435c670e2f1a9ca45263771`
Published DMG SHA-256: `c46f7bde5cb4ad0782943cd479dfe0a3841929b663cc605022b33dd7dcec9142`
Replacement local DMG SHA-256: `9505a7acdbce80e558d279ad07a8e81699eec160114ba52911da771d725294c3`

이 문서는 v1.4.0 Usage Intelligence 구현 이후 실제 릴리즈까지 남은 이슈를 우선순위와 진행 순서 기준으로 고정합니다.
구현 세부 범위와 데이터 경계는 [V140UsageIntelligence.md](V140UsageIntelligence.md)에 두고, 이 문서는 릴리즈 실행과 smoke 증거만 다룹니다.

## 현재 확인

- v1.4.0 P0-P2 구현은 자동 검증 기준으로 완료했습니다.
- Published DMG checksum, `hdiutil verify`, Finder drag-and-drop 설치, `/Applications/MacDog.app` 첫 실행, live fetch/cache smoke, release final-state 검증을 확인했습니다.
- 실제 Codex 탭 UI smoke에서 하단 `기록 시작` 라벨 클리핑, current reset timestamp drift가 지난 window로 보이는 문제, `오버레이` UI 문구 모호성이 발견되어 `33b53c9`와 `4ddb5ff`로 수정했습니다.
- 재검증 중 과거 데이터 backfill, 날짜 기반 지난/비교 timeline 라벨, reset-window history append diagnostic 누락을 `04e7e8d`와 `0714c75`로 추가 수정했습니다.
- `main` 직접 push 과정에서 GitHub ruleset direct push bypass 로그가 발생했습니다. `0714c75` 기준 required checks 2개(`static-gates`, `guardrails`)는 통과했습니다.
- 현재 remote `v1.4.0` tag와 published asset은 아직 `7327977` 기준입니다. Re-run verified head `0714c75` 기준 local replacement DMG는 생성/검증했지만, remote tag 이동과 asset 교체는 아직 수행하지 않았습니다.
- Re-run verified head 기준 candidate 앱 실제 UI 확인: `dist/MacDog.app`에서 Codex 현재 탭, popover placement, 하단 날짜 라벨, copy/export 버튼 표시를 확인했습니다. 자동 클릭 주입으로 지난/비교 탭 전환은 완료하지 못해 published DMG 설치 smoke에서 다시 확인해야 합니다.
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning, App Store Connect가 필요한 stable release 경로는 현재 v1.4.0 unsigned release 완료 조건에서 제외합니다.
- WidgetKit은 기본 앱/DMG 완료 조건에서 제외하고 opt-in source/test/package 경계만 유지합니다.

## Post-smoke fix 기록

기록 시각: 2026-06-26 22:10 KST

- Commit: `33b53c93b8f0bf880c7cf8668ee4bb72556e86e0` (`fix: refine v1.4.0 usage graph smoke issues`)
- Commit: `4ddb5ff8f4f33f78f62cfc0f390dc5bd0fe9abf2` (`docs: refresh v1.4 usage screenshot`)
- Direct push/admin bypass: `main` direct push로 GitHub ruleset bypass가 기록됐습니다.
- Required checks: `4ddb5ff` 기준 `CI` success, `Public Repo Guardrails` success.
- Local replacement artifact: `dist/release/MacDog-1.4.0.dmg`, `dist/release/MacDog-1.4.0.dmg.sha256`
- Local replacement checksum: `8475305a73202b9b5921edf785f4e2a07acb00b9496f74f8042a9032a2b03152`
- Local verification: `git diff --check`, focused Swift tests, 전체 `swift test`, Xcode Debug build, `MACDOG_RELEASE_VERSION=1.4.0 ./script/check.sh --no-run`, `hdiutil verify`, checksum 검증, `./script/verify_release_final_state.sh --version 1.4.0` 통과.
- UI evidence: source renderer와 README screenshot에서 하단 `기록 시작` 라벨이 popover 내부에 표시됨을 확인했습니다.
- Remote release gap: `v1.4.0` tag와 published asset은 아직 `7327977` 기준입니다. `4ddb5ff` 기준 tag 이동과 asset 교체는 별도 승인 후 진행합니다.

## Re-run 기록

기록 시각: 2026-06-27 00:52 KST

- Commit: `04e7e8d277bdb158a76b28abe11a01b2851d4e8c` (`fix: refine v1.4 usage history comparison`)
- Commit: `0714c750df3e5a67e435c670e2f1a9ca45263771` (`fix: report reset window history cache writes`)
- Direct push/admin bypass: `main` direct push로 GitHub ruleset bypass가 기록됐습니다.
- Required checks: `0714c75` 기준 `static-gates` success, `guardrails` success.
- Local replacement artifact: `dist/release/MacDog-1.4.0.dmg`, `dist/release/MacDog-1.4.0.dmg.sha256`
- Local replacement checksum: `9505a7acdbce80e558d279ad07a8e81699eec160114ba52911da771d725294c3`
- Local verification: `MACDOG_RELEASE_VERSION=1.4.0 ./script/check.sh --no-run`, checksum 검증, `hdiutil verify`, `./script/verify_usage_fetch_cache_contract.sh --cli /Users/dhseo/Desktop/workspace/MacDog/dist/MacDog.app/Contents/MacOS/codex-usage` 통과.
- Live cache smoke: successful fetch가 `usage-weekly-history.json`과 `usage-reset-window-history.json`을 생성했고, reset-window append diagnostic과 sample schema를 확인했습니다.
- Candidate UI evidence: `dist/MacDog.app` 실제 popover에서 Codex 현재 탭, 날짜 기반 `기록 시작`/reset end 라벨, copy/export 버튼 표시를 확인했습니다.
- UI gap: 좌표 클릭 자동화가 SwiftUI segmented control에 전달되지 않아 `지난`/`비교` 실제 탭 전환, window picker, hover/tap marker, PNG copy/export 실행은 published DMG 설치 smoke에서 다시 확인해야 합니다.
- Remote release gap: `v1.4.0` tag와 published asset은 아직 `7327977` 기준입니다. `0714c75` 기준 tag 이동과 asset 교체가 다음 단계입니다.

## 현재 PR 게이트 기록

기록 시각: 2026-06-26 21:08 KST

- PR: `codex/v1.4.0-release -> main` [#16](https://github.com/dhseo90/MacDog/pull/16)
- PR head: `53810268ccc9695c9374c3ad2697f29e4076c1e3`
- Base head: `6dcf2c0297679dba188624a66de36cc1eeb2f1b6`
- Required checks: `static-gates` 통과, `guardrails` 통과
- Branch protection: approving review 1개 필요, code owner review 필요, stale review dismissal 켜짐
- Merge state: `BLOCKED`
- Review state: `REVIEW_REQUIRED`
- 원격 tag `v1.4.0`: 미존재
- Direct push/admin bypass: `enforce_admins=false`라 관리자 우회 가능성은 있지만, v1.4.0 release branch는 PR 경로로 검증 중이며 별도 승인 없이 direct push/admin bypass로 release head를 만들지 않습니다. 최종 release head는 PR merge 후 `origin/main` 최신 SHA로 다시 기록합니다.

## 릴리즈 잔여 이슈

| 번호 | 우선순위 | 이슈 | 완료 증거 |
| ---: | --- | --- | --- |
| 1 | P0 | 원격 CI와 보호 규칙 상태 확인 | `0714c75` 기준 required checks 2개 통과, direct push bypass 기록 |
| 2 | P0 | v1.4.0 최종 릴리즈 문서 정리 | README/ROADMAP/Docs가 release head, DMG 이름, checksum, smoke 결과 기록 위치를 같은 용어로 설명 |
| 3 | P0 | 릴리즈 전 자동검증 | `git diff --check`, v1.4.0 self-test, 전체 `swift test`, Xcode Debug build, `MACDOG_RELEASE_VERSION=1.4.0 ./script/check.sh --no-run` 통과 |
| 4 | P0 | release candidate 패키징 | 기존 원격 tag `v1.4.0`은 `7327977` 기준, replacement `MacDog-1.4.0.dmg`와 `MacDog-1.4.0.dmg.sha256` 생성, checksum과 `hdiutil verify` 통과 |
| 5 | P0 | GitHub draft release 생성/검증 | `Draft Release`가 `UNSIGNED-DRAFT` 확인 입력으로 생성되고 `targetCommitish`가 최신 release head이며 asset 2개가 포함됨 |
| 6 | P0 | GitHub release publish 검증 | publish 후 `isDraft=false`, `isPrerelease=false`, tag `v1.4.0` 생성, published asset download URL 확인 |
| 7 | P0 | published DMG 재다운로드 검증 | published `MacDog-1.4.0.dmg` 재다운로드, `.sha256` 검증, `hdiutil verify` 통과 |
| 8 | P0 | Finder drag-and-drop 설치 smoke | Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop |
| 9 | P0 | 설치본 첫 실행과 앱 UI smoke | `/Applications/MacDog.app` 기준 첫 실행, menu bar runner, popover placement, Codex 탭 현재/지난/비교, window picker, hover/tap marker, PNG copy/export 확인 |
| 10 | P0 | live fetch/cache 계약 smoke | `./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage` 실행, `usage-reset-window-history.json` append diagnostic과 sample 확인 |
| 11 | P1 | release smoke 종료 정리 | `./script/cleanup_release_smoke_state.sh --apply`, `./script/verify_release_final_state.sh --version 1.4.0` 통과 |
| 12 | P1 | 최종 결과 기록 | v1.4.0 release metadata, checksum, smoke 결과, 미수행 항목을 README/ROADMAP/Docs에 과장 없이 기록 |

## 릴리즈 전 필수 자동검증

릴리즈 PR merge 또는 workflow 실행 전 아래 명령을 통과시킵니다.

```sh
git diff --check
markdownlint-cli2
./script/verify_v140_usage_intelligence_contract.sh --self-test
./script/verify_v140_release_readiness.sh --self-test
swift test --filter UsageResetWindowHistoryTests
swift test --filter UsagePaceProjectionTests
swift test --filter ResetWindowOverlayModelTests
swift test --filter CodexUsageGraphImageExporterTests
swift test --filter UsageMonitorStateTests
swift test --filter PopoverScreenshotRendererTests
swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
MACDOG_RELEASE_VERSION=1.4.0 ./script/check.sh --no-run
```

기본 `swift`가 Command Line Tools SDK와 맞지 않으면 Xcode toolchain을 명시합니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --no-parallel
```

## 릴리즈 실행 스텝

1. `git status -sb`로 릴리즈 브랜치가 깨끗한지 확인합니다.
2. `git fetch origin --tags` 후 `main`, `origin/main`, `codex/v1.4.0-release`, `origin/codex/v1.4.0-release` head를 기록합니다.
3. `git diff --check`, 문서 lint, v1.4.0 self-test, focused Swift tests, 전체 `swift test`, Xcode Debug build, `MACDOG_RELEASE_VERSION=1.4.0 ./script/check.sh --no-run`을 실행합니다.
4. `codex/v1.4.0-release -> main` PR을 만들고 CI와 리뷰 상태를 확인합니다.
5. PR merge 후 `origin/main` 최신 SHA를 v1.4.0 release head로 기록합니다.
6. 원격 tag `v1.4.0`이 없는지 확인합니다.
7. `Release Candidate` workflow 또는 로컬 packaging script를 최신 release head 기준으로 실행합니다.
8. 생성된 `MacDog-1.4.0.dmg`와 `MacDog-1.4.0.dmg.sha256` artifact를 확인하고 checksum과 `hdiutil verify`를 확인합니다.
9. `Draft Release` workflow를 `UNSIGNED-DRAFT` 확인 입력으로 실행합니다.
10. draft release의 `isDraft`, `isPrerelease`, `targetCommitish`, asset 목록을 확인합니다.
11. stale draft가 아니고 `targetCommitish`가 최신 release head일 때만 publish합니다.
12. publish 후 `isDraft=false`, tag `v1.4.0`, published asset download URL을 확인합니다.
13. published DMG와 `.sha256`을 다시 내려받아 checksum과 `hdiutil verify`를 재확인합니다.
14. Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop합니다.
15. `/Applications/MacDog.app` 기준으로 앱을 실행해 menu bar runner, popover, 주요 tab 전환, popover placement, 첫 실행 user component 상태를 확인합니다.
16. Codex 탭에서 현재/지난/비교 전환, 지난 window picker, hover/tap marker, PNG copy/export를 확인합니다.
17. `~/bin/codex-usage`, usage cache LaunchAgent, 실행 중 app path가 `/Applications/MacDog.app` 기준인지 확인합니다.
18. `./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage`를 실행합니다.
19. live fetch 성공 시 5시간/주간 window, `usage-weekly-history.json`, `usage-reset-window-history.json` append diagnostic과 sample을 확인합니다.
20. live fetch 실패 시 stale/error snapshot인지 분리해서 보고하고 제품 회귀로 단정하지 않습니다.
21. `./script/cleanup_release_smoke_state.sh --apply`로 smoke 잔여물을 정리합니다.
22. `./script/verify_release_final_state.sh --version 1.4.0`이 통과해야 release smoke 종료로 기록합니다.
23. release branch 정리는 `codex/v1.4.0-release`와 `origin/codex/v1.4.0-release`가 각각 `main`과 `origin/main`에 포함된 것을 확인한 뒤 별도 승인으로 수행합니다.

## 보고 원칙

- 실행하지 않은 UI/설치/live fetch 검수는 완료로 쓰지 않고 `UI 확인 미수행` 또는 `미수행`으로 기록합니다.
- raw app-server payload, auth/session material, token, cookie는 출력하거나 저장하지 않습니다.
- `Plus`/`Pro $100`/`Pro $200` 가격 tier는 v1.4.0 릴리즈 노트와 UI smoke 결과에 추정해 쓰지 않습니다.
- signed/notarized stable release, Gatekeeper 검증, 실제 Widget UI 검수는 현재 unsigned v1.4.0 release 완료 조건에서 제외합니다.
