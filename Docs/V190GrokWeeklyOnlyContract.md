# v1.9.0 Grok weekly-only 입력 계약과 인증 예외

상태: weekly-only 입력 계약 유지 / 인증 예외를 Grok `auth.json` sibling 주기로 확장 /
writer 갱신·쓰기 코드는 후속 / live 인증 조회 미수행
작성일: 2026-08-16
개정일: 2026-08-22
대상 버전: `1.9.0`
기준 문서: [V190GrokUsageAndClaudeHide.md](V190GrokUsageAndClaudeHide.md)
원천 spike: [V190GrokUsageSourceSpike.md](V190GrokUsageSourceSpike.md)

이 문서는 1차 구현 `[03/10]`의 weekly-only 입력 계약과 인증 예외의 현재 기준이다.
1차 `[03/10]`은 읽기 전용 memory-only 예외였다. 이 개정은 Grok CLI와 같은
`~/.grok/auth.json` sibling 주기를 허용한다. writer 갱신·쓰기 코드는 후속 단계에서
만든다. 메뉴바 앱은 auth store를 읽지 않는다.

## 기본 UI 입력

기본 UI가 읽어도 되는 값은 세 개뿐이다.

| 입력 | 계산 | 없으면 |
| --- | --- | --- |
| `usedPercent` | unofficial `creditUsagePercent`를 그대로 쓴다 | weekly 없음 |
| `remainingPercent` | `100 - usedPercent` | 계산하지 않는다 |
| `resetsAt` | unix epoch seconds | `없음`. 합성하지 않는다 |

규칙:

- 5시간 window는 없다. 없으면 `현재 제공되지 않음`이다.
- Extra Usage Credits, Auto Top Up, console prepaid는 입력도 표시도 아니다.
- 제품별 Chat/Build/Imagine/Voice/API 분해는 기본 UI window가 아니다.
- `includedUsed`, `totalUsed`, `$ limit`로 잔여율을 다시 계산하지 않는다.
- 공식 사용률과 로컬 session token / OTEL 메트릭을 섞지 않는다.

`resetsAt`은 spike에서 live 확인하지 못했다. writer가 나중에 주간 reset unix
seconds를 확인하면 그 값만 넣고, 불확실하면 field를 생략한다.
`billingPeriodStart + 7일` 후보는 live 승인 전에는 채택하지 않는다.

## fixture에 넣을 최소 schema

후속 cache 구현이 쓸 최소 sanitize snapshot이다. 원문 billing JSON을 fixture로
복사하지 않는다. 아래 예시는 합성 값이다.

```json
{
  "schemaVersion": 1,
  "source": "unofficial-cli-billing",
  "fetchedAt": 1900000000,
  "lastUsageObservedAt": 1900000000,
  "staleAfterSeconds": 180,
  "weekly": {
    "usedPercent": 42.5,
    "remainingPercent": 57.5,
    "resetsAt": 1900600000
  },
  "issue": null
}
```

허용 key:

- `schemaVersion`
- `source` (`unofficial-cli-billing`만)
- `fetchedAt`, `lastUsageObservedAt`, `staleAfterSeconds`
- `weekly.usedPercent`, `weekly.remainingPercent`, `weekly.resetsAt`
- `issue.code`, `issue.recordedAt`

weekly-only 성공에서 5시간 object를 만들지 않는다. 없으면 생략한다. `null`로
채워 0%처럼 읽히게 하지 않는다.

`resetsAt`을 모르면 weekly object에서 생략한다.

```json
{
  "schemaVersion": 1,
  "source": "unofficial-cli-billing",
  "fetchedAt": 1900000000,
  "lastUsageObservedAt": 1900000000,
  "staleAfterSeconds": 180,
  "weekly": {
    "usedPercent": 42.5,
    "remainingPercent": 57.5
  },
  "issue": null
}
```

weekly 자체가 없으면 성공 snapshot이 아니다.

```json
{
  "schemaVersion": 1,
  "source": "unofficial-cli-billing",
  "fetchedAt": 1900000000,
  "lastUsageObservedAt": null,
  "staleAfterSeconds": 180,
  "issue": {
    "code": "weekly-window-missing",
    "recordedAt": 1900000000
  }
}
```

계획 파일 이름. 이 단계에서는 파일을 만들지 않는다.

| 역할 | 파일 | 기존 파일과 분리 |
| --- | --- | --- |
| Grok snapshot | `grok-usage.json` | `usage.json`, `claude-usage.json` |
| Grok history | `grok-usage-history.json` | Codex/Claude history |
| Grok lock | `grok-usage.lock` | Codex/Claude lock |

권한 계약은 Claude cache와 같다. directory `0700`, file `0600`, atomic write.

## 금지 항목

fixture, cache, history, log, 문서 예시에 아래를 넣지 않는다.

원문·비밀:

- access token, refresh token, cookie, session material, `Authorization` header
- `~/.grok/auth.json` 원문, MCP credential, `XAI_API_KEY` 값
- unofficial billing 원문 응답 전체
- local path, email, user id, team id, account id

주간 pool이 아닌 값:

- `prepaidBalance`, `monthlyLimit`, `onDemandCap`, `onDemandUsed`
- `on_demand_enabled`, Extra Usage Credits, Auto Top Up
- `subscription_tier`로 만든 플랜/용량 예측
- `includedUsed` / `totalUsed`를 잔여율로 환산한 값
- 제품별 Chat/Build/Imagine/Voice/API 사용률 window
- 합성한 5시간 `usedPercent` 또는 `resetsAt`
- OTEL `grok_code.token.usage`
- `x.ai/session/usage` context token

다른 provider:

- Codex `usage.json` sample을 Grok 성공으로 복사
- Claude cache를 Grok fallback으로 읽기

## 인증 예외

Grok weekly 조회는 grok.com session 하나의 `~/.grok/auth.json`만 쓴다.
`macdog-grok-usage`는 Grok CLI sibling이다. 로그인/로그아웃은 `grok login` /
`grok logout`이다. MacDog 전용 토큰 파일과 메모리 단독 세션은 없다.

허용 순서:

1. grok.com access token을 auth store에서 **조회 직전**에만 메모리로 읽는다.
2. 그 token을 CLI-proxy `x.ai/billing` 요청의 `Authorization` header에 즉시 쓴다.
3. access token이 유효하면 refresh 하지 않고 파일을 고치지 않는다.
4. access token이 만료되었거나 billing이 401이면 `auth.json.lock`을 잡는다.
   디스크에 이미 새 값이 있으면 채택한다. 없으면 OIDC `refresh_token`으로 갱신하고
   새 access/refresh를 같은 파일에 atomic merge write한다.
5. 응답에서 allowlist field만 남기고 token과 원문을 버린다.

금지:

- token 출력
- token을 cache, history, log, fixture, 문서에 저장
- raw billing 응답 저장
- 에이전트가 사용자 승인 없이 `~/.grok/auth.json` 원문을 열거나 출력하기
- `XAI_API_KEY`를 SuperGrok 주간 pool 인증으로 사용
- grok.com 브라우저 쿠키 또는 WKE 재사용
- 메뉴바 앱의 auth store 읽기/쓰기
- `auth.json`을 다른 경로에 복사
- Grok 프로세스 존재 여부로 refresh를 분기
- 유효한 access token을 60초마다 refresh

auth store 읽기/갱신/쓰기는 writer의 billing 요청 직전에만 있다. 메뉴바 앱은
auth store를 읽지 않는다. 읽을 수 있는 주체는 `macdog-grok-usage`뿐이다.

## 후속 테스트 항목

`[10/10]` focused test가 고정해야 할 항목이다. 지금 테스트를 추가하지 않는다.

1. sanitize 결과는 fixture 금지 문자열을 포함하지 않는다.
2. Grok cache/history encode 결과에 `Authorization`, `Bearer`, `access_token`,
   `refresh_token`, `cookie` key가 없다.
3. writer 실패 경로가 raw response 또는 auth 원문을 쓰지 않는다.
4. 문서와 fixture에 `~/.grok/auth.json` 내용이 없다.
5. `remainingPercent == 100 - usedPercent`이다.
6. weekly 없는 입력은 5시간 값을 만들지 않는다.
7. Extra/on-demand/prepaid field는 decode 뒤 버려지고 표시 입력에 안 남는다.
8. `resetsAt`이 없으면 합성하지 않고 생략한다.
9. auth store 읽기/갱신/쓰기 경로는 writer의 billing 요청 직전에만 있다.
10. `XAI_API_KEY`만 있는 입력은 weekly 성공이 아니다.
11. Grok stale/error에서 Codex 또는 Claude cache를 읽지 않는다.
12. 유효한 access token에서는 refresh와 `auth.json` write가 없다.
13. 만료/401에서 lock을 못 잡으면 IdP를 부르지 않고 디스크를 다시 읽는다.
14. merge write가 다른 scope와 프로필 field를 지우지 않는다.

이 항목을 구현 전에 바꾸려면 이 문서를 먼저 고친다.
