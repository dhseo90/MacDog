# Charge Limit Research

상태: 조사 완료 / 직접 제어 구현 보류
작성일: 2026-05-27

## 결론

MacDog는 1차 제품에서 Charge Limit을 직접 제어하지 않는다. 현재 안전한 범위는 지원 가능 여부를 표시하고 macOS 배터리 설정으로 이동시키는 것이다.

## 확인한 근거

- Apple Support 기준 Charge Limit은 macOS Tahoe 26.4 이상과 Apple silicon Mac이 필요하다.
- Apple Support 기준 사용자는 Battery settings에서 Charge Limit 값을 80%부터 100% 사이로 선택한다.
- Apple Support 기준 Charge Limit을 사용하더라도 macOS가 배터리 상태 추정 정확도를 위해 가끔 100%까지 충전할 수 있다.
- Apple Developer의 `IOPowerSources` 계열 문서는 전원 소스 상태 접근을 제공하지만, Charge Limit 값을 쓰는 공개 API는 확인하지 못했다.
- `shortcuts` CLI는 현재 개발 환경에 존재하지만 `shortcuts list` 실행 시 helper application 통신 실패가 발생했다. 따라서 Shortcuts 기반 Charge Limit 자동화는 이 환경에서 검증하지 않았다.

## 제품 방침

1. macOS 26.4+와 Apple silicon이면 "지원 가능"으로 표시한다.
2. 직접 제어 대신 배터리 설정 화면을 여는 현재 동작을 유지한다.
3. Shortcuts 액션은 실제 대상 OS에서 액션 이름과 입력 계약을 확인한 뒤 별도 기능으로 붙인다.
4. SMC 또는 privileged helper 방식은 기본 제품 기능에 넣지 않는다.
5. helper 방식이 필요하면 uninstall 원복, 실패 복구, macOS 업데이트 호환성, 배터리 calibration 리스크를 별도 milestone에서 설계한다.

## 후속 후보

- macOS 26.4+ 실제 기기에서 Shortcuts Charge Limit action 존재 여부 확인
- Shortcuts action이 확인되면 MacDog에서 "설정 열기"와 "Shortcut 실행"을 분리
- Charge Limit 상태 읽기: 배터리 메뉴 상태 문자열이나 공개 API로 현재 limit 값을 읽을 수 있는지 조사
- SMC/helper 스파이크: 별도 승인, 관리자 권한, 원복 스크립트, 충돌 감지 포함
