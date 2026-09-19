# v1.9.2 메뉴바 glance polish와 uninstall history 정리

상태: Step 1~5 코드·자동 검증 완료 / Step 6 실제 메뉴바 GUI·uninstall 실실행 미수행
작성일: 2026-09-18
대상 버전: `1.9.2`
기준 브랜치: `v1.9.2`
개발 검증 버전: `MACDOG_APP_VERSION=1.9.2`

버전 정책: minor 구간은 `0~9`까지만 사용한다. `v1.9.1` 다음 기능 버전은 `v1.9.2`다.

## 목표

`v1.9.2`는 published `v1.9.1`의 메뉴바 주간 잔여율 glance를 강아지 아이콘 높이에 맞게
줄이고, 클린 삭제가 주간 history만 지우고 5시간/완료 창 history를 남기는 불일치를
없애는 patch다. provider 선택, cache schema, 러너 속도 계약은 바꾸지 않는다.

## 현재 결함

1. 아이콘 위 오버레이는 캐릭터를 가리거나 안 보인다. 강아지를 오른쪽 끝에 두고
   `%`는 그 바로 왼쪽에 붙인다. 설정 `현재 잔여 사용량`과 `% 표기`로 끈다.
2. uninstall이 그래프 history를 지우면 재설치 후 이번 주 곡선이 단순해지고 과거
   창도 사라진다. 재설치해도 그래프가 유지되어야 한다.

## 범위

1. 강아지를 메뉴바 extra의 오른쪽 끝에 두고, 주간 잔여율 `%`는 그 바로 왼쪽에
   9pt tabular 숫자와 더 작은 `%`로 붙인다. 아이콘 위 오버레이는 쓰지 않는다.
2. 숫자와 강아지 사이는 2pt, 바깥은 1pt다. `100%` 고정 폭 패딩은 두지 않는다.
3. 설정 `현재 잔여 사용량` 오른쪽에 종속 옵션 `% 표기`를 둔다.
   잔여 사용량을 끄거나 주간이 없으면 강아지만 남긴다.
4. `uninstall.sh`는 앱/CLI/LaunchAgent/snapshot cache만 지우고
   `usage-weekly-history.json`, `usage-five-hour-history.json`,
   `usage-reset-window-history.json`과 Claude/Grok 그래프 history는 보존한다.

표시 계약은 v1.9.1과 같다. 메인 provider 주간 잔여율만 정수 `%`로 보이고, 주간이
없거나 stale이면 숨기며, 설정 `현재 잔여 사용량`과 `% 표기`로 끈다.

## 불변 계약

- 메인 provider 주간 잔여율만 메뉴바에 둔다. 보조 provider `%`를 붙이지 않는다.
- 없는 주간 값을 합성하지 않는다. used%로 바꾸지 않는다.
- Codex CLI/JSON/cache schema와 Grok weekly-only/auth sibling을 변경하지 않는다.
- 5시간/reset-window/주간 history **파일 내용·schema**는 바꾸지 않는다.
  uninstall도 이 파일들을 지우지 않는다.
- cache 로그 rotation과 `~/Library/Logs/MacDog` 삭제는 이번 범위가 아니다.
- UserDefaults와 privileged helper 기본 보존은 유지한다.
- 실제 GUI 실행, 실제 uninstall, 설치, LaunchAgent 변경, push는 각 동작의 명시
  승인 뒤에만 수행한다. 이 문서의 범위 고정 커밋에 대한 push 승인은 구현·설치
  승인으로 확대하지 않는다.

## 구현 순서

앞 단계가 실패하면 뒤 단계를 시작하지 않는다.

| Step | 제목 | 우선순위 | 할 일 | 완료 조건 |
| ---: | --- | --- | --- | --- |
| 1 | 범위 고정 | P0 | ROADMAP과 이 문서에 4개 이슈, 제외 경계, 검증을 기록한다. | 완료. 합산·used%·로그 삭제는 범위 밖이다. |
| 2 | 라벨 presentation | P0 | 강아지 오른쪽, `%` 바로 왼쪽, 9pt 숫자. | 완료. placement focused test. |
| 3 | status item 적용 | P0 | glance view가 숫자를 강아지 왼쪽에 붙이고 설정으로 숨긴다. | 완료. |
| 4 | uninstall history | P0 | dry-run과 `rm`이 그래프 history를 지우지 않는다. | 완료. `verify_install_dry_run.sh` 통과. 실제 삭제는 미수행. |
| 5 | 계약 verifier와 문서 | P1 | v1.9.2 verifier를 추가하고 Scripts/onboarding의 현재 uninstall 잔여 문구를 구현 결과에 맞춘다. | 완료. `verify_v192_menu_bar_glance_contract.sh --self-test --skip-tests` 통과. |
| 6 | GUI와 삭제 검수 | P2 | 실제 메뉴바 숫자 크기·간격·폭 고정과, 승인된 경우 uninstall dry-run/실삭제를 확인한다. | 미수행. |

## 테스트와 검증

최소 자동 검증:

```bash
git diff --check
npx --yes markdownlint-cli2@0.22.1
swift test --filter MenuBarWeeklyRemainingLabelTests
swift test --filter PopoverScreenshotRendererTests
./script/verify_install_dry_run.sh
swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build \
  -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
./script/verify_v192_menu_bar_glance_contract.sh --self-test
```

TDD에서 먼저 고정할 mutation:

- 기본 `button.title` 시스템 폰트를 그대로 쓰는 오류
- `9%`와 `100%`에서 라벨 폭이 달라 아이콘이 움직이는 오류
- 주간이 없거나 설정이 꺼졌는데 빈 폭이 남는 오류
- uninstall dry-run/실삭제가 주간·5시간·reset-window·Grok/Claude 그래프 history를 지우는 오류
- 메뉴바에 보조 provider `%`나 used%를 넣는 오류

screenshot renderer는 popover 회귀용이다. 메뉴바 status item 글자 크기와 간격은
focused presentation test와 실제 메뉴바 GUI로 구분한다. renderer 성공을 메뉴바
검수로 쓰지 않는다.

실제 앱 실행, 메뉴바 픽셀 확인, `uninstall.sh` 실실행, 설치, 장시간 테스트,
codesign/notarization은 사용자 명시 요청 전에는 실행하지 않는다.

## 보존 대상

- v1.9.1 활성 집합과 메인 provider, 합산·fallback 금지
- 메뉴바 `%` 설정 토글과 기본값 켜짐
- Codex/Grok cache/history schema와 writer 경계
- Claude source와 hidden debug re-enable
- cache 로그 파일과 privileged helper 기본 보존
- WidgetKit opt-in source/test 경계

## 제외 경계

- 메뉴바에 Codex/Grok 잔여율을 함께 표시
- 잔여율 대신 사용률 표시
- 러너 속도 공식 변경
- cache schema breaking change
- cache 로그 rotation 또는 `~/Library/Logs/MacDog` 삭제
- UserDefaults 기본 삭제, helper 기본 삭제
- Mac/Sleep/Battery/Settings 탭 기능 변경. 해당 탭 GUI 미수행은 검수 공백이며
  이번 이슈가 아니다
- Apple Developer Program, Developer ID, notarization, App Group provisioning
- WidgetKit 실제 UI
- 사용자 명시 요청 없는 GUI, 실제 uninstall, 설치, LaunchAgent 실등록, 릴리즈
  publish

## 완료 기준

개발 완료:

- 강아지는 extra 오른쪽, `%`는 바로 왼쪽이다.
- 설정 `현재 잔여 사용량`과 `% 표기`로 숫자와 `%`를 따로 끈다.
- `uninstall.sh --dry-run`과 실제 삭제가 주간/5시간/reset-window와 Claude/Grok
  그래프 history를 보존한다. snapshot cache는 지울 수 있다.
- `git diff --check`, focused test, 전체 `swift test`, Xcode Debug build,
  `verify_install_dry_run.sh`, v1.9.2 verifier가 통과한다.

검증 완료:

- `git diff --check`, markdownlint 0 error,
  `verify_install_dry_run.sh`,
  `verify_v192_menu_bar_glance_contract.sh --self-test --skip-tests` 통과.
- `MenuBarWeeklyRemainingLabelTests` 16 passed.
- `PopoverScreenshotRendererTests` 가운데 이번 변경 가드와 dual/graph-hidden
  renderer는 통과.
- `CodexUsageCoreTests` 197 passed / 1 skipped,
  `MacDogPrivilegedHelperSupportTests` 29 passed.
- 이 환경의 Xcode license가 동의되지 않아 `xcrun swift test`와
  `xcodebuild` Debug build는 실행하지 못했다. XCTest bundle은 Xcode toolchain
  `xctest`로 실행했다. 주간 history window picker 4개 테스트는 `xctest` 호스트에서
  `NSPopUpButton`을 찾지 못해 실패했으며, 해당 뷰는 이번 변경 대상이 아니다.
- 실제 메뉴바 크기·간격·폭 고정은 `UI 확인 미수행`.
- 실제 uninstall은 `미수행`.

릴리즈 준비 문서는 구현이 끝난 뒤에 `Docs/V192ReleaseReadiness.md`로 추가한다.
지금 만들지 않는다.

## 모델 추천

전체 milestone:

추천 모델: `grok-4.6`
추론 수준: 중간 (medium)
선정 근거: 영향도 1 + 불확실성 0 + 검증 난이도 2 + 변경 범위 1 = 4점. 표시와
삭제 대상만 다루고 cache/인증 계약은 유지한다. 메뉴바 글자는 AppKit status item
제약이 있어 자동 테스트와 실제 GUI를 구분한다.

단계별:

| 묶음 | 추천 모델 | 추론 수준 | 선정 근거 |
| --- | --- | --- | --- |
| Step 1 문서 계약 | `grok-4.5` | 낮음 (low) | 영향도 0 + 불확실성 0 + 검증 난이도 0 + 변경 범위 1 = 1점 |
| Step 2~3 메뉴바 라벨 | `grok-4.6` | 중간 (medium) | 영향도 1 + 불확실성 1 + 검증 난이도 2 + 변경 범위 1 = 5점. attributedTitle이 무시될 수 있음 |
| Step 4 uninstall history | `grok-4.5` | 낮음 (low) | 영향도 1 + 불확실성 0 + 검증 난이도 1 + 변경 범위 1 = 3점. dry-run/fixture |
| Step 5 자동 검증 | `grok-4.6` | 중간 (medium) | 영향도 1 + 불확실성 0 + 검증 난이도 1 + 변경 범위 1 = 3점 |
| Step 6 GUI·삭제 검수 | `grok-4.6` | 높음 (high) | 영향도 1 + 불확실성 0 + 검증 난이도 2 + 변경 범위 1 = 4점. 실제 메뉴바 |
