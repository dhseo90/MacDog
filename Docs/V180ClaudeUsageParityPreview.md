# v1.8.0 Claude Usage Parity Preview

상태: source·fixture·자동 검증 구현 / live Claude 구독 검수 미수행
작성일: 2026-07-12
대상 버전: `1.8.0`

## 목표

현재 Codex 사용량 기능 중 Claude Code의 공식 데이터 계약으로 표현할 수 있는 기능을
별도 Preview로 구현하고, 실제 Claude 전환 전에 자동 검증과 live 검수 경계를 고정합니다.

Codex와 Claude를 하나의 AI 탭에 통합하는 작업은 `v1.9.0`으로 분리합니다.

## 공식 입력 후보

Claude Code status line command는 JSON을 stdin으로 전달할 수 있고, Claude 구독자에게는
첫 API 응답 이후 `rate_limits.five_hour`와 `rate_limits.seven_day`가 제공될 수 있습니다.

참고:

- <https://code.claude.com/docs/en/statusline>
- <https://support.anthropic.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan>

현재 설치된 Claude Code version에서 실제 필드가 제공되는지는 live capability probe로 별도 확인합니다.
문서 shape만으로 현재 사용자 계정의 live 제공을 완료로 간주하지 않습니다.

## 기능 동등성

| Codex 현재 기능 | Claude Preview 판단 | 비고 |
| --- | --- | --- |
| 5시간 사용률 | 가능 후보 | `rate_limits.five_hour` |
| 주간 사용률 | 가능 후보 | Claude는 `seven_day` |
| reset countdown | 가능 후보 | 각 window의 `resets_at` |
| stale/error | 가능 | 마지막 event 수신 시각 기준 |
| 현재/지난/비교 history | 가능 | Claude 전용 history 필요 |
| pace 예측 | 가능 | 같은 window의 연속 sample 필요 |
| 사용량 알림 | 가능 | event ingest 이후 판정 |
| PNG export | 가능 | provider label 포함 |
| 러너 속도 | 가능 | Preview mode에서만 적용 |
| live poll/manual refresh | 공식 계약 없음 | 새 Claude 응답 후 event-driven 갱신 |
| reset credit | 대응 없음 | Claude에 Codex 동등 계약 없음 |
| 가격 tier 자동 감지 | 지원하지 않음 | 수동 label도 v1.8 필수 아님 |

## Sanitized Bridge

status line JSON 전체를 cache나 log에 저장하지 않습니다.

저장 허용 후보:

- provider id
- 관측 시각
- model 표시명 또는 식별자
- 5시간/7일 사용률
- 5시간/7일 reset 시각

저장 금지:

- `session_id`, `prompt_id`
- `transcript_path`
- `cwd`, `workspace`, repository 정보
- prompt/response 내용
- auth token, cookie, session material, auth header
- raw status line JSON

bridge는 stdin을 decode한 즉시 허용 필드만 새 snapshot으로 만들고 원문을 폐기합니다.

구현된 bridge product는 `macdog-claude-statusline`입니다. status line 입력은 최대 1 MiB까지만
메모리에서 처리하며, stdout에는 sanitize된 provider/사용률 또는 고정 waiting/error 문구만
출력합니다. decode error 원문과 `localizedDescription`은 cache, history, stdout, stderr에 남기지
않습니다.

bridge는 기본 앱 번들의 `Contents/MacOS/macdog-claude-statusline`에 포함됩니다. MacDog 설정은
Claude 설정을 읽지 않으므로 연결 command를 복사해 사용자가 직접 검토하는 방식만 제공합니다.
기존 status line이 없는 경우의 command preview는 다음 shape입니다.

```sh
"/Applications/MacDog.app/Contents/MacOS/macdog-claude-statusline"
```

기존 command가 있으면 자동으로 바꾸지 않습니다. 설정 UI는 기존 command와 bridge를 함께
유지하려면 감사된 stdin fan-out wrapper가 필요하다는 비실행 병합 preview를 보여 줍니다.
v1.8.0 bridge는 raw status line JSON을 임의 shell command에 전달하거나 child stdout을 다시
출력하지 않습니다. 안전한 wrapper가 별도로 준비되지 않았다면 기존 command 유지와 standalone
Preview 연결 중 하나를 사용자가 선택합니다.

```sh
기존 command 보존 + "/Applications/MacDog.app/Contents/MacOS/macdog-claude-statusline" · 감사된 stdin fan-out wrapper 필요
```

MacDog 제거도 Claude 설정을 읽거나 수정하지 않습니다. Preview를 수동 연결했다면 앱을 제거하기
전에 기존 command를 기록하고, 제거 뒤 `statusLine`을 원래 command로 직접 복구해야 합니다.

## 설정 충돌 경계

- Claude Preview는 기본 꺼짐입니다.
- 기존 `~/.claude/settings.json`과 auth store를 자동으로 읽거나 수정하지 않습니다.
- 사용자가 연결을 요청한 경우에도 기존 status line command를 자동 덮어쓰지 않습니다.
- 기존 status line이 있으면 충돌 상태, 병합 가능한 command preview, 수동 복구 절차를 먼저 제시합니다.
- 설정 변경 실제 적용은 사용자 승인과 별도 milestone step을 요구합니다.

## Cache와 UI

- Claude cache/history는 Codex 파일과 별도 경로와 schema를 사용합니다.
- event가 아직 없으면 `연결 대기`, 오래됐으면 `stale`, decode 실패면 sanitized `error`로 표시합니다.
- v1.8.0 기본 제품은 Codex 탭을 유지하고 Claude는 명시적 Preview mode에서만 표시합니다.
- Claude Preview는 5시간/7일, reset, history, pace, 알림, export, runner 반응을 검토합니다.
- Claude live 검수가 없으면 UI에 Preview 상태를 유지합니다.

구현 계약:

- cache: `~/Library/Application Support/MacDog/claude-usage.json`
- history: `~/Library/Application Support/MacDog/claude-usage-history.json`
- ingest lock: `~/Library/Application Support/MacDog/claude-usage.lock`
- event stale 기준: 마지막 정상 사용량 관측 후 15분(900초)
- `lastEventAt`과 `lastUsageObservedAt`을 분리해 `rate_limits`가 없는 정상 event가 오래된
  사용량을 fresh로 바꾸지 않습니다.
- cache/history는 각각 atomic write하고 Claude status line 프로세스 간 append는 전용 file
  lock으로 직렬화합니다.
- Preview는 기본 OFF이며 Codex tab artwork/deep link를 유지합니다. opt-in 상태에서만 기존
  Codex 화면과 `Claude Preview` 화면을 단일-provider picker로 전환합니다. 두 provider를 한
  화면에 합치거나 평균내지 않습니다.
- Claude 화면은 5시간/7일, reset countdown, current/past/compare history, pace, provider label이
  포함된 PNG export를 제공합니다. reset credit은 표시하지 않습니다.
- 러너와 Claude 알림은 각각 별도 opt-in입니다. fresh Claude 사용량만 사용하며 notification
  dedupe key/ledger는 Codex와 분리합니다.

## 검증 기준

자동 검증:

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
swift test --filter ClaudeStatusLineSnapshotTests
swift test --filter ClaudeUsageCacheTests
swift test --filter ClaudeUsagePrivacyTests
swift test --filter UsageMonitorStateTests
swift test --filter PopoverScreenshotRendererTests
```

fixture 범위:

- 5시간/7일 모두 존재
- 5시간만 존재
- 7일만 존재
- `rate_limits` 미제공
- null/unknown field 추가
- 민감정보가 포함된 원문에서 허용 필드만 남는지 확인

live 검수:

1. 실제 Claude 구독 계정으로 Claude Code 응답을 1회 이상 완료합니다.
2. status line bridge가 5시간/7일 snapshot을 받았는지 확인합니다.
3. MacDog Preview가 같은 사용률/reset 시각을 표시하는지 확인합니다.
4. 다음 응답 후 history append와 stale 회복을 확인합니다.

live 검수를 수행하지 않았다면 다음처럼 보고합니다.

```text
Claude Usage Preview 자동 검증 완료
live Claude 구독 검수 미수행
```

2026-07-12 자동 검증 시 로컬 Claude Code version은 `2.1.39`였습니다. 공식 최신 문서에는
`rate_limits`가 있지만 현재 설치본에서 실제 구독 event의 해당 field는 확인하지 못했습니다.
Claude 설정, auth store, Keychain, transcript는 capability 확인을 위해 읽지 않았습니다. 따라서
이 milestone은 source/fixture/자동 검증 경계만 구현 완료이며 live 제품 동등성 완료로 보지 않습니다.

## 제외 범위

- Codex와 Claude 통합 탭
- Claude auth store 또는 transcript 직접 읽기
- raw status line payload 보관
- Claude reset credit 추정
- web/TUI scraping
- Grok/Gemini provider

## 모델 추천

추천 모델: `5.6 Sol`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 2 = 8점. 사용자 status line 설정 충돌, 민감정보 제거, optional payload, live 미검수 경계를 함께 처리해야 합니다.
