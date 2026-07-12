# v1.6.1 릴리즈 준비 감사

상태: 릴리즈 완료, final-state 검증 통과
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

## 릴리즈 결과

- Signed annotated tag: `v1.6.1`
- Published release head: `62147e9d346094bf9d10920bd91b3186bc3e27dc`
- Published asset: `MacDog-1.6.1.dmg`, `MacDog-1.6.1.dmg.sha256`
- Published DMG SHA-256: `e145c34d98133d6f1db7fab100574ecb6c5901e75b867f2fe0e5e4baf5eba959`
- Published DMG checksum과 `hdiutil verify`: 통과
- Finder drag-and-drop 설치와 payload/설치본 executable checksum 비교: 통과
- 설치본 codesign `--deep --strict`: 통과
- Codex `현재`/`지난`/`비교` mode와 dropdown 표시 조건: 사용자 직접 확인, 이상 없음
- Usage cache LaunchAgent: `/Applications/MacDog.app/Contents/MacOS/codex-usage`, 60초 주기, 최근 종료 코드 0
- Release Candidate, Draft Release, release head CI 재실행: 통과
- Release smoke cleanup: 통과
- Background Task DB: 설치 앱과 usage cache LaunchAgent 모두 `[enabled, allowed, notified]`
- `./script/verify_release_final_state.sh --version 1.6.1`: 통과

## 로그인 항목 교차 검증

앱 외부에서 실행한 `SMAppService.mainApp.status`는 처음에 `notFound`를 반환했습니다.
앱 설정에서 `로그인 시 MacDog 실행`을 끈 뒤 다시 켜는 동작은 오류 없이 완료됐고 설정값 `loginLaunchEnabled = 1`도 보존됐습니다.
사용자 승인 아래 Background Task DB를 교차 확인한 결과 `/Applications/MacDog.app`과 usage cache LaunchAgent가 모두 `[enabled, allowed, notified]`였습니다.
이후 공식 final-state script가 통과했으므로 최초 `notFound`는 앱 외부 진단의 false negative로 분리합니다.

## 확인된 로그 상태와 후속 이슈

1. `cache.err.log`에는 과거 Codex app-server timeout과 성공한 history append 진단이 함께 누적되어 약 17MB가 됐습니다.
   최신 구간은 `history append: stored/skipped`이며 cache LaunchAgent의 최근 종료 코드는 0입니다.
2. `monitor.err.log`는 0바이트였습니다.
3. `codex-usage doctor` 단발 실행은 app-server timeout으로 실패했으므로 live source가 항상 가용하다고 보고하지 않습니다.

후속 이슈: usage cache stdout/stderr 로그 rotation과 성공 진단의 출력 채널/빈도를 정리합니다.

- 추천 모델: 5.6 Terra
- 추론 수준: 중간 (medium)
- 선정 근거: 영향도 1 + 불확실성 1 + 검증 난이도 1 + 변경 범위 1 = 4점. LaunchAgent logging과 history 진단을 여러 파일에서 조정하지만 공용 schema는 변경하지 않습니다.

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
