# GitHub 릴리즈 체크리스트

이 문서는 GitHub에서 MacDog를 공개 배포하기 전에 레포 설정과 release 절차를 확인하기 위한 체크리스트입니다. 레포 안의 파일만으로 `main` 직접 push를 완전히 막을 수는 없으므로, branch protection 또는 repository ruleset은 GitHub 설정에서 별도로 적용해야 합니다.

## 저장소 규칙

MacDog는 `main` 직접 push를 막고 PR 검토를 거쳐 병합하는 운영을 목표로 합니다. 레포에 포함된 준비물은 다음과 같습니다.

- `.github/workflows/ci.yml`: PR과 `main` push에서 `MACDOG_APP_VERSION=9.9.9 ./script/check.sh --no-run`을 실행합니다.
- `.github/workflows/public-repo-guardrails.yml`: public repo 전환 전/후 artifact, secret, workflow 권한, 필수 문서 guardrail을 검사합니다.
- `.github/CODEOWNERS`: 전체 파일의 기본 reviewer를 지정합니다.
- `.github/pull_request_template.md`: 검증/미검증 항목을 PR에 남기게 합니다.
- `.github/dependabot.yml`: GitHub Actions dependency update PR을 주 단위로 만듭니다.
- `SECURITY.md`: 취약점/민감정보 보고 기준을 고정합니다.
- `config/public_repo_policy.json`: public repo 서버 설정 목표값을 기록합니다.
- `script/configure_github_public_repo_settings.sh`: Actions/security/public 전환/branch protection 적용 순서를 자동화합니다.
- `script/configure_github_branch_protection.sh`: GitHub branch protection을 재현 가능하게 적용합니다.

주의: GitHub Free의 private repository에서는 branch protection/ruleset API가 거절될 수 있습니다. 이 경우 public 전환 또는 GitHub Pro/Team 조건이 먼저 필요합니다.

`main` 보호 권장값:

- Require a pull request before merging
- Require approvals before merge
- Require review from Code Owners
- Require status checks before merge
- Block force pushes
- Block branch deletion
- Require conversation resolution before merge

권장 status check:

- GitHub Actions: `static-gates`
- GitHub Actions: `guardrails`
- local equivalent: `MACDOG_APP_VERSION=<version> ./script/check.sh --no-run`
- release workflow 변경 시: `script/verify_release_workflow.sh`
- packaging 변경 시: `script/verify_release_packaging.sh`
- README 이미지 변경 시: `script/verify_readme_screenshots.sh`

권장 Actions 설정:

- Actions enabled
- default workflow permissions: read
- Actions can approve or create pull request reviews: off
- public 전환 후 fork pull request workflow approval: first-time contributors require approval

권장 security 설정:

- vulnerability alerts: on
- Dependabot security updates: on
- secret scanning: public/security feature availability에 맞춰 on

적용 명령:

```sh
script/configure_github_public_repo_settings.sh --dry-run
script/configure_github_public_repo_settings.sh --check
script/configure_github_public_repo_settings.sh --apply
script/configure_github_branch_protection.sh --dry-run
script/configure_github_branch_protection.sh --apply
```

public 전환까지 한 번에 실행하려면 별도 확인값이 필요합니다.

```sh
MACDOG_CONFIRM_PUBLIC=MAKE-MACDOG-PUBLIC script/configure_github_public_repo_settings.sh --apply --make-public
```

Branch protection `--apply`는 GitHub에서 CI workflow가 한 번 보인 뒤 실행합니다. repo가 private이고 현재 plan에서 branch protection을 지원하지 않으면 스크립트가 중단하고 public 전환 또는 plan 변경을 안내합니다.

## PR 운영

- `.github/pull_request_template.md`의 Verification 항목을 채웁니다.
- 실행하지 않은 검증은 삭제하지 말고 미실행 사유를 적습니다.
- 설치, LaunchAgent, helper, 배터리 충전 한도처럼 사용자 환경을 바꾸는 검증은 실제 실행 여부를 분리해서 씁니다.
- README 스크린샷을 갱신한 경우 임시 이미지가 남지 않았고 README renderer 산출물과 커밋 이미지가 일치하는지 로컬 `script/verify_readme_screenshots.sh`로 확인합니다. GitHub Actions는 runner별 SwiftUI PNG rasterization 차이를 피하기 위해 렌더 산출물과 이미지 크기까지 확인하며, byte 일치가 필요하면 `MACDOG_README_SCREENSHOT_STRICT=1`을 사용합니다.

## 릴리즈 초안

unsigned 검증 후보:

```sh
MACDOG_RELEASE_VERSION=<version> ./script/check.sh --no-run
MACDOG_RELEASE_VERSION=<version> ./script/package_release.sh
hdiutil verify dist/release/MacDog-<version>.dmg
shasum -a 256 -c dist/release/MacDog-<version>.dmg.sha256
```

GitHub Release를 만들기 전 release tag는 최신 release head에 대해 signed annotated tag로 먼저 생성하고 push합니다. GitHub에서 tag가 `Verified`로 표시되지 않으면 release draft를 만들거나 publish하지 않습니다. `gh release create`는 tag가 없을 때 unsigned/lightweight tag를 자동 생성할 수 있으므로 `--verify-tag` 또는 동등한 검증으로 이미 존재하는 signed tag만 사용합니다.

```sh
git tag -s v<version> <release-head>
git push origin v<version>
gh release create v<version> dist/release/MacDog-<version>.dmg dist/release/MacDog-<version>.dmg.sha256 --verify-tag --draft
```

GitHub Actions에서는 `Draft Release` workflow를 `UNSIGNED-DRAFT` 확인 입력과 함께 수동 실행합니다. 이 workflow도 원격에 이미 존재하는 signed/Verified tag만 사용해야 하며, tag를 자동 생성하면 안 됩니다. 이 draft는 외부 사용자를 위한 stable release가 아니라 설치 흐름 확인용입니다.

release smoke가 끝나면 Finder 검색 중복을 막기 위해 아래 순서로 종료 상태를 확인합니다.

```sh
./script/cleanup_release_smoke_state.sh --apply
./script/verify_release_final_state.sh --version <version>
```

`verify_release_final_state.sh`는 `/Applications/MacDog.app`의 앱 번들 버전, `~/Applications/MacDog.app` 중복 설치본, stale `~/bin/codex-usage` symlink, stale usage cache LaunchAgent plist/loaded job, `dist/MacDog.app` 빌드 산출물, `/Volumes/MacDog*` 마운트 잔여물을 확인합니다. 이 검증이 실패하면 release smoke를 완료로 기록하지 않습니다.

## 안정 릴리즈

public stable release 전에 필요한 gate:

- repository public 전환 또는 private branch protection 가능 plan 확인
- `main` branch protection 적용
- release tag가 최신 release head를 가리키는 signed annotated tag이고 GitHub에서 `Verified`로 표시됨
- Developer ID Application signing
- hardened runtime
- notarization
- stapling
- `spctl` Gatekeeper 검증
- 깨끗한 사용자 계정 또는 다른 Mac에서 DMG drag-and-drop 설치 검수
- 앱 설정 탭의 optional 권한 도우미 설치/제거 검수

`Stable Release` workflow는 `SIGNED-STABLE` 확인 입력, GitHub Environment approval, Apple signing/notarization secrets가 모두 있을 때만 public release로 진행합니다.
