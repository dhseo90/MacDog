# v1.4.0 릴리즈 준비 감사

상태: v1.4.0 릴리즈 재정렬 필요 / published DMG 설치본 smoke 완료 / signed Verified tag 재발행 필요
작성일: 2026-06-27
기준 브랜치: `main`
대상 버전: `1.4.0`
Release tag: `v1.4.0`
Published release head: `8cc3922ce857020c55eb7c6990380576ca39d75f`
Latest main head after release documentation: `a8b92299c07a5c1b390892850c5d9029daaddfd3`
Published asset: `MacDog-1.4.0.dmg`
Published DMG SHA-256: `52ba15b0f4ff93e45fb50eb84aa5cfca7500206718fe4adc07f8b290eef4a86a`

이 문서는 v1.4.0 Usage Intelligence 구현 이후 실제 릴리즈 완료 결과와 smoke 증거를 기록합니다.
구현 세부 범위와 데이터 경계는 [V140UsageIntelligence.md](V140UsageIntelligence.md)에 두고, 이 문서는 릴리즈 실행과 smoke 증거만 다룹니다.

## 현재 확인

- v1.4.0 P0-P2 구현과 GitHub Release publish를 완료했습니다.
- Published DMG 재다운로드 checksum, `hdiutil verify`, Finder drag-and-drop 설치, `/Applications/MacDog.app` 첫 실행, live fetch/cache smoke, release final-state 검증을 확인했습니다.
- 설치본 Codex 탭 UI smoke에서 현재/지난/비교 전환, 지난 window picker, hover/tap marker, PNG copy/export를 확인했습니다.
- 실제 Codex 탭 UI smoke에서 하단 `기록 시작` 라벨 클리핑, current reset timestamp drift가 지난 window로 보이는 문제, `오버레이` UI 문구 모호성이 발견되어 `33b53c9`와 `4ddb5ff`로 수정했습니다.
- 재검증 중 과거 데이터 backfill, 날짜 기반 지난/비교 timeline 라벨, reset-window history append diagnostic 누락을 `04e7e8d`와 `0714c75`로 추가 수정했습니다.
- 설치본 PNG export Save panel이 닫히지 않는 문제가 발견되어 `8cc3922`로 수정했습니다.
- `main` 직접 push 과정에서 GitHub ruleset direct push bypass 로그가 발생했습니다. 최종 head `8cc3922` 기준 required checks 2개(`CI`, `Public Repo Guardrails`)는 통과했습니다.
- remote `v1.4.0` tag와 published asset은 `8cc3922` 기준으로 교체됐고, GitHub Release는 `isDraft=false`, `isPrerelease=false`입니다.
- 이후 릴리즈 완료 기록 문서 커밋 `a8b9229`가 추가되어 최신 `main`과 release tag가 달라졌습니다.
- 현재 `v1.4.0` tag는 lightweight tag라 GitHub `Verified` tag 조건을 만족하지 않습니다. v1.4.0을 다시 닫으려면 최신 release head 기준 signed annotated tag를 만들고 GitHub에서 `Verified`를 확인한 뒤 package/release asset을 재검증해야 합니다.
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning, App Store Connect가 필요한 stable release 경로는 현재 v1.4.0 unsigned release 완료 조건에서 제외합니다.
- WidgetKit은 기본 앱/DMG 완료 조건에서 제외하고 opt-in source/test/package 경계만 유지합니다.

## 재정렬 필요 항목

아래 항목은 v1.4.0 릴리즈를 다시 완료 상태로 기록하기 전에 모두 충족해야 합니다.

1. 최신 `main` release head를 확정합니다.
2. `v1.4.0`을 최신 release head에 대한 signed annotated tag로 재발행합니다.
3. GitHub에서 `v1.4.0` tag가 `Verified`로 표시되는지 확인합니다.
4. 최신 release head 기준으로 `MacDog-1.4.0.dmg`와 `.sha256`을 다시 생성하거나, 기존 asset을 유지하는 경우 그 사유와 source head 차이를 명시합니다.
5. GitHub Release `targetCommitish`, tag target, published asset checksum, smoke 결과를 같은 release head 기준으로 다시 기록합니다.

## 최종 릴리즈 기록

기록 시각: 2026-06-27 02:34 KST

- Final release head: `8cc3922ce857020c55eb7c6990380576ca39d75f`
- Commit: `8cc3922ce857020c55eb7c6990380576ca39d75f` (`fix: unblock codex graph export save panel`)
- Direct push/admin bypass: `main` direct push로 GitHub ruleset bypass가 기록됐습니다.
- Required checks: `8cc3922` 기준 `CI` success, `Public Repo Guardrails` success.
- GitHub Release: `v1.4.0`, `isDraft=false`, `isPrerelease=false`, `targetCommitish=8cc3922ce857020c55eb7c6990380576ca39d75f`
- Published assets: `MacDog-1.4.0.dmg`, `MacDog-1.4.0.dmg.sha256`
- Published DMG SHA-256: `52ba15b0f4ff93e45fb50eb84aa5cfca7500206718fe4adc07f8b290eef4a86a`
- Published asset verification: 재다운로드한 `.sha256` 검증과 `hdiutil verify`를 통과했습니다.
- Finder install smoke: published DMG Finder 창에서 `MacDog.app`을 `Applications`로 drag-and-drop한 뒤 `/Applications/MacDog.app`가 `dist/MacDog.app` 및 DMG 앱 바이너리와 일치함을 확인했습니다.
- Installed UI smoke: `/Applications/MacDog.app`에서 현재/지난/비교 탭, 지난 window picker, hover/tap marker, PNG copy/export, popover placement를 확인했습니다.
- Installed cache smoke: `./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage`가 `usage-fetch:success`로 통과했습니다.
- Release cleanup: `./script/cleanup_release_smoke_state.sh --apply`와 `./script/verify_release_final_state.sh --version 1.4.0`이 통과했습니다.

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
- 당시 remote release gap: `v1.4.0` tag와 published asset은 아직 `7327977` 기준이었습니다. 최종 릴리즈에서는 `8cc3922` 기준으로 교체했습니다.

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
- 당시 UI gap: candidate 자동 클릭 주입으로는 `지난`/`비교` 전환을 완료하지 못했습니다. 최종 published DMG 설치본 smoke에서 `지난`/`비교`, window picker, hover/tap marker, PNG copy/export를 확인했습니다.
- 당시 remote release gap: `v1.4.0` tag와 published asset은 아직 `7327977` 기준이었습니다. 최종 릴리즈에서는 `8cc3922` 기준으로 교체했습니다.

## 초기 PR 게이트 기록

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

상태: 아래 이슈는 모두 완료했습니다.

| 번호 | 우선순위 | 이슈 | 완료 증거 |
| ---: | --- | --- | --- |
| 1 | P0 | 원격 CI와 보호 규칙 상태 확인 | `8cc3922` 기준 required checks 2개 통과, direct push bypass 기록 |
| 2 | P0 | v1.4.0 최종 릴리즈 문서 정리 | README/ROADMAP/Docs가 release head, DMG 이름, checksum, smoke 결과 기록 위치를 같은 용어로 설명 |
| 3 | P0 | 릴리즈 전 자동검증 | `git diff --check`, v1.4.0 self-test, 전체 `swift test`, Xcode Debug build, `MACDOG_RELEASE_VERSION=1.4.0 ./script/check.sh --no-run` 통과 |
| 4 | P0 | release candidate 패키징 | `MacDog-1.4.0.dmg`와 `MacDog-1.4.0.dmg.sha256` 생성, checksum과 `hdiutil verify` 통과 |
| 5 | P0 | GitHub release target/asset 교체 검증 | 재진행 필요: `v1.4.0` tag는 최신 release head를 가리키는 signed/Verified tag여야 함 |
| 6 | P0 | GitHub release publish 검증 | `isDraft=false`, `isPrerelease=false`, tag `v1.4.0`, published asset download URL 확인 |
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
6. 원격 tag `v1.4.0` 상태를 확인합니다. 기존 tag를 재발행하면 기존 target, asset checksum, 재발행 사유를 기록합니다.
7. 최신 release head 기준 signed annotated tag를 만들고 원격에 push합니다.
8. GitHub에서 `v1.4.0` tag가 `Verified`로 표시되는지 확인합니다. `Verified`가 아니면 publish하지 않습니다.
9. `Release Candidate` workflow 또는 로컬 packaging script를 최신 release head 기준으로 실행합니다.
10. 생성된 `MacDog-1.4.0.dmg`와 `MacDog-1.4.0.dmg.sha256` artifact를 확인하고 checksum과 `hdiutil verify`를 확인합니다.
11. `Draft Release` workflow를 `UNSIGNED-DRAFT` 확인 입력으로 실행합니다. workflow는 이미 존재하는 signed/Verified tag만 사용해야 하며, tag를 자동 생성하면 안 됩니다.
12. draft release의 `isDraft`, `isPrerelease`, `targetCommitish`, asset 목록을 확인합니다.
13. stale draft가 아니고 `targetCommitish`가 최신 release head이며 tag가 `Verified`일 때만 publish합니다.
14. publish 후 `isDraft=false`, tag `v1.4.0`, tag `Verified`, published asset download URL을 확인합니다.
15. published DMG와 `.sha256`을 다시 내려받아 checksum과 `hdiutil verify`를 재확인합니다.
16. Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop합니다.
17. `/Applications/MacDog.app` 기준으로 앱을 실행해 menu bar runner, popover, 주요 tab 전환, popover placement, 첫 실행 user component 상태를 확인합니다.
18. Codex 탭에서 현재/지난/비교 전환, 지난 window picker, hover/tap marker, PNG copy/export를 확인합니다.
19. `~/bin/codex-usage`, usage cache LaunchAgent, 실행 중 app path가 `/Applications/MacDog.app` 기준인지 확인합니다.
20. `./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage`를 실행합니다.
21. live fetch 성공 시 5시간/주간 window, `usage-weekly-history.json`, `usage-reset-window-history.json` append diagnostic과 sample을 확인합니다.
22. live fetch 실패 시 stale/error snapshot인지 분리해서 보고하고 제품 회귀로 단정하지 않습니다.
23. `./script/cleanup_release_smoke_state.sh --apply`로 smoke 잔여물을 정리합니다.
24. `./script/verify_release_final_state.sh --version 1.4.0`이 통과해야 release smoke 종료로 기록합니다.
25. release branch 정리는 `codex/v1.4.0-release`와 `origin/codex/v1.4.0-release`가 각각 `main`과 `origin/main`에 포함된 것을 확인한 뒤 별도 승인으로 수행합니다.

## 보고 원칙

- 실행하지 않은 UI/설치/live fetch 검수는 완료로 쓰지 않고 `UI 확인 미수행` 또는 `미수행`으로 기록합니다.
- raw app-server payload, auth/session material, token, cookie는 출력하거나 저장하지 않습니다.
- `Plus`/`Pro $100`/`Pro $200` 가격 tier는 v1.4.0 릴리즈 노트와 UI smoke 결과에 추정해 쓰지 않습니다.
- signed/notarized stable release, Gatekeeper 검증, 실제 Widget UI 검수는 현재 unsigned v1.4.0 release 완료 조건에서 제외합니다.
