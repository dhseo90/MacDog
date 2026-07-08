# v1.6.1 릴리즈 준비 감사

상태: 릴리즈 준비 중
작성일: 2026-07-09
대상 버전: `1.6.1`

## 릴리즈 전 확인 대상

- Release tag: `v1.6.1`
- Release scope: Codex 탭 history mode control compact layout과 지난 window dropdown 표시 조건 정리
- 변경 문서: [V161HistoryControlPolish.md](V161HistoryControlPolish.md)

## Release smoke 계약

실제 menu bar popover를 열지 않았다면 `UI 확인 미수행`으로 보고합니다.

1. Published DMG를 다시 내려받아 checksum과 `hdiutil verify`를 확인합니다.
2. Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop합니다.
3. `/Applications/MacDog.app` 기준으로 앱을 실행합니다.
4. Codex 탭에서 `현재`, `지난`, `비교` mode를 전환합니다.
5. `현재` mode에서는 지난 window dropdown이 보이지 않는지 확인합니다.
6. `지난`/`비교` mode에서는 지난 window가 있을 때 dropdown이 보이는지 확인합니다.
7. `./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage`를 실행합니다.
8. `./script/cleanup_release_smoke_state.sh --apply` 뒤 `./script/verify_release_final_state.sh --version 1.6.1`을 실행합니다.

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
