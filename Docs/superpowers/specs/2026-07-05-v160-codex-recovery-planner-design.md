# v1.6.0 Codex Recovery Planner Design

상태: 브레인스토밍 승인 / 구현 전 설계 고정
작성일: 2026-07-05
대상 버전: `1.6.0`
기준 브랜치: `v1.6.0`

## 목적

v1.6.0은 MacDog의 Codex 탭을 단순한 현재 사용량 확인 화면에서 "언제 회복되는지 보고 다음 작업을 정하는 화면"으로 확장합니다.

핵심 컨셉은 `Codex Recovery Planner`입니다. 첫 번째 탭 이름은 계속 `Codex`로 유지합니다. 별도 `Dashboard` 탭을 만들거나 첫 탭을 전체 시스템 대시보드로 바꾸지 않습니다.

사용자는 Codex 탭에서 다음을 바로 알아야 합니다.

- 현재 사용 가능한 Codex 사용량 회복 일정이 몇 장으로 보이는지
- 각 회복 카드가 어떤 window 또는 bucket을 나타내는지
- 각 카드의 초기화 날짜와 남은 시간
- 지금 속도로 계속 쓰면 reset 전에 위험한지
- 다음에 어떤 행동을 하는 것이 좋은지

## 배경

v1.4.0은 주간 history, reset window 비교, pace 예측, 그래프 export를 추가했습니다.
v1.5.0은 reset boundary 회귀, cache/history health, `codex-usage doctor`, data status UI를 정리했습니다.

v1.6.0은 이 기반 위에서 새 cache schema를 크게 늘리지 않고, 이미 있는 app-server report와 history를 더 읽기 쉬운 "회복 일정"과 "작업 계획"으로 재구성합니다.

## 결정

추천 접근은 `Codex Recovery Planner`입니다.

검토한 대안은 다음과 같습니다.

| 접근 | 장점 | 단점 | 결정 |
| --- | --- | --- | --- |
| Codex Recovery Planner | Codex 탭 정체성을 유지하면서 reset 일정, pace, 작업 판단을 강화 | Mac/Sleep/Battery를 깊게 묶는 기능은 일부 후순위가 됨 | 채택 |
| Command Center Lite | Codex, Mac, Sleep, Battery 상태를 한눈에 모을 수 있음 | 첫 탭이 대시보드처럼 변하고 정보 밀도가 과해질 수 있음 | 제외 |
| Desktop Pet Intelligence | 캐릭터 경험이 풍부해짐 | 버전의 핵심 생산성 기능으로는 정보 전달력이 약함 | 제외 |

## 범위

v1.6.0은 Codex 탭 중심 버전입니다.

포함합니다.

- Codex reset schedule 모델
- Codex 탭 회복 카드 UI
- 다음 회복 시점 강조
- stale/error/waiting 상태에서 reset 시각의 신뢰도 표현
- 작업 세션 계획 요약
- reset 기준 알림 문구 개선
- 메뉴바 tooltip 또는 펫 메뉴의 다음 초기화 glance
- CLI 텍스트 출력의 reset schedule 요약
- v1.6 전용 문서, focused tests, 검증 스크립트

제외합니다.

- `codex-usage status --json` schema breaking change
- 기존 `usage.json`, `usage-weekly-history.json`, `usage-reset-window-history.json` schema breaking change
- Codex app-server raw response 저장
- auth token, refresh token, cookie, session material, auth header 읽기, 출력, 저장
- 공식 사용량과 로컬 SQLite 추정치 혼합 표시
- `Plus`, `Pro $100`, `Pro $200` 가격 tier 추정
- 새 전체 Dashboard 탭
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning이 필요한 기능
- WidgetKit 실제 UI 완료 조건
- 사용자 명시 요청 없는 GUI 실행, 설치, LaunchAgent 변경, helper 설치/삭제, 장시간 테스트, push

## 제품 경험

Codex 탭의 상단은 "현재 상태"와 "회복 일정"을 빠르게 읽게 합니다.

권장 정보 구조는 다음 순서입니다.

1. 현재 위험 상태 요약
2. 회복 카드 영역
3. 5시간/주간 사용량 행
4. 작업 세션 계획 요약
5. 현재/지난/비교 그래프

회복 카드 영역은 사용자에게 "몇 장 남았는지"처럼 읽히되, 내부적으로는 app-server report의 window와 bucket에서 파생합니다.

기본 카드 후보는 다음입니다.

- 5시간 회복 카드
- 주간 회복 카드
- 같은 기본 `codex` bucket에서 추가로 식별 가능한 reset window

기본 UI는 `rateLimitsByLimitId.codex`를 중심으로 표시합니다.
`codex_bengalfox` 같은 추가 bucket은 기본 카드와 섞지 않고 advanced/debug 영역으로 분리합니다.
추가 bucket이 제품적으로 어떤 의미인지 확인되지 않았기 때문에 기본 사용자 판단 재료로 승격하지 않습니다.

## 회복 카드

각 회복 카드는 다음 값을 표시합니다.

| 필드 | 설명 |
| --- | --- |
| 제목 | `5시간`, `주간`, 또는 확인된 window label |
| 초기화 시각 | `resetsAt`을 로컬 시간대로 변환한 날짜와 시간 |
| 남은 시간 | 현재 시각 기준 reset까지 남은 시간 |
| 사용률 | 해당 window의 `usedPercent` |
| 잔여율 | `100 - usedPercent` |
| 신뢰 상태 | fresh, stale, error, waiting |

카드 정렬은 reset 시각이 빠른 순서입니다.
가장 빨리 회복되는 카드는 `다음 회복`으로 강조합니다.

fresh cache에서는 초기화 시각을 확정 정보로 표시합니다.
stale cache에서는 `마지막 확인 기준` 문구를 붙입니다.
error snapshot에서는 마지막 성공 cache가 있어도 오류 상태를 함께 표시합니다.
필수 5시간/주간 window가 누락되면 `프로토콜 확인 필요` 상태로 표시하고 카드 생성을 제한합니다.

## 작업 세션 계획

작업 세션 계획은 "앞으로 어느 정도 작업해도 괜찮은가"를 짧게 알려주는 P1 기능입니다.

초기 설정은 사용자 입력 없이 보수적으로 시작합니다.

- 기본 계획 길이: 1시간
- 표시 대상: Codex 탭 compact summary
- 계산 근거: 현재 weekly sample pace와 reset까지 남은 시간
- 상태: safe, watch, risky, unavailable

사용자 조작은 Codex 탭 안의 작은 segmented control 하나로 제한합니다.
선택지는 1시간, 3시간, reset까지입니다.
기본 선택값은 1시간입니다.
세션 계획은 공식 한도가 아니라 현재 sample pace 기반 예상이므로 UI에서 `예상`으로 표시합니다.

## 알림과 Glance

v1.6.0 알림은 기존 `UserNotifications` 로컬 알림 경계를 유지합니다.

개선 방향은 다음입니다.

- reset 30분 전 알림 문구를 "곧 회복" 관점으로 조정
- 같은 reset window 안에서 같은 회복 알림이 반복 발송되지 않게 dedupe 유지
- stale/error cache에서는 회복 알림을 확정적으로 발송하지 않음
- 알림은 계속 기본 꺼짐이며 사용자 opt-in과 macOS 알림 권한이 필요함

메뉴바 tooltip 또는 펫 우클릭 메뉴에는 다음 초기화 glance를 추가합니다.

예시:

```text
다음 초기화: 5시간 · 오늘 18:20
주간 초기화: 7월 10일 03:00
```

tooltip은 너무 길어지지 않게 다음 회복 하나와 주간 reset 정도만 표시합니다.

## CLI

`codex-usage status` 텍스트 출력에는 reset schedule 요약을 추가합니다.

예시:

```text
Next reset: 5시간 오늘 18:20 (2시간 14분 남음)
Weekly reset: 2026-07-10 03:00
```

`status --json`은 v1.6.0에서 breaking change하지 않습니다.
새 JSON 필드가 필요하면 별도 opt-in 출력 또는 새 subcommand를 먼저 설계합니다.
v1.6.0 MVP는 텍스트 출력과 앱 UI 모델 중심으로 진행합니다.

## 아키텍처

새 모델은 `CodexUsageCore`에 둡니다.

권장 구성은 다음입니다.

| 구성 | 역할 |
| --- | --- |
| `CodexUsageResetSchedule` | 여러 reset entry를 담는 값 타입 |
| `CodexUsageResetScheduleEntry` | window/bucket별 reset 카드 데이터 |
| `CodexUsageResetScheduleBuilder` | `CodexUsageReport`와 cache 상태에서 schedule 생성 |
| `CodexUsageSessionPlan` | 작업 세션 길이와 pace 기반 위험도 |
| `CodexUsageSessionPlanBuilder` | history와 현재 snapshot에서 session plan 생성 |

앱 쪽에서는 `UsageMonitorState`가 schedule과 session plan summary를 계산해 Codex 탭에 전달합니다.
기존 `CodexUsagePanel`, `WeeklyRemainingHistoryBlock`, `CodexUsageDataStatusBlock` 경계를 유지하고, 회복 카드 UI는 별도 작은 view로 분리합니다.

## 데이터 흐름

데이터 흐름은 다음입니다.

1. `codex-usage` 또는 앱 cache refresh가 기존 방식으로 app-server report를 얻습니다.
2. cache writer는 기존 cache/history 파일에 breaking change 없이 저장합니다.
3. 앱은 `usage.json`, weekly history, reset-window history를 읽습니다.
4. `CodexUsageResetScheduleBuilder`가 report의 5시간/주간 window를 schedule entry로 변환합니다.
5. `CodexUsageSessionPlanBuilder`가 weekly history와 현재 snapshot으로 세션 위험도를 계산합니다.
6. Codex 탭은 schedule entry, data status, session plan, 기존 그래프를 함께 표시합니다.

WidgetKit은 v1.6.0 기본 완료 조건에 포함하지 않습니다.
Widget source가 이 모델을 재사용하는 작업은 v1.6.0 기본 범위에서 제외합니다.
실제 위젯 UI 검수는 App Group provisioning 이후 별도 milestone에서만 다룹니다.

## 오류 처리

오류 처리는 v1.5.0 용어와 맞춥니다.

| 상태 | UI 처리 |
| --- | --- |
| `ok` | reset 시각과 남은 시간을 일반 표시 |
| `waiting` | 카드 대신 사용량 데이터 대기 문구 표시 |
| `stale` | 마지막 확인 기준 reset 일정으로 표시 |
| `error` | 마지막 성공 cache와 오류 상태를 함께 표시 |
| protocol drift 가능성 | 필수 window 누락으로 표시하고 카드 생성을 제한 |

raw error message를 사용자 UI나 cache에 그대로 확장 저장하지 않습니다.
진단 문구는 기존 redaction 정책을 유지합니다.

## 테스트

최소 검증은 문서 전용 단계와 구현 단계로 나눕니다.

설계 문서 단계:

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
```

구현 단계:

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
swift test --filter CodexUsageResetScheduleTests
swift test --filter CodexUsageSessionPlanTests
swift test --filter UsageMonitorStateTests
swift test --filter PopoverScreenshotRendererTests
./script/verify_v160_codex_recovery_planner_contract.sh --self-test
swift test
```

macOS 앱 UI 변경이 있으므로 release head 전에는 Xcode Debug build도 실행합니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

실제 popover를 열지 않았다면 `UI 확인 미수행`으로 보고합니다.
장시간 `codex-usage status --watch 60`은 사용자 명시 요청 없이는 실행하지 않습니다.

## v1.6.0 이슈 순서

| 순서 | 우선순위 | 이슈 | 완료 경계 |
| ---: | --- | --- | --- |
| 1 | P0 | v1.6.0 baseline 정렬 | README, ROADMAP, v1.6 문서, source roadmap 용어 정렬 |
| 2 | P0 | Reset schedule 모델 | 5시간/주간 reset entry, 로컬 시간 표시, 남은 시간, 사용률/잔여율 계산 |
| 3 | P0 | Codex 탭 회복 카드 | 다음 회복 강조, 카드 정렬, compact layout, screenshot/focused test |
| 4 | P0 | 추가 bucket 경계 | 기본 `codex` bucket과 advanced/debug bucket 분리 |
| 5 | P0 | stale/error/waiting 처리 | reset 시각 신뢰도와 오류 상태를 과장 없이 표시 |
| 6 | P1 | 작업 세션 계획 | 1시간 기본 plan, safe/watch/risky/unavailable 상태 계산 |
| 7 | P1 | 회복 기준 알림 개선 | reset 30분 전 알림 문구와 dedupe를 회복 관점으로 정리 |
| 8 | P1 | 메뉴바 tooltip과 펫 메뉴 glance | 다음 초기화 정보를 짧게 표시 |
| 9 | P1 | CLI reset schedule 요약 | `status` 텍스트 출력에 schedule summary 추가, `--json` breaking change 금지 |
| 10 | P2 | 검증 스크립트 | v1.6 contract verifier와 fixture self-test 추가 |
| 11 | P2 | 문서와 screenshot closure | README, ROADMAP, Docs, screenshot renderer 정리 |
| 12 | P2 | release readiness 문서 | 자동 검증, UI smoke, live fetch smoke, 미수행 보고 형식 분리 |

각 단계는 순서대로 진행합니다.
P0이 실패하면 P1/P2는 진행하지 않습니다.

## 성공 기준

v1.6.0은 다음이 충족될 때 구현 완료로 볼 수 있습니다.

- Codex 탭에서 5시간/주간 회복 카드를 볼 수 있습니다.
- 각 카드에 초기화 날짜, 남은 시간, 사용률, 잔여율이 표시됩니다.
- 가장 빠른 reset이 다음 회복으로 강조됩니다.
- stale/error/waiting 상태가 reset 일정의 신뢰도를 과장하지 않습니다.
- 작업 세션 계획이 sample 부족, stale, error 상태를 분리합니다.
- 추가 bucket은 기본 UI에 섞이지 않고 advanced/debug 경계로 남습니다.
- `status --json`과 기존 cache/history schema가 breaking change 없이 유지됩니다.
- raw app-server response와 auth/session material을 저장하거나 출력하지 않습니다.
- focused tests, verifier, 전체 `swift test`, 필요한 Xcode build가 통과합니다.
- 실제 UI 확인을 하지 않은 경우 `UI 확인 미수행`으로 보고합니다.

## 후속으로 남기는 항목

아래 항목은 v1.6.0 기본 범위에 넣지 않습니다.

- 전체 Dashboard 탭
- 사용자 정의 세션 preset의 복잡한 편집 UI
- 장기 사용량 예산 리포트
- 모델 자동 전환 힌트
- WidgetKit 실제 UI의 회복 카드 표시
- Apple Developer Program이 필요한 stable signed/notarized 배포 작업

이 항목들은 사용자가 별도 milestone으로 승인할 때만 다시 검토합니다.
