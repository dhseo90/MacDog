# v1.6.0 Codex Usage & Reset Credits

상태: publish 완료 / Finder 설치 smoke 완료 / final-state 검증 통과
작성일: 2026-07-05
최종 갱신: 2026-07-06
대상 버전: `1.6.0`

## 목표

v1.6.0은 Codex 탭을 현재 사용량과 사용자 보유 초기화권을 함께 확인하는 화면으로 정리합니다.
첫 탭 이름은 계속 `Codex`로 유지하고, 새 Dashboard 탭은 만들지 않습니다.

## 포함 범위

- 5시간/주간 사용률과 잔여율을 한 번만 표시합니다.
- 사용량 window의 1차 정보는 사용률/잔여율과 reset까지 남은 시간입니다.
- 실제 초기화 시각은 2차 정보로 함께 표시합니다.
- 사용자 보유 초기화권은 5시간권/주간권과 분리해 표시합니다.
- 초기화권은 보유 장수와 각 장의 유효기간을 표시할 수 있는 모델을 둡니다.
- 초기화권 상세 조회가 실패하거나 backend shape가 바뀐 경우에는 장수만 표시하고 유효기간은 갱신 필요 상태로 표시합니다.
- 주간 잔여량 그래프는 보조 정보로 낮춰 Codex 탭 하단에 여유 있게 배치합니다.
- v1.6 focused tests와 verifier를 새 UI 계약에 맞춥니다.

## 제외 범위

- 5시간/주간 사용량을 회복 일정 카드로 중복 표시
- 1시간, 3시간, reset까지 같은 임의 작업 세션 계획
- `codex-usage status --json` schema breaking change
- 기존 app-owned cache와 history 파일 schema breaking change
- raw app-server response 저장
- auth token, refresh token, cookie, session material, auth header 출력 또는 저장
- reset credit 상세 조회 범위를 벗어난 auth store 접근
- `~/.codex/auth.json` 직접 읽기
- 공식 사용량과 로컬 SQLite 추정치 혼합 표시
- 가격 tier 추정
- 새 Dashboard 탭
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning이 필요한 기능
- WidgetKit 실제 UI 완료 조건

## 데이터 계약

1. 사용량 source는 기존 Codex app-server `account/rateLimits/read`입니다.
2. `primary.windowDurationMins = 300`은 5시간 window입니다.
3. `secondary.windowDurationMins = 10080`은 주간 window입니다.
4. 잔여량은 `100 - usedPercent`입니다.
5. `resetsAt`은 Unix epoch seconds이며, 표시 시 로컬 시간대로 변환합니다.
6. 기본 limit bucket은 `rateLimitsByLimitId.codex`입니다.
7. 사용자 초기화권 장수는 `rateLimitResetCredits.availableCount`에서 읽습니다.
8. 각 초기화권의 유효기간은 ChatGPT backend reset credit 상세 응답의 `credits[].expires_at`에서 읽습니다.
9. cache와 JSON에는 장별 `expiresAt`, `status`, `resetType`만 저장하고 reset credit id/title/description은 저장하지 않습니다.

## 공개 구현 참고

공개 오픈소스 `junhoyeo/tokscale`는 ChatGPT backend의 `wham/rate-limit-reset-credits` 상세 응답에서 `available_count`와 `credits[].expires_at`을 읽습니다.
MacDog도 같은 상세 응답을 사용하되, access token은 `codex-usage` 프로세스 메모리에서만 backend `Authorization` header에 사용합니다.
Codex app-server가 `account/chatgptAuthTokens/refresh`를 지원하면 그 경로를 우선 사용하고, 현재 런타임처럼 해당 method가 없으면 Codex auth store를 reset credit 상세 요청 직전에만 읽습니다.

## 완료 기준

- Codex 탭에는 5시간/주간 사용량 게이지가 각각 한 번만 표시됩니다.
- Codex 탭에 회복 일정 카드와 1시간/3시간/session plan UI가 없습니다.
- 사용량 게이지는 reset까지 남은 시간을 먼저 보여주고 실제 초기화 시각은 보조로 보여줍니다.
- 초기화권 영역은 보유 장수와 각 장의 유효기간을 표시합니다.
- 초기화권 상세 조회 결과는 sanitize되어 cache/JSON에 `expiresAt`, `status`, `resetType`만 남습니다.
- `CreditsSnapshot`의 balance를 초기화권 장수로 오해하지 않습니다.
- `status --json`과 기존 cache/history schema가 breaking change 없이 유지됩니다.
- 실제 UI 확인을 하지 않았다면 `UI 확인 미수행`으로 보고합니다.

## v1.6.0 검증 결과

- Published DMG 기준 `/Applications/MacDog.app` 설치 smoke에서 Codex 탭을 직접 확인했습니다.
- Codex 탭은 5시간/주간 사용량을 각각 한 번씩 표시했고, 회복 일정 카드와 1시간/3시간/session plan UI는 없었습니다.
- 사용자 초기화권은 `3장`으로 표시됐고, 장별 유효기간 `7/18 09:34`, `7/27 08:47`, `8/1 04:07`이 표시됐습니다.
- 설치본 CLI `codex-usage status --write-cache --timeout 20` 출력에서 `Reset credits: 3 available`과 세 장의 만료일을 확인했습니다.
- `./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage`가 `usage-fetch:success`로 통과했습니다.
- `./script/verify_release_final_state.sh --version 1.6.0`이 통과했습니다.
