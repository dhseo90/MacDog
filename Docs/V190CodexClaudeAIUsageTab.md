# v1.9.0 Codex + Claude AI Usage Tab

상태: 로드맵 확정 / 개발 전
작성일: 2026-07-12
대상 버전: `1.9.0`

## 목표

1번 탭을 `AI 사용량`으로 전환하고 Codex와 Claude 사용량을 같은 화면에서 확인합니다.
각 provider의 공식 한도와 history는 분리하며 하나의 잔여량으로 합산하지 않습니다.

지원 provider는 Codex와 Claude 두 개로 고정합니다.
Grok, Gemini, 기타 provider는 현재 제품 로드맵에 포함하지 않습니다.

## Provider 경계

| Provider | 표시 범위 | 전용 범위 |
| --- | --- | --- |
| Codex | 5시간, 주간, reset, history, pace, 알림 | reset credit, app-server health |
| Claude | 5시간, 7일, reset, history, pace, 알림 | status line bridge health, Preview/live 검수 상태 |

두 provider는 같은 `usedPercent` 단위를 사용할 수 있지만 한도량과 과금 계약이 다릅니다.
따라서 합계, 평균, `통합 잔여량`을 계산하지 않습니다.

## 1번 탭 Migration

- 사용자 표시명은 `Codex`에서 `AI 사용량`으로 변경합니다.
- 기존 `MacDogPopoverModule.codex` raw preference와 deep link는 migration 또는 alias로 보존합니다.
- Codex-only cache를 읽는 기존 설치본과 새 앱 사이에 breaking migration을 만들지 않습니다.
- tab artwork와 `codex-pup-tab-art.json` manifest 변경이 필요하면 character profile 검증을 함께 갱신합니다.
- 기본 캐릭터 `Codex Pup`과 menu bar/desktop pet sprite 세트는 유지합니다.

## UI 구조

상단 통합 summary:

- 가장 높은 pressure provider
- 가장 먼저 reset되는 provider/window
- provider별 data health 요약
- Claude Preview 상태가 남아 있으면 명시적 Preview badge

provider section:

- Codex: 5시간/주간, reset credit, history control
- Claude: 5시간/7일, history control
- provider가 unavailable이면 다른 provider section을 숨기거나 실패시키지 않습니다.

## Runner와 알림

기본 runner pressure:

```text
pressure = max(codexPressure, claudePressure)
```

설정에서 `최대`, `Codex`, `Claude` 기준을 선택할 수 있습니다.
선택한 provider가 unavailable이면 다른 provider로 조용히 바꾸지 않고 상태를 표시합니다.

알림 dedupe key는 provider, window, reset 경계, 이벤트 종류를 포함합니다.
알림 제목과 본문에는 provider를 명시합니다.

## CLI와 Cache

- 기존 `codex-usage` 명령과 JSON/cache contract를 유지합니다.
- 공통 조회가 필요하면 별도 `macdog-usage` executable과 새 schema를 추가합니다.
- 공통 CLI 후보:

```text
macdog-usage status --provider codex
macdog-usage status --provider claude
macdog-usage status --provider all
```

- `--provider all`은 provider별 snapshot 배열을 반환하며 합산 잔여량을 만들지 않습니다.
- provider별 raw payload, auth/session material, local transcript/repository path는 저장하지 않습니다.

## 검증 기준

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_character_profile.sh
swift test --filter MacDogCharacterProfileTests
swift test --filter UsageMonitorStateTests
swift test --filter UsageNotificationPolicyTests
swift test --filter PopoverScreenshotRendererTests
```

fixture/UI 상태 조합:

- Codex-only
- Claude-only
- Codex + Claude 정상
- Codex stale + Claude 정상
- Codex 정상 + Claude stale/error
- 두 provider 모두 unavailable
- Claude Preview/live 검수 미수행

실제 앱에서는 AI 탭, provider section, runner 기준, provider별 알림을 직접 확인합니다.
GUI를 열어보지 않았다면 UI 검수 완료로 보고하지 않습니다.

## 제외 범위

- Grok, Gemini, 기타 provider
- provider plugin marketplace 또는 임의 provider 등록 UI
- provider 사용률 합계/평균과 `통합 잔여량`
- provider 또는 모델 자동 실행/전환
- auth store, transcript, raw provider response 저장
- 기존 Codex JSON/cache/history breaking change

## 모델 추천

추천 모델: `5.6 Sol`
추론 수준: 높음 (high)
선정 근거: 영향도 2 + 불확실성 1 + 검증 난이도 2 + 변경 범위 2 = 7점. 첫 탭, 러너, 알림, cache, CLI, character manifest 경계를 함께 변경합니다.
