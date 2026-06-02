# v1.1.0 보강 항목 검증

상태: read-only/self-test 보강 구현 완료 / 최신 설치본 GUI, Battery Settings, GitHub 서버 상태, live app-server smoke, 장시간 덮개 닫힘 실사용 증거 별도 확인

이 문서는 `ROADMAP.md`의 `v1.1.0` 보강 항목 6개를 완료 증거 경계와 로컬 검증 스크립트에 연결합니다. 자동 self-test와 dry-run은 실제 UI, 장시간 관찰, Shortcuts helper 정상 환경, GitHub 서버 설정 적용을 대체하지 않습니다.

공통 경계:

- GUI 앱 실행, menu bar popover 확인, desktop pet 확인, Battery Settings 화면 확인은 verifier가 수행하지 않으며, 별도 수동/GUI 증거로만 기록합니다.
- 장시간 덮개 닫힘 회귀 검증은 자동으로 수행하지 않습니다. 실제 덮개 닫힘 유지 시간, 전원 상태, `SleepDisabled` before/after, 잠금/슬립 여부를 별도 증거로 기록해야 합니다.
- GitHub 서버 설정 verifier는 변경하지 않습니다. repository public 전환, branch protection `--apply`, GitHub Actions dispatch는 별도 승인 범위입니다. 2026-06-02에는 서버 상태를 읽기 전용으로 확인했습니다.
- 이 문서의 verifier는 live Codex app-server 호출과 `~/.codex/auth.json` 접근을 수행하지 않습니다. protocol drift 점검은 redacted fixture, transport guard, failure guide를 확인합니다.
- 2026-06-02 별도 live smoke는 sandbox 밖에서 제품 JSON만 확인했으며, raw app-server payload, auth token, cookie, session material은 출력하거나 저장하지 않았습니다.
- Apple Developer Program, Developer ID 인증서, notarization credential, App Group provisioning, App Store Connect 권한이 필요한 항목은 v1.1.0 구현 계획에서 제외합니다.

## 1. Shortcuts Charge Limit 입력 계약 확인

목표: Shortcuts helper가 정상 동작하는 환경에서 Charge Limit 액션 이름과 입력 계약을 확인할 수 있게 합니다.

로컬 보강:

- `script/verify_shortcuts_charge_limit.sh --self-test`
- `script/verify_shortcuts_charge_limit.sh --allow-unavailable`
- `script/verify_shortcuts_charge_limit.sh --contract-file <captured-contract.json>`

`--contract-file`은 실제 대상 환경에서 확인한 계약 JSON을 parser-only로 검증합니다. 요구 입력 계약은 정수 또는 숫자 타입이며 허용값은 `80,85,90,95,100`입니다. 이 스크립트는 단축어를 생성, 실행, 수정하지 않습니다.

2026-06-02 실제 환경 확인:

- v1.1.0 최신 설치본 갱신 후 `script/verify_shortcuts_charge_limit.sh --allow-unavailable`를 실행했습니다.
- Shortcuts 앱을 실행해 helper를 깨운 뒤 다시 probe했지만 `/usr/bin/shortcuts list`는 `Error: Couldn’t communicate with a helper application.`으로 실패했습니다.
- 이후 sandbox 밖 사용자 세션에서 `/usr/bin/shortcuts list`를 직접 실행하자 정상 종료했고, `script/verify_shortcuts_charge_limit.sh`도 `shortcuts:available count=0`, `charge-limit-shortcuts:candidates count=0`을 출력했습니다.
- 현재 Shortcuts library가 비어 있어 Charge Limit 후보 단축어/액션 이름과 입력 계약은 캡처하지 못했습니다.
- 단축어 생성, 실행, 수정은 하지 않았고, native Charge Limit read-only 경로가 primary implementation으로 유지되는 것을 확인했습니다.

남은 실제 증거:

- Charge Limit 후보 단축어/액션이 실제로 존재하는 환경에서 후보 이름 확인
- 액션 입력값 전달 방식과 허용값 확인
- 확인한 계약 JSON과 확인자/시각 기록

## 2. native Charge Limit 회귀 진단 강화

목표: macOS 업데이트, 공개 배포 설치본 변경, helper/앱 재설치 이후 native 진단값과 Battery Settings 표시값이 어긋났는지 분리합니다.

로컬 보강:

- `script/verify_charge_limit_regression.sh --self-test`
- `script/verify_charge_limit_regression.sh --read-output-file <captured-read.txt> --expected-current <80|85|90|95|100>`
- `script/verify_charge_limit_regression.sh --allow-unavailable`

실제 read 모드는 `script/verify_charge_limit.sh --read`를 호출하므로 MacDog 진단 모드 실행을 동반합니다. 기본 동작은 native 값을 읽기만 하며 시스템 충전 한도를 변경하지 않습니다.

2026-06-02 실제 회귀 비교:

- v1.1.0 DMG를 Finder drag-and-drop으로 `/Applications/MacDog.app`에 갱신한 뒤 `script/verify_charge_limit_regression.sh --allow-unavailable`를 실행했습니다.
- native read 결과는 `current=90`, `available=80,85,90,95,100`이었고, verifier는 charge limit을 변경하지 않았습니다.
- Battery Settings 화면의 접근성 트리와 화면에서 `충전 중: 89% 90% 한도까지 충전 중`이 확인되어 native current `90`과 표시값이 일치했습니다.

남은 실제 증거:

- 없음. 두 값 불일치가 새로 발생하면 OS 버전, 설치본 freshness, helper 재설치 여부를 별도 기록합니다.

## 3. closed-display 장시간 회귀 검증

목표: macOS 업데이트, helper 재설치, 공개 배포 설치본 변경 뒤 실제 덮개 닫힘 유지 여부를 다시 확인할 수 있게 합니다.

로컬 보강:

- `script/verify_closed_display_regression_plan.sh --self-test`
- `script/verify_closed_display_regression_plan.sh`

이 스크립트는 `pmset -g live`의 `SleepDisabled`와 helper 설치 상태를 읽고 장시간 검증 readiness만 출력합니다. `SleepDisabled`를 바꾸거나 helper를 설치/삭제하거나 덮개를 닫거나 장시간 대기하지 않습니다.

2026-06-02 최신 설치본 변경 후 preflight:

- v1.1.0 DMG를 Finder drag-and-drop으로 `/Applications/MacDog.app`에 갱신한 뒤 `script/verify_closed_display_regression_plan.sh`를 실행했습니다.
- helper는 installed-loaded 상태이고 `/Library/PrivilegedHelperTools/com.dhseo.macdog.helper` code signature가 valid이며 designated requirement를 만족합니다.
- `SleepDisabled` 현재값은 `1`이고, verifier는 `SleepDisabled`, helper install state, screen lock state를 변경하지 않았습니다.
- 사용자는 2026-06-01부터 2026-06-02까지 노트북 덮개를 닫은 상태로 계속 사용했다고 보고했습니다.
- 2026-06-02 22:40 KST 현재 전원 상태는 AC 연결, 배터리 89%, not charging이고 `SleepDisabled=1`입니다.
- `pmset -g log` 기준 2026-06-01 00:00 KST 이후 `Entering Sleep`, `Entering DarkWake`, `Clamshell Sleep`, `Maintenance Sleep` 이벤트 카운트는 `0`입니다.
- 같은 기간 MacDog sleep-prevention assertion 관련 로그는 640라인 확인됐고, 현재 MacDog는 `PreventUserIdleSystemSleep`, `PreventUserIdleDisplaySleep`, `NetworkClientActive` assertion을 유지합니다.
- 2026-06-02 재확인한 preflight도 `ready-for-approved-long-run`이며, helper는 여전히 installed-loaded입니다.

남은 실제 증거:

- 없음. macOS 업데이트, helper 재설치, 공개 설치본 변경, power policy 변경 후에는 같은 방식으로 다시 기록합니다.

## 4. public repo와 branch protection 적용 준비

목표: repo-local 준비물과 dry-run payload를 유지하되, 실제 서버 적용은 GitHub plan/권한이 충족될 때 별도 승인으로만 수행합니다.

로컬 보강:

- `script/verify_public_repo_branch_protection_plan.sh --self-test`
- `script/configure_github_public_repo_settings.sh --dry-run`
- `script/configure_github_branch_protection.sh --dry-run`

검증은 `config/public_repo_policy.json`, `static-gates`, `guardrails`, `CODEOWNERS`, PR template, Dependabot, required check payload를 확인합니다. `--apply`와 public 전환은 실행하지 않습니다.

2026-06-02 실제 서버 상태 확인:

- `script/configure_github_public_repo_settings.sh --check`로 `dhseo90/MacDog`가 `PUBLIC`임을 확인했습니다.
- Actions는 enabled/all, workflow token은 read, PR review approval은 disabled, vulnerability alerts는 enabled, Dependabot security updates는 enabled, public fork PR workflow approval은 `first_time_contributors`로 확인했습니다.
- `gh api repos/dhseo90/MacDog/branches/main/protection`으로 main branch protection을 확인했습니다. required status checks는 `static-gates`, `guardrails`이고 strict mode가 enabled입니다.
- branch protection은 stale review dismissal, code owner review required, required approving review count 1, required conversation resolution enabled, force push/deletion disabled로 확인했습니다.

남은 실제 증거:

- 없음. 단, `script/verify_public_repo_branch_protection_plan.sh` 자체는 서버 설정을 바꾸지 않는 repo-local verifier입니다.

## 5. Codex app-server protocol drift 대응

목표: `account/rateLimits/read` 응답 변화가 생겼을 때 fixture 갱신 기준과 오류 안내 문구를 유지합니다.

로컬 보강:

- `script/verify_codex_app_server_protocol_drift.sh --self-test`
- `swift test --filter 'RateLimitModelsTests|CodexUsageFailureGuideTests|CodexAppServerClientTests'`

검증은 기본 bucket `rateLimitsByLimitId.codex`, 5시간 `300`, 주간 `10080`, 추가 bucket 허용, schema/protocol drift 안내, raw payload/token 비공개 안내를 확인합니다. 또한 현재 Codex CLI가 `app-server proxy`와 daemon control socket을 제공할 수 있음을 감안해, daemon이 실제로 있을 때만 proxy를 우선하고 없으면 legacy `app-server` stdio 경로로 바로 조회하는 transport guard를 확인합니다. verifier는 live app-server를 호출하지 않습니다.

2026-06-02 실제 drift 확인:

- sandbox 내부 live smoke는 `~/.codex` SQLite state runtime 쓰기 제한으로 initialize timeout처럼 실패했습니다. 원인은 sandbox 파일 권한이며 제품 회귀로 단정하지 않습니다.
- sandbox 밖 `.build/debug/codex-usage status --json --timeout 10`은 통과했습니다. 제품 JSON에서 `codex` primary `windowDurationMins=300`, secondary `windowDurationMins=10080`, 추가 bucket `codex_bengalfox`, `planType=pro`, `source=codex-app-server`가 확인됐습니다.
- Codex CLI `0.136.0-alpha.2` schema generator에서 `account/rateLimits/read` 메서드와 `GetAccountRateLimitsResponse`가 유지되는 것을 확인했습니다. 생성 schema는 임시 디렉터리에만 두었고 repo fixture로 저장하지 않았습니다.

남은 실제 증거:

- live 응답 shape이 바뀐 경우 민감정보를 제거한 redacted fixture 갱신
- JSON schema/cache schema/API 해석 변경 여부를 README/ROADMAP/AGENTS와 함께 검토
- auth token, cookie, session material 미포함 확인

## 6. 캐릭터 asset polish 점검

목표: 메뉴바 runner, 플로팅 펫, 탭 버튼이 같은 `Codex Pup` 캐릭터 세트로 보이는지 자동 계약을 강화합니다.

로컬 보강:

- `script/verify_character_asset_polish.sh --self-test`
- `script/verify_character_profile.sh`
- `script/verify_runner_baseline.sh`
- `swift test --filter 'MacDogCharacterProfileTests|PopoverScreenshotRendererTests'`

검증은 runner 8프레임 `80x48`, desktop pet 40프레임 `192x204`, popover tab 5개 `256x256`, 모든 PNG alpha channel, `MacDogCharacterProfile.codexPup` 연결, tab artwork manifest 연결, README 이미지 hygiene/freshness를 확인합니다.

2026-06-02 실제 UI 확인:

- v1.1.0 DMG를 Finder drag-and-drop으로 `/Applications/MacDog.app`에 갱신한 뒤, 설치본이 `dist/MacDog.app`과 일치하는 상태에서 최신 설치본을 실행했습니다.
- 메뉴바 runner, Codex 탭 popover 우측 tab buttons, 설정 탭의 `Codex Pup` 캐릭터 미리보기, 설정 탭 버튼이 같은 강아지 캐릭터 세트로 보이는 것을 확인했습니다.
- `데스크톱 펫 표시`를 잠시 켜서 desktop pet이 같은 캐릭터 세트로 표시되는 것을 확인했고, 확인 뒤 원래처럼 꺼서 `desktopPetEnabled` preference가 남지 않게 복원했습니다.

남은 실제 증거:

- 없음. 단, `script/verify_character_asset_polish.sh` 자체는 여전히 UI를 열지 않는 read-only verifier이므로, verifier 출력의 `ui-not-run`은 자동 검증 경계를 뜻합니다.

## 전체 self-test

아래 명령은 보강 항목 문서 연결과 로컬 self-test만 확인합니다.

```sh
script/verify_v110_reinforcement_plan.sh --self-test
```

이 명령은 GUI 앱 실행, 장시간 덮개 닫힘, GitHub 서버 적용, live app-server 호출, Apple Developer 의존 작업을 수행하지 않습니다.
