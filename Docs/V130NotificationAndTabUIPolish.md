# v1.3.0 알림 중심 사용량 인지와 탭별 UI 개선

상태: 구현 범위 / 문서 제외 경계 정리
작성일: 2026-06-04
갱신일: 2026-06-05
기준 릴리즈: v1.2.3
작업 브랜치: `v.1.3.0`

## 목적

v1.3.0은 MacDog가 단순히 사용량을 보여주는 앱에서, 위험 구간을 먼저 알려주는 개발 도구로 한 단계 나아가는 범위입니다.
핵심은 Codex 사용량 알림이고, 함께 손대는 UI 개선은 각 탭에서 현재 상태와 다음 행동을 더 빨리 읽히게 만드는 데 집중합니다.

## 제품 원칙

1. 알림은 유용해야 하며 귀찮으면 안 됩니다.
2. 알림은 사용자가 설정 탭에서 켜고 macOS 알림 권한을 승인한 뒤에만 발송합니다.
3. 같은 reset window 안에서는 같은 threshold 알림이 반복 폭주하지 않아야 합니다.
4. Codex 사용량 JSON schema, app-owned cache schema, app-server 해석 계약은 변경하지 않습니다.
5. menu bar UI process는 기존처럼 app-owned cache를 읽고, live app-server 호출은 CLI/cache writer 경로에 둡니다.
6. 탭별 UI 개선은 새 기능을 과장하지 않고 현재 구현된 상태를 더 명확하게 보여주는 범위로 제한합니다.
7. Apple Developer 계정이 필요한 기능명은 v1.3.0 문서/로드맵/검증 항목/후속 이슈에 나열하지 않습니다.
8. README/ROADMAP/AGENTS와 이 문서의 알림, cache, 제외 경계 용어를 일치시킵니다.

## Apple Developer 계정 필요 여부

결론: v1.3.0 알림 MVP는 Apple Developer 계정 없이 진행 가능한 `UserNotifications` 기반 로컬 알림 범위로 설계합니다.

확인한 경계:

- MacDog 앱이 이미 읽고 있는 app-owned usage cache를 기준으로 사용자 Mac 안에서 알림 이벤트를 판단합니다.
- 알림 표시는 `UserNotifications` 기반 로컬 알림과 사용자 권한 요청으로 제한합니다.
- 알림은 기본 꺼짐이며, 사용자가 설정 탭에서 켜고 macOS 알림 권한을 승인한 뒤에만 표시합니다.
- Apple Developer 계정이 필요한 기능명은 v1.3.0 문서/로드맵/검증 항목/후속 이슈에 나열하지 않습니다.
- Codex 사용량 JSON/cache/app-server 계약은 변경하지 않습니다.

중단 조건:

- 로컬 알림만으로 구현할 수 없다는 사실이 확인되면 해당 단계에서 중단합니다.
- 중단 시 확인된 원인, 변경 파일, 뒤 단계 건너뜀을 보고합니다.

근거:

- Apple Developer Documentation: `UserNotifications` local notification scheduling과 permission request

## 알림 정책 초안

알림 이벤트는 기본 `rateLimitsByLimitId.codex`의 5시간/주간 window를 기준으로 판단합니다.
러너 속도와 동일하게 `max(fiveHour.usedPercent, weekly.usedPercent)`를 기본 위험도로 사용하되, 알림 문구에는 실제로 threshold를 넘긴 window 이름을 함께 표시합니다.

| 이벤트 | 조건 초안 | 예시 문구 방향 | 반복 방지 |
| --- | --- | --- | --- |
| 사용량 높음 | 5시간 또는 주간 사용률 80% 이상 | `Codex 사용량 80% 이상` | 같은 window/reset 안에서 1회 |
| 한도 임박 | 5시간 또는 주간 사용률 95% 이상 | `한도 임박 · reset까지 ...` | 같은 window/reset 안에서 1회 |
| 한도 도달 | `rateLimitReachedType` 존재 또는 사용률 100% 이상 | `Codex 한도 도달` | 같은 window/reset 안에서 1회 |
| reset 임박 | 높은 사용량 상태에서 reset까지 30분 이하 | `곧 회복됩니다 · reset까지 ...` | 같은 window/reset 안에서 1회 |

확정 결정:

- reset 임박 기준 시간: 30분
- 알림 이벤트: 80%, 95%, limit, reset 임박을 모두 포함
- 반복 방지: 같은 window/reset 안에서 이벤트별 1회
- 알림 기본값: 시스템 알림은 기본 꺼짐, 설정 탭에서 사용자가 켬
- threshold별 개별 토글 여부: MVP에서는 전체 알림 켜기와 reset 임박 알림 토글만 우선 검토
- 테스트 알림 버튼: v1.3.0 MVP에 포함하지 않음
- dedupe 저장 위치: `UserDefaults` 기반 앱 설정으로 시작하고 cache schema에는 넣지 않음

## 탭별 UI 개선 초안

### 1. Codex 사용량 탭

목표는 "지금 얼마나 위험한지"와 "언제 회복되는지"를 바로 읽게 하는 것입니다.

- 5시간/주간 row 위나 아래에 현재 위험 요약을 둡니다.
- 5시간 reset countdown과 주간 reset countdown을 절대 시각 옆에 일관되게 표시합니다.
- 알림 기준과 현재 단계가 연결되도록 `80%`, `95%`, `limit` 상태 문구를 정리합니다.
- 주간 잔여량 그래프는 유지하되, 그래프가 알림 MVP의 필수 판단 데이터처럼 보이지 않게 합니다.

### 2. 활성 자원 탭

목표는 CPU, 메모리, 저장공간, 네트워크 상태를 더 빨리 스캔하게 하는 것입니다.

- 상단에 현재 Mac 상태 한 줄 요약을 둡니다.
- CPU/메모리 trend block은 경고 기준을 더 명확히 표시합니다.
- 네트워크 누적값과 현재 속도를 구분해 읽히게 합니다.
- 새 시스템 측정 항목은 v1.3.0 MVP에 넣지 않습니다.

### 3. 잠들지 않기 탭

목표는 현재 세션이 왜 켜져 있는지와 무엇을 끄면 되는지를 먼저 보여주는 것입니다.

- 현재 제어 방식, 남은 시간, 활성 trigger 이유를 상단 요약으로 분리합니다.
- 상태 기준 모드에서는 켜진 trigger와 현재 충족 여부를 더 명확히 구분합니다.
- 덮개 닫힘 보호와 잠금 화면 경고는 권한 도우미 설치 상태와 연결해 표시합니다.
- `pmset`, helper 설치/삭제, 실제 덮개 닫힘 검수는 사용자 별도 지시 없이는 실행하지 않습니다.

### 4. 배터리 탭

목표는 native Charge Limit 상태를 더 명확하게 구분하는 것입니다.

- 지원 가능, 지원 불가, 읽기 실패, 적용 실패를 서로 다른 상태로 표시합니다.
- 현재 한도와 목표 한도, 전원 연결/충전 상태를 한 눈에 보이게 정리합니다.
- Shortcuts 후보 입력 계약, SMC 충전 제어는 v1.3.0 기본 범위에서 제외합니다.

### 5. 설정 탭

목표는 새 알림 설정을 넣어도 설정 탭이 과밀해지지 않게 하는 것입니다.

- `알림` 섹션을 추가합니다.
- 시스템 알림 권한 상태, 알림 켜기, reset 임박 알림 토글을 우선 검토합니다.
- 테스트 알림 버튼은 v1.3.0 MVP에 넣지 않습니다. UI 복잡성을 줄이고 실제 알림 표시는 별도 UI 검수에서 확인합니다.
- 캐릭터 설정, 로그인 실행, 권한 도우미 섹션은 기존 기능을 유지하되 시각적 우선순위를 조정합니다.

## 중요도와 개발 순서

아래 순서는 중요도와 실제 개발 의존성을 함께 반영합니다.
Apple Developer 계정 없이 가능한 로컬 알림 경계를 가장 먼저 확인했고, 알림 정책과 설정 UI를 고정한 뒤 탭별 UI 개선으로 넘어갑니다.
로컬 알림 경계를 벗어나는 계정 의존 요구가 발견되면 해당 단계에서 중단합니다.

- v1.3.0 (1) Apple Developer 계정 필요 여부와 로컬 알림 경계를 먼저 고정합니다.
  - 로컬 알림만으로 가능한 설계임을 문서와 구현 계획에 남깁니다.
  - Apple Developer 계정이 필요한 기능명은 세부 후보나 후속 이슈로 나열하지 않습니다.
- v1.3.0 (2) 알림 정책 모델과 이벤트별 1회 dedupe 계약을 테스트로 고정합니다.
  - 80%, 95%, limit, reset 30분 전 이벤트를 계산합니다.
  - 같은 window/reset 안에서 이벤트별 1회만 알림 후보가 나오게 합니다.
- v1.3.0 (3) 설정 탭 알림 섹션과 권한 상태 UI를 추가하되 테스트 알림 버튼은 제외합니다.
  - 알림 켜기 전에는 macOS 권한 prompt를 띄우지 않습니다.
  - UI 복잡성을 줄이기 위해 테스트 알림 버튼은 MVP에서 제외합니다.
- v1.3.0 (4) cache refresh 이후 로컬 알림 발송 경로를 연결합니다.
  - app-owned cache와 `UsageMonitorState` 표시 정보만 사용합니다.
  - raw app-server payload나 auth/session material은 다루지 않습니다.
- v1.3.0 (5) Codex 탭 1차 UI 개선을 끝내고 첫 UI 검수를 수행합니다.
  - 위험 단계, reset countdown, 알림 기준이 한 화면에서 어긋나지 않게 정리합니다.
  - 실제 앱을 열지 않았다면 `UI 확인 미수행`으로 보고합니다.
- v1.3.0 (6) Mac, 잠들지 않기, 배터리, 설정 탭 UI 개선을 순서대로 진행합니다.
  - 각 탭은 현재 상태 요약과 다음 행동을 먼저 보이게 정리합니다.
  - helper 설치/삭제, 배터리 한도 쓰기, GUI 실행은 사용자 명시 요청 전까지 수행하지 않습니다.
- v1.3.0 (7) 전체 탭 UI 검수와 screenshot/focused test 회귀 확인을 수행합니다.
  - Codex 탭 이후 두 번째 UI 검수 지점입니다.
  - 실행하지 않은 UI 검수는 완료로 기록하지 않습니다.
- v1.3.0 (8) README/ROADMAP/AGENTS 용어와 제외 경계를 정리하고 구현 범위 검증을 닫습니다.
  - Apple Developer 계정이 필요한 기능명, custom runner, 장기 history export가 섞이지 않았는지 확인합니다.
  - push와 release 작업은 사용자 별도 지시 전까지 진행하지 않습니다.

## 세부 로드맵과 검증 경계

### 0단계: 문서와 계약 고정

작업:

- README/ROADMAP/AGENTS와 이 문서에 v1.3.0 범위, 제외 경계, 완료 기준을 기록합니다.
- 기존 Codex JSON/cache/app-server 계약을 변경하지 않는다고 명시합니다.
- 알림이 Apple Developer 계정 없이 가능한 `UserNotifications` 로컬 알림 범위인지 사전 확인합니다.
- Apple Developer 계정이 필요한 기능명은 완료 조건과 후속 이슈에 나열하지 않습니다.

완료 기준:

- `git diff --check`가 통과합니다.
- 실행하지 않은 UI/설치/장시간 검증을 완료처럼 쓰지 않습니다.
- Apple Developer 계정이 필요한 기능명을 v1.3.0 범위에 나열하지 않았음을 확인합니다.
- `./script/verify_v130_local_notification_boundary.sh --self-test`가 통과합니다.

### 1단계: 알림 정책 모델

작업:

- 사용량 snapshot에서 알림 후보 이벤트를 계산하는 작은 정책 타입을 추가합니다.
- threshold crossing, limit 상태, reset 임박, dedupe key를 테스트로 고정합니다.
- 알림 판단은 app-owned cache와 `UsageMonitorState`에서 이미 가진 표시 정보만 사용합니다.

완료 기준:

- 알림 정책 focused test가 통과합니다.
- cache schema와 CLI JSON schema 변경이 없습니다.

### 2단계: 알림 설정과 권한 흐름

작업:

- 설정 탭에 알림 섹션을 추가합니다.
- 알림 기능은 사용자가 켜기 전까지 시스템 권한 prompt를 띄우지 않습니다.
- 권한 거부, 권한 미결정, 권한 승인 상태를 구분합니다.
- 테스트 알림 버튼은 추가하지 않습니다.
- dedupe 상태는 `UserDefaults` 기반 앱 설정으로 저장합니다.

완료 기준:

- 설정 UI 테스트 또는 screenshot renderer가 새 섹션을 검증합니다.
- 실제 macOS 알림 권한 prompt를 열지 않았다면 `UI 확인 미수행`으로 보고합니다.

### 3단계: 알림 발송 연결

작업:

- cache refresh 이후 알림 정책을 평가합니다.
- 같은 window/reset 안에서 같은 이벤트를 반복 발송하지 않습니다.
- reset window가 바뀌면 해당 window의 알림 dedupe 상태를 새로 시작합니다.
- 알림 실패는 앱 오류로 과장하지 않고, 설정 탭에 권한/발송 상태로만 표시합니다.

완료 기준:

- 발송 orchestration test가 통과합니다.
- 알림 발송은 raw app-server payload나 auth/session material을 다루지 않습니다.

### 4단계: Codex 탭 UI 개선

작업:

- 현재 위험 단계와 threshold를 한 줄 요약으로 보여줍니다.
- 5시간/주간 reset countdown 표시를 정리합니다.
- high usage banner와 알림 문구가 서로 어긋나지 않게 합니다.

완료 기준:

- `PopoverScreenshotRendererTests` 또는 focused SwiftUI test가 통과합니다.
- 실제 popover를 열지 않았다면 `UI 확인 미수행`으로 보고합니다.

### 5단계: 나머지 탭 UI 개선

작업:

- 활성 자원 탭의 상단 상태 요약과 metric 구분을 정리합니다.
- 잠들지 않기 탭의 현재 세션/활성 trigger 요약을 정리합니다.
- 배터리 탭의 native Charge Limit 지원/적용/오류 상태를 구분합니다.
- 설정 탭은 알림 섹션 추가 후 과밀해진 구역을 재배치합니다.

완료 기준:

- 관련 focused test와 screenshot renderer가 통과합니다.
- helper 설치/삭제, 배터리 한도 쓰기, GUI 실행은 사용자 명시 요청 전까지 수행하지 않습니다.

### 6단계: 회귀 검증과 문서 정리

작업:

- README/ROADMAP/AGENTS 용어가 알림, cache, Apple Developer 계정 경계와 일치하는지 확인합니다.
- 알림 MVP가 custom runner, 장기 history export와 섞이지 않았는지 확인합니다.
- Apple Developer 계정 없이 가능한 로컬 알림 범위를 벗어나지 않았는지 다시 확인합니다.
- 릴리즈 준비나 push는 사용자가 별도로 지시하기 전까지 진행하지 않습니다.

완료 기준:

- `git diff --check`가 통과합니다.
- 관련 focused `swift test`와 전체 `swift test`가 통과합니다.
- `./script/verify_v130_local_notification_boundary.sh --self-test`가 README/ROADMAP/AGENTS와 이 문서의 로컬 알림 경계를 확인합니다.
- 필요한 경우 Xcode Debug build를 실행하고, 실행하지 않았다면 미실행으로 보고합니다.

## 검증 계획

문서 전용 단계:

```sh
git diff --check
./script/verify_v130_local_notification_boundary.sh --self-test
npx --yes markdownlint-cli2@0.22.1
```

알림/앱 구현 단계:

```sh
git diff --check
swift test --filter UsageNotification
swift test --filter UsageMonitorStateTests
swift test --filter PopoverScreenshotRendererTests
swift test
```

macOS 앱 UI 변경 단계:

```sh
git diff --check
swift test
xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

GUI 앱 실행, 실제 macOS 알림 권한 prompt, Notification Center 표시, 설치/LaunchAgent/helper 변경, DMG drag-and-drop 설치 검수, 장시간 테스트는 사용자 명시 요청이 있을 때만 수행합니다.

UI 검수 시점:

- Codex 탭 1차 개선이 끝난 뒤 1회 수행합니다.
- 전체 탭 개선이 끝난 뒤 1회 수행합니다.
- 두 검수 모두 실제 앱을 열지 않았다면 완료로 기록하지 않고 `UI 확인 미수행`으로 보고합니다.

## 제외 항목

- Apple Developer 계정이 필요한 기능 또는 배포/권한 흐름
- Apple Developer 계정이 필요한 기능명 또는 후속 이슈 나열
- `codex-usage status --json` breaking change
- app-owned cache schema breaking change
- Codex app-server raw response 저장 또는 출력
- 새 Codex bucket 기본 UI 노출
- custom runner import
- 장기 사용량 history export
- SMC 충전 제어
- 자동 모델 전환 힌트
- 사용자 명시 요청 없는 릴리즈 준비 또는 push

## 결정된 항목

1. reset 임박 알림 기준은 30분으로 둡니다.
2. 80%, 95%, limit, reset 임박 알림을 모두 MVP 이벤트로 포함합니다.
3. 반복 방지는 같은 window/reset 안에서 이벤트별 1회로 둡니다.
4. 테스트 알림 버튼은 v1.3.0 MVP에 포함하지 않습니다.
5. UI 검수는 Codex 탭 1차 완료 후 1회, 전체 탭 완료 후 1회 수행하는 것을 목표로 합니다.
6. 로컬 알림만으로 구현할 수 없다는 사실이 확인되면 v1.3.0 알림 개발은 중단합니다.
7. v1.3.0 (8) 문서 경계는 README 알림 경계, ROADMAP v1.3.0 섹션, AGENTS 문서 관리 규칙, `verify_v130_local_notification_boundary.sh --self-test`로 닫습니다.
