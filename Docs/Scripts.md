# Script Reference

이 문서는 `script/*.sh`가 무엇을 하는지 정리한다. 기본 원칙은 read-only 검증 스크립트와 설치/실행처럼 사용자 환경을 바꾸는 스크립트를 구분하는 것이다.

## 자주 쓰는 스크립트

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/check.sh` | 표준 로컬 검증 전체 실행 | Swift test, build, packaging dry-run, 일부 상태 조회. 기본 모드는 앱을 실행할 수 있고 `--no-run`은 실행하지 않는다. |
| `script/build_and_run.sh` | MacDog 앱 번들 빌드와 실행 | `dist/MacDog.app`을 만들고 옵션에 따라 앱을 실행한다. |
| `script/install.sh` | 개발용 로컬 설치 | `~/Applications/MacDog.app`, `~/bin/codex-usage`, user LaunchAgent, cache 경로를 만든다. helper 설치 옵션은 관리자 권한이 필요하다. |
| `script/uninstall.sh` | 개발용 로컬 삭제 | 앱, CLI symlink, user LaunchAgent, cache 파일을 제거한다. 기본값은 UserDefaults와 optional helper를 유지한다. |
| `script/package_release.sh` | GitHub Release 후보 DMG 생성 | `dist/release`에 drag-and-drop DMG 후보와 checksum을 만든다. staging 폴더는 검증 후 남기지 않는다. signing/notarization은 별도 workflow gate다. |
| `script/configure_github_branch_protection.sh` | GitHub `main` 보호 규칙 적용 | 기본은 dry-run이다. `--apply`는 GitHub repo 설정을 변경하며 public repo 또는 private branch protection 가능 plan이 필요하다. |

## 설치/삭제

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/install.sh --dry-run` | 설치 전 변경 대상 출력 | 파일/LaunchAgent를 바꾸지 않는다. |
| `script/install.sh` | 앱, CLI symlink, user LaunchAgent 설치 | 사용자 홈 아래 파일과 LaunchAgent를 변경하고 앱을 실행한다. |
| `script/install.sh --with-helper` | 앱 설치와 optional 권한 도우미 설치 | user component와 `/Library/PrivilegedHelperTools`, `/Library/LaunchDaemons`를 변경한다. 터미널 `sudo` 또는 명시 허용이 필요하다. |
| `script/install.sh --helper-only` | helper만 설치 | 실행 중인 앱과 user LaunchAgent는 건드리지 않고 `/Library` helper만 변경한다. |
| `script/uninstall.sh --dry-run` | 삭제 전 변경 대상 출력 | 파일/LaunchAgent를 바꾸지 않는다. |
| `script/uninstall.sh` | user component 삭제 | 앱, CLI symlink, user LaunchAgent, cache 파일을 제거한다. helper는 유지한다. |
| `script/uninstall.sh --with-helper` | user component와 optional helper 삭제 | user component와 `/Library` helper를 함께 제거한다. |
| `script/uninstall.sh --helper-only` | helper만 삭제 | 실행 중인 앱과 user LaunchAgent는 건드리지 않고 `/Library` helper만 제거한다. |

## 앱 빌드와 런타임

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/build_and_run.sh --no-run` | release app bundle만 빌드 | `dist/MacDog.app`을 갱신하고 앱은 실행하지 않는다. |
| `script/build_and_run.sh` | 빌드 후 앱 실행 | 기존 MacDog 프로세스를 정리하고 새 앱을 실행할 수 있다. |
| `script/build_and_run.sh --verify` | 빌드, 실행, 프로세스 확인 | 앱 실행 상태를 확인한다. |
| `script/build_and_run.sh --verify-runtime 10` | 짧은 CPU/RSS smoke | 앱을 실행하고 지정 초 동안 CPU/RSS를 샘플링한다. |
| `script/build_and_run.sh --verify-floating-pet-runtime 10` | 플로팅 펫 포함 runtime smoke | 데스크톱 펫을 켠 상태로 CPU/RSS를 샘플링한다. |

## Read-Only 검증

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/verify_app_bundle.sh` | app bundle 구조 검증 | 지정 앱 번들의 실행 파일, helper, widget extension, signature 구조를 읽는다. |
| `script/verify_app_privacy_boundaries.sh` | 앱 privacy boundary 검증 | menu bar UI가 live Codex app-server나 shared cache fallback을 직접 열지 않는지 코드 기준으로 확인한다. |
| `script/verify_autostart_contract.sh` | 로그인 자동 실행 계약 검증 | `loginLaunchEnabled` 설정과 monitor LaunchAgent 생성 규칙을 확인한다. |
| `script/verify_cache_contract.sh` | cache schema와 stale/error 계약 검증 | cache 모델, README/AGENTS 용어, token 저장 금지 규칙을 확인한다. |
| `script/verify_character_profile.sh` | 캐릭터 리소스 계약 검증 | runner, desktop pet, tab artwork manifest와 실제 PNG를 확인한다. |
| `script/verify_dist_hygiene.sh` | dist 산출물 hygiene 검증 | stale app bundle 복사본 같은 혼동 요소를 확인한다. |
| `script/verify_distribution_gate.sh` | public release gate 검증 | unsigned draft와 signed stable release 문구/워크플로 분리를 확인한다. |
| `script/verify_install_dry_run.sh` | install/uninstall dry-run 출력 검증 | 설치/삭제 계획 문구와 helper 경계를 확인한다. |
| `script/verify_readme_screenshots.sh` | README 이미지 hygiene 검증 | README가 참조하는 공식 이미지와 임시 이미지 삭제 상태를 확인한다. |
| `script/verify_release_workflow.sh` | GitHub release workflow 검증 | release candidate, draft, stable workflow의 gate를 확인한다. |
| `script/verify_runner_baseline.sh` | 메뉴바 runner 기준선 검증 | runner frame count, size, 상태 mapping을 확인한다. |
| `script/verify_runtime_contract.sh` | runtime sampling 계약 검증 | runtime smoke 명령과 문서의 연결을 확인한다. |
| `script/verify_widget_packaging.sh` | WidgetKit packaging 검증 | Xcode host/extension target을 빌드하고 `.appex` 포함을 확인한다. |
| `script/verify_widget_readiness.sh` | WidgetKit readiness 검증 | shared cache, deep link, empty/stale/error 표시 계약을 확인한다. |

## 시스템 상태 조회와 권한 도우미

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/verify_install_state.sh` | 현재 설치 상태 조회 | 설치된 앱, CLI symlink, LaunchAgent, 실행 중인 앱 경로, payload freshness를 읽는다. |
| `script/verify_privileged_helper_state.sh` | helper 설치/로드 상태 조회 | `/Library` helper 파일, LaunchDaemon plist, launchd load 상태를 읽는다. |
| `script/verify_privileged_helper_xpc.sh` | helper 연결 진단 | 기본은 read-only 조회다. `--set 0|1 --restore`를 주면 `SleepDisabled` 변경 후 복구한다. |
| `script/verify_privileged_helper_preflight.sh` | helper 설치 전 안전 점검 | helper dry-run, bundle 상태, 현재 helper 상태, 연결 진단 경로를 묶어 확인한다. |
| `script/verify_privileged_helper_reinstall_plan.sh` | helper 재설치 전 계획 검증 | helper-only uninstall/install dry-run과 현재 상태를 묶어 실제 승인 전 순서를 확인한다. |
| `script/verify_charge_limit.sh --read` | 배터리 충전 한도 조회 | native Charge Limit 현재값과 지원 상태를 읽는다. 쓰기 옵션은 실제 시스템 한도를 바꿀 수 있다. |
| `script/verify_shortcuts_charge_limit.sh` | Shortcuts Charge Limit 후보 확인 | 기본은 read-only probe다. `--self-test`는 fixture 기반 parser만 확인한다. |

## 수동 UI 검수 보조

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/verify_manual_ui_prerequisites.sh` | UI 직접 검수 전 prerequisite gate | 앱 bundle, 캐릭터, privacy boundary, widget readiness, helper preflight, 설치본 freshness를 묶어 확인한다. |
| `script/write_widget_cache_fixture.sh --self-test` | widget fixture writer self-test | live cache를 건드리지 않고 fixture writer 동작만 확인한다. |
| `script/write_widget_cache_fixture.sh --state stale --shared-cache` | widget 수동 검수용 shared cache fixture 작성 | 실제 shared cache에 stale/error/updated fixture를 써서 위젯 표시를 확인할 수 있다. |

## Release Packaging

| Script | 의미 | 영향 |
| --- | --- | --- |
| `script/package_release.sh --dry-run` | release packaging 계획 출력 | 파일을 만들지 않고 DMG 구성과 gate를 보여준다. |
| `script/package_release.sh --skip-build --no-dmg` | staging 폴더만 생성 | `dist/release/MacDog-<version>`을 만든다. |
| `script/package_release.sh` | DMG와 checksum 생성 | `dist/release/MacDog-<version>.dmg`와 `.sha256`을 만든다. |
| `script/verify_release_packaging.sh` | release packaging 구조 검증 | staging payload, Applications symlink, command syntax, helper command 제거, `osascript` 승인창 미사용을 확인한다. |
| `script/configure_github_branch_protection.sh --dry-run` | PR 보호 규칙 payload 확인 | GitHub repo를 변경하지 않고 적용 대상과 branch protection payload를 출력한다. |
| `script/configure_github_branch_protection.sh --apply` | PR 보호 규칙 적용 | GitHub `main`에 PR 필수, Code Owners review, `verify` status check, force push/delete 차단, 대화 해결 필수 규칙을 적용한다. |

## 주의가 필요한 스크립트

- 앱을 실행하거나 종료할 수 있음: `build_and_run.sh`, `check.sh`, `install.sh`
- 사용자 홈의 앱/LaunchAgent/cache를 바꿈: `install.sh`, `uninstall.sh`, `package_release.sh` staging/DMG 생성
- `/Library` helper를 바꿀 수 있음: `install.sh --with-helper`, `install.sh --helper-only`, `uninstall.sh --with-helper`, `uninstall.sh --helper-only`
- 시스템 배터리 충전 한도를 바꿀 수 있음: `verify_charge_limit.sh`의 쓰기 옵션
- widget live/shared cache를 바꿀 수 있음: `write_widget_cache_fixture.sh --shared-cache`
- GitHub repo 설정을 바꿀 수 있음: `configure_github_branch_protection.sh --apply`
