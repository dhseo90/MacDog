# Closed-Display Mode Research

상태: 조사 완료 / 구현 보류
작성일: 2026-05-27

## 결론

MacDog의 현재 IOKit power assertion은 일반 idle sleep 방지에는 적합하지만, MacBook 덮개를 닫았을 때 발생하는 lid-close sleep을 안전하게 우회하는 공개 API로 보기는 어렵다.

따라서 1차 제품에는 다음 범위까지만 넣는다.

- 일반 잠자기 방지: 현재 구현처럼 `kIOPMAssertionTypePreventUserIdleSystemSleep` 사용
- closed-display 안내: 외부 디스플레이, 전원, 외부 키보드/마우스/트랙패드 조건을 문서화
- 관리자 권한이 필요한 lid-close 우회: 자동 실행하지 않고 연구 스파이크로 분리

## 확인한 근거

- Apple Developer Documentation의 `kIOPMAssertionTypePreventUserIdleSystemSleep` 설명은 idle activity로 인한 system sleep을 막는 범위이며, lid close, Apple menu, low battery 같은 다른 sleep reason은 여전히 sleep할 수 있다고 명시한다.
- Apple Support의 closed-display 관련 문서는 외부 키보드/마우스 또는 트랙패드, 전원 공급, 외부 디스플레이 연결 조건을 요구한다.
- 로컬 `man caffeinate` 기준 `caffeinate -i`는 idle sleep assertion, `-s`는 AC power에서 system sleep 방지 assertion이다.
- 로컬 `man pmset` 기준 `pmset -g assertions`로 power assertion을 확인할 수 있고, `pmset sleep 0`은 idle sleep timer를 끄는 설정이다.
- 현재 개발 Mac의 `pmset -g cap` 출력에는 `disablesleep` capability가 표시되지 않았다.

## 제품 방침

MacDog는 closed-display mode를 다음처럼 다룬다.

1. 일반 idle sleep 방지는 앱 내부 IOKit assertion으로 유지한다.
2. 덮개 닫힘 방지는 "지원 조건 안내 + 위험 고지"까지만 1차 제공한다.
3. `sudo pmset`, privileged helper, SMC/low-level 제어는 자동 실행하지 않는다.
4. 관리자 권한 helper가 필요하면 설치, 해제, 실패 복구, 다른 sleep 앱과의 충돌을 별도 milestone에서 먼저 설계한다.

## 후속 후보

- closed-display readiness 표시: 전원 연결 여부, 외부 디스플레이 연결 여부, 외부 입력 장치 감지 가능성 조사
- display sleep 허용/방지 옵션: `kIOPMAssertionTypePreventUserIdleDisplaySleep` 별도 적용 여부 검토
- 관리자 권한 helper 스파이크: 실행 전 사용자 승인, uninstall 복구, `pmset` 원복 확인 포함
