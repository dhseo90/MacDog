# v1.6.0 Codex Recovery Planner

상태: P0-P2 구현 완료 / 자동 검증 완료 / 실제 UI smoke 미수행
작성일: 2026-07-05
대상 버전: `1.6.0`

## 목표

v1.6.0은 Codex 탭을 "언제 회복되는지 보고 다음 작업을 정하는 화면"으로 확장합니다.
첫 탭 이름은 계속 `Codex`로 유지하고, 새 Dashboard 탭은 만들지 않습니다.

## 포함 범위

- Codex reset schedule 모델
- Codex 탭 회복 카드
- 작업 세션 계획
- 회복 기준 알림 문구
- 메뉴바 tooltip과 펫 메뉴 glance
- CLI reset schedule 텍스트 요약
- v1.6 focused tests와 verifier

## 제외 범위

- `codex-usage status --json` schema breaking change
- 기존 cache/history schema breaking change
- raw app-server response 저장
- auth token, refresh token, cookie, session material, auth header 읽기, 출력, 저장
- 공식 사용량과 로컬 SQLite 추정치 혼합 표시
- 가격 tier 추정
- 새 Dashboard 탭
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning이 필요한 기능
- WidgetKit 실제 UI 완료 조건

## 완료 기준

- Codex 탭에 5시간/주간 회복 카드가 표시됩니다.
- 각 카드에 초기화 날짜, 남은 시간, 사용률, 잔여율, 신뢰 상태가 표시됩니다.
- 가장 빠른 reset이 다음 회복으로 강조됩니다.
- session plan은 safe, watch, risky, unavailable 상태를 분리합니다.
- 추가 bucket은 기본 UI에 섞이지 않고 advanced/debug 경계로 남습니다.
- `status --json`과 기존 cache/history schema가 breaking change 없이 유지됩니다.
- 실제 UI 확인을 하지 않았다면 `UI 확인 미수행`으로 보고합니다.
