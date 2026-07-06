# v1.6.0 릴리즈 준비 감사

상태: publish 완료 / Finder 설치 smoke 완료 / final-state 검증 통과
작성일: 2026-07-05
최종 갱신: 2026-07-06
대상 버전: `1.6.0`

## 릴리즈 결과

- Release tag: `v1.6.0`
- Release head: `538c1e3501ec4c03c5331d45604030100f302d14`
- Tag verification: GitHub `Verified`, reason `valid`
- GitHub Release: <https://github.com/dhseo90/MacDog/releases/tag/v1.6.0>
- Release 상태: `isDraft=false`, `isPrerelease=false`
- Published asset: `MacDog-1.6.0.dmg`, `MacDog-1.6.0.dmg.sha256`
- Published DMG SHA-256: `9b14a126866cbef06590cf22e9479ebab5d733b435d4ea7c42251d3ace86a411`
- Published asset digest: `sha256:9b14a126866cbef06590cf22e9479ebab5d733b435d4ea7c42251d3ace86a411`
- `.dmg.sha256` asset digest: `sha256:2e7f00e3ae06e51e5ab9759227c35b4e3d17329bdea983e9ffad4855c925d160`
- Release workflow: `Draft Release` run `28792583599`, conclusion `success`

## Release smoke 결과

- Published DMG를 `/private/tmp/macdog-v160-published.TULVwf`로 재다운로드했습니다.
- `shasum -a 256 -c MacDog-1.6.0.dmg.sha256` 통과.
- `hdiutil verify /private/tmp/macdog-v160-published.TULVwf/MacDog-1.6.0.dmg` 통과.
- Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop했습니다.
- 기존 `/Applications/MacDog.app` 대치 확인창에서 `대치`를 선택했습니다.
- `/Applications/MacDog.app` 버전은 `1.6.0`입니다.
- `/Applications/MacDog.app`의 app/CLI 바이너리 checksum이 mounted DMG 내부 app/CLI와 일치했습니다.
- `/Applications/MacDog.app`을 실행했고, 프로세스 경로가 `/Applications/MacDog.app/Contents/MacOS/MacDog --open-popover-on-launch`임을 확인했습니다.
- 첫 실행 설치 파일 정리 안내가 표시됐고 `나중에`로 닫았습니다.
- Codex 탭에서 5시간/주간 사용량이 한 번씩 표시되고, 사용자 초기화권 `3장`과 `7/18 09:34`, `7/27 08:47`, `8/1 04:07` 유효기간이 표시됨을 확인했습니다.
- 활성 자원, 잠들지 않기, 배터리, 설정 탭 전환을 확인했습니다.
- `./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage`가 `usage-fetch:success`로 통과했습니다.
- 설치본 CLI `codex-usage status --write-cache --timeout 20` 출력에서 reset credit 3장과 장별 만료일을 확인했습니다.
- `./script/cleanup_release_smoke_state.sh --apply`로 `/Volumes/MacDog 1.6.0`을 eject하고 `dist/MacDog.app`을 격리했습니다.
- `./script/verify_release_final_state.sh --version 1.6.0`이 `Release final state ok`로 통과했습니다.

## 릴리즈 전 자동검증

2026-07-06 최종 release head 기준 아래 명령이 통과했습니다.

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v160_codex_recovery_planner_contract.sh --self-test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --no-parallel
MACDOG_RELEASE_VERSION=1.6.0 ./script/check.sh --no-run
```

`verify_v160_codex_recovery_planner_contract.sh`는 source guard와 focused Swift tests를 함께 실행합니다.
전체 Swift test와 release packaging, public repo guardrails, release workflow, distribution gate는 `script/check.sh --no-run` 경로에서 통과했습니다.

macOS 앱 UI 변경이 있으므로 아래 Xcode Debug build도 통과했습니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

빌드 중 CoreSimulator out-of-date 경고가 출력됐지만 macOS build는 `BUILD SUCCEEDED`로 종료했습니다.

## 수동 UI smoke 계약

실제 menu bar popover를 열지 않았다면 `UI 확인 미수행`으로 보고합니다.

- Codex 탭에 회복 일정 카드가 없는지 확인합니다.
- 1시간, 3시간, reset까지 session plan 선택이 없는지 확인합니다.
- 5시간/주간 사용량이 각각 한 번만 표시되는지 확인합니다.
- 사용자 초기화권 장수와 장별 유효기간이 보이는지 확인합니다.
- 현재/지난/비교 그래프가 아래로 밀려도 읽을 수 있는지 확인합니다.
- 메뉴바 tooltip 또는 펫 메뉴에 다음 초기화 glance가 보이는지 확인합니다.

## 미수행 보고 형식

```text
미실행:
- GUI 실행: 실행하지 않음
- live fetch smoke: 실행하지 않음
- published DMG 재다운로드 검증: 실행하지 않음
- Finder drag-and-drop 설치 smoke: 실행하지 않음
- WidgetKit 실제 UI: 실행하지 않음
- 장시간 테스트: 실행하지 않음
```

v1.6.0 릴리즈 종료 기준에서 장시간 `codex-usage status --watch 60` 테스트와 WidgetKit 실제 UI 검수는 수행하지 않았습니다.
