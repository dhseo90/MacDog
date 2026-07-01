# v1.5.0 Usage Reliability & Diagnostics

상태: P0-P2 구현 완료 / reset boundary 실제 UI smoke 수행 / 릴리즈 smoke 미수행
작성일: 2026-06-29
대상 버전: `1.5.0`

이 문서는 v1.5.0 P0에서 다루는 사용량 reliability, reset boundary, cache/history health, doctor 진단 경계를 고정합니다.
릴리즈 packaging, published DMG smoke, signed tag 검증은 별도 릴리즈 단계에서만 완료로 기록합니다.

## P0 진행 순서

| 번호 | 이슈 | 완료 경계 |
| --- | --- | --- |
| v1.5.0 (1) | v1.5.0 baseline 정렬 | VERSION/docs/backlog/source roadmap 정렬 |
| v1.5.0 (2) | 지난 사용량/reset boundary 그래프 회귀 수정 | weekly reset 이후 새 window와 Codex 탭 `지난` 사용량이 이전 32% marker 뒤로 이어지지 않고, reset-start 기준 partial window를 backfill하며 남은 7일 구간을 비워두고 같은 logical weekly window의 rolling reset timestamp record를 dedupe |
| v1.5.0 (3) | 데이터 계약과 제외 경계 고정 | `status --json`, `usage.json`, `usage-weekly-history.json`, `usage-reset-window-history.json` breaking change 금지 |
| v1.5.0 (4) | usage health 모델 정의 | cache, weekly history, reset-window history를 `ok`, `missing`, `stale`, `error`, `waiting`으로 분리 |
| v1.5.0 (5) | cache/history health reader 구현 | app-owned cache 옆 weekly/reset-window history를 읽고 sample/record 수, 최신 reset, append, retention, pace sample 상태를 진단 |
| v1.5.0 (6) | `codex-usage doctor` 확장 | app-server 접근 결과와 cache/history health, append/retention/pace 상태, 다음 조치 안내를 함께 출력 |
| v1.5.0 (7) | 실패 가이드와 protocol drift 진단 강화 | schema/protocol drift, stale/error cache, raw payload/auth material 금지 문구 유지 |
| v1.5.0 (8) | 검증 스크립트와 fixture 묶음 추가 | `verify_v150_usage_reliability_contract.sh --self-test`로 source guard와 focused Swift tests를 묶음 |
| v1.5.0 (9) | Codex 탭 데이터 상태 UI | cache 최신성, history sample 부족, stale/error, protocol drift 가능성을 compact status로 표시 |
| v1.5.0 (10) | live fetch/cache smoke 진단 정리 | live smoke 성공 시 weekly/reset-window history 요약을 함께 출력 |
| v1.5.0 (11) | 운영 회귀 guard 확장 | runtime sampler, helper state, Charge Limit read-only, release final-state를 release readiness에 연결 |
| v1.5.0 (12) | release readiness 문서화 | `Docs/V150ReleaseReadiness.md`에 자동검증, UI smoke, live fetch smoke, published DMG smoke 경계를 분리 |
| v1.5.0 (13) | README/ROADMAP/Docs closure | README/ROADMAP/Docs/Scripts/check.sh가 v1.5.0 release readiness와 같은 용어를 사용 |

## 사용자 이슈

weekly reset이 오늘 발생한 상태에서 마지막으로 본 주간 사용량이 32%였는데, reset 이후 그래프가 이전 window 뒤쪽까지 이어지고 동일 날짜의 이전 데이터가 여러 개 생성되는 문제가 보고됐습니다.
새 `resetsAt`이 감지되면 이전 history와 새 timeline을 분리하고, 새 window는 왼쪽 100% 잔여율에서 시작해야 합니다.
이 문제는 `지난` 사용량과 비교 그래프가 현재 reset window의 rolling timestamp record를 과거 window로 오인하는 오류와, 공식 `resetsAt`이 아직 미래인 interrupted partial window를 지난 사용량에서 숨기는 오류까지 포함합니다.

## 데이터 원칙

- 1순위 source는 Codex app-server `account/rateLimits/read`에서 만들어진 기존 `CodexUsageReport`입니다.
- `primary.windowDurationMins = 300`은 5시간 창, `secondary.windowDurationMins = 10080`은 주간 창으로 유지합니다.
- `status --json`, `usage.json`, `usage-weekly-history.json`, `usage-reset-window-history.json` schema는 v1.5.0 P0에서 breaking change하지 않습니다.
- `codex_bengalfox` 같은 추가 bucket은 advanced/debug 출력 경계로 남기고 기본 limit bucket은 `codex`입니다.
- auth token, refresh token, cookie, session material, auth header, raw app-server payload는 읽기, 출력, 저장, cache, fixture, 로그에 넣지 않습니다.
- 공식 app-server 잔여 한도와 로컬 SQLite 추정치를 섞지 않습니다.

## Reset Boundary 규칙

- 주간 잔여량 그래프는 같은 `resetsAt` window 안에서 표시 잔여율이 증가하지 않도록 그립니다.
- 그래프 window의 기준은 `resetsAt` 자체가 아니라 `resetStartAt = resetsAt - 7일`입니다.
- OpenAI가 주간 한도를 실제 리셋해 새 reset-start가 관측된 경우 이전 history와 새 timeline을 분리합니다.
- 공식 `resetsAt`이 아직 미래여도 더 새로운 current weekly window가 시작됐으면 이전 sample group은 완료된 interrupted window로 backfill합니다.
- interrupted window는 reset-start 기준 7일 축을 유지하되 마지막 sample 이후부터 7일 끝까지의 남은 구간을 빈 그래프로 둡니다.
- reset 직후 app-server가 rolling reset timestamp를 몇 분 단위로 갱신하는 경우 같은 logical weekly window로 canonicalize하고 record를 하나로 합칩니다.
- 같은 날짜 안에서도 reset start가 충분히 떨어져 있고 잔여율이 새 창처럼 회복된 실제 reset은 별도 past window로 유지합니다.
- 현재 weekly window와 같은 logical reset window의 record는 Codex 탭 `지난` 사용량과 지난 window overlay에서 제외합니다.

## Health 진단

`CodexUsageHealthReader`는 app-owned `usage.json`과 같은 디렉터리의 history 파일을 읽기 전용으로 진단합니다.

| 상태 | 의미 |
| --- | --- |
| `ok` | cache 또는 history가 읽히고 표시 가능한 데이터가 있습니다. |
| `missing` | 파일이 아직 없습니다. |
| `stale` | cache snapshot이 stale window를 넘었습니다. |
| `error` | cache가 error snapshot이거나 파일 decode가 실패했습니다. |
| `waiting` | 파일은 있지만 표시할 report/sample/record가 아직 없습니다. |

`codex-usage doctor`는 cache age, staleAfter, report 유무, weekly sample 수, reset-window record 수, 최신 reset, 다음 조치 안내를 출력합니다.
weekly append는 마지막 cache snapshot의 weekly sample이 history에 저장됐는지, dense unchanged 정책으로 skip된 것으로 볼 수 있는지, 또는 누락됐는지를 분리합니다.
reset-window append는 현재 cache snapshot과 같은 logical weekly reset window record가 있는지 확인합니다.
retention은 `codex`/window duration별 reset-window record 수가 최근 12개 완료 window와 현재 window 기준 13개를 넘는지 확인합니다.
pace는 기존 projection 모델을 재사용해 `projected`, `waitingForSamples`, `stale`, `error`, `unavailable`과 sample 수만 표시합니다.
raw error message, raw app-server response, auth/session material은 doctor health 출력에 포함하지 않습니다.

## 제외 경계

- 실제 GUI smoke, published DMG 설치 smoke, signed tag verification은 v1.5.0 P0 자동 검증 완료 조건이 아닙니다.
- Codex 탭 데이터 상태 UI의 실제 화면 smoke는 Step 20 설치본 UI smoke에서 별도로 확인합니다.
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning, App Store Connect 권한이 필요한 항목은 v1.5.0 P0 완료 조건에 넣지 않습니다.
- WidgetKit 실제 UI 검수는 App Group provisioning 전 완료로 보고하지 않습니다.
- 장시간 watch 테스트는 사용자가 별도로 요청할 때만 실행합니다.

## 검증 기준

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v150_usage_reliability_contract.sh --self-test
swift test --filter UsageResetWindowHistoryTests
swift test --filter ResetWindowOverlayModelTests
swift test --filter UsageMonitorStateTests
swift test --filter CodexUsageCacheTests
swift test --filter CodexUsageDoctorFormatterTests
swift test --filter CodexUsageFailureGuideTests
swift test --filter CodexUsageReportTests
```

기본 `swift`가 Command Line Tools SDK와 맞지 않으면 Xcode toolchain을 명시합니다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test --filter UsageResetWindowHistoryTests --filter ResetWindowOverlayModelTests --filter UsageMonitorStateTests --filter CodexUsageCacheTests --filter CodexUsageDoctorFormatterTests --filter CodexUsageFailureGuideTests --filter CodexUsageReportTests
```

실제 popover, menu bar runner, Widget UI를 열어보지 않았다면 `UI 확인 미수행`으로 보고합니다.
