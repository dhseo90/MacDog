# 스크립트 참조

이 문서는 `script/*.sh`가 무엇을 하는지 정리합니다. 기본 원칙은 read-only 검증 스크립트와 설치/실행처럼 사용자 환경을 바꾸는 스크립트를 구분하는 것입니다.

## 자주 쓰는 스크립트

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/check.sh` | 표준 로컬 검증 전체 실행 | Swift test, build, packaging dry-run, 일부 상태 조회. 기본 모드는 앱을 실행할 수 있고 `--no-run`은 실행하지 않습니다. |
| `script/build_and_run.sh` | MacDog 앱 번들 빌드와 실행 | `dist/MacDog.app`을 만들고 옵션에 따라 앱을 실행합니다. |
| `script/install.sh` | 개발용 로컬 설치 | `~/Applications/MacDog.app`, `~/bin/codex-usage`, user LaunchAgent, 앱 cache 경로를 만듭니다. helper 설치 옵션은 관리자 권한이 필요합니다. |
| `script/uninstall.sh` | 개발용 로컬 삭제 | 앱, CLI symlink, user LaunchAgent, cache/history 파일을 제거합니다. 기본값은 UserDefaults와 optional helper를 유지합니다. |
| `script/package_release.sh` | GitHub Release 후보 DMG 생성 | `dist/release`에 drag-and-drop 배경이 포함된 DMG 후보와 checksum을 만듭니다. staging 폴더는 검증 후 남기지 않습니다. signing/notarization은 별도 workflow gate입니다. |
| `script/configure_github_public_repo_settings.sh` | GitHub public release 서버 설정 적용 | 기본은 dry-run입니다. `--apply`는 Actions/security 설정을 변경하고, `--make-public`은 추가 확인값이 있을 때만 repo 공개 전환을 수행합니다. |
| `script/configure_github_branch_protection.sh` | GitHub `main` 보호 규칙 적용 | 기본은 dry-run입니다. `--apply`는 GitHub repo 설정을 변경하며 public repo 또는 private branch protection 가능 plan이 필요합니다. |

## 설치/삭제

릴리즈 또는 사용자 설치 검수는 아래 개발용 스크립트로 대체할 수 없습니다. 사용자가 설치하는 그대로 검수해야 하므로, 최종 DMG를 Finder에서 열고 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop한 경우만 사용자 설치 검수로 기록합니다. `install.sh`, 직접 복사, hdiutil mount 후 파일 복사, 숨김 Finder 창/화면 밖 UI 조작은 drag-and-drop 설치 검수의 대체 수단으로 금지합니다.

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/install.sh --dry-run` | 개발용 설치 전 변경 대상 출력 | 파일/LaunchAgent를 바꾸지 않습니다. 사용자 drag-and-drop 설치 검수를 대체하지 않습니다. |
| `script/install.sh` | 개발용 앱, CLI symlink, user LaunchAgent 설치 | 사용자 홈 아래 파일과 LaunchAgent를 변경하고 앱을 실행합니다. 사용자 drag-and-drop 설치 검수를 대체하지 않습니다. |
| `script/install.sh --with-widget` | 개발용 optional WidgetKit 포함 설치 | 기본 설치는 WidgetKit을 제외합니다. 이 옵션을 줄 때만 `.appex`와 shared cache mirror를 포함합니다. 사용자 drag-and-drop 설치 검수를 대체하지 않습니다. |
| `script/install.sh --with-helper` | 개발용 앱 설치와 optional 권한 도우미 설치 | user component와 `/Library/PrivilegedHelperTools`, `/Library/LaunchDaemons`를 변경합니다. 터미널 `sudo` 또는 명시 허용이 필요합니다. 사용자 drag-and-drop 설치 검수를 대체하지 않습니다. |
| `script/install.sh --helper-only` | helper만 설치 | 실행 중인 앱과 user LaunchAgent는 건드리지 않고 `/Library` helper만 변경합니다. |
| `script/uninstall.sh --dry-run` | 삭제 전 변경 대상 출력 | 파일/LaunchAgent를 바꾸지 않습니다. |
| `script/uninstall.sh` | user component 삭제 | 앱, CLI symlink, user LaunchAgent, cache/history 파일을 제거합니다. helper는 유지합니다. |
| `script/uninstall.sh --reset-preferences` | user component 삭제와 설정 초기화 | 앱, CLI symlink, user LaunchAgent, cache/history 파일을 제거하고 MacDog UserDefaults를 초기화합니다. helper는 유지합니다. |
| `script/uninstall.sh --with-helper` | user component와 optional helper 삭제 | user component와 `/Library` helper를 함께 제거합니다. |
| `script/uninstall.sh --helper-only` | helper만 삭제 | 실행 중인 앱과 user LaunchAgent는 건드리지 않고 `/Library` helper만 제거합니다. |

## 앱 빌드와 런타임

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/build_and_run.sh --no-run` | release app bundle만 빌드 | `dist/MacDog.app`을 갱신하고 앱은 실행하지 않습니다. |
| `script/build_and_run.sh` | 빌드 후 앱 실행 | 기존 MacDog 프로세스를 정리하고 새 앱을 실행할 수 있습니다. |
| `script/build_and_run.sh --with-widget` | optional WidgetKit 포함 빌드 | 기본 앱 번들은 WidgetKit을 제외합니다. 이 옵션을 줄 때만 `.appex`를 포함합니다. |
| `script/build_and_run.sh --verify` | 빌드, 실행, 프로세스 확인 | 앱 실행 상태를 확인합니다. |
| `script/build_and_run.sh --verify-runtime 10` | 짧은 CPU/RSS smoke | 앱을 실행하고 지정 초 동안 CPU/RSS를 샘플링합니다. |
| `script/build_and_run.sh --verify-floating-pet-runtime 10` | 플로팅 펫 포함 runtime smoke | 데스크톱 펫을 켠 상태로 CPU/RSS를 샘플링합니다. |
| `script/sample_existing_runtime_resources.sh --samples 5 --interval 1` | 실행 중인 앱 CPU/RSS read-only 샘플링 | 앱을 빌드/실행/종료하지 않고 이미 실행 중인 `MacDog` 프로세스만 읽습니다. |

## 읽기 전용 검증

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/verify_app_bundle.sh` | app bundle 구조 검증 | 지정 앱 번들의 실행 파일, helper, signature 구조를 읽고 기본 번들에 widget extension이 없는지 확인합니다. `--with-widget`은 opt-in `.appex` 포함을 확인합니다. |
| `script/verify_app_privacy_boundaries.sh` | 앱 privacy boundary 검증 | menu bar UI가 live Codex app-server나 shared cache fallback을 직접 열지 않는지 코드 기준으로 확인합니다. |
| `script/verify_autostart_contract.sh` | 로그인 자동 실행 계약 검증 | `loginLaunchEnabled` 설정과 macOS 로그인 항목 등록 규칙을 확인합니다. |
| `script/verify_cache_contract.sh` | cache schema와 stale/error/history 계약 검증 | cache 모델, 주간 잔여량 history, README/AGENTS 용어, token 저장 금지 규칙을 확인합니다. |
| `script/verify_character_profile.sh` | 캐릭터 리소스 계약 검증 | runner, desktop pet, tab artwork manifest와 실제 PNG를 확인합니다. |
| `script/verify_character_asset_polish.sh --self-test` | 캐릭터 asset polish 점검 | 캐릭터 프로필, runner 기준선, README 이미지 hygiene, PNG 크기/alpha 계약을 확인합니다. 실제 UI는 열지 않습니다. |
| `script/verify_codex_app_server_protocol_drift.sh --self-test` | Codex app-server protocol drift guardrail | live app-server를 호출하지 않고 redacted fixture schema, 기본 codex bucket, 5시간/주간 window, failure guide redaction 문구를 확인합니다. |
| `script/verify_dist_hygiene.sh` | dist 산출물 hygiene 검증 | stale app bundle 복사본 같은 혼동 요소를 확인합니다. |
| `script/verify_distribution_gate.sh` | public release gate 검증 | unsigned draft와 signed stable release 문구/워크플로 분리를 확인합니다. |
| `script/verify_install_dry_run.sh` | install/uninstall dry-run 출력 검증 | 설치/삭제 계획 문구와 helper 경계를 확인합니다. |
| `script/verify_public_repo_guardrails.sh` | public repo guardrail 검증 | 필수 문서, CODEOWNERS, Dependabot, Actions 권한, workflow action allowlist, secret/대형 파일/생성 산출물 추적 여부를 확인합니다. |
| `script/verify_readme_screenshots.sh` | README 이미지 hygiene 검증 | README가 참조하는 공식 이미지와 임시 이미지 삭제 상태를 확인합니다. |
| `script/verify_release_workflow.sh` | GitHub release workflow 검증 | release candidate, draft, stable workflow의 gate를 확인합니다. |
| `script/verify_runner_baseline.sh` | 메뉴바 runner 기준선 검증 | runner frame count, size, 상태 mapping을 확인합니다. |
| `script/verify_runtime_contract.sh` | runtime sampling 계약 검증 | runtime smoke 명령과 문서의 연결을 확인합니다. |
| `script/sample_existing_runtime_resources.sh --self-test` | 실행 중 프로세스 sampler 자체검증 | MacDog 실행 여부와 무관하게 sampler 출력/누락 프로세스 처리를 확인합니다. |
| `script/verify_v110_priority_plan.sh --self-test` | v1.1.0 우선 항목 계획 자체검증 | 로드맵의 우선 항목 7개와 수동/외부 증거 경계를 확인합니다. |
| `script/verify_v110_manual_runbook.sh --self-test` | v1.1.0 수동/외부 runbook 자체검증 | 실제 검수를 실행하지 않고 7개 항목의 evidence id, 순서, 기록 명령, 금지 경계를 확인합니다. |
| `script/render_v110_manual_evidence.sh --check` | v1.1.0 증거 ledger 렌더 검증 | `Docs/V110ManualEvidence.json`에서 생성한 Markdown이 `Docs/V110ManualEvidence.md`와 일치하는지 확인합니다. |
| `script/record_v110_manual_evidence.sh --self-test` | v1.1.0 증거 기록기 자체검증 | 실제 검수 없이 임시 ledger에 증거를 기록하고 renderer/verifier 연결을 확인합니다. |
| `script/verify_v110_manual_evidence.sh --allow-incomplete` | v1.1.0 수동/외부 증거 ledger 확인 | 실제 검수를 수행하지 않고 `Docs/V110ManualEvidence.json`과 `Docs/V110ManualEvidence.md`가 미완료 항목을 숨기지 않는지 확인합니다. |
| `script/verify_v110_manual_execution_readiness.sh --allow-incomplete` | v1.1.0 실제 검수 착수 가능 상태 요약 | 실제 실행 없이 7개 항목을 `ready-for-manual-ui`, `blocked`, `external-required`, `ready-for-additional-runtime-sampling`으로 분리해 보여줍니다. |
| `script/verify_v110_reinforcement_plan.sh --self-test` | v1.1.0 보강 항목 계획 자체검증 | Shortcuts 계약, native Charge Limit 회귀, closed-display 장시간 검증, public repo/branch protection, app-server drift, character polish 보강 self-test를 묶어 확인합니다. |
| `script/verify_widget_packaging.sh` | Optional WidgetKit packaging 검증 | Xcode host/extension target을 빌드하고 opt-in `.appex` 산출물을 확인합니다. 기본 설치 검증에는 포함하지 않습니다. |
| `script/verify_widget_readiness.sh` | WidgetKit opt-in readiness 검증 | shared cache, deep link, empty/stale/error 표시 계약과 기본 번들 제외/opt-in 연결 경계를 확인합니다. |
| `script/verify_widget_app_group_signing.sh` | WidgetKit App Group 서명 상태 분류 | installed Widget extension의 code signature와 embedded provisioning profile이 shared cache UI 검수 가능한 App Group grant를 갖는지 읽기 전용으로 분류합니다. |
| `script/verify_widget_manual_ui_plan.sh --self-test` | WidgetKit 수동 UI 검수 계획 자체검증 | live cache를 건드리지 않고 갤러리/클릭/stale/error 수동 검수 계획과 fixture dry-run 경로를 확인합니다. |

## 시스템 상태 조회와 권한 도우미

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/verify_install_state.sh` | 현재 설치 상태 조회 | 설치된 앱, CLI symlink, LaunchAgent, WidgetKit mirror 인자, 실행 중인 앱 경로, payload freshness를 읽습니다. `--explain-current-dist`는 설치본과 `dist/MacDog.app`이 다를 때 변경/추가/삭제 payload 경로를 요약하고, `--self-test`는 이 요약 경로를 fixture로 검증합니다. |
| `script/verify_privileged_helper_state.sh` | helper 설치/로드 상태 조회 | `/Library` helper 파일, LaunchDaemon plist, launchd load 상태를 읽습니다. |
| `script/verify_privileged_helper_xpc.sh` | helper 연결 진단 | 기본은 read-only 조회입니다. `--set 0` 또는 `--set 1`과 `--restore`를 주면 `SleepDisabled` 변경 후 복구합니다. |
| `script/verify_privileged_helper_preflight.sh` | helper 설치 전 안전 점검 | helper dry-run, bundle 상태, 현재 helper 상태, 연결 진단 경로를 묶어 확인합니다. |
| `script/verify_privileged_helper_reinstall_plan.sh` | helper 재설치 전 계획 검증 | helper-only uninstall/install dry-run과 현재 상태를 묶어 실제 승인 전 순서를 확인합니다. |
| `script/verify_charge_limit.sh --read` | 배터리 충전 한도 조회 | native Charge Limit 현재값과 지원 상태를 읽습니다. 쓰기 옵션은 실제 시스템 한도를 바꿀 수 있습니다. |
| `script/verify_charge_limit_regression.sh --self-test` | native Charge Limit 회귀 진단 | captured read 출력과 기대 current 값을 비교하고 Battery Settings 화면 비교는 manual-required로 분리합니다. live read 모드는 진단 앱 실행을 동반하지만 값을 변경하지 않습니다. |
| `script/verify_closed_display_regression_plan.sh --self-test` | closed-display 장시간 회귀 preflight | `pmset -g live`와 helper 상태를 읽어 장시간 검증 readiness를 출력합니다. `SleepDisabled` 변경, helper 설치/삭제, 덮개 닫힘, 장시간 대기는 하지 않습니다. |
| `script/verify_shortcuts_charge_limit.sh` | Shortcuts Charge Limit 후보/입력 계약 확인 | 기본은 read-only probe다. `--self-test`는 fixture 기반 후보 parser와 contract parser를 확인하고, `--contract-file`은 수동 확인한 입력 계약 JSON을 검증합니다. |

## 수동 UI 검수 보조

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/verify_manual_ui_prerequisites.sh` | UI 직접 검수 전 prerequisite gate | 앱 bundle, 캐릭터, privacy boundary, helper preflight, 설치본 freshness를 묶어 확인합니다. WidgetKit은 기본적으로 건너뛰고 `--with-widget`일 때만 확인합니다. |
| `script/verify_widget_manual_ui_plan.sh` | Optional WidgetKit 수동 UI 검수 순서 출력 | `--with-widget` prerequisite를 실행하고, 실제 위젯 갤러리 추가/클릭/stale/error 확인 순서와 shared cache fixture dry-run target을 출력합니다. |
| `script/record_v110_manual_evidence.sh --item <id> --status <status> --evidence <text>` | v1.1.0 수동/외부 검수 증거 기록 | 실제 검수 후 잠금과 후보 검증을 거쳐 `Docs/V110ManualEvidence.json`을 갱신하고 Markdown ledger를 재렌더링합니다. |
| `script/write_widget_cache_fixture.sh --self-test` | widget fixture writer self-test | live cache를 건드리지 않고 fixture writer 동작만 확인합니다. |
| `script/write_widget_cache_fixture.sh --state stale --shared-cache` | widget 수동 검수용 shared cache fixture 작성 | 실제 shared cache에 stale/error/updated fixture를 써서 위젯 표시를 확인할 수 있습니다. |

## 릴리즈 패키징

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/package_release.sh --dry-run` | release packaging 계획 출력 | 파일을 만들지 않고 DMG 구성과 gate를 보여줍니다. |
| `script/package_release.sh --skip-build --no-dmg` | staging 폴더만 생성 | `dist/release/MacDog-<version>`을 만들고 숨김 DMG 배경 이미지를 포함합니다. |
| `script/package_release.sh` | DMG와 checksum 생성 | drag-and-drop 배경이 적용된 `dist/release/MacDog-<version>.dmg`와 `.sha256`을 만듭니다. Finder layout 적용이 실패하면 plain DMG로 대체합니다. |
| `script/verify_release_packaging.sh` | release packaging 구조 검증 | staging payload, Applications symlink, legacy command payload 미포함, release note, checksum, DMG 무결성을 확인합니다. |
| `script/configure_github_public_repo_settings.sh --dry-run` | GitHub public release 서버 설정 계획 출력 | GitHub repo를 변경하지 않고 Actions/security/public/branch protection 적용 순서를 출력합니다. |
| `script/verify_public_repo_branch_protection_plan.sh --self-test` | public repo/branch protection 적용 준비 검증 | GitHub 서버 설정을 바꾸지 않고 public repo policy, guardrail workflow, required checks, branch protection dry-run payload를 확인합니다. |
| `script/configure_github_public_repo_settings.sh --check` | GitHub 서버 설정 조회 | Actions 권한, workflow token 권한, vulnerability alerts, Dependabot security updates, public fork PR approval 상태를 읽습니다. |
| `script/configure_github_public_repo_settings.sh --apply` | GitHub 서버 설정 적용 | Actions/security 설정을 변경합니다. repo가 public이면 fork PR approval과 branch protection도 적용합니다. |
| `script/configure_github_public_repo_settings.sh --apply --make-public` | GitHub public 전환 포함 적용 | `MACDOG_CONFIRM_PUBLIC=MAKE-MACDOG-PUBLIC` 확인값이 있어야 public 전환 후 보호 규칙을 적용합니다. |
| `script/configure_github_branch_protection.sh --dry-run` | PR 보호 규칙 payload 확인 | GitHub repo를 변경하지 않고 적용 대상과 branch protection payload를 출력합니다. |
| `script/configure_github_branch_protection.sh --apply` | PR 보호 규칙 적용 | GitHub `main`에 PR 필수, Code Owners review, `static-gates`/`guardrails` status check, force push/delete 차단, 대화 해결 필수 규칙을 적용합니다. |

## 주의가 필요한 스크립트

- 앱을 실행하거나 종료할 수 있음: `build_and_run.sh`, `check.sh`, `install.sh`
- 이미 실행 중인 앱만 읽음: `sample_existing_runtime_resources.sh`
- 사용자 홈의 앱/LaunchAgent/cache를 바꿈: `install.sh`, `uninstall.sh`, `package_release.sh` staging/DMG 생성
- `/Library` helper를 바꿀 수 있음: `install.sh --with-helper`, `install.sh --helper-only`, `uninstall.sh --with-helper`, `uninstall.sh --helper-only`
- 시스템 배터리 충전 한도를 바꿀 수 있음: `verify_charge_limit.sh`의 쓰기 옵션
- widget live/shared cache를 바꿀 수 있음: `write_widget_cache_fixture.sh --shared-cache`
- GitHub repo 공개/보안/Actions 설정을 바꿀 수 있음: `configure_github_public_repo_settings.sh --apply`
- GitHub repo 설정을 바꿀 수 있음: `configure_github_branch_protection.sh --apply`
