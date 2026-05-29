# 덮개 닫힘 보호 조사

상태: helper 기반 1차 구현 완료 / 장시간 실사용 검증 통과
작성일: 2026-05-27
갱신일: 2026-05-29

## 결론

MacDog의 IOKit power assertion은 일반 idle sleep 방지에는 적합하지만, MacBook 덮개를 닫았을 때 발생하는 lid-close sleep을 공개 IOKit assertion만으로 막을 수는 없습니다.

현재 1차 구현은 다음처럼 동작합니다.

- 일반 idle sleep 방지: `PreventUserIdleDisplaySleep`, `PreventUserIdleSystemSleep`, `NetworkClientActive` assertion을 함께 사용합니다.
- 덮개 닫힘 보호: 사용자가 관리자 권한을 승인하면 `pmset disablesleep 1`을 실행합니다.
- 되돌림: MacDog가 `SleepDisabled`를 켠 경우에만 원래 값을 저장하고, 끄기/시간 만료/조건 해제 시 `pmset disablesleep 0`으로 되돌립니다.
- 다른 앱이나 사용자가 이미 `SleepDisabled`를 켠 상태라면 MacDog는 그 값을 소유하지 않고 끄지 않습니다.

## 확인한 근거

- Apple Developer Documentation의 `kIOPMAssertionTypePreventUserIdleSystemSleep` 설명은 idle activity로 인한 system sleep을 막는 범위이며, lid close, Apple menu, low battery 같은 다른 sleep reason은 여전히 sleep할 수 있다고 명시합니다.
- Apple Support의 closed-display 관련 문서는 외부 키보드/마우스 또는 트랙패드, 전원 공급, 외부 디스플레이 연결 조건을 요구합니다.
- 로컬 `man caffeinate` 기준 `caffeinate -i`는 idle sleep assertion, `-s`는 AC power에서 system sleep 방지 assertion입니다.
- 로컬 `man pmset` 기준 `pmset -g assertions`로 power assertion을 확인할 수 있고, `pmset sleep 0`은 idle sleep timer를 끄는 설정입니다.
- 현재 개발 Mac의 `pmset -g cap` 출력에는 `disablesleep` capability가 표시되지 않았습니다.
- 현재 개발 Mac의 `pmset -g live` 출력에는 `SleepDisabled` 값이 표시됩니다.
- 2026-05-28 Chrome Remote Desktop 상태에서 `SleepDisabled=1`로 덮개를 닫았을 때 약 10분 동안 원격 화면이 잠금/슬립 없이 유지됨을 확인했습니다.
- 2026-05-28 대조군으로 `SleepDisabled=0`을 설정한 뒤 덮개를 닫자 즉시 잠금이 걸렸고, 잠시 뒤 검정 화면으로 바뀌었으며, 클릭 시 비밀번호 화면이 표시됨을 확인했습니다.
- 2026-05-28 최신 설치본에서 `잠들지 않기` UI의 `시간 제어`와 `끔`을 실제 클릭해 `SleepDisabled`가 각각 `1`과 `0`으로 바뀌는 것을 확인했습니다. 최신 설치본 UI 왕복 중 관리자 비밀번호 프롬프트는 발생하지 않았습니다.
- 2026-05-28 이전 설치본이 실행 중이면 helper 연동 이전 경로가 남아 비밀번호 프롬프트가 발생할 수 있음을 확인했습니다. 개발 설치본 UI 검수 전에는 `./script/verify_install_state.sh --expect-current-dist`로 설치본과 현재 payload 일치를 확인해야 합니다. GitHub Release DMG 검수는 깨끗한 설치 상태에서 새로 내려받은 DMG로 진행합니다.
- 2026-05-28 23:50 KST에 전원 연결 기준 슬립 방지, `SleepDisabled=1`, Charge Limit `90%`, 배터리 `95%`, AC 연결, `not charging` 상태로 장시간 에이징을 시작했습니다.
- 2026-05-29 사용자 실사용 확인에서 덮개 닫힘 상태가 슬립/락으로 떨어지지 않았고, 배터리가 `95%`에서 `90%`로 내려갔습니다.

## 제품 방침

MacDog는 closed-display mode를 다음처럼 다룹니다.

1. 일반 idle sleep 방지는 앱 내부 IOKit assertion으로 유지합니다.
2. 덮개 닫힘 보호는 사용자가 명시적으로 관리자 권한 프롬프트를 승인한 경우에만 `pmset disablesleep`으로 적용합니다.
3. 배터리 영향을 줄이기 위해 시간 제어 만료, 끄기, 상태 기준 해제 시 MacDog가 켠 전역 설정만 되돌립니다.
4. SMC/low-level 제어는 사용하지 않습니다.
5. privileged helper가 설치되어 있으면 최초 설치 승인 이후 `pmset disablesleep` 변경은 helper XPC 경로로 처리합니다.

## 후속 후보

- closed-display 장시간 회귀 검증: macOS 업데이트, helper 재설치, 공개 배포 설치본 변경 뒤 실제 덮개 닫힘 유지 여부 재확인
- closed-display readiness 표시: 전원 연결 여부, 외부 디스플레이 연결 여부, 외부 입력 장치 감지 가능성 조사
- display sleep 허용/방지 옵션: `잠들지 않기` 탭의 세션 옵션으로 분리했고, 끄면 system sleep assertion만 유지합니다.
- 관리자 권한 helper polish: 앱 내부 설치 UX, 업데이트/삭제 flow, 실패 시 degraded 안내 강화
