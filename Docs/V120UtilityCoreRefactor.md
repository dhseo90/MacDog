# v1.2.0 유틸리티 코어 정리 결정

## 배경

v1.2.0 Codex 데이터 탐색 관문은 `codex-usage doctor`에 사용량 묶음과 필드 목록을 구조 요약으로 추가했습니다. 2026-06-03 live doctor smoke에서 확인한 현재 응답은 아래와 같습니다.

- app-server 상태: ok
- plan: pro
- 5시간 창: ok
- 주간 창: ok
- 사용량 묶음: `codex`, `codex_bengalfox`
- 두 묶음 모두 같은 필드 구조:
  - bucket fields: `credits`, `limitId`, `limitName`, `planType`, `primary`, `rateLimitReachedType`, `secondary`
  - primary fields: `resetsAt`, `usedPercent`, `windowDurationMins`
  - secondary fields: `resetsAt`, `usedPercent`, `windowDurationMins`
  - credits fields: `balance`, `hasCredits`, `unlimited`

sandbox 안에서는 app-server 응답 대기 timeout이 발생했지만, 같은 명령을 sandbox 밖에서 실행하면 정상 응답했습니다. 이 현상은 제품 회귀로 보지 않고 sandbox 실행 환경 차이로 분리합니다.

## 결정

현재 `codex_bengalfox`는 기본 사용자 UI에 새 표면으로 추가할 만큼 별도 의미가 확인되지 않았습니다. 따라서 v1.2.0에서 추가 Codex UI를 만들지 않고, bucket 구조 요약은 `doctor` 고급 진단에만 유지합니다.

이후 v1.2.0 PR 전 단계의 주 작업은 `MenuBarController`와 `UsagePopoverView`를 작은 책임 단위로 나누는 유틸리티 코어 정리 계획입니다.

## 근거

- 기본 `codex`와 추가 `codex_bengalfox`는 현재 live 응답에서 같은 field shape를 가집니다.
- 사용량 계산의 기본 계약은 `rateLimitsByLimitId.codex`입니다.
- 추가 bucket을 기본 runner 속도, popover 기본 행, cache schema에 섞으면 사용자가 공식 잔여 한도와 보조 bucket을 혼동할 수 있습니다.
- 이미 구현된 `doctor` field inventory는 숨은 구조 변화 탐지에는 충분합니다.

## 다음 구현 방향

유틸리티 코어 정리는 동작 변경이 아니라 유지보수 표면 축소입니다.

1. `UsagePopoverView.swift`의 module별 panel과 chart/helper view를 파일 단위로 분리합니다.
2. `MenuBarController.swift`의 usage cache refresh 조율과 popover placement 계산을 작은 타입으로 추출합니다.
3. `UsageMonitorState`, `PetAction`, `PetMenuModel`, Codex JSON/cache schema는 유지합니다.
4. AppKit popover 표시 방식과 SwiftUI 화면 구성은 사용자-visible 동작이 바뀌지 않게 보존합니다.

세부 구현 계획은 `Docs/superpowers/plans/2026-06-03-macdog-utility-core-refactor-plan.md`에 둡니다.

## 제외 범위

- Apple Developer Program, Developer ID, notarization, App Group provisioning, App Store Connect가 필요한 항목
- WidgetKit 실제 UI 검수
- 새 Codex bucket 기본 UI 추가
- `status --json` schema 변경
- app-owned cache schema 변경
- 새 캐릭터 세트 추가
- DMG 설치 검수, helper 설치/삭제, LaunchAgent 변경
- 장시간 watch 테스트

## PR 전 완료 기준

PR 생성 전에는 아래 상태까지만 준비합니다.

- live doctor 근거를 바탕으로 추가 Codex UI 미진행 결정을 기록합니다.
- 유틸리티 코어 refactor 구현 계획을 한국어 문서로 작성합니다.
- 문서 검증을 통과합니다.
- 변경이 있으면 커밋하고 원격 브랜치에 푸시합니다.
- PR은 생성하지 않습니다.
