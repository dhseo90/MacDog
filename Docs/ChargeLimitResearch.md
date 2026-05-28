# Charge Limit Research

상태: native 설정 연동 1차 구현 / 직접 제어는 별도 기능으로 검토
작성일: 2026-05-27
갱신일: 2026-05-28

## 결론

MacDog는 1차 제품에서 Charge Limit을 직접 제어하지 않는다. 현재 안전한 범위는 지원 가능 여부와 목표 한도를 표시하고 macOS 배터리 설정으로 이동시키는 것이다.

## 확인한 근거

- Apple Support 기준 Charge Limit은 macOS Tahoe 26.4 이상과 Apple silicon Mac이 필요하다.
- Apple Support 기준 사용자는 Battery settings에서 Charge Limit 값을 80%부터 100% 사이로 선택한다.
- Apple Support 기준 Charge Limit을 사용하더라도 macOS가 배터리 상태 추정 정확도를 위해 가끔 100%까지 충전할 수 있다.
- Apple Developer의 `IOPowerSources` 계열 문서는 전원 소스 상태 접근을 제공하지만, Charge Limit 값을 쓰는 공개 API는 확인하지 못했다.
- `shortcuts` CLI는 현재 개발 환경에 존재하지만 `shortcuts list` 실행 시 helper application 통신 실패가 발생했다. 따라서 Shortcuts 기반 Charge Limit 자동화는 이 환경에서 검증하지 않았다.
- 2026-05-28 현재 개발 Mac은 macOS 26.5, arm64, AC 연결, 배터리 95%, `not charging` 상태로 확인됐다.
- 2026-05-28 재확인 시에도 `shortcuts list`는 `Couldn’t communicate with a helper application.`으로 실패했다.

## 제품 방침

1. macOS 26.4+와 Apple silicon이면 "지원 가능"으로 표시한다.
2. 앱 안에서는 80~100% 목표 한도만 선택하고 저장한다.
3. 직접 제어 대신 메뉴의 배터리 설정 열기 동작으로 macOS 배터리 설정 화면에 진입한다.
4. 현재 배터리가 AC 연결 상태에서 충전 중이 아니면 "충전 안 함"으로 표시한다.
5. Shortcuts 액션은 실제 대상 OS에서 액션 이름과 입력 계약을 확인한 뒤 별도 기능으로 붙인다.
6. privileged helper는 먼저 덮개 닫힘 보호의 반복 관리자 프롬프트 제거용으로 도입한다.
7. 배터리 충전 제어는 helper 통로를 재사용할 수 있지만, native Charge Limit/Shortcuts 경로 검증을 먼저 한다.
8. SMC 방식이 필요하면 uninstall 원복, 실패 복구, macOS 업데이트 호환성, 배터리 calibration 리스크를 별도 기능 게이트로 설계한다.

## 후속 후보

- 충전 한도 목표값과 실제 시스템 설정값 차이를 표시할 수 있는 읽기 경로 조사
- macOS 26.4+ 실제 기기에서 Shortcuts Charge Limit action 존재 여부 확인
- Shortcuts action이 확인되면 MacDog에서 "설정 열기"와 "Shortcut 실행"을 분리
- Charge Limit 상태 읽기: 배터리 메뉴 상태 문자열이나 공개 API로 현재 limit 값을 읽을 수 있는지 조사
- SMC 충전 제어 스파이크: helper 안정화 이후 별도 승인, 관리자 권한, 원복 스크립트, 충돌 감지 포함

참고:

- <https://support.apple.com/ko-kr/102338>
- <https://support.apple.com/guide/mac-help/change-battery-settings-mchlfc3b7879/mac>
