# v1.9.2 릴리즈 준비 감사

상태: 릴리즈 준비 / PR 전. published GitHub Release는 `v1.9.1`
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
published GitHub Release는 아직 [v1.9.1](https://github.com/dhseo90/MacDog/releases/tag/v1.9.1)입니다.

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

1. `v1.9.2` → `main` PR은 이 문서 작성 이후 별도로 진행합니다.
2. 필수 CI `static-gates`와 `guardrails`가 SUCCESS이고 unresolved conversation이
   0개여야 다음 외부 단계로 갑니다.
3. merge 후 최신 `origin/main` SHA를 v1.9.2 최종 release head로 기록합니다.

현재 상태: PR 미수행.

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

현재 상태: tag/DMG/draft/publish 미수행.

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

현재 상태: published DMG 설치 미수행. 개발본 메뉴바 숫자와 설정 토글은 사용자가
확인했습니다. 개발본 `/Applications/MacDog.app` 1.9.2는 설치 검수가 아닙니다.

## Release smoke 종료

```sh
./script/cleanup_release_smoke_state.sh --apply
./script/verify_release_final_state.sh --version 1.9.2
```

현재 상태: 미수행.

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
| PR, CI, review | 미수행 |
| signed annotated `v1.9.2` tag / GitHub `Verified` | 미수행 |
| Published `v1.9.2` DMG | 없음. published는 `v1.9.1` |
| Finder drag-and-drop와 그래프 보존 | 미수행 |
| Mac/Sleep/Battery 탭 직접 조작 | v1.9.1부터 미수행. 이번 완료 조건 아님 |
| cleanup / final-state | 미수행 |

검증하지 않은 항목은 완료로 바꾸지 않습니다.

## 릴리즈 잔여 이슈

코드 기능 잔여는 없습니다. PR부터 publish, Finder 재설치와 그래프 보존 확인이
남습니다. 별도 uninstall 테스트는 없습니다.
