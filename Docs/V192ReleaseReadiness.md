# v1.9.2 릴리즈 준비 감사

상태: v1.9.2 GitHub Release publish / published DMG checksum·설치본 executable checksum /
Finder 재설치 후 그래프 보존 확인 / Mac/Sleep/Battery 탭 직접 조작 미수행
작성일: 2026-09-19
대상 버전: `1.9.2`
기준 브랜치: `v1.9.2`
개발 검증 버전: `MACDOG_APP_VERSION=1.9.2`

## 릴리즈 범위

- 메뉴바 extra는 강아지를 오른쪽에 두고, 메인 provider 주간 잔여 사용량은 바로
  왼쪽에 9pt tabular 숫자로 붙입니다. `%`는 더 작은 7pt입니다.
- 설정 `현재 잔여 사용량`과 오른쪽 종속 옵션 `% 표기`로 숫자와 `%`를 따로 끕니다.
  잔여 사용량을 끄면 강아지만 남습니다.
- `uninstall.sh`는 앱/CLI/LaunchAgent/snapshot cache만 지우고 주간/5시간/
  reset-window와 Claude/Grok 그래프 history는 보존합니다. 재설치해도 그래프가
  유지되어야 합니다.
- 별도 uninstall 실실행 항목은 두지 않습니다. history 보존은 publish된 DMG를
  Finder에서 `/Applications`로 다시 넣는 과정에서 확인합니다.
- Codex/Grok 선택, cache schema, 러너 속도, 합산·fallback 금지는 v1.9.1과
  같습니다. Claude source는 숨깁니다.
- WidgetKit과 Apple Developer Program이 필요한 `Stable Release` workflow는
  이번 완료 조건에서 제외합니다.

제품 계약은 [V192MenuBarGlancePolish.md](V192MenuBarGlancePolish.md)를 기준으로 합니다.
published GitHub Release는 [v1.9.2](https://github.com/dhseo90/MacDog/releases/tag/v1.9.2)입니다.
signed annotated `v1.9.2` tag object는 `ce099bbbe7267058bd1fc7e75b160c976d24f9c7`이고
GitHub tag verification은 `Verified`입니다. 코드 merge head는 PR
[#43](https://github.com/dhseo90/MacDog/pull/43) `3756b1abc4306add7ab77aa106b3952e6043f1ab`입니다.
이 기록 PR merge 후 tag를 마지막 커밋에 맞춥니다. GitHub Releases Latest는 `v1.9.2`입니다.
published DMG SHA-256은
`6d65189a71d2dd0266f18bb8a44f101f760d461ac8682e4c84ad6219c5569df7`입니다.

## 릴리즈 전 자동 gate

release branch의 clean worktree에서 실행합니다.

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v192_menu_bar_glance_contract.sh --self-test
./script/verify_v192_release_readiness.sh --self-test
MACDOG_APP_VERSION=1.9.2 ./script/check.sh --no-run
```

확인 항목:

- README snapshot 설정 탭이 `현재 잔여 사용량`과 `% 표기`를 보여 줍니다.
  `메뉴바에 주간 잔여율 표시`만 있는 이전 문구를 현재 UI로 적지 않습니다.
- published `v1.9.1` 완료 증거와 `verify_v191_*`를 덮어쓰지 않습니다.
- 기본 app bundle과 DMG에는 WidgetKit extension이 없어야 합니다.
- Codex CLI JSON/cache/app-server 계약과 Grok weekly-only/auth sibling, Claude
  source를 유지합니다.
- uninstall dry-run이 그래프 history를 `Would preserve`로 남깁니다.

## PR, CI, review와 release head

1. `v1.9.2` → `main` PR [#43](https://github.com/dhseo90/MacDog/pull/43)을 사용했습니다.
2. 필수 CI `static-gates`와 `guardrails`는 SUCCESS였고 unresolved conversation은 0개였습니다.
3. blocker는 작성자 본인 review 불가에 따른 `REVIEW_REQUIRED`뿐이라 사용자 릴리즈 승인 아래
   admin bypass merge를 했습니다. merge SHA는
   `3756b1abc4306add7ab77aa106b3952e6043f1ab`입니다.

현재 상태: PR merge 완료.

## Signed tag, artifact, draft와 publish

1. 최종 release head에 signed annotated `v1.9.2` tag만 만듭니다. GitHub
   `Verified`가 아니면 draft/publish를 하지 않습니다.
2. `Release Candidate`로 `MacDog-1.9.2.dmg`와 `.dmg.sha256`을 만들고 checksum과
   `hdiutil verify`를 확인합니다.
3. Draft Release는 기존 signed tag만 사용합니다. workflow가 unsigned tag를
   자동 생성하지 않게 합니다.
4. publish 후 Latest, asset 재다운로드, checksum·`hdiutil verify`를 확인합니다.
5. `gh api PATCH draft=false`만으로 Latest가 남을 수 있으므로
   `gh release edit v1.9.2 --latest --verify-tag`를 확인합니다.

`Stable Release` workflow는 Developer ID signing, notarization과 App Group
provisioning이 별도 승인되지 않았으므로 실행하지 않습니다.

현재 상태: 통과. RC run `35434155238`, Draft run `35434340164`, publish 후
Latest는 `v1.9.2`, release ID `392011164`입니다. 재다운로드 checksum과
`hdiutil verify`를 확인했습니다.

## Published DMG 설치와 그래프 보존

별도 `uninstall.sh` 실실행 검수는 하지 않습니다.

1. published DMG와 checksum을 새로 내려받아 checksum과 `hdiutil verify`를
   재확인합니다.
2. Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제
   drag-and-drop합니다. 개발용 `dist/MacDog.app`은 설치원이 아닙니다.
3. 첫 실행 후 버전, executable checksum, LaunchAgent, `~/bin/codex-usage`를
   확인합니다.
4. 이번 주 그래프가 단순 직선으로 리셋되지 않았는지, 지난 창 기록이 남아 있는지
   확인합니다. 이 단계가 history 보존 검수입니다.
5. 설정에서 `현재 잔여 사용량`과 `% 표기`를 확인합니다.

Finder drag-and-drop 또는 설치본 그래프를 직접 확인하지 않았다면 설치 smoke는
`미수행`으로 보고합니다.

현재 상태: 사용자가 published DMG를 Finder drag-and-drop으로 설치했습니다.
`/Applications/MacDog.app` v1.9.2 executable checksum
`6225175233edcfd82ec3d93f9865b46b7ab47b5a3fdf5db623f1a70212ecb16e`가 published
payload와 일치합니다. 그래프 history는 유지되었습니다. 주간 sample 2125개,
reset-window 기록 12건, 5시간 sample 304개, Grok history 4096개입니다. 이번 주
곡선이 1 sample 직선으로 리셋되지 않았습니다. Codex/Grok LaunchAgent는 둘 다
`/Applications/MacDog.app/Contents/MacOS/` writer입니다.

## Release smoke 종료

```sh
./script/cleanup_release_smoke_state.sh --apply
./script/verify_release_final_state.sh --version 1.9.2
```

현재 상태: 이 기록 PR에서 문서만 갱신합니다. cleanup `--apply`는 사용자가
설치본을 쓰는 동안 실행하지 않았습니다.

## 릴리즈 증거 기록

| 증거 | 현재 상태 |
| --- | --- |
| `git diff --check` | 2026-09-19, 통과 |
| `npx --yes markdownlint-cli2@0.22.1` | 2026-09-19, 43 file / 0 error |
| `./script/verify_v192_menu_bar_glance_contract.sh --self-test` | 2026-09-19, 통과. `--skip-tests` |
| `./script/verify_v192_release_readiness.sh --self-test` | 2026-09-19, 통과 |
| `./script/verify_install_dry_run.sh` | 2026-09-19, 통과. history `Would preserve` |
| 전체 `swift test` | 2026-09-19, `xcrun`은 Xcode license 미동의. toolchain `xctest`로 CodexUsageCoreTests 197 passed / 1 skipped, helper 29 passed. MacDogTests 363 executed / 3 skipped / 5 failed. 실패는 주간 history window picker의 `NSPopUpButton`이며 이번 변경 대상이 아님 |
| Xcode Debug no-sign build | 2026-09-19, Xcode license 미동의로 미실행 |
| `MACDOG_APP_VERSION=1.9.2 ./script/check.sh --no-run` | 2026-09-19, `xcrun` license 미동의로 시작 실패 |
| README screenshot freshness | 2026-09-19, 설정 탭을 `현재 잔여 사용량` / `% 표기`로 renderer 갱신 |
| PR, CI, review | PR [#43](https://github.com/dhseo90/MacDog/pull/43), `static-gates`/`guardrails` SUCCESS, admin bypass merge `3756b1a` |
| signed annotated `v1.9.2` tag / GitHub `Verified` | tag object `ce099bbbe7267058bd1fc7e75b160c976d24f9c7`, 코드 head `3756b1a`. 이 기록 merge 후 마지막 커밋에 맞춤 |
| Published `v1.9.2` DMG | 있음. SHA-256 `6d65189a71d2dd0266f18bb8a44f101f760d461ac8682e4c84ad6219c5569df7`. release ID `392011164`. GitHub Latest `v1.9.2` |
| 설치본 executable checksum | 통과. `6225175233edcfd82ec3d93f9865b46b7ab47b5a3fdf5db623f1a70212ecb16e` |
| Codex/Grok LaunchAgent | 통과. 둘 다 `/Applications/MacDog.app/Contents/MacOS/` writer |
| Finder drag-and-drop와 그래프 보존 | 사용자 설치. 주간 sample 2125, reset-window 12, 5시간 304, Grok 4096 |
| Mac/Sleep/Battery 탭 직접 조작 | v1.9.1부터 미수행. 이번 완료 조건 아님 |
| cleanup / final-state | 미수행. 설치본 사용 중 |

검증하지 않은 항목은 완료로 바꾸지 않습니다.

## 릴리즈 잔여 이슈

코드 기능 잔여는 없습니다. publish, Finder 재설치, 그래프 보존은 닫혔습니다.
이 기록 PR merge 후 `v1.9.2` tag를 마지막 커밋에 맞춥니다. Mac/Sleep/Battery 탭
직접 조작은 미수행으로 남습니다.
