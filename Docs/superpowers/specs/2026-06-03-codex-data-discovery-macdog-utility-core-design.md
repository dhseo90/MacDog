# Codex 데이터 탐색과 MacDog 유틸리티 코어 설계

## 배경

MacDog v1.1.0은 Codex 사용량 모니터링, 메뉴바 표시, 데스크톱 펫, 잠들지 않기, 배터리 충전 한도 상태, 선택형 권한 도우미, 릴리즈 패키징 검증까지 기본 축이 이미 갖춰져 있습니다. 다음 방향은 기능을 무작위로 늘리는 것이 아니라, 실제 불편을 줄이는 순서로 정해야 합니다.

사용자의 우선순위는 다음과 같습니다.

- Codex 사용량 쪽은 MacDog가 아직 보여주지 않는 유용한 데이터가 있을 때만 확장합니다.
- 매일 쓰는 가치는 Mac 상주 유틸리티 쪽이 더 중요합니다.
- 캐릭터와 펫 추가는 다음 핵심 milestone이 아니라 여유가 있을 때 더하는 보너스 성격으로 둡니다.

현재 저장소 고정 예제와 모델 계층에서 확인되는 Codex app-server 데이터는 다음 정도입니다.

- 최상위 키: `rateLimits`, `rateLimitsByLimitId`
- 알려진 사용량 묶음: `codex`, `codex_bengalfox`
- 사용량 묶음 필드: `limitId`, `limitName`, `primary`, `secondary`, `credits`, `planType`, `rateLimitReachedType`
- 사용량 창 필드: `usedPercent`, `windowDurationMins`, `resetsAt`
- 크레딧 필드: `hasCredits`, `unlimited`, `balance`

따라서 현재 코드 기준으로 가장 현실적인 Codex 확장 후보는 여러 사용량 묶음을 고급 정보로 보여주는 것입니다. 그 외 숨은 데이터는 live 프로토콜 변화 확인에서 안전한 필드가 발견될 때만 다룹니다.

## 절대 경계

이 설계는 Apple Developer Program 접근이 필요한 작업을 포함하지 않습니다. 사용자는 현재 Apple Developer 계정이 없으므로, 해당 권한이 필요한 항목은 개발 대상, 완료 조건, 후속 이슈에 넣지 않습니다.

범위에서 제외하는 항목은 다음과 같습니다.

- Developer ID 서명
- notarization 또는 stapling
- App Store Connect
- App Group provisioning을 완료 조건으로 삼는 작업
- 서명된 안정 공개 릴리즈 관문
- provisioning된 App Group이 필요한 WidgetKit 실제 UI 검수
- Apple Developer 인증 정보가 있다고 전제하는 모든 계획

WidgetKit 소스, 테스트, 선택 빌드 경계는 기존처럼 보존할 수 있지만, 이 설계의 구현 대상은 아닙니다.

보안 경계는 다음과 같습니다.

- `~/.codex/auth.json`을 읽거나 출력하지 않습니다.
- access token, refresh token, cookie, session id, auth header, raw app-server payload를 로그나 문서에 남기지 않습니다.
- raw app-server 응답을 캐시에 저장하지 않습니다.
- live Codex app-server를 확인하더라도 민감정보를 제거한 필드 목록과 사용량 묶음/창 요약만 기록합니다.
- 사용자가 명시적으로 schema migration을 승인하지 않는 한 CLI JSON schema, 앱 소유 캐시 schema, WidgetKit 캐시 계약, app-server 응답 해석 계약을 깨지 않습니다.

운영 경계는 다음과 같습니다.

- 사용자 명시 승인 없이 GUI 앱 실행, 장시간 테스트, 설치 스크립트 실행, LaunchAgent 변경, helper 설치/삭제, DMG 설치 검수, codesign, notarization, push를 하지 않습니다.
- 문서 전용 변경도 최소 `git diff --check`를 실행합니다.
- markdown lint를 시도하지 못했거나 네트워크/도구 문제로 실패했다면 통과로 포장하지 않고 그대로 보고합니다.

## 목표

1. Codex가 현재 MacDog가 보여주지 않는 유용한 데이터를 제공하는지 확인합니다.
2. 안전하고 유용한 데이터가 있으면 기존 기본 출력 계약을 바꾸지 않는 고급 Codex 표면을 설계합니다.
3. 유용한 추가 데이터가 없으면 Codex 확장은 중단하고 MacDog 유틸리티 코어 정리에 집중합니다.
4. Apple Developer 의존성을 추가하지 않고, 이후 매일 쓰는 Mac 유틸리티 기능을 넣기 쉬운 구조를 준비합니다.

## 비목표

- 새 캐릭터 세트 추가
- WidgetKit을 기본 앱 또는 기본 DMG에 포함
- 공개 릴리즈 signing/notarization 전략 변경
- 현재 `codex-usage status --json` schema 교체
- SMC 기반 배터리 제어 추가
- 새 installer 흐름 추가
- 직접 파일 복사나 `install.sh`를 사용자 설치 검수로 인정

## 접근안

### 안 A: Codex 데이터 탐색 우선

기존 app-server 응답 계약을 기준으로 작은 탐색 작업을 진행합니다. 현재 고정 예제/모델 필드와 민감정보를 제거한 live 필드 목록을 비교한 뒤, 고급 화면을 추가할 가치가 있는지 판단합니다.

장점:

- 사용자가 처음 느낀 Codex 사용량 불편에 가장 직접적으로 답합니다.
- 필드 목록과 고정 예제 테스트 중심으로 시작하면 제품 위험이 낮습니다.
- Codex에 추가로 보여줄 데이터가 없으면 빠르게 멈출 수 있습니다.

단점:

- 새 데이터가 없으면 사용자에게 보이는 기능 산출물이 작을 수 있습니다.

추천: 첫 단계로 진행합니다.

### 안 B: MacDog 유틸리티 코어 정리 우선

새 기능을 더하기 전에 앱 조율부와 팝오버 UI를 기능별로 나눕니다. 현재 압력이 큰 파일은 `MenuBarController.swift`와 `UsagePopoverView.swift`입니다.

장점:

- 장기 개발 속도가 좋아지고 회귀 위험이 줄어듭니다.
- 잠들지 않기, 배터리, helper UX 같은 매일 쓰는 유틸리티 기능을 더 안전하게 붙일 수 있습니다.

단점:

- 당장 사용자 눈에 보이는 기능 변화는 적습니다.
- 기존 동작을 바꾸지 않는 구조 정리 검증이 필요합니다.

추천: Codex 데이터 탐색 뒤, 추가 Codex 데이터가 없거나 작을 때 바로 진행합니다.

### 안 C: 매일 쓰는 유틸리티 기능 우선

잠들지 않기 세션 상태, 배터리 충전 한도 알림, helper 문제 해결 안내처럼 바로 보이는 유틸리티 기능을 추가합니다.

장점:

- 사용자 체감 가치가 가장 큽니다.
- MacDog를 매일 켜두는 이유가 강해집니다.

단점:

- 현재 큰 UI/controller 파일에 바로 붙이면 유지보수 부담이 더 커집니다.
- 먼저 작은 구조 정리가 없으면 기능 경계가 흐려질 수 있습니다.

추천: 안 A와 안 B의 작은 구간을 먼저 끝낸 뒤 진행합니다.

## 권장 설계

두 개의 관문으로 진행합니다.

1. Codex 데이터 탐색 관문
2. 유틸리티 코어 정리 관문

Codex 관문에서 안전하고 유용한 데이터가 확인되면 고급/디버그 표면에 추가합니다. 확인되지 않으면 그 사실을 기록하고 앱 구조 정리로 넘어갑니다.

## Codex 데이터 탐색 관문

### 필드 목록

현재 고정 예제/모델이 알고 있는 필드와 현재 app-server 응답의 민감정보 제거 필드 목록을 비교할 수 있는 local-only 진단 경로를 추가합니다.

출력은 raw JSON이 아니라 구조 요약이어야 합니다. 아래 예시는 진단 명령의 구조적 출력 형식입니다.

```text
bucket: codex
fields: credits, limitId, limitName, planType, primary, rateLimitReachedType, secondary
primary fields: resetsAt, usedPercent, windowDurationMins
secondary fields: resetsAt, usedPercent, windowDurationMins
```

live 확인이 필요하다면 기존 `codex-usage` app-server client 경로 또는 같은 수준으로 민감정보가 제거되는 진단 경로를 사용합니다. Codex auth 파일을 직접 읽는 방식은 사용하지 않습니다.

### 평가 기준

새 필드는 아래 조건을 모두 만족할 때만 보여줍니다.

- 민감정보가 아닙니다.
- 사용자에게 설명할 만큼 안정적입니다.
- 실제 Codex 사용량 판단에 도움이 됩니다.
- 기존 JSON/캐시 schema에 추가형 변경이거나, 고급/디버그 출력에만 격리됩니다.

유용할 가능성이 있는 항목은 다음과 같습니다.

- `codex`, `codex_bengalfox` 같은 여러 사용량 묶음 요약
- `doctor`에서 알 수 없는 사용량 묶음 존재 안내
- 기본 JSON을 바꾸지 않는 명시적 고급/디버그 옵션

유용하지 않은 항목은 다음과 같습니다.

- raw 응답 dump
- 사용자 의미가 불분명한 내부 이름
- auth/session/account material처럼 보이는 필드

### UI 계약

기본 Codex 탭은 계속 primary `codex` 사용량 묶음에 집중합니다.

- 5시간 사용량
- 주간 사용량
- reset 시각
- plan
- 크레딧
- stale/error 상태
- 주간 잔여량 history

고급 사용량 묶음 정보가 추가된다면 아래처럼 낮은 소음의 표면에 둡니다.

- CLI: `codex-usage doctor` 사용량 묶음 목록 섹션
- CLI: 명시적 고급/디버그 옵션
- 팝오버: 추가 사용량 묶음이 있을 때만 보이는 간결한 고급 행

사용자가 명시적으로 요청하지 않는 한, 추가 사용량 묶음을 기본 runner 속도 계산에 넣지 않습니다.

## 유틸리티 코어 정리 관문

Codex 데이터 관문에서 강한 기능 후보가 나오지 않으면 집중 유지보수 milestone으로 넘어갑니다.

### 컨트롤러 분리

`MenuBarController`는 AppKit 표면 소유권을 유지하되, 독립 책임을 작은 협력 타입으로 옮깁니다.

- 사용량 캐시 loading과 refresh request 조율
- local system metrics polling
- sleep-prevention 동기화
- privileged helper 설치/삭제 UI 작업
- installed app first-run setup prompt
- floating pet 동기화

목표는 대규모 재작성이나 동작 변경이 아닙니다. 추출된 각 타입은 현재 동작을 보존해야 하며, 기존 또는 새 집중 테스트로 검증합니다.

### 팝오버 분리

`UsagePopoverView`는 외곽 구조 역할을 유지하고, 모듈별 패널을 별도 파일로 나눕니다.

- `CodexUsagePanel`
- `MacResourcesPanel`
- `SleepPreventionPanel`
- `BatteryPanel`
- `SettingsPanel`
- 이미 의미 있는 chart/sparkline/supporting view

이 분리는 UI 재설계가 아닙니다. 다음 매일 쓰는 유틸리티 기능을 넣을 표면을 작게 만드는 것이 목적입니다.

### 상태와 동작

현재 `UsageMonitorState`, `PetAction`, `PetMenuModel` 개념은 유지합니다. 메뉴바와 데스크톱 펫 표면 사이의 경계로 이미 잘 동작하고 있습니다.

새 동작은 실제 제품 동작이 필요할 때만 추가합니다.

## 오류 처리

Codex 데이터 탐색에서:

- app-server 확인이 Codex 미실행, auth, network, app-server 문제로 실패하면 MacDog 회귀로 단정하지 않고 환경/상태 문제로 분리해 보고합니다.
- 알 수 없는 필드가 나오면 `safe`, `unclear`, `ignored`로 분류합니다.
- 민감정보처럼 보이는 필드가 있으면 즉시 중단하고 표시하거나 캐시하지 않습니다.

유틸리티 구조 정리에서:

- 기존 stale/error 캐시 동작을 보존합니다.
- helper missing/installed/error 상태 표시를 보존합니다.
- sleep-prevention fallback 동작을 보존합니다.
- WidgetKit 기본 제외 정책을 보존합니다.

## 테스트 계획

Codex 데이터 탐색 범위:

- `swift test --filter RateLimitModelsTests`
- `swift test --filter CodexUsageReportTests`
- 추가 안전 사용량 묶음 기능이 추가되면 고정 예제 테스트 추가
- 필드 목록 진단이 추가되면 민감정보 제거 테스트 추가
- `git diff --check`

유틸리티 코어 refactor 범위:

- `swift test --filter UsageMonitorStateTests`
- `swift test --filter PetMenuModelTests`
- `swift test --filter PopoverMetricsRefreshPolicyTests`
- `swift test --filter CodexUsageCacheRefreshPolicyTests`
- 추출한 패널/컨트롤러별 관련 테스트
- `git diff --check`

변경 폭이 넓어질 때:

- `swift test --no-parallel`
- `./script/verify_app_privacy_boundaries.sh`
- `./script/verify_cache_contract.sh`
- 캐릭터 resource contract를 건드렸을 때만 `./script/verify_character_profile.sh`

명시 요청 없이는 포함하지 않는 검증:

- GUI 앱 실행
- screenshot/manual UI 검수
- DMG 설치 검수
- helper 설치/삭제
- LaunchAgent 등록
- 장시간 watch 테스트
- push

## 완료 기준

Codex 데이터 탐색은 아래 조건을 만족하면 완료입니다.

- 현재 고정 예제/모델 필드가 문서화됩니다.
- live 또는 진단 확인을 했다면 민감정보 제거 구조 요약만 남깁니다.
- 결정을 기록합니다: 고급 Codex 사용량 묶음 표시를 추가할지, 현재는 Codex 확장을 멈출지.

유틸리티 코어 refactor는 아래 조건을 만족하면 완료입니다.

- 선택한 컨트롤러 또는 팝오버 분리를 사용자 동작 변경 없이 구현합니다.
- 집중 테스트가 통과합니다.
- `git diff --check`가 통과합니다.
- Apple Developer 의존 작업을 추가하지 않습니다.
- Codex JSON/캐시 schema 계약 파괴 변경을 만들지 않습니다.

## 구현 계획 결정

2026-06-03 구현 계획은 Codex 데이터 탐색 관문만 대상으로 합니다. 첫 구현은 `codex-usage doctor`에 안전한 사용량 묶음/필드 목록을 추가하고, 기본 `status` 텍스트/JSON 출력과 cache schema는 변경하지 않습니다.

유틸리티 코어 정리는 Codex 데이터 탐색 결과를 확인한 뒤 별도 계획으로 작성합니다.

## 현재 범위 안의 후속 후보

- 탐색 관문에서 유용성이 확인되면 `doctor`에 고급 사용량 묶음 목록 추가
- UI 재설계 없이 `UsagePopoverView` 모듈 패널 분리
- `MenuBarController`에서 사용량 캐시 갱신 조율 추출
- Developer ID 없는 local helper 경계 안에서 helper troubleshooting 문구 개선
- 대상 표면이 충분히 작아진 뒤 매일 쓰는 유틸리티 기능 하나 추가
