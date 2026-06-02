# v1.1.0 보강 항목 검증

상태: read-only/self-test 보강 구현 완료 / 실제 GUI, 장시간 덮개 닫힘, GitHub 서버 적용, live app-server 호출은 미수행

이 문서는 `ROADMAP.md`의 `v1.1.0` 보강 항목 6개를 완료 증거 경계와 로컬 검증 스크립트에 연결합니다. 자동 self-test와 dry-run은 실제 UI, 장시간 관찰, Shortcuts helper 정상 환경, GitHub 서버 설정 적용을 대체하지 않습니다.

공통 경계:

- GUI 앱 실행, menu bar popover 확인, desktop pet 확인, Battery Settings 화면 확인은 이 문서나 verifier가 수행하지 않습니다.
- 장시간 덮개 닫힘 회귀 검증은 자동으로 수행하지 않습니다. 실제 덮개 닫힘 유지 시간, 전원 상태, `SleepDisabled` before/after, 잠금/슬립 여부를 별도 증거로 기록해야 합니다.
- GitHub 서버 설정은 변경하지 않습니다. repository public 전환, branch protection `--apply`, GitHub Actions dispatch, push는 수행하지 않습니다.
- live Codex app-server 호출과 `~/.codex/auth.json` 접근은 수행하지 않습니다. protocol drift 점검은 redacted fixture와 failure guide만 확인합니다.
- Apple Developer Program, Developer ID 인증서, notarization credential, App Group provisioning, App Store Connect 권한이 필요한 항목은 v1.1.0 구현 계획에서 제외합니다.

## 1. Shortcuts Charge Limit 입력 계약 확인

목표: Shortcuts helper가 정상 동작하는 환경에서 Charge Limit 액션 이름과 입력 계약을 확인할 수 있게 합니다.

로컬 보강:

- `script/verify_shortcuts_charge_limit.sh --self-test`
- `script/verify_shortcuts_charge_limit.sh --allow-unavailable`
- `script/verify_shortcuts_charge_limit.sh --contract-file <captured-contract.json>`

`--contract-file`은 실제 대상 환경에서 확인한 계약 JSON을 parser-only로 검증합니다. 요구 입력 계약은 정수 또는 숫자 타입이며 허용값은 `80,85,90,95,100`입니다. 이 스크립트는 단축어를 생성, 실행, 수정하지 않습니다.

남은 실제 증거:

- Shortcuts CLI/helper가 정상인 환경에서 후보 액션 이름 확인
- 액션 입력값 전달 방식과 허용값 확인
- 확인한 계약 JSON과 확인자/시각 기록

## 2. native Charge Limit 회귀 진단 강화

목표: macOS 업데이트, 공개 배포 설치본 변경, helper/앱 재설치 이후 native 진단값과 Battery Settings 표시값이 어긋났는지 분리합니다.

로컬 보강:

- `script/verify_charge_limit_regression.sh --self-test`
- `script/verify_charge_limit_regression.sh --read-output-file <captured-read.txt> --expected-current <80|85|90|95|100>`
- `script/verify_charge_limit_regression.sh --allow-unavailable`

실제 read 모드는 `script/verify_charge_limit.sh --read`를 호출하므로 MacDog 진단 모드 실행을 동반합니다. 기본 동작은 native 값을 읽기만 하며 시스템 충전 한도를 변경하지 않습니다.

남은 실제 증거:

- `charge-limit:read current=<value>` 결과
- Battery Settings 화면의 Charge Limit 표시값 직접 확인
- 두 값 불일치 시 OS 버전, 설치본 freshness, helper 재설치 여부 기록

## 3. closed-display 장시간 회귀 검증

목표: macOS 업데이트, helper 재설치, 공개 배포 설치본 변경 뒤 실제 덮개 닫힘 유지 여부를 다시 확인할 수 있게 합니다.

로컬 보강:

- `script/verify_closed_display_regression_plan.sh --self-test`
- `script/verify_closed_display_regression_plan.sh`

이 스크립트는 `pmset -g live`의 `SleepDisabled`와 helper 설치 상태를 읽고 장시간 검증 readiness만 출력합니다. `SleepDisabled`를 바꾸거나 helper를 설치/삭제하거나 덮개를 닫거나 장시간 대기하지 않습니다.

남은 실제 증거:

- 승인된 환경에서 덮개 닫힘 전 `SleepDisabled`와 helper 상태 기록
- 지정한 장시간 동안 잠금/슬립으로 떨어지지 않았는지 확인
- 재개 후 `SleepDisabled`, 전원 상태, 배터리 상태, 잠금/슬립 결과 기록

## 4. public repo와 branch protection 적용 준비

목표: repo-local 준비물과 dry-run payload를 유지하되, 실제 서버 적용은 GitHub plan/권한이 충족될 때 별도 승인으로만 수행합니다.

로컬 보강:

- `script/verify_public_repo_branch_protection_plan.sh --self-test`
- `script/configure_github_public_repo_settings.sh --dry-run`
- `script/configure_github_branch_protection.sh --dry-run`

검증은 `config/public_repo_policy.json`, `static-gates`, `guardrails`, `CODEOWNERS`, PR template, Dependabot, required check payload를 확인합니다. `--apply`와 public 전환은 실행하지 않습니다.

남은 실제 증거:

- GitHub repository visibility 또는 private branch protection 가능 plan 확인
- 서버 설정 적용 별도 승인
- `static-gates`와 `guardrails`가 GitHub에 표시된 뒤 branch protection 적용 결과 확인

## 5. Codex app-server protocol drift 대응

목표: `account/rateLimits/read` 응답 변화가 생겼을 때 fixture 갱신 기준과 오류 안내 문구를 유지합니다.

로컬 보강:

- `script/verify_codex_app_server_protocol_drift.sh --self-test`
- `swift test --filter 'RateLimitModelsTests|CodexUsageFailureGuideTests'`

검증은 기본 bucket `rateLimitsByLimitId.codex`, 5시간 `300`, 주간 `10080`, 추가 bucket 허용, schema/protocol drift 안내, raw payload/token 비공개 안내를 확인합니다. live app-server는 호출하지 않습니다.

남은 실제 증거:

- live 응답이 바뀐 경우 민감정보를 제거한 redacted fixture 갱신
- JSON schema/cache schema/API 해석 변경 여부를 README/ROADMAP/AGENTS와 함께 검토
- auth token, cookie, session material 미포함 확인

## 6. 캐릭터 asset polish 점검

목표: 메뉴바 runner, 플로팅 펫, 탭 버튼이 같은 `Codex Pup` 캐릭터 세트로 보이는지 자동 계약을 강화합니다.

로컬 보강:

- `script/verify_character_asset_polish.sh --self-test`
- `script/verify_character_profile.sh`
- `script/verify_runner_baseline.sh`
- `swift test --filter 'MacDogCharacterProfileTests|PopoverScreenshotRendererTests'`

검증은 runner 8프레임 `80x48`, desktop pet 40프레임 `192x204`, popover tab 5개 `256x256`, 모든 PNG alpha channel, `MacDogCharacterProfile.codexPup` 연결, tab artwork manifest 연결, README 이미지 hygiene을 확인합니다.

남은 실제 증거:

- 최신 앱에서 menu bar runner, desktop pet, popover tab button, 설정 탭 미리보기 직접 확인
- 직접 확인하지 않은 경우 `UI 확인 미수행`으로 보고

## 전체 self-test

아래 명령은 보강 항목 문서 연결과 로컬 self-test만 확인합니다.

```sh
script/verify_v110_reinforcement_plan.sh --self-test
```

이 명령은 GUI 앱 실행, 장시간 덮개 닫힘, GitHub 서버 적용, live app-server 호출, Apple Developer 의존 작업을 수행하지 않습니다.
