# v1.6.1 History Control Polish

작성일: 2026-07-09
상태: 로컬 검증 완료, 릴리즈 준비 중
대상 버전: `1.6.1`

## 목표

`v1.6.1`은 Codex 탭의 주간 잔여량 history control을 안정화하는 patch release입니다.
`현재`/`지난`/`비교` mode control을 compact하게 고정하고, 지난 window dropdown은 `지난` 또는 `비교` mode에서만 표시합니다.

## 범위

1. `현재`/`지난`/`비교` segmented control은 mode 전환과 무관하게 compact width를 유지합니다.
2. `현재` mode에서는 지난 window dropdown을 표시하지 않습니다.
3. `지난`과 `비교` mode에서는 지난 window가 있을 때 dropdown을 표시합니다.
4. Codex 사용량 JSON, cache, history schema, reset credit schema는 변경하지 않습니다.
5. 1번 탭의 사용량, 초기화권, history 정보 구조는 유지합니다.

## 제외 경계

- 새 history mode 추가
- history 데이터 schema 변경
- reset credit 조회 경로 변경
- WidgetKit 실제 UI 검수
- Apple Developer Program, notarization, App Group provisioning이 필요한 배포 경로

## 검증 계약

아래 자동 검증을 v1.6.1 release head에 포함합니다.

```sh
git diff --check
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --filter PopoverScreenshotRendererTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --no-parallel
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

릴리즈 smoke에서는 published DMG 설치본 기준으로 Codex 탭을 열고 `현재`/`지난`/`비교` mode를 직접 전환해, `현재`에는 dropdown이 없고 `지난`/`비교`에는 dropdown이 표시되는지 확인합니다.
