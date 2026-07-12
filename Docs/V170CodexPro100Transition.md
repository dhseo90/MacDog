# v1.7.0 Codex Pro $100 Downgrade Readiness

상태: 로드맵 확정 / 개발 전
작성일: 2026-07-12
대상 버전: `1.7.0`

## 목표

현재 Codex Pro $200 사용 패턴으로 Pro $100 전환 시 한도 부족 가능성을 사전에 판단하고,
전환 이후에는 서로 다른 플랜 epoch의 백분율 history를 분리합니다.

이 기능은 요금제를 자동 판별하거나 OpenAI의 실제 한도량을 역산하지 않습니다.
사용자가 확인한 현재/목표 플랜과 상대 용량을 입력하고, MacDog는 로컬 관측 history에만 적용합니다.

## 사용자 결정 지원

MacDog는 다음 질문에 답하는 것을 목표로 합니다.

1. 현재 5시간 peak를 목표 플랜 상대 용량에 적용하면 100%를 넘는가?
2. 현재 주간 사용 패턴에서 사용자가 원하는 reserve를 유지할 수 있는가?
3. 판단에 필요한 history가 충분한가?
4. 실제 전환 이후 첫 7일 관측이 전환 전 시나리오와 얼마나 다른가?

## 데이터 계약

- 기존 `CodexUsageReport`, `usage.json`, `usage-weekly-history.json`, `usage-reset-window-history.json` schema는 유지합니다.
- 5시간 관측 history와 플랜 epoch/scenario는 별도 파일로 저장합니다.
- 플랜 설정은 사용자가 입력한 label, 전환 시각, 상대 용량, reserve 기준만 저장합니다.
- `planType`, credits, 사용률, reset 시각을 조합해 가격 tier를 추정하지 않습니다.
- raw app-server response, raw log, auth token, cookie, session material, auth header는 저장하지 않습니다.

## 5시간 History

현재 weekly history와 별도로 5시간 window sample을 저장합니다.

최소 필드:

| 필드 | 목적 |
| --- | --- |
| `schemaVersion` | migration |
| `recordedAt` | 관측 시각 |
| `windowDurationMins` | `300` window 확인 |
| `usedPercent` | 공식 app-server 사용률 |
| `resetsAt` | logical window 경계 |
| `planEpochID` | 전환 전후 history 분리 |

retention과 dense sample skip 기준은 실제 구현 단계에서 fixture로 고정합니다.
같은 logical 5시간 window 안에서 sample을 dedupe하고, reset 이후 새 window와 분리합니다.

## 플랜 Scenario

입력값:

- 현재 플랜 label
- 목표 플랜 label
- 목표 플랜 상대 용량
- 전환 예정일 또는 실제 전환일
- reserve 기준

기본 계산:

```text
목표 플랜 예상 사용률 = 현재 플랜 관측 사용률 / 목표 상대 용량
```

계산 결과는 실제 한도가 아니라 `사용자 설정 기반 예상`입니다.
P50, P90, 최대 peak와 reserve 미달/100% 초과 window 수를 표시합니다.
sample 수와 관측 기간이 기준에 미치지 못하면 `관측 부족`을 우선 표시합니다.

## 플랜 Epoch

- 사용자가 전환일을 확정하면 새 `planEpochID`를 시작합니다.
- 전환 전과 전환 후의 같은 사용률을 같은 절대 사용량으로 해석하지 않습니다.
- 그래프는 epoch 경계를 표시하고 기본 비교는 같은 epoch 안에서만 수행합니다.
- 전환 후 첫 7일은 `전환 관측 중` 상태로 두고 예상과 실제의 차이를 표시할 수 있습니다.

## UI 범위

- 첫 탭은 계속 `Codex`입니다.
- 현재 사용량 아래에 compact `플랜 전환 준비` section을 둡니다.
- 설정 탭에서 플랜 label, 상대 용량, reserve, 전환일을 관리합니다.
- reset credit은 기존 영역에 유지하되 목표 플랜 제공량을 추정하지 않습니다.
- PNG export는 공식 사용률과 scenario 값을 시각적으로 구분합니다.

## 제외 범위

- Claude/Grok/Gemini provider 구현
- AI 통합 탭
- 가격 tier 자동 감지와 원격 가격표 자동 갱신
- 자동 플랜 변경 또는 자동 reset credit 사용
- 공식 사용량과 로컬 SQLite 추정치 혼합
- 기존 JSON/cache/history breaking change

## 검증 기준

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
swift test --filter CodexUsageFiveHourHistoryTests
swift test --filter CodexPlanTransitionScenarioTests
swift test --filter UsageMonitorStateTests
swift test --filter PopoverScreenshotRendererTests
```

실제 전환 전후 관측을 수행하지 않았다면 scenario 정확도 또는 Pro $100 적합성 검증 완료로 보고하지 않습니다.

## 모델 추천

추천 모델: `5.6 Sol`
추론 수준: 높음 (high)
선정 근거: 영향도 2 + 불확실성 1 + 검증 난이도 2 + 변경 범위 2 = 7점. 기존 history와 별도 5시간 history, scenario 오차, 플랜 epoch를 함께 보호해야 합니다.
