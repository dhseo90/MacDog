# v1.6.0 릴리즈 준비 감사

상태: 재작업 구현 완료 / 자동 검증 통과 / release smoke 미수행
작성일: 2026-07-05
대상 버전: `1.6.0`

## 릴리즈 전 자동검증

2026-07-05 재작업 기준 아래 명령이 통과했습니다.

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v160_codex_recovery_planner_contract.sh --self-test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --no-parallel
```

`verify_v160_codex_recovery_planner_contract.sh`는 source guard와 focused Swift tests를 함께 실행합니다.
전체 Swift test는 351개 통과, opt-in screenshot test 2개 skip으로 완료됐습니다.

macOS 앱 UI 변경이 있으므로 아래 Xcode Debug build도 통과했습니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

빌드 중 CoreSimulator out-of-date 경고가 출력됐지만 macOS build는 `BUILD SUCCEEDED`로 종료했습니다.

## 수동 UI smoke

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
