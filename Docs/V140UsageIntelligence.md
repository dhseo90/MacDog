# v1.4.0 Usage Intelligence

상태: P0 baseline 진행
작성일: 2026-06-25
대상 버전: `1.4.0`

이 문서는 v1.4.0에서 다룰 과거 사용량, 현재 pace 예측, reset window 오버레이, 이미지 export, 대량 로그 처리 기준을 고정합니다.
플랜/가격 tier 인사이트는 현재 조회 경로로 `Pro $100`과 `Pro $200`을 구분할 수 없으므로 v1.4.0 범위에서 제외합니다.

## P0 진행 순서

| 번호 | 이슈 | 완료 경계 |
| --- | --- | --- |
| v1.4.0 (1) | v1.4.0 baseline 정렬 | VERSION/docs/backlog/source roadmap 정렬 |
| v1.4.0 (2) | 플랜 tier 제외 경계 고정 | `Plus`/`Pro $100`/`Pro $200` 구분 불가 확정, raw `planType` 기존 표시만 유지, 가격 tier 추정 금지 문서화 |
| v1.4.0 (3) | reset window history 계약 | `limitId` + `windowDurationMins` + `resetsAt` 기준 최소 history record schema 정의, 기존 `usage.json`/`usage-weekly-history.json` breaking change 금지 |
| v1.4.0 (4) | history store 구현 | 별도 history 파일, atomic write, retention, dedupe, schema migration, token/session/raw response 저장 금지 |
| v1.4.0 (5) | cache writer 축약 append | live fetch/cache writer 성공 시 weekly sample을 reset window history record로 축약 저장 |

P0 이후 범위는 별도 요청이 있을 때만 진행합니다.

## 목표

MacDog가 현재 잔여량을 보여주는 도구를 넘어, 사용자가 "이번 주 사용 속도가 과거와 비교해 어떤지", "reset 전에 어느 정도까지 쓸 것 같은지", "과거 7일 패턴과 현재 흐름이 어떻게 다른지"를 이해하게 합니다.

## 사용자 이슈

1. 과거 reset window별 사용량을 보고 싶습니다.
2. 현재 사용 속도로 reset 전 예상 사용률을 알고 싶습니다.
3. 최근 과거 7일 window와 현재 window를 오버레이해서 비교하고 싶습니다.
4. 각 7일 끝의 사용량과 window final usage를 hover/tap으로 보고 싶습니다.
5. 그래프를 이미지로 저장하거나 공유하고 싶습니다.
6. 대량 로그나 backfill이 필요해도 raw log를 저장하지 않고, 최소 history record가 만들어지는 것을 처리 기준으로 삼고 싶습니다.

## 제외하는 항목

플랜/가격 tier 인사이트는 제외합니다.

검토 결과 현재 잔여량 조회 경로에서 확인된 값은 `Plan: pro`와 raw `planType` 수준입니다.
`individualLimit` 필드는 보이지만 현재 값이 `null`이며, `Pro $100`과 `Pro $200`을 구분할 수 있는 신뢰 가능한 값이 없습니다.
따라서 v1.4.0은 가격 tier를 추정하거나 표시하지 않습니다.

## 데이터 원칙

- 1순위 source는 Codex app-server `account/rateLimits/read`에서 만들어진 기존 `CodexUsageReport`입니다.
- `primary.windowDurationMins = 300`은 5시간 창, `secondary.windowDurationMins = 10080`은 주간 창으로 유지합니다.
- v1.4.0 MVP는 주간 7일 reset window를 1차 대상으로 합니다.
- 기존 `usage.json` cache schema와 `usage-weekly-history.json` v1 파일은 breaking change 없이 유지합니다.
- v1.4.0 과거 데이터는 별도 파일로 저장해 현재 앱/위젯/cache 경계를 보호합니다.
- auth token, refresh token, cookie, session material, auth header, raw app-server response, raw log line은 저장하거나 이미지 metadata에 넣지 않습니다.
- 공식 사용량과 로컬 SQLite 추정치는 섞지 않습니다.

## 최소 History Record

record 단위는 reset window입니다.

```text
key = limitId + windowDurationMins + resetsAt
```

각 record는 그래프와 비교에 필요한 최소 필드만 포함합니다.

| 필드 | 목적 |
| --- | --- |
| `schemaVersion` | history 파일 migration |
| `generatedAt` | 이 요약 record가 생성된 시각 |
| `limitId` | 기본값은 `codex` |
| `windowDurationMins` | v1.4.0 MVP는 `10080` |
| `resetStartAt` | `resetsAt - windowDurationMins * 60` |
| `resetsAt` | reset window 종료 시각 |
| `dailyEndSamples` | day 1-7 끝의 사용률/잔여율 marker |
| `finalUsedPercent` | window 종료 또는 reset 직전 기준 최종 사용률 |
| `finalRemainingPercent` | window 종료 또는 reset 직전 기준 최종 잔여율 |
| `sampleCount` | record 생성에 사용된 축약 sample 수 |
| `source` | `live-cache`, `backfill`, `imported-summary` 중 하나 |

초기 retention은 최근 12개 완료 weekly window와 현재 window를 기본값으로 둡니다.
장기 보관 설정은 v1.4.0 MVP 이후 별도 이슈로 분리합니다.

## Pace 예측

현재 pace 예측은 최근 weekly sample delta를 사용합니다.

- sample이 2개 이상이고 같은 reset window 안에 있을 때만 계산합니다.
- 남은 시간과 현재 변화율로 reset 전 예상 final used percent를 계산합니다.
- 예측값은 공식 한도가 아니라 로컬 추정이므로 UI에서 "예상"으로 표시합니다.
- stale/error cache에서는 예측을 숨기거나 "갱신 필요"로 표시합니다.
- sample이 부족하면 "샘플 대기"로 표시합니다.

## 그래프와 오버레이

현재 주간 그래프는 유지하고, 과거 보기에는 세 모드를 둡니다.

| 모드 | 설명 |
| --- | --- |
| 현재 window | 기존 주간 잔여량 그래프 |
| 과거 window | 선택한 reset window 하나의 7일 그래프 |
| 오버레이 | 여러 reset window를 0-7일 x축에 겹쳐 표시 |

오버레이 규칙:

- x축은 reset 시작을 0일, reset 끝을 7일로 정규화합니다.
- y축은 사용률 또는 잔여율 중 하나를 선택하되, 기본은 기존 UI와 맞춰 잔여율입니다.
- 각 날짜 끝 marker는 day 1-7에 표시합니다.
- window final marker는 reset 직전 또는 마지막 관측 sample로 표시합니다.
- 같은 reset window 안에서 잔여율이 증가하지 않는 기존 정책을 유지합니다.
- hover/tap은 날짜 끝 사용률, 잔여율, reset 종료일, source를 보여줍니다.

## 이미지 Export

사용자는 화면에 보이는 과거 그래프를 PNG 이미지로 export하거나 클립보드에 복사할 수 있습니다.

이미지에는 다음만 포함합니다.

- 앱 이름과 버전
- 그래프 모드
- 선택한 reset window 범위
- 7일 marker와 final usage
- 예상 final usage를 표시 중이면 "예상" 라벨

이미지와 metadata에는 다음을 포함하지 않습니다.

- auth/session material
- raw app-server response
- raw log line
- local file path
- user account 식별자

## 대량 로그 처리 기준

v1.4.0에서 대량 로그 처리는 raw log 분석 기능이 아니라 "v1.4.0 history record 생성" 기능으로 정의합니다.

처리 흐름:

1. 입력 source를 읽습니다.
2. 민감정보가 포함될 수 있는 raw line을 앱 cache나 UI 상태에 보관하지 않습니다.
3. reset window별 최소 요약 record를 생성합니다.
4. UI, 오버레이, image export는 생성된 record만 읽습니다.
5. raw input은 사용자가 별도 파일로 갖고 있더라도 MacDog 저장소에는 복사하지 않습니다.

이 기준을 만족하지 않는 대량 로그 기능은 v1.4.0 범위에 넣지 않습니다.

## 구현 이슈

1. v1.4.0 baseline 정렬로 VERSION, Docs, backlog, source roadmap을 같은 버전/범위로 맞춥니다.
2. 플랜 tier 제외 경계를 문서화하고 제품 표시는 기존 raw `planType` 수준으로만 유지합니다.
3. reset window history record 계약을 별도 schema로 고정합니다.
4. reset window history store를 별도 파일로 구현하고 atomic write, retention, dedupe, schema migration test를 작성합니다.
5. live cache success 후 weekly sample을 reset window record로 축약 append합니다.

## 검증 기준

- `git diff --check`
- `npx --yes markdownlint-cli2@0.22.1`
- `swift test --filter UsageResetHistory`
- `swift test --filter UsagePaceProjection`
- `swift test --filter WeeklyHistory`
- `swift test --filter PopoverScreenshotRendererTests`
- 전체 `swift test`
- macOS 앱 UI 변경이 있으면 Xcode Debug build

실제 popover, image export, hover/tap을 열어보지 않았다면 `UI 확인 미수행`으로 보고합니다.

## v1.4.0 완료 판단

v1.4.0은 다음이 모두 충족될 때 완료로 봅니다.

- 과거 reset window 데이터가 별도 최소 파일로 저장됩니다.
- 현재 pace와 reset 전 예상 final usage가 표시됩니다.
- 사용자가 현재/과거/오버레이 그래프를 볼 수 있습니다.
- 각 7일 끝 사용량과 window final usage를 hover/tap으로 확인할 수 있습니다.
- 표시 그래프를 PNG로 export하거나 복사할 수 있습니다.
- 대량 로그 처리 경로가 raw log 저장 없이 v1.4.0 history record를 생성합니다.
- cache/privacy/JSON 계약에 breaking change가 없습니다.
