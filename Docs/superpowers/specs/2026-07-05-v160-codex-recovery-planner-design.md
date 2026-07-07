# v1.6.0 Codex Usage & Reset Credits Redesign

작성일: 2026-07-05
상태: 재작업 구현 완료 / 자동 검증 통과 / release smoke 완료

## 문제

기존 v1.6.0 구현은 5시간/주간 사용량 window를 `회복 일정` 카드와 하단 게이지로 중복 표시했습니다.
또한 사용자 요청의 `리셋권`을 사용자 보유 초기화권이 아니라 rate-limit reset window처럼 해석했고, 공식 데이터에 없는 1시간/3시간 작업 세션 계획을 만들었습니다.

## 결정

Codex 탭의 v1.6.0 컨셉은 `Codex Usage & Reset Credits`입니다.
첫 탭은 계속 `Codex`이며 Dashboard 탭으로 바꾸지 않습니다.

## 정보 구조

1. 상태 요약
2. 데이터 freshness/stale/error 상태
3. 현재 사용량: 5시간, 주간
4. 사용자 초기화권: 보유 장수와 장별 유효기간
5. 보조 그래프: 주간 잔여량 history

## 표시 원칙

- 5시간/주간 사용량은 한 번만 표시합니다.
- reset까지 남은 시간을 주 정보로 둡니다.
- 실제 초기화 시각은 보조 정보로 둡니다.
- 초기화권은 5시간/주간 window와 섞지 않습니다.
- 초기화권 장별 유효기간은 상세 응답의 `expiresAt`만 표시합니다.
- `CreditsSnapshot.balance`는 API credit balance일 수 있으므로 초기화권 장수로 쓰지 않습니다.
- access token은 메모리에서만 backend `Authorization` header에 사용하고 출력/저장하지 않습니다.

## app-server 확인

`codex app-server generate-ts` 기준 `account/rateLimits/read` 응답에는 `rateLimitResetCredits: RateLimitResetCreditsSummary | null`이 포함됩니다.
현재 공개 schema의 `RateLimitResetCreditsSummary`는 `availableCount`만 제공합니다.
공개 `tokscale` 구현은 직접 backend 상세 endpoint에서 `credits[].expires_at`을 읽습니다.
MacDog도 reset credit 상세 endpoint를 호출하되, token은 메모리에서만 사용하고 cache/JSON에는 `expiresAt`, `status`, `resetType`만 저장합니다.

## 폐기

- `CodexUsageResetSchedule`
- `CodexUsageSessionPlan`
- `CodexRecoveryPlannerBlock`
- CLI 텍스트의 `Recovery cards`
- 1시간/3시간/reset까지 작업 세션 picker

## 검증

```sh
git diff --check
swift test --filter RateLimitModelsTests
swift test --filter CodexUsageReportTests
swift test --filter UsageMonitorStateTests
swift test --filter PopoverScreenshotRendererTests
script/verify_v160_codex_recovery_planner_contract.sh --self-test
```
