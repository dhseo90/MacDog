# v1.7.0 Codex 주간 잔여량 페이스메이커

상태: v1.7.0 릴리즈 완료 / 당시 전환 scenario·epoch UI는 과도 구현으로 재분류 /
v1.8.0 개발 브랜치 source·focused test 단순화 완료 / 전체 build·release 검증 전
작성일: 2026-07-12
대상 버전: `1.7.0`

## 바로잡은 제품 목적

v1.7.0의 목적은 특정 가격 플랜의 절대 한도를 예측하는 것이 아니라 현재 활성화된 Codex
주간 window 안에서 사용 속도를 관리하는 것입니다. MacDog가 확인할 수 있는 값은 현재 플랜의
정규화된 사용률과 reset 시각이며 `Pro $100`과 `Pro $200`의 실제 용량 비율은 알 수 없습니다.

따라서 사용자가 현재/목표 플랜 label, 상대 용량, reserve, 전환일을 입력해 `$100 적합성`을
추정하는 기능은 제품 범위에서 제거합니다. 이 문서는 이미 published된 v1.7.0 release를
취소하거나 과거 구현 사실을 숨기지 않고, v1.8.0에서 유지·제거할 경계를 고정합니다.

## 페이스메이커 계약

- weekly window 시작은 `resetsAt - windowDurationMins * 60`입니다.
- 달력 자정이 아니라 window 시작부터 24시간씩 최대 7개 day slot으로 나눕니다.
- 7일 window의 기본 일일 목표는 전체 한도의 `1/7`, 약 `14.3%`입니다.
- 현재 day 사용량은 day 시작 이후 weekly `usedPercent` 증가량입니다.
- day 시작 sample이 없으면 초과를 추정하지 않고 `오늘 기준 계산 중`으로 표시합니다.
- 현재 day 목표까지 남은 비율과 주간 누적 목표 대비 실제 사용량을 함께 표시합니다.
- day 목표 접근·초과와 누적 페이스 초과 알림은 weekly window/day/event별 한 번만 발송합니다.
- 알림은 기존 로컬 사용량 알림 master opt-in을 따릅니다.

## 보존할 데이터 계층

- `usage-weekly-history.json`의 atomic sample과 reset window 분리
- weekly reset-window history의 `dailyEndSamples`
- current/past/compare graph와 day marker
- 5시간 history의 `recordedAt`, `usedPercent`, `resetsAt`, `windowDurationMins`
- 5시간 history의 atomic write, 13주 retention, dense dedupe, logical reset 분리
- corrupt file 처리, migration, 민감정보 미저장 검증

`usage-five-hour-history.json`은 단기 burst와 reset 전 pace에 계속 사용할 가치가 있습니다.
v1.8.0에서는 `planEpochID`를 신규 계산과 UI에서 제거하되 기존 파일 decode 호환을 유지합니다.

## 제거할 기능

- 현재/목표 플랜 label
- 목표 상대 용량과 reserve
- 전환 예정일·확정일
- `planEpochID` 기반 active/target epoch
- 전환 전후 P50/P90/최대와 target epoch 재분류
- Codex 탭 `플랜 전환 준비` block
- 설정 탭 plan transition editor
- graph epoch boundary와 export scenario 범례
- `usage-plan-transition.json` 신규 read/write

기존 `usage-plan-transition.json`은 자동 삭제하지 않습니다. 사용자의 기존 파일을 손상하지 않고
신규 read/write만 중단합니다.

## 제외 경계

- `$100에서도 충분함` 또는 특정 가격 플랜 적합성 판단
- 가격 tier 자동 감지와 원격 가격표 추정
- 공식 사용률과 로컬 token 추정치 혼합
- 자동 플랜 변경 또는 reset credit 사용
- 기존 CLI JSON/cache/history schema breaking change

## v1.8.0 구현 검증 계약

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v170_codex_pacemaker_contract.sh --self-test
```

v1.8.0 개발 브랜치에서는 plan transition source/UI/configuration read·write를 제거했고,
기존 legacy 파일을 읽거나 수정·삭제하지 않습니다. 5시간 history는 과거 `planEpochID`를 decode할
수 있지만 신규 encoding과 logical-window 계산에는 사용하지 않으며 단기 pace에 재사용합니다.
주간 history는 reset 기준 7개 day slot, 일일 `1/7` 목표, sample 부족 상태와 day별 알림을 제공합니다.

## published v1.7.0 기록

- Signed annotated tag: `v1.7.0`, GitHub `Verified`
- Published release head: `9d4c7d610827aa889f6dc9e5845ed4bd0f99ac56`
- Published asset: `MacDog-1.7.0.dmg`, `MacDog-1.7.0.dmg.sha256`
- Published DMG SHA-256: `92fe575cd66fed1c4ee52b6e350b961d27956930cfba98c23adc17d0c7b25a9f`
- published DMG 설치본 UI smoke와 release final-state는 완료했습니다.
- 당시 plan transition UI가 포함됐다는 사실은 유지하지만 후속 제품 방향에서는 제거 대상으로
  분류합니다.

## 모델 추천

추천 모델: `5.6 Sol`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 2 = 8점. published release 기록과
legacy file 호환을 보존하면서 scenario·epoch를 제거하고 5시간/주간 pace로 교체해야 합니다.
