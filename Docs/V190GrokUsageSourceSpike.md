# v1.9.0 Grok 사용량 원천 spike

상태: unofficial 원천 조사 완료 / live billing 조회 미수행
작성일: 2026-08-16
대상 버전: `1.9.0`
기준 문서: [V190GrokUsageAndClaudeHide.md](V190GrokUsageAndClaudeHide.md)

이 문서는 1차 구현 `[02/10]`의 완료 기록이다. token, raw auth, 원문 응답은 저장하지
않았다. `~/.grok/auth.json`은 열지 않았고 live billing 요청도 하지 않았다.

계약 등급: **unofficial**. 공개 REST 문서에 Codex급 구독 잔여율 API는 없다.

## 조사 범위

확인한 공개 원문:

- [FAQ - Grok Website / Apps](https://docs.x.ai/grok/faq) Usage & Limits
- [Welcome to Grok](https://docs.x.ai/grok/overview) Plans and usage
- [Rate Limits](https://docs.x.ai/developers/rate-limits) 팀 RPS/TPM
- [Manage Billing](https://docs.x.ai/console/billing) console prepaid / invoiced credit
- Grok Build user guide `~/.grok/docs/user-guide/02-authentication.md`
- Grok Build user guide `~/.grok/docs/user-guide/04-slash-commands.md` `/usage`
- Grok Build user guide `~/.grok/docs/user-guide/24-monitoring-usage.md` 외부 OTEL

확인한 로컬 바이너리:

- `/Users/dhseo/.grok/bin/grok` → `grok-macos-aarch64`
- `strings`로 billing/usage 식별자만 추출했다. auth store, token, raw response는
  읽지 않았다.

확인하지 않은 것:

- live `x.ai/billing` 응답
- Settings → Usage 실제 화면
- CLI TUI `/usage` 실제 렌더
- `XAI_API_KEY` fallback이 weekly pool을 주는지

## 제품 원천 분리

| 원천 | 종류 | v1.9.0 기본 UI | 이유 |
| --- | --- | --- | --- |
| SuperGrok / Grok Build 공유 주간 pool | 구독 잔여율 | 사용 | FAQ가 공식 제품 모델로 고정한다 |
| Settings → Usage 제품별 분해 (API/Build/Chat/Imagine/Voice) | 같은 pool의 표시 분해 | 보류 | 별도 window가 아니다 |
| Extra Usage Credits / Auto Top Up | 주간 포함량 소진 후 유료 연장 | 금지 | Codex 초기화권이 아니다 |
| console.x.ai prepaid / invoiced credit | 선불 API 달러 | 금지 | 구독 잔여율과 다른 계정이다 |
| 팀 RPS/TPM | developer rate limit | 금지 | 잔여율이 아니다 |
| 외부 OTEL `grok_code.token.usage` | 로컬 session token 메트릭 | 금지 | 공식 사용률과 섞으면 안 된다 |
| `x.ai/session/usage` | 현재 session/context 사용 | 금지 | 주간 pool이 아니다 |
| CLI `/usage` TUI 화면 | 사람용 표시 | 금지 | 화면 parser는 제외 경계다 |

FAQ가 고정한 공식 제품 모델:

- 유료 사용량은 제품별 일일 한도가 아니라 **공유 주간 1개 pool**이다.
- 사용량은 **사용한 비율(%)** 로 보여 준다.
- reset은 Settings → Usage의 **주간 reset 날짜와 시각**이다.
- Extra Usage Credits는 주간 포함량을 소진한 뒤에만 쓰이며 기본 잔여율이 아니다.

## 기계가 읽는 경로

공개 문서화된 구독 잔여율 REST는 없다. 기계 경로는 CLI 로그인 기반 billing이며
unofficial이다.

선택한 경로:

```text
grok.com session → CLI-proxy → x.ai/billing
```

근거:

- CLI `/usage`는 TUI 명령이고 alias는 `/cost`다. 기계 출력이 아니다.
- CLI는 `x.ai/billing` method와 `/billing?format=credits` 조회를 쓴다.
- 메시지는 `Billing data requires auth with grok.com. Run \`grok login\``이다.
- `XAI_API_KEY`만 있는 상태는 grok.com session이 아니므로 이 경로의 성공 조건이
  아니다.

쓰지 않는 경로:

- grok.com 브라우저 쿠키, WKE
- `/usage` TUI 화면 OCR/parser
- console.x.ai billing HTML
- OTEL exporter
- `x.ai/session/usage`

## 안정적으로 쓸 unofficial field

아래 이름은 CLI billing 식별자에서 온 후보다. live 응답으로 확인하지 않았다.
기본 UI 입력으로 확정하는 값은 `[03/10]` 계약 문서에서 다시 줄인다.

| unofficial field | 후보 용도 | 기본 UI | 비고 |
| --- | --- | --- | --- |
| `creditUsagePercent` | `usedPercent` | 후보 | FAQ의 사용 비율과 이름이 맞다 |
| `billingPeriodStart` | reset 계산 입력 | 후보 | unix seconds 여부는 live 미확인 |
| `billingCycle` | 주간 여부 확인 | 후보 | `WEEKLY`일 때만 채택. `MONTHLY`는 console 한도로 본다 |
| `currentPeriod` | window 식별 | 보류 | 표시용 원본으로 쓰지 않는다 |
| `includedUsed` / `totalUsed` | 절대량 | 금지 | 달러/credit 단위일 수 있다 |
| `prepaidBalance` | console 선불 | 금지 | SuperGrok 잔여율이 아니다 |
| `monthlyLimit` | console 월 한도 | 금지 | 주간 pool이 아니다 |
| `onDemandCap` / `onDemandUsed` / `on_demand_enabled` | Extra/on-demand | 금지 | 초기화권으로 합성하지 않는다 |
| `subscription_tier` | 플랜 label | 금지 | 가격/용량 예측에 쓰지 않는다 |
| `isUnifiedBillingUser` | 계정 유형 | 금지 | 잔여율 계산에 쓰지 않는다 |
| `history` / `latestHistory` | 원본 history | 금지 | MacDog history는 별도 sanitize 파일만 쓴다 |

TUI 라벨도 같은 분리를 보여 준다.

```text
Weekly limit
Monthly limit
Next reset:
Credits:
Auto topup:
used of $ limit
```

`Weekly limit`과 `Next reset`만 주간 pool 후보다. `Credits`, `Auto topup`,
`used of $ limit`, `Monthly limit`은 console/Extra 쪽이다.

## 사용률 / 잔여율 / reset 계산

기본 UI 계산은 아래만 허용한다. 공식 계약이 아니므로 writer는 이 식을 바꾸고
표시 원본을 섞지 않는다.

```text
usedPercent = creditUsagePercent
remaining   = 100 - usedPercent
```

`resetsAt` 후보:

1. billing 응답에 주간 reset unix seconds가 있으면 그 값만 쓴다.
2. 없으면 `billingCycle`이 주간이고 `billingPeriodStart`가 unix seconds일 때
   `billingPeriodStart + 7일`을 후보로 둔다. live 확인 전에는 채택하지 않는다.
3. 둘 다 없으면 reset을 합성하지 않고 `없음`으로 둔다.

금지 계산:

- `prepaidBalance`나 `$ limit`로 잔여율을 만들지 않는다.
- Extra Usage Credits를 잔여율에 더하지 않는다.
- 제품별 Chat/Build/Imagine 비율을 별도 window 사용률로 쓰지 않는다.
- 5시간 window를 0%나 과거 값으로 만들지 않는다.
- OTEL token count로 사용률을 추정하지 않는다.

## 실패 시 동작

writer와 UI는 아래를 오류/대기로 분리하고 다른 provider로 fallback하지 않는다.

| 상황 | 동작 |
| --- | --- |
| grok.com session 없음 | error. `XAI_API_KEY`로 weekly pool을 대체하지 않는다 |
| billing 요청 실패 / timeout | error. 마지막 성공 cache가 있으면 stale/error를 함께 표시한다 |
| 응답 parse 실패 | error. 원문 응답을 저장하지 않는다 |
| `creditUsagePercent` 없음 | weekly 없음. 성공 cache로 합성하지 않는다 |
| `billingCycle`이 주간이 아님 | weekly-only 입력으로 채택하지 않는다 |
| 5시간 field 없음 | `현재 제공되지 않음`. 정상이다 |
| `usage_pool_exhausted` | 서버 한도 신호일 수 있다. 사용률 100%로 임의 합성하지 않는다 |

## live 확인

미수행.

- `~/.grok/auth.json`을 열지 않았다.
- CLI-proxy billing 요청을 보내지 않았다.
- Settings → Usage 화면을 열지 않았다.

후속 live spike는 사용자 승인 후에만 한다. 승인이 있어도 token과 원문 응답은
저장하지 않고, allowlist field 이름과 계산 결과만 기록한다.

## `[03/10]`으로 넘기는 결론

1. 기본 원천은 unofficial CLI-proxy `x.ai/billing`이다.
2. 기본 UI 입력은 `usedPercent`, `remaining = 100 - usedPercent`, `resetsAt`만이다.
3. 5시간, Extra Credits, console prepaid, 제품별 분해는 계약에서 금지한다.
4. 인증은 grok.com session의 memory-only 예외만 허용한다.
