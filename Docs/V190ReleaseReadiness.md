# v1.9.0 릴리즈 준비 감사

상태: 1차 구현·문서 정렬 완료 / GUI·live Grok billing·published DMG·Finder 설치·final-state
미수행
작성일: 2026-08-16
대상 버전: `1.9.0`

## 릴리즈 범위

- 사용자가 설정에서 `Codex` 또는 `Grok` 중 하나를 `사용량 mode`로 선택합니다.
- 1번 탭, 메뉴바 러너, 사용량 알림은 선택한 provider만 사용하며 합산·비교·자동 fallback을
  제공하지 않습니다.
- Claude source는 남기고 기본 picker에서는 숨깁니다. hidden re-enable이 켜진 경우에만
  Claude를 유지합니다.
- Grok는 SuperGrok / Grok Build 공유 주간 pool만 표시합니다. 5시간 window는 `현재 제공되지
  않음`이며 Extra Usage Credits를 reset credit처럼 보여 주지 않습니다.
- published GitHub Release는 이 문서를 작성하는 시점에도 [v1.8.0](https://github.com/dhseo90/MacDog/releases/tag/v1.8.0)입니다.
  `v1.9.0` tag와 published DMG는 없습니다.
- WidgetKit과 Apple Developer Program이 필요한 stable workflow는 이번 완료 조건에서 제외합니다.

제품 계약은 [V190GrokUsageAndClaudeHide.md](V190GrokUsageAndClaudeHide.md)를 기준으로 합니다.

## 릴리즈 전 자동 gate

release branch의 clean worktree에서 실행합니다.

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v180_selected_provider_contract.sh --self-test
./script/verify_v190_selected_provider_contract.sh --self-test
MACDOG_APP_VERSION=1.9.0 ./script/check.sh --no-run
```

확인 항목:

- 문서 용어가 visible `Codex`/`Grok`과 일치합니다.
- published `v1.8.0` 완료 증거와 `verify_v180_*`를 덮어쓰지 않습니다.
- `dist/MacDog.app` 버전을 1.9.0으로 맞추는 것은 packaging 단계입니다. 이 문서의
  현재 단계는 앱 실행과 DMG 생성을 하지 않습니다.
- 기본 app bundle과 DMG에는 WidgetKit extension이 없어야 합니다.
- Codex CLI JSON/cache/app-server 계약과 Claude source를 유지합니다.
- Grok cache는 `grok-usage.json`이며 token/원문 billing을 저장하지 않습니다.

## PR, CI, review와 release head

아직 수행하지 않습니다. `v1.9.0` → `main` PR, 필수 CI, review, merge 후 `origin/main`
release head 기록은 이후 릴리즈 실행에서만 합니다.

## Signed tag, artifact, draft와 publish

아직 수행하지 않습니다.

1. 원격 `v1.9.0` tag와 stale draft가 없는지 확인합니다.
2. `Release Candidate` workflow를 최종 release head 기준으로 실행합니다.
3. `MacDog-1.9.0.dmg`와 `MacDog-1.9.0.dmg.sha256`을 내려받아 checksum과
   `hdiutil verify`를 확인합니다.
4. 최종 release head에 signed annotated `v1.9.0` tag를 만들고 push합니다.
5. GitHub tag verification이 `Verified`인지 확인합니다.
6. 이미 존재하는 signed tag를 사용해 `Draft Release` workflow를 실행합니다.
7. signed tag target과 asset이 최신 release head와 일치하고 tag가 `Verified`일 때만
   publish합니다.

`Stable Release` workflow는 Developer ID signing, notarization과 App Group provisioning이
별도 승인되지 않았으므로 실행하지 않습니다.

## 실제 Grok live smoke

실제 SuperGrok / Grok Build 주간 billing으로 아래만 확인합니다.

- `creditUsagePercent`와 잔여율 `100 - usedPercent`
- 5시간 값이 합성되지 않고 `현재 제공되지 않음`
- Extra Usage Credits, prepaid, MONTHLY가 주간 잔여율로 들어오지 않음
- cache/history가 token, cookie, session, `~/.grok/auth.json` 원문, billing 원문을 저장하지 않음
- Grok stale/error에서 Codex cache가 runner·알림·1번 탭으로 fallback하지 않음
- Codex mode에서 Grok cache가 runner·알림에 영향을 주지 않음

`~/.grok/auth.json`은 사용자 승인 없이 열지 않습니다. live billing이 없으면 synthetic
fixture 통과와 live 미수행을 분리 보고합니다.

현재 상태: 미수행.

## Published DMG 설치와 GUI smoke

1. published DMG와 checksum을 새로 내려받아 checksum과 `hdiutil verify`를 재확인합니다.
2. Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제
   drag-and-drop합니다.
3. `/Applications/MacDog.app`의 version, executable checksum, codesign과 실행 중 app path를
   확인합니다.
4. 설정 탭 visible mode가 `Codex`/`Grok`만 있고 Claude가 기본 picker에 없는지 확인합니다.
5. Codex/Grok mode 전환 시 1번 탭, 러너, 알림 source가 함께 바뀌고 다른 provider로
   fallback하지 않는지 확인합니다.
6. Grok 주간 사용률·잔여율·reset, 5시간 `현재 제공되지 않음`, cache 없음 empty state,
   stale/error를 확인합니다.
7. runner, popover placement, 주요 탭, `~/bin/codex-usage`, Codex/Grok mode별 usage cache
   LaunchAgent 설치·제거를 확인합니다.

Finder drag-and-drop 또는 실제 앱 UI를 직접 확인하지 않았다면 설치·GUI smoke는 `미수행`으로
보고합니다. 릴리즈 전 설치 후 UI 체크는 사용자가 직접 합니다.

현재 상태: 미수행.

## Release smoke 종료

```sh
./script/cleanup_release_smoke_state.sh --apply
./script/verify_release_final_state.sh --version 1.9.0
```

완료 조건:

- `/Applications/MacDog.app` 외 중복 app bundle 0개
- 설치 app의 `MacDog`, `codex-usage`, `macdog-grok-usage`, `macdog-claude-statusline` 실행 가능
- Finder `응용 프로그램` 범위 `MacDog` 검색 결과 1개
- CLI symlink가 설치 앱을 가리키고 usage cache LaunchAgent가 선택 mode와 일치
- README와 ROADMAP에 published release head, tag, asset checksum, smoke 결과를 반영
- release branch 삭제는 main/origin/main 포함 확인과 사용자 명시 승인 뒤에만 수행

현재 상태: 미수행.

## 릴리즈 증거 기록

| 증거 | 현재 상태 |
| --- | --- |
| `git diff --check` | 2026-08-16, 통과 |
| `npx --yes markdownlint-cli2@0.22.1` | 2026-08-16, 39 file / 0 error |
| `./script/verify_v190_selected_provider_contract.sh --self-test` | 2026-08-16, 통과. focused 160개 통과 / opt-in 3개 skip / 실패 0개 |
| `./script/verify_v190_release_readiness.sh --self-test` | 2026-08-16, 통과 |
| `./script/verify_v180_release_readiness.sh --self-test` | 2026-08-16, 통과. published `v1.8.0` 증거 유지 |
| 전체 `swift test` | 이번 단계에서 실행하지 않음 |
| Xcode Debug no-sign build | 이번 단계에서 실행하지 않음 |
| `MACDOG_APP_VERSION=1.9.0 ./script/check.sh --no-run` | 이번 단계에서 실행하지 않음 |
| 실제 Grok live smoke | 미수행 |
| `~/.grok/auth.json` 조회 | 미수행 |
| PR, CI, review | 미수행 |
| signed annotated `v1.9.0` tag / GitHub `Verified` | 없음 |
| Published `v1.9.0` DMG | 없음. 현재 GitHub Release는 `v1.8.0` |
| Finder drag-and-drop와 GUI smoke | 미수행. 사용자가 릴리즈 전 직접 검수 |
| cleanup / final-state | 미수행 |

검증하지 않은 항목은 완료로 바꾸지 않습니다.

## 알려진 설치 잔여

`script/uninstall.sh`는 현재 Grok cache/history/lock과
`com.dhseo.macdog.grok-usage-cache` LaunchAgent를 제거하지 않습니다. 릴리즈 전 사용자
설치 검수와 별도로 정리 여부를 확인할 수 있습니다.

## 릴리즈 잔여 이슈

### P0 — 사용자 설치 후 UI 검수

추천 모델: `grok-4.6`
추론 수준: 높음 (high)
선정 근거: 영향도 2 + 불확실성 1 + 검증 난이도 2 + 변경 범위 1 = 6점.
설정 picker, Grok 1번 탭, Codex/Grok LaunchAgent 전환은 실제 앱에서만 확인한다.

### P0 — Grok live billing smoke

추천 모델: `grok-4.6`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 1 = 7점. 인증 경계 상향.
unofficial billing과 memory-only token 예외를 live로 확인해야 한다. 사용자 승인 없이
`~/.grok/auth.json`을 열지 않는다.

### P1 — published DMG와 final-state

추천 모델: `grok-4.6`
추론 수준: 높음 (high)
선정 근거: 영향도 2 + 불확실성 0 + 검증 난이도 2 + 변경 범위 1 = 5점. 릴리즈 영향.
`v1.9.0` → `main` merge와 signed tag 이후에만 실행한다.
