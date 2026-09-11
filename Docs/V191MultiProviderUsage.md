# v1.9.1 복수 provider와 메인 provider 사용량 UI

상태: Step 2~5 main runtime TDD 완료 / Step 6~11 미착수
작성일: 2026-09-02
대상 버전: `1.9.1`
기준 브랜치: `v1.9.1`
개발 검증 버전: `MACDOG_APP_VERSION=1.9.1`

버전 정책: minor 구간은 `0~9`까지만 사용한다. 따라서 `v1.9.0` 다음 기능 버전은
`v1.9.1`이다.

## 목표

설정에서 `Codex`와 `Grok`을 하나 또는 둘 다 활성화한다. 둘 다 활성화하면 한 provider를
메인으로 지정한다. 1번 탭은 하위 provider 탭 없이 한 화면을 유지하며, 활성 provider의
주간 게이지를 상단에서 함께 보여 준다. 상세 그래프, pace, 초기화권, 러너, tooltip, 알림,
펫과 잠들지 않기 문구는 메인 provider만 기준으로 삼는다.

두 provider를 활성화한 예시는 아래와 같다.

```text
활성 provider     [x] Codex  [x] Grok
메인 provider     Codex
상세 그래프 표시  [x]

1번 탭 상단       Codex 5시간 + Codex 주간 + Grok 주간
상세 영역          Codex pace + 초기화권 + Codex 주간 그래프 + Codex 상태
```

`Grok`이 메인이면 상단은 Grok 주간과 Codex 주간을 함께 보여 주고, 상세 영역은 Grok pace와
Grok 주간 그래프를 사용한다. 보조 provider의 5시간 window나 상세 그래프는 표시하지 않는다.

## 용어와 상태 불변조건

- **활성 provider**: 사용자가 설정에서 체크한 `Codex` 또는 `Grok`이다.
- **메인 provider**: 활성 provider 중 상세 UI와 앱 반응을 담당하는 하나의 provider다.
- **보조 provider**: 둘 다 활성화했을 때 메인이 아닌 provider다.
- **상세 그래프 표시**: 메인 provider의 `WeeklyRemainingHistoryBlock`과 현재/지난/비교 control을
  보이거나 숨기는 설정이다. 꺼도 모든 활성 provider의 주간 게이지는 남는다.
- 활성 provider는 최소 하나다. 마지막 하나를 해제하는 동작은 허용하지 않는다.
- 메인 provider는 항상 활성 provider 집합에 포함된다.
- 활성 provider가 하나면 그 provider가 자동으로 메인이다.
- 메인 provider를 해제하면 남은 provider가 즉시 메인으로 승격한다.
- 보조 provider가 stale/error/missing이어도 메인 provider 데이터로 합성하거나 fallback하지
  않는다. 보조 게이지 자리에서 자체 상태를 표시한다.
- Codex와 Grok 사용률을 합산하거나 하나의 수치로 비교하지 않는다.

## preference와 migration 계약

기존 `usageProviderMode`는 메인 provider key로 보존한다. v1.9.1은 visible provider 활성
집합을 위한 별도 integer mask와 상세 그래프 표시 여부 key를 추가한다. 구현 모델은
`UsageProviderSelection`처럼 활성 집합과 메인을 함께 정규화하는 단일 값 객체로 둔다.

예정 저장 경계:

- `usageProviderMode`: 메인 provider raw value. 기존 key를 유지한다.
- `usageEnabledProviderMask`: visible `Codex`/`Grok` 활성 bit mask.
- `usageDetailGraphVisible`: 메인 provider 상세 그래프 표시 여부. 기본값은 `true`다.

migration 규칙:

1. 새 mask가 없으면 기존 `usageProviderMode`의 `Codex` 또는 `Grok` 하나만 활성화한다.
2. 기존 main 값은 그대로 메인으로 보존한다.
3. mask가 비었거나 알 수 없는 bit만 있으면 `Codex` 하나로 정규화한다.
4. main이 활성 집합에 없으면 활성 집합의 `Codex`, 그다음 `Grok` 순서로 승격한다.
5. hidden re-enable이 켜진 `Claude`는 기존 debug 전용 단일 경로로 보존하며 visible
   Codex/Grok 복수 선택에 섞지 않는다.
6. migration은 여러 번 실행해도 같은 결과를 내야 한다.

`codex-usage status --json`, `usage.json`, Grok cache/history schema는 변경하지 않는다.

## 데이터와 runtime routing

활성 집합과 메인 provider가 담당하는 범위를 분리한다.

활성 집합 기준:

- provider별 cache/history load
- 사용자가 요청한 refresh
- 설치본의 Codex/Grok cache LaunchAgent 유지 여부
- 1번 탭 주간 게이지 표시 여부

메인 provider 기준:

- 메뉴바 러너 pressure와 animation phase
- status item tooltip과 다음 초기화 glance
- 80%/95%/한도/reset 30분 전 로컬 알림과 기존 dedupe
- 1번 탭 제목, subtitle, pace, 초기화권, 상세 그래프, 데이터 상태
- 우클릭 펫 제목과 `사용량 종료` 문구
- 잠들지 않기 `실행 중` trigger 문구와 앱 match 기본 의미

둘 다 활성화하면 `com.dhseo.macdog.usage-cache`와
`com.dhseo.macdog.grok-usage-cache`를 함께 유지한다. 한쪽 refresh 실패가 다른 쪽 cache 평가,
게이지 표시, writer 생명주기를 취소하지 않게 한다. 앱은 Grok auth store를 읽거나 쓰지 않고,
기존 `macdog-grok-usage` writer 경계와 token 미저장 계약을 그대로 사용한다.

알림은 메인 provider만 평가한다. 보조 provider가 임계값을 넘더라도 알림을 보내지 않는다.
메인 provider가 stale/error여도 보조 provider 값으로 러너나 알림을 대체하지 않는다.

## 1번 탭 UI

provider 전환용 하위 탭, segmented control, disclosure navigation은 추가하지 않는다. 기존 1번
탭의 같은 content surface 안에서 다음 순서로 표시한다.

1. 메인 provider 상태 header
2. 활성 provider 게이지 묶음
   - Codex 메인: Codex 5시간, Codex 주간, 필요하면 Grok 주간
   - Grok 메인: Grok 주간, 필요하면 Codex 주간
3. 메인 provider pace와 provider 전용 정보
4. `상세 그래프 표시`가 켜진 경우 메인 provider 주간 그래프
5. 메인 provider 데이터 상태

게이지 묶음은 스크롤 전 상단에서 함께 읽히게 배치한다. 보조 provider 게이지는 provider명,
사용률, 잔여율, reset 또는 stale/error를 포함한다. Grok 5시간 값을 합성하지 않고, 보조
Codex도 주간 게이지만 표시한다.

상세 그래프를 숨기면 graph mode picker, hover plot, copy/export control도 함께 숨긴다. pace와
초기화권 같은 메인 전용 정보는 그대로 둔다.

## 구현 순서

앞 단계가 실패하면 뒤 단계를 시작하지 않는다. 각 단계는 실패 테스트, 최소 구현, focused
test, 결과 기록 순으로 닫는다.

| Step | 제목 | 우선순위 | 할 일 | 완료 조건 |
| ---: | --- | --- | --- | --- |
| 1 | 범위와 계약 고정 | P0 | `ROADMAP.md`와 이 문서에 복수 활성, 메인, 보조 게이지, no-fallback, 제외 경계를 기록한다. | 구현 전 모순되는 단일 provider 요구가 새 milestone 경계에서 해소된다. |
| 2 | selection 모델과 migration | P0 | 활성 bit mask, main, graph visibility를 읽고 정규화하는 preference 모델을 TDD로 추가한다. | 최소 하나 활성, main 포함, main 해제 승격, 기존 Codex/Grok migration, idempotence가 통과한다. |
| 3 | provider load policy | P0 | 단일 `SelectedUsageSourcePolicy`를 활성 집합 기반 load policy로 확장한다. hidden Claude는 별도 debug 경계를 유지한다. | 둘 다 활성일 때 두 cache/history를 읽고 어느 한쪽으로 fallback하지 않는다. |
| 4 | 두 cache writer 동시 운영 | P0 | `UserComponentInstaller`와 controller가 활성 집합에 따라 두 LaunchAgent를 독립적으로 install/remove하도록 확장한다. | 둘 다 활성 시 둘 다 install, 하나만 활성 시 해당 writer만 install하는 unit test가 통과한다. 실제 등록은 하지 않는다. |
| 5 | 메인 provider runtime policy | P0 | runner, tooltip, next reset, 알림, 메뉴, sleep trigger를 main 기준으로 바꾸고 copy 경로에서도 selection을 보존한다. | 보조 provider의 더 높은 사용률이나 stale 상태가 메인 반응을 바꾸지 않는다. |
| 6 | 통합 게이지 presentation model | P1 | 메인 전체 window와 보조 주간 상태를 한 번에 만드는 testable model을 추가한다. | Codex-main/Grok-main/single/stale/error 조합을 literal expectation으로 검증한다. |
| 7 | 설정 UI | P1 | provider checkbox, 둘 다일 때 main picker, 상세 그래프 checkbox를 추가하고 마지막 provider 해제를 막는다. | 설정 변경 직후 정규화된 selection이 저장되고 controller refresh가 한 번 발생한다. |
| 8 | 1번 탭 단일 화면 | P1 | 상단 게이지 묶음과 메인 상세 영역을 조합한다. provider 하위 탭은 만들지 않는다. | 두 provider 게이지가 한 content surface에 있고 graph visibility가 상세 그래프만 숨긴다. |
| 9 | controller 통합 | P1 | refresh task cancellation과 installed setup 동기화를 단일 mode 전환에서 selection diff로 바꾼다. | 한 provider 실패/해제가 다른 provider의 유효 cache와 task를 잘못 취소하지 않는다. |
| 10 | 회귀 검증과 문서 정렬 | P1 | focused test, screenshot renderer, 새 v1.9.1 계약 verifier를 추가하고 README/ROADMAP/Docs 용어를 정렬한다. | source guard가 provider 하위 탭, 합산, fallback, auth 접근을 거부하고 전체 자동 검증이 통과한다. |
| 11 | GUI와 릴리즈 검수 | P2 | 실제 설정 전환과 1번 탭 상단 게이지를 눈으로 확인한다. 설치/LaunchAgent/release smoke는 별도 명시 요청 뒤 수행한다. | 실행한 검증만 증거로 기록하고 나머지는 `미수행`으로 남긴다. |

## 테스트와 검증

최소 자동 검증:

```bash
git diff --check
swift test --filter UsageMonitorStateTests
swift test --filter UserComponentInstallerTests
swift test --filter UsageNotificationDeliveryTests
swift test --filter PopoverScreenshotRendererTests
swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build \
  -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
./script/verify_v191_multi_provider_contract.sh --self-test
```

TDD에서 먼저 고정할 주요 mutation은 아래와 같다.

- main이 활성 집합에서 빠져도 그대로 남는 오류
- 마지막 활성 provider를 해제할 수 있는 오류
- 둘 다 활성인데 한 writer만 설치되는 오류
- 보조 사용률이 runner/알림 source가 되는 오류
- 보조 stale/error가 메인 cache로 fallback하는 오류
- 상세 그래프 숨김이 게이지까지 숨기는 오류
- main 전환 뒤 이전 provider task/tooltip/알림이 남는 오류
- hidden Claude가 visible 복수 선택에 노출되는 오류

실제 앱 실행, GUI 조작, LaunchAgent 등록/제거, 설치, 장시간 테스트, codesign/notarization,
push는 사용자 명시 요청 전에는 실행하지 않는다.

## 보존 대상

- Codex app-server `account/rateLimits/read` 해석과 `codex-usage --json` schema
- Codex cache/history/reset credit와 weekly-only partial success
- Grok unofficial weekly-only writer, 별도 cache/history/lock, auth sibling 주기
- provider별 stale/error와 no-fallback
- Claude source/sanitizer/cache/privacy test와 hidden debug re-enable
- 공통 주간 그래프, current/past/compare, 날짜 기준, copy/export 구현
- WidgetKit source/test/opt-in build 경계

## 제외 경계

- Codex와 Grok 사용률 합산, 평균, 경쟁 순위 또는 비교 그래프
- 보조 provider 5시간 window나 상세 그래프 표시
- provider 자동 failover 또는 stale 값을 다른 provider로 대체
- Claude를 기본 설정에 다시 노출하거나 Codex/Grok과 동시에 활성화
- Codex/Grok cache JSON schema breaking change
- 메뉴바 앱의 Grok auth store 접근
- Grok 5시간 합성, Extra Usage Credits, console prepaid 혼합
- Apple Developer Program, Developer ID, notarization, App Group provisioning
- WidgetKit 실제 UI 완료 조건
- 사용자 명시 요청 없는 GUI, 설치, LaunchAgent 실등록, 릴리즈 publish, push

## 완료 기준

개발 완료:

- 설정에서 Codex/Grok 하나 또는 둘 다 활성화할 수 있고 최소 하나가 남는다.
- 둘 다 활성일 때 main을 선택하며 main은 항상 활성 집합에 포함된다.
- 기존 단일 Codex/Grok 사용자는 같은 provider 하나와 같은 main으로 migration된다.
- 두 provider writer/cache는 활성 집합 기준으로 독립 운영된다.
- 1번 탭 상단에서 활성 provider 주간 게이지를 탭 전환 없이 함께 본다.
- 나머지 UI와 runtime 반응은 main provider만 기준으로 한다.
- 상세 그래프를 숨겨도 활성 provider 게이지는 유지된다.
- stale/error/missing에서 합성이나 provider 간 fallback이 없다.
- token, cookie, session, auth header, auth 원문이 cache/log/fixture에 없다.

검증 완료:

- selection migration, writer action, main routing, 통합 게이지 model이 focused test로 보호된다.
- screenshot renderer가 single, Codex-main dual, Grok-main dual, graph-hidden 상태를 렌더링한다.
- `git diff --check`, focused test, 전체 `swift test`, Xcode Debug build, v1.9.1 verifier가 통과한다.
- 실제 UI를 열지 않았다면 `UI 확인 미수행`으로 보고한다.

## 모델 추천

전체 milestone:

추천 모델: `grok-4.6`
추론 수준: 높음 (high)
선정 근거: 영향도 2 + 불확실성 1 + 검증 난이도 2 + 변경 범위 2 = 7점. 기존 단일
provider 상태가 preference, writer, runner, 알림, UI 경계에 걸쳐 있어 통합 회귀 검토가 필요하다.
인증 방식이나 cache schema는 바꾸지 않으므로 `xhigh`까지 올리지 않는다.

단계별:

| 묶음 | 추천 모델 | 추론 수준 | 선정 근거 |
| --- | --- | --- | --- |
| Step 1 문서 계약 | `grok-4.5` | 낮음 (low) | 영향도 0 + 불확실성 1 + 검증 난이도 0 + 변경 범위 1 = 2점. 구현 전 범위 고정 |
| Step 2~5 상태·runtime | `grok-4.6` | 높음 (high) | 영향도 2 + 불확실성 1 + 검증 난이도 2 + 변경 범위 2 = 7점. preference와 writer 전이 회귀 위험 |
| Step 6~9 UI·controller | `grok-4.6` | 높음 (high) | 영향도 1 + 불확실성 1 + 검증 난이도 2 + 변경 범위 2 = 6점. 단일 화면과 task 생명주기 통합 |
| Step 10 자동 검증 | `grok-4.6` | 중간 (medium) | 영향도 1 + 불확실성 0 + 검증 난이도 2 + 변경 범위 1 = 4점. 반복 가능한 회귀 guard 구축 |
| Step 11 GUI·릴리즈 검수 | `grok-4.6` | 높음 (high) | 영향도 2 + 불확실성 0 + 검증 난이도 2 + 변경 범위 1 = 5점. 실제 설치·릴리즈 영향 |
