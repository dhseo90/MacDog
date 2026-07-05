# v1.6.0 릴리즈 준비 감사

상태: 구현 예정 / release smoke 미수행
작성일: 2026-07-05
대상 버전: `1.6.0`

## 릴리즈 전 자동검증

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v160_codex_recovery_planner_contract.sh --self-test
swift test --filter CodexUsageResetScheduleTests
swift test --filter CodexUsageSessionPlanTests
swift test --filter UsageMonitorStateTests
swift test --filter UsageNotificationPolicyTests
swift test --filter PetMenuModelTests
swift test --filter PopoverScreenshotRendererTests
swift test
```

macOS 앱 UI 변경이 있으므로 release head 확정 전 Xcode Debug build도 통과시킵니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

## 수동 UI smoke

실제 menu bar popover를 열지 않았다면 `UI 확인 미수행`으로 보고합니다.

- Codex 탭 회복 카드가 겹치지 않는지 확인합니다.
- 다음 회복 강조가 보이는지 확인합니다.
- 1시간, 3시간, reset까지 session plan 선택이 동작하는지 확인합니다.
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
