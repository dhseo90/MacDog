# v1.9.1 릴리즈 준비 감사

상태: v1.9.1 GitHub Release publish / published DMG checksum·설치본 executable checksum·final-state 확인 /
사용량 탭 GUI 확인 / Mac/Sleep/Battery/Settings 탭 직접 조작 미수행
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
- Claude source는 숨깁니다. published GitHub Release는 [v1.9.1](https://github.com/dhseo90/MacDog/releases/tag/v1.9.1)입니다.
  signed annotated `v1.9.1` tag target은
  `a9cdfebf82ec822a4cda77dd2a55afb6e703458b`이고 GitHub tag verification은
  `Verified`입니다. GitHub Releases Latest는 `v1.9.1`입니다. published DMG SHA-256은
  `b0dec380a38cefe531dbd27e34cfeb3a6f2aa52d8eedf0b9cf8ab3e02506a14f`입니다.
- 현재 문서와 README는 `사용량 mode` 단독 picker를 현재 UI로 적지 않습니다.
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
- 기본 app bundle과 DMG에는 WidgetKit extension이 없어야 합니다.
- Codex CLI JSON/cache/app-server 계약과 Grok weekly-only/auth sibling, Claude source를
  유지합니다.

## PR, CI, review와 release head

1. `v1.9.1` → `main` PR [#41](https://github.com/dhseo90/MacDog/pull/41)을 사용했습니다.
2. 필수 CI `static-gates`와 `guardrails`는 SUCCESS였고 unresolved conversation은 0개였습니다.
3. blocker는 작성자 본인 review 불가에 따른 `REVIEW_REQUIRED`뿐이라 사용자 릴리즈 승인 아래
   admin bypass merge를 했습니다. merge SHA는
   `a9cdfebf82ec822a4cda77dd2a55afb6e703458b`입니다.
4. merge 후 최신 `origin/main` SHA를 v1.9.1 최종 release head로 기록했습니다.

## Signed tag, artifact, draft와 publish

1. 원격 `v1.9.1` tag와 stale draft가 없는 것을 확인했습니다.
2. `Release Candidate` workflow run `34678461289`를 최종 release head 기준으로 실행했습니다.
   `--ref v1.9.1`이 브랜치로 해석된 run `34678448298`은 취소했습니다.
3. `MacDog-1.9.1.dmg`와 `MacDog-1.9.1.dmg.sha256`을 내려받아 checksum과
   `hdiutil verify`를 확인했습니다. Release Candidate와 Draft Release는 별도 build입니다.
   bit-for-bit 동등성 통과로 기록하지 않습니다.
4. 최종 release head에 signed annotated `v1.9.1` tag를 만들고 push했습니다. tag object SHA는
   `61f99121da952876bdd4781e4101055eb49438e0`입니다.
5. GitHub tag verification이 `Verified`인지 확인했습니다.
6. 이미 존재하는 signed tag를 사용해 `Draft Release` workflow run `34678627746`을
   `UNSIGNED-DRAFT`로 실행했습니다. workflow가 tag를 자동 생성하게 두지 않았습니다.
7. draft의 `isDraft=true`, `isPrerelease=false`, signed tag target SHA, tag, 두 asset을
   확인했습니다.
8. signed tag target과 asset이 최신 release head와 일치하고 tag가 `Verified`일 때
   publish했습니다. published release ID는 `387480356`입니다.
9. publish 후 `isDraft=false`, asset download URL과 tag target을 다시 확인했습니다.
10. `gh api PATCH draft=false`만으로는 GitHub Releases Latest가 이전 tag에 남을 수 있습니다.
    publish 뒤 `gh release edit v1.9.1 --latest --verify-tag`로 Latest를 `v1.9.1`으로
    맞췄습니다.

`Stable Release` workflow는 Developer ID signing, notarization과 App Group provisioning이
별도 승인되지 않았으므로 실행하지 않습니다.

## 실제 Grok live smoke

실제 SuperGrok / Grok Build 주간 billing으로 아래만 확인합니다.

- `creditUsagePercent`와 잔여율 `100 - usedPercent`
- 5시간 값이 합성되지 않음
- Extra Usage Credits, prepaid, MONTHLY가 주간 잔여율로 들어오지 않음
- cache/history가 token, cookie, session, `~/.grok/auth.json` 원문, billing 원문을
  저장하지 않음
- Grok stale/error에서 Codex cache가 runner·알림·1번 탭으로 fallback하지 않음

`~/.grok/auth.json`은 사용자 승인 없이 열지 않습니다.

현재 상태: 통과. 설치본 `macdog-grok-usage status --write-cache`가 `Grok · 주간 76%`를
반환했습니다. cache `source=unofficial-cli-billing`, `usedPercent=76`,
`remainingPercent=24`, `resetsAt` 있음, 5시간 필드 없음, token 키 없음.

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

현재 상태: 설치는 사용자가 직접 Finder drag-and-drop으로 검수했습니다.
`/Applications/MacDog.app` v1.9.1 executable checksum이 published payload와 일치합니다.
사용량 탭 GUI는 사용자가 확인했습니다. 클린 삭제(`uninstall.sh`)가
`usage-weekly-history.json`을 지워 현재 주간 그래프는 sample 1개(잔여 9%)입니다.
완료된 이전 주는 `usage-reset-window-history.json` 12건이 남아 있습니다.
Mac/Sleep/Battery/Settings 탭 직접 조작은 미수행입니다.

## Release smoke 종료

```sh
./script/cleanup_release_smoke_state.sh --apply
./script/verify_release_final_state.sh --version 1.9.1
```

현재 상태: 통과. `mdfind -onlyin /Applications` 결과 `/Applications/MacDog.app` 하나.

## 릴리즈 증거 기록

| 증거 | 현재 상태 |
| --- | --- |
| `git diff --check` | 2026-09-12, 통과 |
| `npx --yes markdownlint-cli2@0.22.1` | 2026-09-12, 41 file / 0 error |
| `./script/verify_v191_multi_provider_contract.sh --self-test` | 2026-09-12, 통과 |
| `./script/verify_v191_release_readiness.sh --self-test` | 2026-09-12, publish 후 문서 게이트 |
| 전체 `swift test` | 2026-09-12, 583 passed / 4 skipped |
| Xcode Debug no-sign build | 2026-09-12, BUILD SUCCEEDED |
| `MACDOG_APP_VERSION=1.9.1 ./script/check.sh --no-run` | 2026-09-12, 통과 |
| README screenshot freshness | renderer 산출물을 `Docs/Images/README/PopoverTabs/`에 반영 |
| 실제 Grok live smoke | 통과 |
| `~/.grok/auth.json` 조회 | 미수행 |
| PR, CI, review | PR [#41](https://github.com/dhseo90/MacDog/pull/41), `static-gates`/`guardrails` SUCCESS, admin bypass merge |
| signed annotated `v1.9.1` tag / GitHub `Verified` | tag object `61f99121da952876bdd4781e4101055eb49438e0`, target `a9cdfebf82ec822a4cda77dd2a55afb6e703458b` |
| Published `v1.9.1` DMG | 있음. SHA-256 `b0dec380a38cefe531dbd27e34cfeb3a6f2aa52d8eedf0b9cf8ab3e02506a14f`. release ID `387480356`. GitHub Latest `v1.9.1` |
| 설치본 executable checksum | 통과. `1c4e91ac64c40a3361f3b169b9d33571f3aabcea0f26ff9beb54faf66329e67b` |
| Codex/Grok LaunchAgent | 통과. 둘 다 `/Applications/MacDog.app/Contents/MacOS/` writer |
| 사용량 탭 GUI | 사용자 확인. 현재 주간 그래프는 클린 삭제 후 sample 1개 |
| Mac/Sleep/Battery/Settings 탭 직접 조작 | 미수행 |
| cleanup / final-state | 통과 |

검증하지 않은 항목은 완료로 바꾸지 않습니다.

## 알려진 설치 잔여

클린 삭제에 `script/uninstall.sh`를 써서 `usage-weekly-history.json`과
`grok-usage-history.json`이 지워졌습니다. Trash/Time Machine에서 복구하지 못했습니다.
`usage-five-hour-history.json`과 `usage-reset-window-history.json`은 uninstall 대상이
아니라 남았습니다. 현재 주간 그래프는 새 sample부터 다시 쌓입니다.

Privileged helper `/Library/PrivilegedHelperTools/com.dhseo.macdog.helper`는
`--with-helper` 없이 남겨 두었습니다.

## 릴리즈 잔여 이슈

코드 기능 잔여는 없습니다. publish, Finder 설치, LaunchAgent, live Grok, final-state는
닫혔습니다. Mac/Sleep/Battery/Settings 탭 직접 조작은 미수행으로 남습니다.

추천 모델: `grok-4.6`
추론 수준: 높음 (high)
선정 근거: 영향도 2 + 불확실성 0 + 검증 난이도 2 + 변경 범위 1 = 5점. 릴리즈 영향.
