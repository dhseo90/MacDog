# Closed-Display Mode Research

상태: 1차 구현 완료 / helper 도입 예정
작성일: 2026-05-27
갱신일: 2026-05-28

## 결론

MacDog의 IOKit power assertion은 일반 idle sleep 방지에는 적합하지만, MacBook 덮개를 닫았을 때 발생하는 lid-close sleep을 공개 IOKit assertion만으로 막을 수는 없다.

현재 1차 구현은 다음처럼 동작한다.

- 일반 idle sleep 방지: `PreventUserIdleDisplaySleep`, `PreventUserIdleSystemSleep`, `NetworkClientActive` assertion을 함께 사용한다.
- 덮개 닫힘 보호: 사용자가 관리자 권한을 승인하면 `pmset disablesleep 1`을 실행한다.
- 원복: MacDog가 `SleepDisabled`를 켠 경우에만 원래 값을 저장하고, 끄기/시간 만료/조건 해제 시 `pmset disablesleep 0`으로 되돌린다.
- 다른 앱이나 사용자가 이미 `SleepDisabled`를 켠 상태라면 MacDog는 그 값을 소유하지 않고 끄지 않는다.

## 확인한 근거

- Apple Developer Documentation의 `kIOPMAssertionTypePreventUserIdleSystemSleep` 설명은 idle activity로 인한 system sleep을 막는 범위이며, lid close, Apple menu, low battery 같은 다른 sleep reason은 여전히 sleep할 수 있다고 명시한다.
- Apple Support의 closed-display 관련 문서는 외부 키보드/마우스 또는 트랙패드, 전원 공급, 외부 디스플레이 연결 조건을 요구한다.
- 로컬 `man caffeinate` 기준 `caffeinate -i`는 idle sleep assertion, `-s`는 AC power에서 system sleep 방지 assertion이다.
- 로컬 `man pmset` 기준 `pmset -g assertions`로 power assertion을 확인할 수 있고, `pmset sleep 0`은 idle sleep timer를 끄는 설정이다.
- 현재 개발 Mac의 `pmset -g cap` 출력에는 `disablesleep` capability가 표시되지 않았다.
- 현재 개발 Mac의 `pmset -g live` 출력에는 `SleepDisabled` 값이 표시된다.

## 제품 방침

MacDog는 closed-display mode를 다음처럼 다룬다.

1. 일반 idle sleep 방지는 앱 내부 IOKit assertion으로 유지한다.
2. 덮개 닫힘 보호는 사용자가 명시적으로 관리자 권한 프롬프트를 승인한 경우에만 `pmset disablesleep`으로 적용한다.
3. 배터리 영향을 줄이기 위해 시간 제어 만료, 끄기, 상태 기준 해제 시 MacDog가 켠 전역 설정만 원복한다.
4. SMC/low-level 제어는 사용하지 않는다.
5. 다음 본작업은 privileged helper를 도입해 최초 승인 이후 `pmset disablesleep` 변경에서 관리자 프롬프트를 반복하지 않는 것이다.

## 후속 후보

- closed-display 장시간 실기 검증: 실제 덮개 닫힘 유지, 잠금/깨움, 배터리 소모 확인
- closed-display readiness 표시: 전원 연결 여부, 외부 디스플레이 연결 여부, 외부 입력 장치 감지 가능성 조사
- display sleep 허용/방지 옵션: `kIOPMAssertionTypePreventUserIdleDisplaySleep` 별도 적용 여부 검토
- 관리자 권한 helper 도입: helper 설치/업데이트/삭제, 앱-host 검증, allowlist IPC, 실패 시 degraded 동작 구현
