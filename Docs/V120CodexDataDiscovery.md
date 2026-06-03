# v1.2.0 Codex 데이터 탐색 계획

## 목적

v1.2.0은 Codex 사용량 쪽에서 MacDog가 아직 보여주지 않는 안전하고 유용한 데이터가 있는지 확인하는 관문입니다. 첫 구현은 `codex-usage doctor`에 사용량 묶음과 필드 목록을 구조 요약으로 보여주는 고급 진단을 추가하는 것입니다.

이 문서는 `ROADMAP.md`의 v1.2.0 계획을 보조합니다. 세부 설계와 단계별 구현 계획은 아래 문서에 둡니다.

- `Docs/superpowers/specs/2026-06-03-codex-data-discovery-macdog-utility-core-design.md`
- `Docs/superpowers/plans/2026-06-03-codex-data-discovery-plan.md`

## 현재 확인된 Codex 데이터

현재 저장소 고정 예제와 모델에서 확인한 Codex app-server 데이터는 아래 범위입니다.

- 최상위 키: `rateLimits`, `rateLimitsByLimitId`
- 알려진 사용량 묶음: `codex`, `codex_bengalfox`
- 사용량 묶음 필드: `limitId`, `limitName`, `primary`, `secondary`, `credits`, `planType`, `rateLimitReachedType`
- 사용량 창 필드: `usedPercent`, `windowDurationMins`, `resetsAt`
- 크레딧 필드: `hasCredits`, `unlimited`, `balance`

현재로서는 여러 사용량 묶음을 고급 진단에 보여주는 것이 가장 현실적인 확장입니다. 그 외 숨은 필드는 live doctor smoke를 사용자 승인 후 실행했을 때만 확인합니다.

## 구현 범위

v1.2.0 Codex 데이터 탐색 관문에서 구현하는 항목은 다음과 같습니다.

1. JSON-RPC rate limit 응답에서 필드 이름만 추출하는 field inventory 모델을 추가합니다.
2. 민감해 보이는 필드 이름은 redacted placeholder로 대체하고, raw value는 출력하지 않습니다.
3. 기존 app-server client가 같은 응답에서 decoded report와 field inventory를 함께 만들 수 있게 합니다.
4. `codex-usage doctor`에 사용량 묶음 목록과 각 묶음의 필드 목록을 추가합니다.
5. 기본 `codex-usage status --json` 출력과 app-owned cache schema는 변경하지 않습니다.
6. README와 ROADMAP에 doctor 고급 진단 경계를 문서화합니다.

## 제외 범위

아래 항목은 v1.2.0 Codex 데이터 탐색 관문에서 제외합니다.

- Apple Developer Program이 필요한 모든 작업
- Developer ID signing, notarization, stapling
- App Store Connect
- App Group provisioning을 전제로 한 WidgetKit 실제 UI 검수
- 서명된 안정 공개 릴리즈 관문
- SMC 기반 배터리 제어
- 캐릭터 세트 추가
- GUI 앱 실행 또는 screenshot 검수
- 설치 스크립트 실행, LaunchAgent 등록, helper 설치/삭제
- DMG drag-and-drop 설치 검수
- 장시간 `codex-usage status --watch 60` 테스트
- push

## 보안 원칙

- `~/.codex/auth.json`을 읽거나 출력하지 않습니다.
- access token, refresh token, cookie, session id, auth header를 로그, cache, 문서, UI에 남기지 않습니다.
- app-server raw payload를 저장하지 않습니다.
- live 확인을 실행하더라도 구조 요약만 남기고 raw JSON은 보고하지 않습니다.
- 필드 이름이 auth/session/account material처럼 보이면 redacted placeholder로 대체합니다.

## 검증 계획

최소 검증:

```bash
swift test --filter CodexUsageFieldInventoryTests --filter CodexUsageDoctorFormatterTests --filter CodexUsageReportTests --filter RateLimitModelsTests
./script/verify_app_privacy_boundaries.sh
./script/verify_cache_contract.sh
git diff --check
```

변경 폭이 넓거나 app-server client 경계가 크게 바뀌면 추가로 실행합니다.

```bash
swift test --no-parallel
```

live smoke는 사용자가 명시 승인한 경우에만 실행합니다.

```bash
.build/debug/codex-usage doctor
```

실행하지 않은 검증은 완료로 보고하지 않습니다.

## 완료 판정

완료로 볼 수 있는 상태:

- `doctor`가 사용량 묶음과 필드 목록을 구조 요약으로 출력합니다.
- raw app-server payload와 민감정보가 출력되지 않음을 테스트로 확인합니다.
- 기본 `status --json` schema와 cache schema가 변경되지 않습니다.
- Apple Developer 의존 작업이 추가되지 않습니다.

완료로 보지 않는 상태:

- raw JSON만 확인하고 doctor 고급 진단이 구현되지 않은 상태
- live smoke를 실행하지 않았는데 live app-server 검증 완료라고 보고한 상태
- WidgetKit source/test만 확인하고 실제 위젯 UI 검수까지 완료했다고 보고한 상태
- Apple Developer 계정이나 credential이 있다고 전제한 완료 조건이 남아 있는 상태

## 다음 결정

Codex 데이터 탐색 관문이 끝나면 아래 중 하나로 결정합니다.

- 유용한 추가 사용량 묶음/필드가 있으면 고급 Codex UI 또는 CLI debug 옵션을 별도 계획으로 설계합니다.
- 새 데이터가 없거나 의미가 작으면 `MenuBarController`와 `UsagePopoverView`를 작은 책임 단위로 나누는 유틸리티 코어 정리 계획을 작성합니다.

## 2026-06-03 live 결정

2026-06-03에 설치된 `codex-usage doctor`를 실행해 live app-server 구조 요약을 확인했습니다. sandbox 안에서는 app-server 응답 대기 timeout이 발생했지만, sandbox 밖 실행에서는 정상 응답했습니다.

확인된 live 구조:

- 사용량 묶음: `codex`, `codex_bengalfox`
- 두 묶음 모두 같은 field shape:
  - bucket fields: `credits`, `limitId`, `limitName`, `planType`, `primary`, `rateLimitReachedType`, `secondary`
  - primary fields: `resetsAt`, `usedPercent`, `windowDurationMins`
  - secondary fields: `resetsAt`, `usedPercent`, `windowDurationMins`
  - credits fields: `balance`, `hasCredits`, `unlimited`

결정:

- `codex_bengalfox`는 현재 기본 UI에 추가할 만큼 별도 의미가 확인되지 않았습니다.
- 추가 bucket은 `doctor` 고급 진단에 유지하고, 기본 runner 속도 계산, popover 기본 행, cache schema에는 섞지 않습니다.
- 다음 v1.2.0 작업은 유틸리티 코어 정리 계획으로 이동합니다.

후속 문서:

- `Docs/V120UtilityCoreRefactor.md`
- `Docs/superpowers/plans/2026-06-03-macdog-utility-core-refactor-plan.md`
