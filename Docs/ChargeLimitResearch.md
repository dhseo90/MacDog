# Charge Limit Research

상태: native Charge Limit 직접 제어 1차 구현 / 90% 실사용 검증 통과 / Shortcuts read-only probe 추가 / SMC 직접 제어는 별도 기능으로 검토
작성일: 2026-05-27
갱신일: 2026-05-29

## 결론

MacDog는 1차 제품에서 macOS native Charge Limit 값을 읽고 80~100% 범위에서 직접 적용합니다. SMC/low-level 직접 제어는 사용하지 않습니다.

## 확인한 근거

- Apple Support 기준 Charge Limit은 macOS Tahoe 26.4 이상과 Apple silicon Mac이 필요합니다.
- Apple Support 기준 사용자는 Battery settings에서 Charge Limit 값을 80%부터 100% 사이로 선택합니다.
- Apple Support 기준 Charge Limit을 사용하더라도 macOS가 배터리 상태 추정 정확도를 위해 가끔 100%까지 충전할 수 있습니다.
- Apple Developer의 `IOPowerSources` 계열 문서는 전원 소스 상태 접근을 제공하지만, Charge Limit 값을 쓰는 공개 API는 확인하지 못했습니다.
- `shortcuts` CLI는 현재 개발 환경에 존재하지만 `shortcuts list` 실행 시 helper application 통신 실패가 발생했습니다. 따라서 Shortcuts 기반 Charge Limit 자동화는 이 환경에서 검증하지 않았습니다.
- 2026-05-28 현재 개발 Mac은 macOS 26.5, arm64, AC 연결, 배터리 95%, `not charging` 상태로 확인되었습니다.
- 2026-05-28 재확인 시에도 `shortcuts list`는 `Couldn’t communicate with a helper application.`으로 실패했습니다.
- 2026-05-28 `PowerUI`의 native smart charge client를 앱 번들 진단 모드로 호출해 사용 가능 한도 `80,85,90,95,100`과 현재 시스템 한도 `95`를 읽었습니다.
- 2026-05-28 같은 값 `95`로 set/restore 검증을 수행해 native Charge Limit 쓰기 경로가 동작함을 확인했습니다.
- 2026-05-28 23:50 KST에 UI에서 목표 한도 `90%`를 적용했고, 진단 read에서 `charge-limit current=90`을 확인했습니다.
- 2026-05-29 사용자 실사용 확인에서 AC 연결 상태의 배터리가 `95%`에서 `90%`로 내려가 native Charge Limit 적용 결과를 확인했습니다.
- 2026-05-29 `script/verify_shortcuts_charge_limit.sh`를 추가해 Shortcuts CLI 상태를 read-only로 probe합니다. 현재 개발 환경에서는 `shortcuts list`가 `Couldn’t communicate with a helper application.`으로 실패할 수 있으므로, 표준 체크에서는 local fixture 기반 `--self-test`로 후보 이름 파서를 고정하고, `--allow-unavailable`로 현재 available/unavailable 상태와 후보 단축어 이름만 기록합니다.

## 제품 방침

1. macOS 26.4+와 Apple silicon이고 native smart charge client가 지원을 보고하면 "macOS 적용됨"으로 표시합니다.
2. 앱 안에서는 80~100% 목표 한도를 선택하고 즉시 macOS native Charge Limit에 적용합니다.
3. 메뉴의 배터리 설정 열기 동작은 fallback/확인용으로 유지합니다.
4. 현재 배터리가 AC 연결 상태에서 충전 중이 아니면 "충전 안 함"으로 표시합니다.
5. Shortcuts 액션은 실제 대상 OS에서 액션 이름과 입력 계약을 확인한 뒤 별도 기능으로 붙입니다. 현재 표준 체크는 후보 이름 파서를 local fixture로 검증하고, Shortcuts CLI/helper 사용 가능 여부와 Charge Limit 후보 단축어 이름만 read-only로 확인합니다.
6. privileged helper는 먼저 덮개 닫힘 보호의 반복 관리자 프롬프트 제거용으로 도입합니다.
7. 배터리 충전 제어는 native Charge Limit 경로를 우선 사용합니다. helper 통로는 SMC 실험 기능이 별도 승인될 때만 검토합니다.
8. SMC 방식이 필요하면 uninstall 되돌림, 실패 복구, macOS 업데이트 호환성, 배터리 calibration 리스크를 별도 기능 게이트로 설계합니다.

## 후속 후보

- native Charge Limit 회귀 검증: macOS 업데이트, 공개 배포 설치본 변경, helper/앱 재설치 이후 `charge-limit current`와 Battery settings 표시가 일치하는지 확인
- Shortcuts CLI/helper가 사용 가능한 환경에서 Charge Limit 후보 단축어 이름을 확인하고, 별도 승인 후 액션 입력 계약 확인
- native smart charge client 실패 시 배터리 탭에서 시스템 배터리 설정 fallback을 안내합니다.
- macOS 업데이트로 private PowerUI contract가 바뀌는 경우를 감지하는 진단 강화
- SMC 충전 제어 스파이크: helper 안정화 이후 별도 승인, 관리자 권한, 되돌림 스크립트, 충돌 감지 포함

참고:

- <https://support.apple.com/ko-kr/102338>
- <https://support.apple.com/guide/mac-help/change-battery-settings-mchlfc3b7879/mac>
