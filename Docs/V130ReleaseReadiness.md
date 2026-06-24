# v1.3.0 릴리즈 준비 감사

상태: 릴리즈 완료 기록 포함
작성일: 2026-06-05
최종 확인일: 2026-06-24
기준 브랜치: `main`
대상 버전: `1.3.0`
Release tag: `v1.3.0`
Release head: `a689fe2e5ae6416a5864ebf9097a8890e2d95a4a`

이 문서는 v1.3.0 구현 범위의 잔여 이슈를 릴리즈 관점에서 닫고, 실제 릴리즈를 시작할 때 따라야 할 순서를 고정합니다.
2026-06-24에는 사용자가 승인한 범위 안에서 tag, GitHub Release asset, published DMG 설치 smoke, 앱 UI smoke, release final-state까지 완료한 결과를 함께 기록합니다.

## 릴리즈 완료 기록

v1.3.0 GitHub Release는 현재 `a689fe2e5ae6416a5864ebf9097a8890e2d95a4a`를 가리킵니다.

확인된 release metadata:

- `tag_name`: `v1.3.0`
- `target_commitish`: `a689fe2e5ae6416a5864ebf9097a8890e2d95a4a`
- `draft`: `false`
- `prerelease`: `false`
- `MacDog-1.3.0.dmg`: `sha256:99103cba8ab2f64b024afb26b4ae37ab046d42410f68ecf69f08038dad145f29`
- `MacDog-1.3.0.dmg.sha256`: `sha256:ae97d01d30e22e028f2db169e3ca6f2b0ee0ba9cde0ed027991bd77676f4b51d`

확인된 release smoke:

- published DMG를 다시 내려받아 checksum과 `hdiutil verify`를 확인했습니다.
- 사용자가 Finder에서 published DMG를 열고 `MacDog.app`을 `Applications`로 실제 drag-and-drop했습니다.
- 설치된 `/Applications/MacDog.app`의 앱/CLI 바이너리가 mounted DMG 내부 앱/CLI 바이너리와 같은 checksum임을 확인했습니다.
- `/Applications/MacDog.app` 첫 실행 후 `~/bin/codex-usage`, usage cache LaunchAgent, macOS 로그인 항목, 실행 중인 app path가 `/Applications/MacDog.app` 기준임을 확인했습니다.
- `./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage`가 `usage-fetch:success`로 통과했습니다.
- Popover 실제 UI에서 Codex 사용량, 활성 자원, 잠들지 않기, 배터리, 설정 탭 전환을 확인했습니다.
- `./script/cleanup_release_smoke_state.sh --apply` 뒤 Finder 검색 중복 원인이 제거되어 `MacDog.app`는 `/Applications/MacDog.app` 하나만 남았습니다.
- `./script/verify_release_final_state.sh --version 1.3.0`이 통과했습니다.

## 릴리즈 준비 판단

자동검증 기준 제품 구현 잔여 이슈: 없음.

근거:

- 알림 MVP는 `UserNotifications` 기반 로컬 알림, 사용자 opt-in, macOS 알림 권한 승인 후 발송, 기본 꺼짐 경계로 닫습니다.
- 알림 정책, 알림 설정, 알림 발송, dedupe 저장은 `UsageNotification` focused tests로 확인합니다.
- Codex 탭과 나머지 탭 UI 개선은 view model, summary, focused Swift tests로 회귀를 막습니다.
- screenshot renderer는 opt-in 증거입니다. 실제 렌더나 앱 화면을 보지 않았다면 UI 검수 완료로 기록하지 않습니다.
- README/ROADMAP/AGENTS와 v1.3.0 문서는 `./script/verify_v130_local_notification_boundary.sh --self-test`로 같은 제외 경계를 확인합니다.
- `codex-usage status --json`, app-owned cache schema, Codex app-server JSON-RPC 해석 계약은 v1.3.0에서 변경하지 않습니다.
- Apple Developer 계정 의존 배포/권한 흐름, WidgetKit 실제 UI, 장기 history export, 자동 모델 전환 힌트는 v1.3.0 구현/완료/후속 이슈에서 제외합니다.

## 잔여 이슈 정리

| 항목 | 릴리즈 판단 | 증거 또는 처리 |
| --- | --- | --- |
| Codex 사용량 알림 정책 | 정리됨 | `UsageNotificationPolicyTests`, `UsageNotificationDeliveryTests`, `UsageNotificationSettingsTests` |
| 이벤트별 1회 dedupe | 정리됨 | reset window 기반 dedupe key test와 dispatcher 중복 방지 test |
| 설정 탭 알림 UI | 정리됨 | 설정 snapshot test, screenshot renderer, 테스트 알림 버튼 부재 test |
| cache refresh 이후 알림 발송 | 정리됨 | `MenuBarController`의 dispatcher 연결과 `UsageNotificationDeliveryTests` |
| Codex 탭 위험/회복 요약 | 정리됨 | `UsageMonitorStateTests`, README screenshot hygiene 검증. 실제 popover 확인은 릴리즈 smoke 증거입니다. |
| Mac, 잠들지 않기, 배터리, 설정 탭 요약 | 정리됨 | `PopoverTabSummaryTests`, `UsageMonitorStateTests`, README screenshot hygiene 검증. 실제 popover 확인은 릴리즈 smoke 증거입니다. |
| 문서/제외 경계 | 정리됨 | README/ROADMAP/AGENTS/V130 문서와 `verify_v130_local_notification_boundary.sh` |
| 실제 앱 화면 확인 | 릴리즈 smoke 증거로 남김, v1.3.0 완료 | 실제 앱을 열지 않았다면 `UI 확인 미수행`으로 보고합니다. 2026-06-24에는 `/Applications/MacDog.app` popover 주요 탭 전환을 확인했습니다. |
| 실제 macOS 알림 권한 prompt와 Notification Center 표시 | 릴리즈 smoke 증거로 남김, 미수행 | Notification Center 표시까지 직접 확인한 경우만 완료로 기록합니다. v1.3.0 릴리즈 smoke에서는 앱 설정 탭의 알림 상태만 확인했고 OS 알림 표시 검수는 수행하지 않았습니다. |
| DMG Finder drag-and-drop 설치 | 릴리즈 smoke 증거로 남김, v1.3.0 완료 | published DMG 기준 Finder에서 실제 drag-and-drop한 경우만 설치 검수로 인정합니다. 2026-06-24에 이 경로로 설치 검수를 수행했습니다. |

릴리즈 전 자동검증이 통과하면 v1.3.0 구현 잔여 이슈는 닫힌 것으로 봅니다.
다만 실제 화면, OS 알림, DMG 설치, live cache fetch는 릴리즈 실행 증거이며 자동검증이나 문서만으로 완료 처리하지 않습니다.
v1.3.0에서는 실제 화면, DMG 설치, live cache fetch는 완료 증거가 있고, OS 알림 표시 검수는 미수행으로 남깁니다.

## 릴리즈 전 필수 자동검증

릴리즈 PR 또는 workflow 실행 전 아래 명령을 통과시킵니다.

```sh
git diff --check
markdownlint-cli2
./script/verify_v130_local_notification_boundary.sh --self-test
./script/verify_v130_release_readiness.sh --self-test
swift test --filter UsageNotification
swift test --filter UsageMonitorStateTests
swift test --filter PopoverTabSummaryTests
swift test --filter PopoverScreenshotRendererTests
swift test
MACDOG_RELEASE_VERSION=1.3.0 ./script/check.sh --no-run
```

기본 `swift`가 Command Line Tools SDK와 맞지 않으면 Xcode toolchain을 명시합니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --no-parallel
```

## 릴리즈 실행 스텝

아래 절차는 다음 릴리즈에서도 재사용할 수 있는 기준 절차입니다. v1.3.0은 최종 release head가 `main`의 `a689fe2e5ae6416a5864ebf9097a8890e2d95a4a`인 상태로 종료했습니다.

1. `git status -sb`로 릴리즈 대상 브랜치가 깨끗하고 원격과 같은지 확인합니다.
2. `git fetch origin` 후 `main`, `origin/main`, 릴리즈 대상 브랜치, 원격 릴리즈 대상 브랜치의 head를 기록합니다.
3. `git merge-base --is-ancestor main <release-branch>`으로 현재 릴리즈 브랜치가 `main`을 기반으로 하는지 확인합니다.
4. `git diff --check`, `markdownlint-cli2`, v1.3.0 boundary/readiness self-test를 실행합니다.
5. `swift test --filter UsageNotification`, `swift test --filter UsageMonitorStateTests`, `swift test --filter PopoverTabSummaryTests`, `swift test --filter PopoverScreenshotRendererTests`, 전체 `swift test`를 실행합니다.
6. `MACDOG_RELEASE_VERSION=1.3.0 ./script/check.sh --no-run`으로 GUI 실행 없이 전체 local gate를 통과시킵니다.
7. 릴리즈 PR을 `v.1.3.0`에서 `main`으로 만들고 CI/리뷰를 확인합니다.
8. 리뷰 수정이 있으면 같은 브랜치에서 수정, 검증, 커밋, 푸시를 반복합니다.
9. PR merge 후 `origin/main` 최신 SHA를 v1.3.0 release head로 기록합니다.
10. 원격 tag `v1.3.0`이 없는지 확인합니다.
11. `Release Candidate` workflow를 release head 기준으로 실행하고 artifact와 checksum을 확인합니다.
12. `Draft Release` workflow를 release head 기준으로 실행하고 draft 대상 commit, asset, checksum을 확인합니다.
13. stale draft가 아님을 확인한 뒤 draft를 publish하고, publish 후 tag와 draft 해제 상태를 확인합니다.
14. published DMG를 다시 내려받아 checksum과 `hdiutil verify`를 확인합니다.
15. 설치 검수가 필요한 릴리즈 종료라면 published DMG를 Finder에서 열고 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop합니다.
16. 설치본 기준 실행 중인 app path, `~/bin/codex-usage`, usage cache LaunchAgent, app-owned cache contract를 확인합니다.
17. 설치된 CLI 또는 빌드된 CLI로 `./script/verify_usage_fetch_cache_contract.sh --cli <codex-usage-path>`를 실행합니다.
18. live fetch 성공 시 5시간/주간 window와 `usage-weekly-history.json` append diagnostic을 확인합니다.
19. live fetch 실패 시 stale/error snapshot으로 분리하고 제품 회귀로 단정하지 않습니다.
20. `./script/cleanup_release_smoke_state.sh --apply`로 smoke 잔여물을 닫습니다.
21. `./script/verify_release_final_state.sh --version 1.3.0`이 통과해야 release smoke 종료로 기록합니다.
22. branch 정리는 `v.1.3.0`과 `origin/v.1.3.0`이 각각 `main`과 `origin/main`에 포함된 것을 확인한 뒤 별도 승인으로 수행합니다.

## 릴리즈 중 보고 원칙

- 실행하지 않은 UI/알림/설치 검수는 완료로 쓰지 않습니다.
- raw app-server payload, auth/session material, token, cookie는 출력하거나 저장하지 않습니다.
- Apple Developer 계정 의존 배포/권한 흐름은 v1.3.0 unsigned release 완료 조건에서 제외합니다.
- WidgetKit은 기본 앱/DMG에서 제외하며, 실제 Widget UI 검수는 별도 opt-in 환경에서만 다룹니다.
