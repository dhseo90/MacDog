# Codex Usage Monitor Development Plan

## 목적

Codex 사용량 한도, 특히 5시간 창과 주간 창의 남은 비율을 빠르게 확인하고, macOS에서 RunCat처럼 시각적으로 감지할 수 있는 도구를 만든다.

최종 목표는 두 가지다.

1. 사용자가 다른 프로젝트에서 "Codex 사용량 체크"라고 요청하면 스크립트가 현재 사용량을 읽어 간단히 응답한다.
2. MacBook에서 사용량이 100%에 가까워질수록 더 빠르게 뛰는 상태표시/위젯을 제공하고, 클릭하면 현재 5시간/주간 사용량을 보여준다.

## 확인된 사실

- 공식 문서 기준 현재 Codex 사용량은 plan, 모델, 작업 크기, 로컬/클라우드 실행 여부에 따라 달라진다.
- 공식 확인 경로는 Codex usage dashboard이며, 활성 Codex CLI 세션 안에서는 `/status`를 사용할 수 있다.
- 로컬 Codex app-server 프로토콜에 `account/rateLimits/read` 요청이 있으며, 응답에는 `primary`, `secondary`, `credits`, `planType`, `rateLimitReachedType`가 포함된다.
- `primary.windowDurationMins = 300`이면 5시간 창으로 해석한다.
- `secondary.windowDurationMins = 10080`이면 주간 창으로 해석한다.
- 각 창의 `usedPercent`로 사용량을 계산하고, 잔여량은 `100 - usedPercent`로 표시한다.
- `resetsAt`은 Unix epoch seconds이며 로컬 시간대로 변환해 보여준다.

## 핵심 설계

### 데이터 소스 우선순위

1. Codex app-server `account/rateLimits/read`
   - 정확한 현재 한도/사용량 소스다.
   - `codex app-server`를 stdio로 실행하고 JSON-RPC 요청을 보낸다.
   - 최초 연결 후 `initialize` 요청을 보내고, 이후 `account/rateLimits/read`를 호출한다.

2. Codex CLI `/status`
   - 활성 CLI 세션 내부에서 사람이 확인하는 보조 경로다.
   - 자동화 API가 깨졌을 때 문서화된 수동 확인 절차로 유지한다.

3. 로컬 SQLite 추정치
   - `~/.codex/state_5.sqlite`의 `threads.tokens_used`는 스레드별 토큰 사용량 추정에는 쓸 수 있으나, 공식 잔여 한도는 아니다.
   - fallback 진단용으로만 사용하고 UI에는 "estimated" 라벨을 붙인다.

### CLI 스크립트

전역 실행 가능한 `codex-usage` 명령을 만든다.

예상 명령:

```sh
codex-usage status
codex-usage status --json
codex-usage status --watch 60
codex-usage doctor
```

텍스트 출력 예시:

```text
Codex usage
5h:     15% used, 85% remaining, resets 2026-05-26 01:27 KST
Weekly: 38% used, 62% remaining, resets 2026-05-31 09:19 KST
Credits: 0
Plan: pro
```

JSON 출력 예시:

```json
{
  "planType": "pro",
  "limits": {
    "codex": {
      "primary": {
        "usedPercent": 15,
        "remainingPercent": 85,
        "windowDurationMins": 300,
        "resetsAt": 1779726477
      },
      "secondary": {
        "usedPercent": 38,
        "remainingPercent": 62,
        "windowDurationMins": 10080,
        "resetsAt": 1780186777
      }
    }
  }
}
```

다른 프로젝트에서 Codex에게 사용량 확인을 요청할 때는 전역 `AGENTS.md`나 프로젝트 `AGENTS.md`에 다음 운영 지침을 추가한다.

```md
사용자가 Codex 사용량, 5시간 한도, 주간 한도, 잔여 토큰을 물으면 `codex-usage status`를 실행해 결과를 요약한다.
```

## macOS 앱/위젯 설계

RunCat과 유사한 "계속 뛰는" 표현은 WidgetKit보다 menu bar app이 적합하다. WidgetKit 위젯은 업데이트 주기와 애니메이션 제약이 있으므로, 1차 구현은 menu bar status item으로 만들고, 2차 구현에서 WidgetKit 위젯을 추가한다.

### 1차: Menu Bar Status App

- SwiftUI + AppKit `NSStatusItem` 기반으로 만든다.
- 작은 러너 아이콘 또는 프레임 애니메이션을 menu bar에 표시한다.
- 클릭 시 popover를 열어 현재 사용량을 보여준다.
- 표시 항목:
  - 5시간 사용률/잔여율
  - 주간 사용률/잔여율
  - reset 시각
  - plan type
  - credits balance
  - 마지막 갱신 시각
  - 데이터 소스 상태

애니메이션 속도 규칙:

```text
maxUsed = max(primary.usedPercent, secondary.usedPercent)
0-49%    calm
50-79%   active
80-94%   fast
95-99%   sprint
100%+    urgent / limit reached
```

### 2차: WidgetKit Widget

- small / medium 위젯을 제공한다.
- WidgetKit 제약 때문에 초당 애니메이션은 기대하지 않는다.
- 위젯은 현재 상태, 잔여율, reset 시각을 보여주고 클릭 시 menu bar app 또는 상세 화면을 연다.
- 위젯 데이터는 직접 Codex app-server를 호출하지 않고 shared cache JSON을 읽는다.

### 백그라운드 갱신

- `CodexUsageCore`가 app-server에서 사용량을 읽는다.
- menu bar app은 기본 60초마다 갱신한다.
- LaunchAgent 또는 앱 내 timer가 다음 파일에 최신 snapshot을 쓴다.

```text
~/Library/Application Support/CodexUsageMonitor/usage.json
```

WidgetKit extension은 이 cache를 읽어 표시한다.

## 권장 저장소 구조

```text
AGENTS.md
scripts/
  codex-usage
Sources/
  CodexUsageCore/
  CodexUsageCLI/
Apps/
  CodexUsageMonitor/
  CodexUsageWidgetExtension/
Tests/
  CodexUsageCoreTests/
Fixtures/
  rate_limits_response.json
```

Swift Package와 Xcode project 중 하나를 선택한다. macOS menu bar app과 WidgetKit까지 고려하면 Xcode project가 편하지만, core parser와 CLI는 Swift Package로 분리해 테스트하기 쉽게 만든다.

## 구현 단계

### Phase 1: CLI MVP

- app-server stdio client 작성
- `initialize` 요청 구현
- `account/rateLimits/read` 요청 구현
- `primary`와 `secondary`를 5시간/주간 창으로 매핑
- text/json 출력 구현
- `doctor` 명령으로 Codex 설치 경로, app-server 접근, auth 상태, 응답 스키마를 점검
- fixture 기반 parser unit test 작성

완료 기준:

- `codex-usage status`가 5시간/주간 사용률, 잔여율, reset 시각을 출력한다.
- `codex-usage status --json`이 안정적인 JSON schema로 출력한다.
- app-server 접근 실패 시 원인과 수동 확인 방법을 출력한다.

### Phase 2: Cache and Polling

- snapshot schema 정의
- `usage.json` atomic write 구현
- stale 상태 판단 추가
- 네트워크/auth 실패 시 마지막 성공 값을 표시하되 stale 경고를 포함
- LaunchAgent 설치/제거 스크립트 작성

완료 기준:

- 60초 단위 갱신이 가능하다.
- 앱과 위젯이 같은 cache를 읽는다.
- 실패 상태에서도 UI가 멈추거나 빈 화면이 되지 않는다.

### Phase 3: Menu Bar App

- SwiftUI popover UI 구현
- menu bar 애니메이션 프레임 구현
- 사용량에 따른 속도 매핑 구현
- 80%, 95%, 100% 임계값 색상/상태 변경 구현
- 클릭 시 상세 사용량 표시

완료 기준:

- 사용량이 높아질수록 애니메이션 속도가 체감된다.
- 5시간/주간 reset 시각이 로컬 시간대로 보인다.
- 앱이 로그인 토큰이나 민감 정보를 표시하거나 저장하지 않는다.

### Phase 4: WidgetKit

- small 위젯: 가장 높은 사용률과 reset 시각 표시
- medium 위젯: 5시간/주간 사용량을 모두 표시
- 위젯 클릭 deep link 구현
- stale cache 표시 구현

완료 기준:

- 데스크톱/알림 센터 위젯에서 현재 snapshot을 볼 수 있다.
- 위젯 클릭 시 상세 화면으로 이동한다.
- WidgetKit 업데이트 제약을 사용자에게 오해 없이 반영한다.

### Phase 5: Packaging

- `install.sh` 또는 signed app bundle 배포 방식 결정
- CLI symlink를 `~/bin/codex-usage`에 설치
- LaunchAgent 설치 옵션 제공
- uninstall 경로 제공
- README에 사용법과 제한사항 작성

## 보안 원칙

- `~/.codex/auth.json`을 직접 읽거나 출력하지 않는다.
- app-server의 인증 상태를 이용하되 access token을 로그에 남기지 않는다.
- 사용량 snapshot에는 plan, percent, reset time, credits balance만 저장한다.
- 오류 로그에는 request/response 전체 원문 대신 redacted summary를 남긴다.
- 네트워크 dashboard scraping은 마지막 수단으로만 고려한다.

## 리스크와 대응

- app-server 프로토콜은 내부/실험 성격일 수 있다.
  - 대응: `doctor`와 fixture test를 두고, 실패 시 `/status` 안내로 degrade한다.
- WidgetKit은 RunCat처럼 계속 뛰는 애니메이션에 적합하지 않다.
  - 대응: menu bar app을 주 구현으로 삼고 WidgetKit은 상태 확인용으로 둔다.
- Codex 한도 정책은 자주 바뀔 수 있다.
  - 대응: window duration과 limit id를 하드코딩하지 않고 응답 기반으로 해석한다.
- 여러 limit id가 반환될 수 있다.
  - 대응: 기본은 `codex`, 추가 bucket은 advanced output에 표시한다.

## 검증 체크리스트

- CLI가 정상 응답을 파싱한다.
- CLI가 app-server 미실행/인증 실패/네트워크 실패를 설명한다.
- 5시간 창 reset 시각이 정확히 로컬 시간대로 표시된다.
- 주간 창 reset 시각이 정확히 로컬 시간대로 표시된다.
- 80%, 95%, 100% 임계값에서 menu bar 상태가 바뀐다.
- cache가 오래되면 stale로 표시된다.
- 위젯은 stale/empty/error 상태를 각각 표시한다.
- 민감 정보가 파일, 로그, UI에 남지 않는다.

