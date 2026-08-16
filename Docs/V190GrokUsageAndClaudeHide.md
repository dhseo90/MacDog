# v1.9.0 Grok 사용량 mode와 Claude hide

상태: 1차 구현 `[01/10]`~`[09/10]` 완료 / verifier·문서 정렬·릴리즈 미착수
작성일: 2026-08-15
대상 버전: `1.9.0`
기준 브랜치: `v1.9.0`
개발 검증 버전: `MACDOG_APP_VERSION=1.9.0`

## 목표

설정에서 `Codex` 또는 `Grok` 중 하나만 현재 사용량 provider로 선택한다. 1번 탭, 메뉴바
러너, 로컬 사용량 알림은 선택한 provider만 사용한다. 두 provider 동시 사용, 합산, 비교,
자동 fallback은 구현하지 않는다.

Claude는 코드를 삭제하지 않고 기본 UI에서 숨긴다. 숨김 재활성 경로를 남겨 나중에 live
검증이 가능해지면 다시 켤 수 있게 한다.

Grok은 SuperGrok / Grok Build의 **공유 주간 사용량 pool**을 대상으로 한다. console.x.ai
선불 API credit이나 팀 RPS/TPM과 섞지 않는다.

이 문서는 v1.9.0 구현 순서와 제외 경계만 고정한다. README / `ROADMAP.md` / `AGENTS.md`
버전 정렬, screenshot, release 문서는 마지막 단계에서 한다.

개발 버전 경계:

- 작업 브랜치는 `v1.9.0`만 사용한다.
- 개발 검증은 `MACDOG_APP_VERSION=1.9.0`을 쓴다.
- published `v1.8.0` 완료 증거와 `verify_v180_*`는 덮어쓰지 않는다.
- 1차 구현은 아래 `[01/10]`~`[10/10]`만 따른다. Step 14~15는 1차에 넣지 않는다.

## 현재 확인된 전제

- Codex는 공식 app-server `account/rateLimits/read`로 5시간/주간 사용률을 읽는다. 검증됨.
- Claude는 status line `rate_limits` backend가 있으나 실제 구독 live는 미수행이다.
- Grok 공개 REST 문서에는 Codex급 구독 잔여율 API가 없다.
- Grok 공식 제품 모델은 주간 1개 공유 pool이다. Settings → Usage와 CLI `/usage`가
  사용 비율과 주간 reset을 보여 준다.
- 기계가 읽는 경로는 CLI 로그인 기반 unofficial `x.ai/billing`이다. 공개 문서화된
  계약은 아니다. 세부 분리는 [V190GrokUsageSourceSpike.md](V190GrokUsageSourceSpike.md)에
  있다. live billing 조회는 미수행이다.
- 기존 `UsageNotificationRoute`는 `codex`가 아니면 `claude`로 떨어진다. Grok를 넣기 전에
  반드시 3분기로 고쳐야 한다.
- Codex `status --json` / `usage.json` schema는 breaking change 없이 유지한다.
- Grok cache는 Claude처럼 별도 파일이어야 한다.

## 제품 경계

설정 탭에는 다음 한 항목만 노출한다.

```text
사용량 mode    Codex ▾
```

보이는 값:

- `Codex`
- `Grok`

숨기는 값:

- `Claude`

규칙:

- 기본값과 기존 사용자 migration은 `Codex`다. Claude를 고른 사용자도 기본 UI에서는
  `Codex`로 되돌린다.
- Claude enum, sanitizer, cache, `macdog-claude-statusline`, 테스트는 삭제하지 않는다.
- Claude를 다시 켜는 경로는 hidden/debug preference 또는 내부 flag만 허용한다.
  설정 탭에 일반 항목으로 되살리지 않는다.
- 선택 provider가 stale/error여도 다른 provider로 fallback하지 않는다.
- Grok 5시간 window는 없다. 없으면 `현재 제공되지 않음`으로 두고 합성하지 않는다.
- Grok Extra Usage Credits는 Codex 초기화권이 아니다. 합성하거나 같은 UI로 보여 주지 않는다.
- `~/.grok/auth.json`을 출력하거나 cache/log/fixture에 저장하지 않는다. billing 조회가
  token을 쓰면 메모리에서만 쓰고 요청 header에 즉시 사용한다.

## 구현 순서

중요도가 높은 항목을 앞에 두고, 앞 단계가 실패하면 뒤 단계를 시작하지 않는다.

| Step | 제목 | 우선순위 | 할 일 | 완료 조건 |
| ---: | --- | --- | --- | --- |
| 1 | v1.9.0 범위 고정 | P0 | 이 문서로 목표, 제외, Claude hide, Grok 주간-only 경계를 고정한다. README/`ROADMAP.md` 정렬은 하지 않는다. | 이 문서가 `v1.9.0` 브랜치에 있고 구현 순서가 명확하다 |
| 2 | Grok 사용량 원천 spike | P0 | SuperGrok 주간 pool과 console API credit을 분리 확인한다. CLI `/usage`, CLI-proxy billing, `x.ai/billing` 중 안정적인 field만 기록한다. token, raw auth, 원문 응답은 저장하지 않는다. | 사용할 field 이름, 사용률/잔여율/reset 계산, 실패 시 동작이 이 문서 또는 후속 spike note에 적혀 있다. 공식 계약이 없으면 unofficial로 표시한다 |
| 3 | Grok weekly-only 입력 계약 고정 | P0 | `usedPercent`, `remaining = 100 - usedPercent`, `resetsAt`만 기본 UI 입력으로 둔다. 5시간 합성, Extra Usage Credits 혼합, 제품별 Chat/Build/Imagine 분해는 보류한다. | [V190GrokWeeklyOnlyContract.md](V190GrokWeeklyOnlyContract.md)에 최소 schema와 금지 항목이 있다 |
| 4 | 인증 예외 경계 고정 | P0 | Grok billing이 login token을 요구하면 Codex 초기화권과 같은 memory-only 예외만 허용한다. auth store 직접 읽기는 조회 직전으로 제한한다. | 같은 계약 문서에 token 미출력·미캐시·fixture 미저장 테스트 항목이 있다. 사용자 승인 없이 auth.json을 열지 않았다 |
| 5 | provider mode와 Claude hide | P0 | `UsageProviderMode`에 `grok`을 추가한다. 설정 picker는 visible cases만 보여 준다. Claude 코드와 테스트는 남긴다. | 설정에서 `Codex`/`Grok`만 보이고 Claude source가 삭제되지 않는다 |
| 6 | preference migration | P0 | 저장된 `claude`는 기본 UI에서 `codex`로 되돌린다. 잘못된 값은 `codex`다. hidden re-enable이 켜진 경우에만 Claude를 유지한다. | 기존 Codex 사용자는 그대로, Claude 선택 사용자는 Codex로 돌아간다 |
| 7 | 알림·러너·refresh 3분기 | P0 | `UsageNotificationRoute`를 `codex`/`grok`/`claude`로 나눈다. `codex`가 아니면 Claude로 떨어지는 분기를 제거한다. LaunchAgent와 live refresh는 Codex만 유지하고, Grok writer가 생기기 전에는 Grok mode에서 Codex cache를 평가하지 않는다. | Grok 선택이 Claude 알림/탭/러너로 가지 않는다. Codex cache로 fallback하지 않는다 |
| 8 | Grok 전용 cache/history | P0 | `usage.json`과 분리된 Grok snapshot/history/lock을 만든다. atomic write, `0700`/`0600`, stale/error, token 미저장을 Claude cache와 같은 수준으로 둔다. | Codex/Claude 기존 schema를 바꾸지 않고 Grok 파일이 따로 있다 |
| 9 | Grok fetch writer | P0 | spike에서 고른 경로로 주기 조회 writer를 만든다. Claude식 status line이 아니라 Codex식 polling이 기본이다. Grok mode에서만 writer/LaunchAgent를 돌린다. | Grok mode에서 주간 sample이 생기고, Codex mode에서는 Grok writer가 돌지 않는다 |
| 10 | 1번 탭 Grok weekly-only UI | P1 | 주간 사용률, 잔여율, reset, stale/error, cache 없음 empty state를 표시한다. 5시간은 `현재 제공되지 않음`이다. reset credit UI는 만들지 않는다. | Codex weekly-only와 같은 읽기 규칙으로 Grok 주간이 보인다 |
| 11 | 러너와 알림 연결 | P1 | 러너는 현재 제공되는 Grok window 사용률만 사용한다. 지금은 주간 하나다. 80%/95%/한도/reset 30분 전 알림은 선택 provider candidate만 만든다. | Grok stale/error에서 Codex 값으로 속도를 바꾸지 않는다 |
| 12 | 주간 그래프와 pace | P1 | 현재/지난/비교와 페이스메이커는 주간 history가 있을 때만 재사용한다. sample이 부족하면 추정하지 않는다. | 같은 `resetsAt` 안에서 표시 잔여율이 증가하지 않는다 |
| 13 | focused test와 계약 스크립트 | P1 | hide, migration, 3분기 routing, Grok weekly-only, privacy, no-fallback을 focused test로 고정한다. 새 v1.9 verifier를 만든다. 기존 v1.8 verifier는 완료 릴리즈 계약으로 유지한다. | 관련 focused test가 통과한다. v1.8 완료 증거를 덮어쓰지 않는다 |
| 14 | 문서 정렬 | P2 | README, `ROADMAP.md`, `AGENTS.md`, Onboarding, screenshot, release 문서를 마지막에 맞춘다. | 용어가 `Codex`/`Grok` visible mode와 일치한다. 실행하지 않은 검증을 완료로 쓰지 않는다 |
| 15 | GUI·live·release smoke | P2 | 실제 앱, Grok live billing, published DMG, final-state는 사용자 명시 요청 후에만 한다. | 실행한 항목만 완료로 기록하고 나머지는 `미수행`으로 남긴다 |

## 보존할 구현

- Codex CLI, JSON schema, cache, weekly/five-hour/reset history, reset credit
- Codex weekly-only partial과 5시간 미제공 표시
- Claude sanitizer, `macdog-claude-statusline`, Claude cache/history/privacy test
- 단일 provider preference, 설정 mode 한 항목, no-fallback
- 기존 로컬 알림 opt-in과 dedupe 구조
- WidgetKit source/opt-in 경계. 기본 DMG에는 넣지 않는다

## 제거하거나 숨길 것

- 설정 picker의 Claude 항목
- 기본 UI의 Claude empty state와 연결 command
- `UsageNotificationRoute`의 `codex` 외 Claude 강제 분기
- Grok 5시간 값 합성
- Grok Extra Usage Credits를 reset credit처럼 표시
- console.x.ai 선불 credit을 SuperGrok 잔여율로 표시
- Codex와 Grok 사용량 합산·비교
- 선택하지 않은 provider cache로 runner/알림 fallback

## 제외 경계

- Claude 코드 삭제
- Claude live 구독 검증 완료 주장
- `codex-usage status --json` 또는 `usage.json` breaking change
- 공식 사용률과 로컬 session token / OTEL 메트릭 혼합
- grok.com 브라우저 쿠키, WKE, 비공식 `/usage` TUI 화면 parser
- 제품별 Chat/Build/Imagine 분해를 기본 UI 완료 조건에 넣기
- Apple Developer Program, Developer ID, notarization, App Group provisioning
- WidgetKit 실제 UI 완료 조건
- 이번 단계에서 README/`ROADMAP.md`/`AGENTS.md` 전체 버전 정렬
- 사용자 명시 요청 없는 GUI 실행, 설치, LaunchAgent 등록, 장시간 테스트, 릴리즈 publish

## 완료 기준

개발 완료:

- 설정 visible mode가 `Codex`와 `Grok`뿐이다.
- Claude source, test, bridge가 저장소에 남아 있다.
- 1번 탭, runner, 알림 source가 같은 선택 provider를 쓴다.
- Grok는 주간 window만 필수이고 5시간을 합성하지 않는다.
- Grok cache는 Codex/Claude 파일과 분리되어 있다.
- token, cookie, session, `auth.json` 원문이 cache/log/fixture에 없다.
- 선택 provider stale/error에서 다른 provider로 fallback하지 않는다.

문서·릴리즈 완료:

- 마지막 단계에서만 README/`ROADMAP.md`/`AGENTS.md`를 맞춘다.
- 실제 GUI/live/설치를 하지 않았다면 `미수행`으로 남긴다.

## 1차 구현 순서

로드맵 Step 1~13을 아래 10개 단위로만 진행한다. 앞 단계가 실패하면 뒤 단계를
시작하지 않는다. Step 14 문서 정렬과 Step 15 GUI·live·release smoke는 1차가 아니다.

| 1차 | 로드맵 Step | 제목 | 상태 |
| --- | --- | --- | --- |
| [01/10] | 1 | 개발 버전 정리 | 완료 |
| [02/10] | 2 | Grok 사용량 원천 spike | 완료 |
| [03/10] | 3~4 | weekly-only 입력 계약과 인증 예외 고정 | 완료 |
| [04/10] | 5 | provider mode와 Claude hide | 완료 |
| [05/10] | 6 | preference migration | 완료 |
| [06/10] | 7 | 알림·러너·refresh 3분기 | 완료 |
| [07/10] | 8 | Grok 전용 cache/history | 완료 |
| [08/10] | 9 | Grok fetch writer | 완료 |
| [09/10] | 10~12 | 1번 탭·러너·알림·주간 그래프 | 완료 |
| [10/10] | 13 | focused test와 계약 스크립트 | 미착수 |

## 권장 착수 단위

한 번에 15번까지 가지 않는다. 아래 묶음으로만 진행한다.

1. `[01/10]` — 이 문서의 개발 버전 정리. 완료.
2. `[02/10]`~`[03/10]` — 원천 spike와 계약. 완료. 구현 PR 전에 닫힌 상태다.
3. `[04/10]`~`[06/10]` — Claude hide와 3분기 routing. 완료.
4. `[07/10]`~`[08/10]` — Grok cache와 writer. 완료.
5. `[09/10]`~`[10/10]` — UI, 러너, 알림, 테스트.
6. Step 14~15 — 문서 정렬과 smoke. 사용자 명시 후에만.

## 모델 추천

모델명은 `AGENTS.md` 2.1의 Grok 기준을 따른다. `5.6 Sol`/`Terra`/`Luna`는 쓰지 않는다.

전체 milestone:

추천 모델: `grok-4.6`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 2 = 8점.
Grok billing 원천이 비공식일 수 있고, 인증 예외와 selected-provider 상태 전이가 겹친다.

단계별:

| 묶음 | 추천 모델 | 추론 수준 | 선정 근거 |
| --- | --- | --- | --- |
| Step 2~4 원천/계약 | `grok-4.6` | 매우 높음 (xhigh) | 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 1 = 7점. 인증 경계 상향 |
| Step 5~7 hide/routing | `grok-4.6` | 높음 (high) | 영향도 1 + 불확실성 1 + 검증 난이도 1 + 변경 범위 2 = 5점. 개발 작업이라 `grok-4.6` |
| Step 8~13 cache/UI/test | `grok-4.6` | 높음 (high) | 영향도 2 + 불확실성 1 + 검증 난이도 2 + 변경 범위 2 = 7점. 정확도 계약 |
| Step 14~15 문서/smoke | `grok-4.5` | 중간 (medium) | 영향도 1 + 불확실성 0 + 검증 난이도 2 + 변경 범위 1 = 4점. live smoke는 별도 승인 |
