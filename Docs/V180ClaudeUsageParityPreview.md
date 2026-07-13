# v1.8.0 선택형 Codex/Claude 사용량 mode와 안정화

상태: backend sanitizer/cache/history, v1.7 제거·페이스메이커, 단일 provider preference migration,
설정·1번 탭·러너·알림·Codex refresh routing, Claude 잔여율·empty state와 release bridge gate 구현 /
Codex weekly-only partial·5시간 복구 구현 / 전체 Swift test·Xcode Debug build·`check.sh --no-run`
재검증 완료 / live·설치·GUI·release 검증 전
작성일: 2026-07-13
대상 버전: `1.8.0`

## 목표

사용자는 설정에서 `Codex` 또는 `Claude` 중 하나만 현재 사용량 provider로 선택합니다. 1번 탭,
menu bar runner, 로컬 사용량 알림은 선택한 provider만 사용합니다. 두 provider 동시 사용,
합산·비교, 통합 pressure, 자동 fallback은 구현하지 않습니다.

v1.8.0은 다음 범위를 한 milestone에서 완료합니다.

1. v1.7.0 과도 plan transition 기능 제거와 페이스메이커 단순화
2. 단일 provider mode와 preference migration
3. Claude 공식 사용량 source 연결
4. Codex 5시간 window 미제공 시 weekly-only partial 호환
5. 실제 Claude 구독 live smoke
6. GUI·설치·패키징·published DMG release smoke

## 단일 provider UI

설정 탭에는 다음 한 항목만 둡니다.

```text
사용량 mode    Codex ▾
```

- 값은 `Codex` 또는 `Claude`입니다.
- 기본값과 기존 사용자 migration은 `Codex`입니다.
- 별도 `Claude Preview 사용`, Claude runner, Claude 알림 toggle을 만들지 않습니다.
- 1번 탭 안에 provider picker를 중복 제공하지 않습니다.
- 선택 provider가 stale/error이면 다른 provider로 자동 fallback하지 않습니다.
- runner와 기존 사용량 알림은 선택 provider를 자동으로 따릅니다.
- Codex usage cache LaunchAgent는 Codex mode에서만 실행하고 Claude mode에서는 unload·제거합니다.

Claude mode에 sanitized cache가 없으면 1번 탭에 최소 empty state만 표시합니다.

```text
Claude 연결 필요
status line 연결 후 첫 응답부터 사용량이 표시됩니다.
[연결 명령 복사]
```

MacDog는 Claude settings를 읽거나 자동 수정하지 않습니다. 연결과 기존 status line 복구는 사용자가
직접 검토해 수행합니다.

## Claude 공식 입력 계약

Claude Code status line JSON에서 사용하는 subscription field:

- `rate_limits.five_hour.used_percentage`
- `rate_limits.five_hour.resets_at`
- `rate_limits.seven_day.used_percentage`
- `rate_limits.seven_day.resets_at`

잔여율은 `100 - used_percentage`로 계산합니다. 각 window는 독립적으로 없을 수 있고 첫 API 응답
전에는 `rate_limits`가 없을 수 있습니다.

`context_window.total_input_tokens`, `total_output_tokens`, `context_window_size`, used/remaining
percentage는 현재 대화 context 정보입니다. subscription plan의 절대 token quota로 표현하지
않습니다.

Claude에는 Codex reset credit과 동등한 공식 status line field가 없습니다. 5시간/7일 reset
시각은 표시하지만 reset credit을 합성하지 않습니다. `/usage`의 대화형 화면을 비공식 parser로
자동화하지 않습니다.

## 보존할 구현

- `ClaudeStatusLineSnapshot` allowlist sanitizer
- 최대 입력 크기와 chunked stdin 처리
- `macdog-claude-statusline` bridge의 고정·sanitize stdout
- Claude 전용 cache/history/lock과 atomic write
- `0700` directory, `0600` cache/history/lock 권한
- missing/partial/available/stale/error와 복구 상태
- window별 freshness를 적용해 만료 window의 과거 값을 현재 사용량으로 표시하지 않는 경계
- 5시간/7일 history, reset 경계, selected-provider pace
- raw JSON, token, cookie, session, transcript, cwd, repository 미저장 privacy fixture
- UI에서 사용하지 않는 model id/display name 미저장과 legacy cache key decode 호환
- app bundle, uninstall, packaging verifier의 bridge 경계

Codex와 Claude cache는 mode를 전환했다 돌아올 수 있고 schema가 다르므로 계속 분리합니다. 분리된
저장은 동시 사용을 의미하지 않으며 선택하지 않은 provider cache는 runner·알림에서 평가하지
않습니다.

Codex는 주간 window를 성공의 필수 기준으로 유지하고 5시간 window는 optional로 처리합니다.
weekly-only 응답은 오류가 아니며 기존 schema version 1 안에서 5시간 field를 생략합니다. 이전
5시간 값을 cache에 병합하거나 0%로 합성하지 않고, 주간 history·runner·알림은 계속 갱신합니다.
5시간 window가 복구되면 보존한 history 파일에 새 sample을 append하고 표시·pace를 자동 재개합니다.

## 제거할 구현

- 설정 탭 `플랜 전환` section
- 설정 탭 상세 `Claude Usage Preview` section
- `Claude Preview 사용`, Claude runner, Claude notification 별도 preference
- tab 내부 segmented provider picker와 Preview enable 상태
- Codex/Claude 동시 pressure와 `max(Codex, Claude)`
- 두 provider notification 병렬 평가
- 선택하지 않은 provider로 fallback하는 동작
- plan scenario·epoch·P50/P90·relative capacity·reserve UI와 export 범례

## 페이스메이커

- Codex 5시간 history는 `planEpochID` 의존만 제거하고 단기 pace에 재사용합니다.
- Codex weekly history와 reset-window `dailyEndSamples`로 day 목표와 누적 pace를 계산합니다.
- Codex weekly-only이면 주간 페이스메이커만 유지하고 5시간 pace를 `계산 중`으로 오인 표시하지 않습니다.
- Claude 5시간/7일 history는 같은 window 내부 sample로 pace를 계산합니다.
- 알림 dedupe key에는 provider를 남기되 선택 provider candidate만 생성합니다.
- source sample이 부족하면 초과를 추정하거나 알림하지 않습니다.

## privacy 경계

- Claude settings, auth store, Keychain, transcript를 읽지 않습니다.
- status line 원문을 cache, history, stdout, stderr, fixture, 문서에 저장하지 않습니다.
- auth token, cookie, session material, local path를 저장하거나 출력하지 않습니다.
- bridge는 raw input을 임의 shell command나 child stdout으로 전달하지 않습니다.
- 기존 Codex `status --json`과 cache schema version은 유지하되 5시간 optional app-server 응답을
  정상 partial로 수용합니다.

## 개발 완료 기준

- v1.7 plan transition source/UI/write path가 제거되고 legacy 파일은 자동 삭제되지 않습니다.
- 5시간 history는 epoch 없이 단기 pace에 재사용됩니다.
- 설정에는 provider mode 한 항목만 존재합니다.
- 1번 탭, runner, notification source가 항상 같은 선택 provider를 사용합니다.
- Claude subscription quota와 context token을 혼합하지 않고 reset credit을 합성하지 않습니다.
- Codex/Claude mode, cache 없음, partial, stale, malformed, 복구를 fixture와 focused test로 검증합니다.
- Codex weekly-only cache/UI/runner/notification과 5시간 window 복구를 fixture와 focused test로 검증합니다.

## 안정화·release 완료 기준

- 전체 `swift test`, Xcode Debug build, release bundle/packaging 검증 통과
- 실제 Claude 구독 첫 API 응답 뒤 5시간/7일 `rate_limits`와 reset 경계 확인
- 앱 재시작, cold start, mode migration, stale/error/복구 반복 검증
- 실제 menu bar runner, 1번 탭, 설정 mode selector, popover placement GUI 확인
- published DMG 재다운로드 checksum과 `hdiutil verify` 통과
- Finder drag-and-drop 설치, 설치본 executable/cache/CLI 확인
- cleanup과 `verify_release_final_state.sh --version 1.8.0` 통과
- 실행하지 않은 live/GUI/설치 검증은 `미수행`으로 분리 보고

WidgetKit은 기본 DMG 완료 조건에서 제외하고 기존 opt-in source/test 경계만 유지합니다.
Apple Developer Program이 필요한 stable workflow는 별도 승인 전 실행하지 않습니다.

## 개발 계약 검증

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v170_codex_pacemaker_contract.sh --self-test
./script/verify_v180_selected_provider_contract.sh --self-test
```

## 모델 추천

추천 모델: `5.6 Sol`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 2 = 8점. legacy 호환,
selected-provider 상태 전이, Claude privacy/live source, GUI·설치·release 검증을 함께 다룹니다.
