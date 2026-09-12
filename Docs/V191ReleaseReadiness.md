# v1.9.1 릴리즈 준비 감사

상태: 자동 gate 준비 / published GitHub Release는 `v1.9.0` 유지 /
PR·signed tag·publish·Finder 설치·LaunchAgent 실등록·릴리즈 smoke 미수행
작성일: 2026-09-12
대상 버전: `1.9.1`

## 릴리즈 범위

- 설정에서 `Codex`와 `Grok`을 하나 또는 둘 다 활성화하고, 둘 다일 때 메인을 지정합니다.
- 1번 탭은 provider 하위 탭 없이 활성 provider 게이지 카드를 상단에 쌓습니다.
  provider 이름은 카드당 한 번이고, 행은 주간/5시간 · 사용 · 남음 · 리셋일입니다.
- 상세 그래프, Codex 초기화권, Grok pace, 러너, tooltip, 알림은 메인 provider만
  사용합니다. Codex 탭에는 페이스메이커 블록을 두지 않습니다.
- 합산·비교·자동 fallback은 없습니다. 없는 Codex 5시간은 게이지에서 숨기고
  weekly-only 성공은 `데이터 정상`입니다.
- Claude source는 숨깁니다. published GitHub Release는 이 문서 작성 시점에
  [v1.9.0](https://github.com/dhseo90/MacDog/releases/tag/v1.9.0)입니다.
- WidgetKit과 Apple Developer Program이 필요한 stable workflow는 이번 완료 조건에서
  제외합니다.

제품 계약은 [V191MultiProviderUsage.md](V191MultiProviderUsage.md)를 기준으로 합니다.

## 릴리즈 전 자동 gate

release branch의 clean worktree에서 실행합니다.

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v191_multi_provider_contract.sh --self-test
./script/verify_v191_release_readiness.sh --self-test
MACDOG_APP_VERSION=1.9.1 ./script/check.sh --no-run
```

확인 항목:

- 문서와 README snapshot이 현재 1번 탭·설정 UI와 맞습니다. `사용량 mode` 단독 picker,
  `현재 사용량` 막대, Codex 탭 페이스메이커 블록을 현재 UI로 적지 않습니다.
- published `v1.9.0` 완료 증거와 `verify_v190_*`를 덮어쓰지 않습니다.
- unpublished `v1.9.1`을 현재 GitHub Release나 `MacDog-1.9.1.dmg`로 주장하지 않습니다.
- 기본 app bundle과 DMG에는 WidgetKit extension이 없어야 합니다.
- Codex CLI JSON/cache/app-server 계약과 Grok weekly-only/auth sibling, Claude source를
  유지합니다.

## PR, CI, review와 release head

`v1.9.1` → `main` PR은 [#41](https://github.com/dhseo90/MacDog/pull/41)입니다.
CI 통과와 merge SHA는 아직 기록하지 않았습니다. `origin/main`은 published `v1.9.0`
merge `63d7fec6a0ca7714bbbf8a985bbb3bda362491ad`를 포함합니다. `v1.9.1` 브랜치는
`main`에 포함되지 않았습니다.

## Signed tag, artifact, draft와 publish

원격 `v1.9.1` tag와 `MacDog-1.9.1.dmg`는 없습니다. Release Candidate, signed tag,
Draft Release, publish는 이 문서의 현재 단계에서 실행하지 않습니다.
`Stable Release` workflow는 Developer ID signing, notarization과 App Group
provisioning이 별도 승인되지 않았으므로 실행하지 않습니다.

## 실제 Grok live smoke

실제 SuperGrok / Grok Build 주간 billing으로 아래만 확인합니다.

- `creditUsagePercent`와 잔여율 `100 - usedPercent`
- 5시간 값이 합성되지 않음
- Extra Usage Credits, prepaid, MONTHLY가 주간 잔여율로 들어오지 않음
- cache/history가 token, cookie, session, `~/.grok/auth.json` 원문, billing 원문을
  저장하지 않음
- Grok stale/error에서 Codex cache가 runner·알림·1번 탭으로 fallback하지 않음

`~/.grok/auth.json`은 사용자 승인 없이 열지 않습니다.

현재 상태: 미수행.

## Published DMG 설치와 GUI smoke

1. published DMG와 checksum을 새로 내려받아 checksum과 `hdiutil verify`를 재확인합니다.
2. Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제
   drag-and-drop합니다.
3. 설정에서 Codex/Grok 체크박스, 메인 picker, 상세 그래프와 메뉴바 주간 잔여율을
   확인합니다.
4. 1번 탭 상단 게이지 카드, 메인 그래프, Codex 초기화권 또는 Grok pace가 메인만
   따르는지 확인합니다.
5. 둘 다 활성일 때 Codex/Grok LaunchAgent가 함께 있는지 확인합니다.

Finder drag-and-drop 또는 설치본 popover를 직접 확인하지 않았다면 설치·GUI smoke는
`미수행`으로 보고합니다.

현재 상태: 미수행. README demo snapshot은 v1.9.1 renderer 결과입니다. 개발용
`ditto`로 `/Applications/MacDog.app`을 바꾼 기록은 Finder 설치 검수가 아닙니다.

## Release smoke 종료

```sh
./script/cleanup_release_smoke_state.sh --apply
./script/verify_release_final_state.sh --version 1.9.1
```

현재 상태: 미수행. published `v1.9.1`이 없습니다.

## 릴리즈 증거 기록

| 증거 | 현재 상태 |
| --- | --- |
| `git diff --check` | 2026-09-12, 통과 |
| `npx --yes markdownlint-cli2@0.22.1` | 2026-09-12, 41 file / 0 error |
| `./script/verify_v191_multi_provider_contract.sh --self-test` | 2026-09-12, 통과 |
| `./script/verify_v191_release_readiness.sh --self-test` | 2026-09-12, 통과 |
| 전체 `swift test` | 2026-09-12, 583 passed / 4 skipped |
| Xcode Debug no-sign build | 2026-09-12, BUILD SUCCEEDED |
| `MACDOG_APP_VERSION=1.9.1 ./script/check.sh --no-run` | 2026-09-12, 통과 |
| README screenshot freshness | renderer 산출물을 `Docs/Images/README/PopoverTabs/`에 반영 |
| 실제 Grok live smoke | 미수행 |
| `~/.grok/auth.json` 조회 | 미수행 |
| PR, CI, review | PR [#41](https://github.com/dhseo90/MacDog/pull/41) 생성. CI/merge 미기록 |
| signed annotated `v1.9.1` tag / GitHub `Verified` | 없음 |
| Published `v1.9.1` DMG | 없음 |
| Finder drag-and-drop와 GUI smoke | 미수행 |
| cleanup / final-state | 미수행 |

검증하지 않은 항목은 완료로 바꾸지 않습니다.

## 릴리즈 잔여 이슈

코드 기능 잔여는 없습니다. 아래는 릴리즈 실행 단계입니다.

1. `v1.9.1` → `main` PR, CI, review, merge
2. signed annotated `v1.9.1` tag와 GitHub `Verified`
3. unsigned draft DMG, publish, Latest 지정
4. Finder drag-and-drop 설치와 설치본 GUI
5. LaunchAgent 실등록과 release smoke / final-state
6. live Grok billing smoke

추천 모델: `grok-4.6`
추론 수준: 높음 (high)
선정 근거: 영향도 2 + 불확실성 0 + 검증 난이도 2 + 변경 범위 1 = 5점. 릴리즈 영향.
