# v1.5.0 릴리즈 준비 감사

상태: v1.5.0 릴리즈 완료 / signed Verified tag 확인 / published DMG 설치본 smoke 완료 / release final-state 통과
작성일: 2026-07-01
최종 갱신: 2026-07-05
기준 브랜치: `main`
대상 버전: `1.5.0`
Release tag: `v1.5.0`
Published release head: signed `v1.5.0` tag target
Published asset: `MacDog-1.5.0.dmg`
Published DMG SHA-256: GitHub Release asset digest와 `MacDog-1.5.0.dmg.sha256`를 기준으로 확인

이 문서는 v1.5.0 Usage Reliability & Diagnostics 구현 이후 릴리즈 완료 결과와 smoke 증거를 기록합니다.
구현 세부 범위와 데이터 경계는 [V150UsageReliability.md](V150UsageReliability.md)에 두고, 이 문서는 릴리즈 실행과 smoke 증거만 다룹니다.

## 현재 확인

- Step 1-8 P0 usage reliability 구현은 source/test/verifier 기준으로 완료했습니다.
- reset boundary 실제 UI smoke는 `dist/MacDog.app` popover에서 수행했습니다. `지난` 탭의 interrupted window가 마지막 sample에서 멈추고 남은 7일 축을 blank tail로 유지하는 것을 확인했습니다.
- Step 9-13은 source/test/verifier/docs 기준으로 완료했습니다. Codex 탭 데이터 상태 UI의 실제 화면 smoke는 릴리즈 수동 UI smoke에서 별도로 확인합니다.
- Step 14 preflight는 `MACDOG_RELEASE_VERSION=1.5.0 ./script/check.sh --no-run`으로 통과했습니다.
- Step 15 local packaging은 `MACDOG_RELEASE_VERSION=1.5.0 ./script/package_release.sh`로 `MacDog-1.5.0.dmg`, `MacDog-1.5.0.dmg.sha256`, release notes를 생성했고 checksum과 `hdiutil verify`를 통과했습니다.
- Step 16 release branch/PR/CI는 `codex/v1.5.0-release` 브랜치와 ready PR [#17](https://github.com/dhseo90/MacDog/pull/17)로 진행했고, 이후 잔여 로그인 항목 수정은 `codex/v1.5.0-residuals`에서 v1.5.0 release head에 포함했습니다.
- GitHub Release, signed annotated tag, Verified tag, published DMG, Finder drag-and-drop 설치 smoke를 v1.5.0 release head 기준으로 다시 수행했습니다.
- `b12dc69` (`fix: harden login item preference state`)은 v1.5.0 tag/release/main 범위에 포함했습니다. 로그인 항목 등록 후 macOS Login Item 상태가 enabled가 아니면 실패로 처리하고, UI/첫 실행 설치 경로의 저장된 선호값을 실제 결과 쪽으로 되돌립니다.
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning, App Store Connect가 필요한 stable release 경로는 현재 v1.5.0 unsigned release 완료 조건에서 제외합니다.
- WidgetKit은 기본 앱/DMG 완료 조건에서 제외하고 opt-in source/test/package 경계만 유지합니다.

## Signed tag 재정렬 기록

기록 시각: 2026-07-05 KST

- 기존 `v1.5.0` tag와 published asset은 `b12dc69` 로그인 항목 hardening을 포함하지 않은 상태였습니다.
- 사용자 지시에 따라 `b12dc69`과 v1.5.0 release closure 문서/AGENTS guard를 v1.5.0 release head에 포함하고, `v1.5.0` signed annotated tag와 GitHub Release asset을 최신 release head 기준으로 재발행합니다.
- GitHub tag verification은 GitHub API의 `verification.verified=true`, `reason=valid`로 확인합니다.
- Published assets: `MacDog-1.5.0.dmg`, `MacDog-1.5.0.dmg.sha256`
- Published asset verification: 재다운로드한 `.sha256` 검증과 `hdiutil verify`를 통과해야 합니다.
- Finder install smoke: Finder에서 published DMG의 `MacDog.app`을 `/Applications`로 drag-and-drop한 뒤 앱을 실행해야 합니다.
- Installed cache smoke: `./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage`가 `usage-fetch:success` 또는 stale/error snapshot 경계를 과장 없이 보고해야 합니다.
- Release cleanup: `./script/cleanup_release_smoke_state.sh --apply` 뒤 `./script/verify_release_final_state.sh --version 1.5.0`이 통과해야 합니다.

## Step 9-13 개발 순서

| Step | 우선순위 | 이슈 | 완료 증거 |
| ---: | --- | --- | --- |
| Step 9 | P1 | Codex 탭 데이터 상태 UI | cache 최신성, history sample 부족, stale/error, protocol drift 가능성을 compact status로 표시하고 `UsageMonitorStateTests`로 검증 |
| Step 10 | P1 | live fetch/cache smoke 진단 정리 | `verify_usage_fetch_cache_contract.sh --cli` 성공 시 `usage-fetch:weekly-history`와 `usage-fetch:reset-window-history` 요약 출력 |
| Step 11 | P1 | 운영 회귀 guard 확장 | `sample_existing_runtime_resources.sh`, `verify_privileged_helper_state.sh --allow-missing`, `verify_charge_limit.sh --read`, `verify_release_final_state.sh --version 1.5.0`를 v1.5 release readiness에 연결 |
| Step 12 | P1 | release readiness 문서화 | 자동검증, UI smoke, live fetch smoke, published DMG smoke, 미수행 보고 형식을 이 문서에 분리 |
| Step 13 | P2 | README/ROADMAP/Docs와 screenshot/test closure | README/ROADMAP/Docs/Scripts/check.sh가 v1.5.0 release readiness와 같은 용어를 사용 |

## 릴리즈 잔여 이슈

상태: 아래 이슈는 모두 v1.5.0 release head에 포함해 닫습니다.

| 번호 | 우선순위 | 이슈 | 완료 증거 |
| ---: | --- | --- | --- |
| 14 | P0 Gate | 릴리즈 preflight 검증 | `MACDOG_RELEASE_VERSION=1.5.0 ./script/check.sh --no-run` 통과 |
| 15 | P0 Gate | DMG 패키징 및 로컬 검증 | `MACDOG_RELEASE_VERSION=1.5.0 ./script/package_release.sh`, `.dmg.sha256`, `hdiutil verify`, checksum 검증 |
| 16 | P0 Gate | release branch/PR/CI 정리 | `b12dc69` 포함 release head 확정, PR/CI/review 또는 direct push bypass 상태 기록 |
| 17 | P0 Gate | signed annotated tag 생성/검증 | `v1.5.0` signed annotated tag 재생성, push, GitHub `Verified` 확인 |
| 18 | P0 Gate | GitHub Release asset 교체 | DMG/checksum asset 첨부, `isDraft=false`, `isPrerelease=false`, target/tag/asset 목록 확인 |
| 19 | P0 Gate | published DMG 재검증 | release asset 재다운로드, checksum, `hdiutil verify` 재확인 |
| 20 | P0 Gate | 실제 설치 smoke | Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop |
| 21 | P0 Gate | release smoke 정리 | `./script/cleanup_release_smoke_state.sh --apply`, `./script/verify_release_final_state.sh --version 1.5.0` 통과 |
| 22 | P0 Gate | 릴리즈 종료 보고 | tag/release head/asset/checksum/smoke/미수행 항목 기록 |
| 23 | P0 Guard | dirty branch PR/merge/delete 방지 | `AGENTS.md`가 미커밋 변경이 있는 worktree에서 해당 브랜치 PR/merge/delete 금지를 명시 |

## 릴리즈 전 필수 자동검증

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v150_usage_reliability_contract.sh --self-test
./script/verify_v150_release_readiness.sh --self-test
swift test --filter UsageMonitorStateTests
swift test --filter UsageResetWindowHistoryTests
swift test --filter ResetWindowOverlayModelTests
swift test --filter CodexUsageCacheTests
swift test --filter CodexUsageDoctorFormatterTests
swift test
MACDOG_RELEASE_VERSION=1.5.0 ./script/check.sh --no-run
```

기본 `swift`가 Command Line Tools SDK와 맞지 않으면 Xcode toolchain을 명시합니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --no-parallel
```

macOS 앱 변경이 있으면 release head 확정 전 Xcode Debug build도 통과시킵니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

## 수동 UI smoke

수동 UI smoke는 자동검증과 분리해 기록합니다.
실제 menu bar popover를 열지 않았다면 `UI 확인 미수행`으로 보고합니다.

확인 대상:

- Codex 탭 데이터 상태 UI가 그래프를 밀어내거나 텍스트를 겹치게 하지 않는지 확인합니다.
- 현재/지난/비교 그래프 전환과 지난 window picker를 확인합니다.
- interrupted reset window가 마지막 sample 뒤로 선을 이어가지 않고 blank tail을 유지하는지 확인합니다.
- PNG copy/export 버튼이 보이고, 저장 패널이 열리는지 확인합니다.
- menu bar runner와 popover placement가 기존 동작을 유지하는지 확인합니다.

## live fetch smoke

live fetch smoke는 실제 Codex app-server와 app-owned cache에 접근합니다.
raw app-server payload, auth token, cookie, session material, auth header는 출력하거나 저장하지 않습니다.

```sh
./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage
```

성공 시 아래 요약이 함께 나와야 합니다.

```text
usage-fetch:success
usage-fetch:weekly-history ...
usage-fetch:reset-window-history ...
```

실패 시 error snapshot인지 확인하고, 5시간/주간 window가 없는 `0% 사용 / 100% 남음` 형태의 success cache가 생성되면 실패로 봅니다.

## 운영 회귀 guard

아래 guard는 사용자 환경을 바꾸지 않거나 read-only 경계로 실행합니다.
실제 설치, LaunchAgent 등록, helper 설치/삭제, charge limit 변경은 별도 승인 없이 수행하지 않습니다.

```sh
./script/sample_existing_runtime_resources.sh --self-test
./script/sample_existing_runtime_resources.sh --samples 5 --interval 1
./script/verify_privileged_helper_state.sh --allow-missing
./script/verify_charge_limit.sh --read
./script/verify_release_final_state.sh --version 1.5.0
```

`verify_release_final_state.sh --version 1.5.0`은 release smoke 종료 시점에만 통과해야 합니다.
release 전 개발 workspace에 `dist/MacDog.app`이 남아 있으면 실패할 수 있으므로 preflight 증거와 release 종료 증거를 분리합니다.

## GitHub Release gate

- 기존 원격 `v1.5.0` tag와 release가 있으면 기존 target, asset digest, 재발행 사유를 먼저 기록합니다.
- tag는 최신 release head를 가리키는 signed annotated tag여야 합니다.
- GitHub에서 tag가 `Verified`로 표시되지 않으면 draft 생성과 publish를 중단합니다.
- `Draft Release` workflow 또는 `gh release create --verify-tag`는 이미 존재하는 signed/Verified tag만 사용해야 합니다.
- workflow나 `gh release create`가 unsigned/lightweight tag를 자동 생성하게 두지 않습니다.
- draft release는 `UNSIGNED-DRAFT` 확인 입력과 함께 진행합니다.
- stable signed/notarized public release는 Apple Developer Program 조건이 별도 승인되기 전까지 제외합니다.

## published DMG smoke

published DMG smoke는 GitHub Release asset을 기준으로 합니다.
로컬 `dist/release` 산출물만 보고 완료로 기록하지 않습니다.

1. published `MacDog-1.5.0.dmg`와 `MacDog-1.5.0.dmg.sha256`를 다시 내려받습니다.
2. checksum과 `hdiutil verify`를 확인합니다.
3. Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop합니다.
4. `/Applications/MacDog.app`를 실행하고 menu bar runner, popover, Codex 탭 데이터 상태 UI, 현재/지난/비교 그래프를 확인합니다.
5. 설치본 CLI로 `./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage`를 실행합니다.
6. `./script/cleanup_release_smoke_state.sh --apply` 뒤 `./script/verify_release_final_state.sh --version 1.5.0`을 실행합니다.

## 미수행 보고 형식

```text
미실행:
- GitHub Release publish: 실행하지 않음
- published DMG 재다운로드 검증: 실행하지 않음
- Finder drag-and-drop 설치 smoke: 실행하지 않음
- WidgetKit 실제 UI: 실행하지 않음
- 장시간 테스트: 실행하지 않음
```
