# v1.8.0 릴리즈 준비 감사

상태: 로컬 개발 자동 검증 통과 / PR·CI·review, live Claude, GUI·설치, tag·artifact·publish 미수행
작성일: 2026-07-12
대상 버전: `1.8.0`

## 릴리즈 범위

- 사용자가 설정에서 `Codex` 또는 `Claude` 중 하나를 `사용량 mode`로 선택합니다.
- 1번 탭, 메뉴바 러너, 사용량 알림은 선택한 provider만 사용하며 합산·비교·자동 fallback을
  제공하지 않습니다.
- v1.7.0 plan transition scenario·epoch UI는 제거하고 주간 1/7 day 목표와 5시간 pace
  페이스메이커를 사용합니다.
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
7. draft의 `isDraft=true`, `isPrerelease=false`, `targetCommitish`, tag, 두 asset을 확인합니다.
8. target과 asset이 최신 release head와 일치하고 tag가 `Verified`일 때만 publish합니다.
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
2. DMG payload version, app/CLI/Claude bridge executable checksum이 release head artifact와
   일치하는지 확인합니다.
3. Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제
   drag-and-drop합니다.
4. `/Applications/MacDog.app`의 version, executable checksum, codesign과 실행 중 app path를
   확인합니다.
5. 설정 탭에는 `사용량 mode` 한 항목만 있고 plan transition·Claude Preview UI가 없는지 확인합니다.
6. Codex/Claude mode 전환 시 1번 탭, 러너, 알림 source가 함께 바뀌고 다른 provider로 fallback하지
   않는지 확인합니다.
7. Claude 사용률·잔여율·reset, cache 없음 연결 state, partial/stale/error/복구 표시를 확인합니다.
8. runner, popover placement, 주요 탭, `~/bin/codex-usage`, Codex mode 전용 usage cache
   LaunchAgent의 설치·Claude mode 제거를 확인합니다.
9. `./script/verify_usage_fetch_cache_contract.sh --cli <installed-codex-usage>`를 실행합니다.

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
| 전체 Swift test | 2026-07-13, 449개 통과 / 명시적 opt-in 4개 skip / 실패 0개 |
| Xcode Debug no-sign build | 2026-07-12, 통과 |
| `MACDOG_APP_VERSION=1.8.0 ./script/check.sh --no-run` | 2026-07-12, 통과 |
| `main` branch protection | 2026-07-12, 승인 1회 / Code Owners / branch 최신화 / `static-gates` / `guardrails` / conversation resolution 확인 |
| PR, CI, review | 미수행 |
| 최종 `origin/main` release head | 미기록 |
| signed annotated `v1.8.0` tag / GitHub `Verified` | 미수행 |
| Release Candidate run / DMG checksum / `hdiutil verify` | 미수행 |
| Draft `targetCommitish` / asset / state 확인 | 미수행 |
| 실제 Claude live smoke | 미수행 |
| Published release와 재다운로드 검증 | 미수행 |
| Finder drag-and-drop와 GUI smoke | 미수행 |
| cleanup / final-state | 미수행 |

검증하지 않은 항목은 완료로 바꾸지 않습니다. 결과를 기록할 때 run ID, SHA, checksum, tag verification,
실제 설치 경로와 확인 화면을 확인된 사실로 남깁니다.

## 릴리즈 잔여 이슈

### P0 — PR·CI·review와 release head 확정

추천 모델: `5.6 Sol`
추론 수준: 높음 (high)
선정 근거: 영향도 2 + 불확실성 1 + 검증 난이도 2 + 변경 범위 1 = 6점. 보호 규칙과 최종
release head 정합성을 함께 확인해야 합니다.

### P0 — 실제 Claude live와 선택 provider GUI smoke

추천 모델: `5.6 Sol`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 1 = 7점. 외부 event 상태 전이와
privacy 경계를 실제 UI에서 함께 검증해야 합니다.

### P0 — signed tag, artifact, draft, publish와 published DMG 설치

추천 모델: `5.6 Sol`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 1 + 검증 난이도 2 + 변경 범위 2 = 7점. tag·artifact·설치본의
동일성과 사용자 환경 변경을 포함합니다.
