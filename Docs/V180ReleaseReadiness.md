# v1.8.0 릴리즈 준비 감사

상태: v1.8.0 GitHub Release publish / published DMG Finder 설치·설치본 UI·final-state 확인 /
실제 Claude 구독 live smoke 미수행
작성일: 2026-07-13
대상 버전: `1.8.0`

## 릴리즈 범위

- 사용자가 설정에서 `Codex` 또는 `Claude` 중 하나를 `사용량 mode`로 선택합니다.
- 1번 탭, 메뉴바 러너, 사용량 알림은 선택한 provider만 사용하며 합산·비교·자동 fallback을
  제공하지 않습니다.
- v1.7.0 plan transition scenario·epoch UI는 제거하고 주간 1/7 day 목표와 5시간 pace
  페이스메이커를 사용합니다.
- Codex 5시간 window가 일시 미제공되면 weekly-only partial success로 저장하고, 1번 탭은
  `현재 제공되지 않음`을 표시하면서 주간 history·runner·알림을 계속 갱신합니다.
- Claude는 status line의 allowlist field만 별도 cache/history로 저장합니다. Claude settings,
  auth store, Keychain, transcript는 읽거나 수정하지 않습니다.
- WidgetKit과 Apple Developer Program이 필요한 stable workflow는 이번 완료 조건에서 제외합니다.

제품 계약은 [V180ClaudeUsageParityPreview.md](V180ClaudeUsageParityPreview.md)를 기준으로 합니다.

## 릴리즈 전 자동 gate

release branch의 clean worktree에서 실행합니다.

```sh
git diff --check
./script/verify_v180_selected_provider_contract.sh --self-test
./script/verify_v180_release_readiness.sh --self-test
MACDOG_APP_VERSION=1.8.0 ./script/check.sh --no-run
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

확인 항목:

- `dist/MacDog.app` 버전은 `1.8.0`입니다.
- app bundle 안의 `MacDog`, `codex-usage`, `macdog-claude-statusline`이 실행 가능합니다.
- 기본 app bundle과 DMG에는 WidgetKit extension이 없습니다.
- Codex CLI JSON/cache/app-server 계약과 legacy history decode 호환을 유지합니다.
- weekly-only cache encode/decode, 주간 history append, 5시간 history 보존과 복구 재개를 확인합니다.
- release branch worktree가 clean 상태입니다.

## PR, CI, review와 release head

1. release branch를 push하고 `<release-branch> -> main` PR을 생성합니다.
2. `main` 보호 규칙의 승인 1회, Code Owners review, branch 최신화, 필수 CI `static-gates`와
   `guardrails`, unresolved conversation 0개를 확인합니다.
3. 실패가 있으면 같은 branch에서 수정, focused/전체 검증, 커밋, push를 반복합니다.
4. blocker가 작성자 본인 review 불가뿐이어도 사용자 명시 승인 전 admin bypass를 사용하지 않습니다.
5. merge 후 최신 `origin/main` SHA를 v1.8.0 최종 release head로 기록합니다.
6. tag 생성 전 release head 이후 추가 커밋이 없는지 확인합니다.

## Signed tag, artifact, draft와 publish

1. 원격 `v1.8.0` tag와 stale draft가 없는지 확인합니다.
2. `Release Candidate` workflow를 최종 release head 기준으로 실행합니다.
3. `MacDog-1.8.0.dmg`와 `MacDog-1.8.0.dmg.sha256`을 내려받아 checksum과
   `hdiutil verify`를 확인합니다.
4. 최종 release head에 signed annotated `v1.8.0` tag를 만들고 push합니다.
5. GitHub tag verification이 `Verified`인지 확인합니다.
6. 이미 존재하는 signed tag를 사용해 `Draft Release` workflow를 실행합니다. workflow가 tag를
   자동 생성하게 두지 않습니다.
7. draft의 `isDraft=true`, `isPrerelease=false`, signed tag target SHA, tag, 두 asset을 확인합니다.
   기존 tag가 있는 release의 `targetCommitish`는 identity가 아니라 정보로만 기록합니다.
   Draft는 tag endpoint로 조회하지 않고 생성 명령이 반환한 고유 URL을 release ID로 해석해
   readback하며, 실패 시에도 그 release ID만 삭제합니다.
8. signed tag target과 asset이 최신 release head와 일치하고 tag가 `Verified`일 때만 publish합니다.
9. publish 후 `isDraft=false`, asset download URL과 tag target을 다시 확인합니다.

`Stable Release` workflow는 Developer ID signing, notarization과 App Group provisioning이 별도
승인되지 않았으므로 실행하지 않습니다.

## 실제 Claude live smoke

실제 Claude Code status line event로 아래만 확인합니다.

- 첫 `rate_limits.five_hour`·`seven_day` 사용률, 잔여율 `100 - used_percentage`, reset 시각
- cache/history가 raw JSON이나 token, cookie, session, transcript, local path를 저장하지 않음
- partial window, event 중단 후 stale, malformed input error, 다음 정상 event 복구
- Claude mode에서 Codex cache가 runner·알림·1번 탭으로 fallback하지 않음
- Codex mode에서 Claude cache가 runner·알림에 영향을 주지 않음

Claude settings, auth store, Keychain, transcript 원문은 live smoke에서도 읽거나 저장하지 않습니다.
실제 event가 없으면 synthetic fixture 통과와 live 미수행을 분리 보고합니다.

## Published DMG 설치와 GUI smoke

1. published DMG와 checksum을 새로 내려받아 checksum과 `hdiutil verify`를 재확인합니다.
2. DMG payload version과 workflow head SHA가 signed release head와 일치하는지 확인합니다.
   Release Candidate와 Draft Release는 같은 head에서 별도 build하므로 ad-hoc signed executable의
   bit-for-bit 동일성을 주장하지 않습니다. 설치본 executable은 published DMG payload와 직접
   checksum을 대조합니다.
3. Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제
   drag-and-drop합니다.
4. `/Applications/MacDog.app`의 version, executable checksum, codesign과 실행 중 app path를
   확인합니다.
5. 설정 탭에는 `사용량 mode` 한 항목만 있고 plan transition·Claude Preview UI가 없는지 확인합니다.
6. Codex/Claude mode 전환 시 1번 탭, 러너, 알림 source가 함께 바뀌고 다른 provider로 fallback하지
   않는지 확인합니다.
7. Claude 사용률·잔여율·reset, cache 없음 연결 state, partial/stale/error/복구 표시를 확인합니다.
8. Codex live가 weekly-only이면 1번 탭의 `5시간 현재 제공되지 않음`, 주간 그래프·페이스메이커,
   주간 runner·알림과 error 없는 success cache를 확인합니다. 5시간 window 복구 시 표시·history·pace가
   자동 재개되는지도 확인합니다.
9. runner, popover placement, 주요 탭, `~/bin/codex-usage`, Codex mode 전용 usage cache
   LaunchAgent의 설치·Claude mode 제거를 확인합니다.
10. `./script/verify_usage_fetch_cache_contract.sh --cli <installed-codex-usage>`를 실행합니다.

Finder drag-and-drop 또는 실제 앱 UI를 직접 확인하지 않았다면 설치·GUI smoke는 `미수행`으로
보고합니다.

## Release smoke 종료

```sh
./script/cleanup_release_smoke_state.sh --apply
./script/verify_release_final_state.sh --version 1.8.0
```

완료 조건:

- `/Applications/MacDog.app` 외 중복 app bundle 0개
- stale MacDog DMG mount 0개
- 설치 app의 `MacDog`, `codex-usage`, `macdog-claude-statusline` 실행 가능
- Finder `응용 프로그램` 범위 `MacDog` 검색 결과 1개
- CLI symlink가 설치 앱을 가리키고 usage cache LaunchAgent가 Codex mode에서만 실행됨
- README와 ROADMAP에 published release head, tag, asset checksum, smoke 결과 반영
- release branch 삭제는 main/origin/main 포함 확인과 사용자 명시 승인 뒤에만 수행

## 릴리즈 증거 기록

| 증거 | 현재 상태 |
| --- | --- |
| 전체 Swift test | 2026-07-13, 464개 통과 / 명시적 opt-in 4개 skip / 실패 0개 |
| Xcode Debug no-sign build | 2026-07-13, 통과 |
| `MACDOG_APP_VERSION=1.8.0 ./script/check.sh --no-run` | 2026-07-13, 통과 |
| Codex weekly-only focused test | v1.8 selected-provider 221개 중 218개 통과 / opt-in 3개 skip / 실패 0개 |
| 실제 Codex weekly-only live cache | 2026-07-13, success / 주간 93% 남음 / weekly history sample 1개 / error 없음 |
| `main` branch protection | 2026-07-12, 승인 1회 / Code Owners / branch 최신화 / `static-gates` / `guardrails` / conversation resolution 확인 |
| PR, CI, review | PR #35·#36 필수 CI 통과 / self-review 제한만 남은 상태에서 사용자 승인 admin bypass merge |
| 최종 `origin/main` release head | `14d716a88ea10a77344a4f9aa3651c23b1160f8c` |
| signed annotated `v1.8.0` tag / GitHub `Verified` | tag object `1d9748753761f0dfeca1b2f3c4aeebccd2389aba` / target `14d716a88ea10a77344a4f9aa3651c23b1160f8c` / `Verified` |
| Release Candidate run / DMG checksum / `hdiutil verify` | run `29253650552` 통과 / artifact checksum·`hdiutil verify` 통과 |
| Draft signed tag target / asset / state 확인 | run `29254330686` 통과 / tag target `14d716a...` / `isDraft=true`, `isPrerelease=false`, asset 2개 확인 뒤 publish |
| 실제 Claude live smoke | 미수행 |
| Published release와 재다운로드 검증 | release ID `353177762`, `isDraft=false`, `isPrerelease=false` / DMG SHA-256 `056926bd16668c288d132fab7ff8efb545f00d8eefb8f222440e3f389338a3af` / checksum·`hdiutil verify` 통과 |
| Finder drag-and-drop와 GUI smoke | 사용자 Finder 대치 / 설치본 v1.8.0 / executable SHA-256 `4526329e79f5cebfd5897830ac3d8037948589ece6c7f9af5529b41da50c910b` / codesign 통과 / 설치본 UI 직접 1번 탭 compact layout·설정 불필요 UI 제거·Claude empty state 확인 |
| 선택 provider 왕복 | `Codex → Claude`에서 Codex cache LaunchAgent plist/job 제거 / `Claude → Codex`에서 weekly-only 화면·LaunchAgent 설치본 CLI 복구 / 최근 종료 코드 0 |
| Codex 설치 component와 live cache | `~/bin/codex-usage` 설치본 symlink / 60초 one-shot LaunchAgent / weekly-only success cache 35% 사용·65% 남음 / 금지 key 없음 |
| 단발 installed CLI live verifier | app-server 10초 timeout을 invalid success가 아닌 `usage-fetch:source-unavailable`로 정상 분리 |
| 로그인 항목 | 외부 `SMAppService.mainApp.status`는 `notFound`였지만 Background Task DB의 설치 앱은 `[enabled, allowed, notified]` / 공식 final-state 교차검증 통과 |
| cleanup / final-state | 중복 `dist/MacDog.app` 격리·DMG eject / `./script/verify_release_final_state.sh --version 1.8.0` 통과 / Finder `응용 프로그램` 범위 `MacDog` 1개 확인 |

Release Candidate app executable SHA-256은 `27001012e6694d00e4ef497a705114e777e4c323760e2c4f5293e140242ce2de`,
published DMG app executable SHA-256은
`4526329e79f5cebfd5897830ac3d8037948589ece6c7f9af5529b41da50c910b`입니다. 두 workflow가 같은
release head를 별도 build하므로 checksum이 다르며, bit-for-bit 동등성 통과로 기록하지 않습니다.
published payload와 `/Applications/MacDog.app` executable checksum은 서로 일치합니다.

검증하지 않은 항목은 완료로 바꾸지 않습니다. 결과를 기록할 때 run ID, SHA, checksum, tag verification,
실제 설치 경로와 확인 화면을 확인된 사실로 남깁니다.

## 릴리즈 잔여 이슈

### P0 — 실제 Claude 구독 live smoke

추천 모델: `5.6 Sol`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 1 = 7점. 현재 환경에서 실제
`rate_limits.five_hour`·`seven_day` event가 제공되지 않아, 외부 event 상태 전이와 privacy 경계를
live data로 검증하지 못했습니다. synthetic fixture 통과를 live 완료로 대체하지 않습니다.
