# GitHub Release Checklist

이 문서는 GitHub에서 MacDog를 공개 배포하기 전에 레포 설정과 release 절차를 확인하기 위한 체크리스트다. 레포 안의 파일만으로 `main` 직접 push를 완전히 막을 수는 없으므로, branch protection 또는 repository ruleset은 GitHub 설정에서 별도로 적용해야 한다.

## Repository Rules

MacDog는 `main` 직접 push를 막고 PR 검토를 거쳐 병합하는 운영을 목표로 한다. 레포에 포함된 준비물은 다음과 같다.

- `.github/workflows/ci.yml`: PR과 `main` push에서 `./script/check.sh --no-run`을 실행한다.
- `.github/workflows/public-repo-guardrails.yml`: public repo 전환 전/후 artifact, secret, workflow 권한, 필수 문서 guardrail을 검사한다.
- `.github/CODEOWNERS`: 전체 파일의 기본 reviewer를 지정한다.
- `.github/pull_request_template.md`: 검증/미검증 항목을 PR에 남기게 한다.
- `.github/dependabot.yml`: GitHub Actions dependency update PR을 주 단위로 만든다.
- `SECURITY.md`: 취약점/민감정보 보고 기준을 고정한다.
- `config/public_repo_policy.json`: public repo 서버 설정 목표값을 기록한다.
- `script/configure_github_branch_protection.sh`: GitHub branch protection을 재현 가능하게 적용한다.

주의: GitHub Free의 private repository에서는 branch protection/ruleset API가 거절될 수 있다. 이 경우 public 전환 또는 GitHub Pro/Team 조건이 먼저 필요하다.

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
- local equivalent: `./script/check.sh --no-run`
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
script/configure_github_branch_protection.sh --dry-run
script/configure_github_branch_protection.sh --apply
```

`--apply`는 GitHub에서 CI workflow가 한 번 보인 뒤 실행한다. repo가 private이고 현재 plan에서 branch protection을 지원하지 않으면 스크립트가 중단하고 public 전환 또는 plan 변경을 안내한다.

## PR 운영

- `.github/pull_request_template.md`의 Verification 항목을 채운다.
- 실행하지 않은 검증은 삭제하지 말고 미실행 사유를 적는다.
- 설치, LaunchAgent, helper, 배터리 충전 한도처럼 사용자 환경을 바꾸는 검증은 실제 실행 여부를 분리해서 쓴다.
- README 스크린샷을 갱신한 경우 임시 이미지가 남지 않았는지 `script/verify_readme_screenshots.sh`로 확인한다.

## Release Draft

unsigned 검증 후보:

```sh
./script/check.sh --no-run
./script/package_release.sh
hdiutil verify dist/release/MacDog-0.1.0.dmg
shasum -a 256 -c dist/release/MacDog-0.1.0.dmg.sha256
```

GitHub Actions에서는 `Draft Release` workflow를 `UNSIGNED-DRAFT` 확인 입력과 함께 수동 실행한다. 이 draft는 외부 사용자를 위한 stable release가 아니라 설치 흐름 확인용이다.

## Stable Release

public stable release 전에 필요한 gate:

- repository public 전환 또는 private branch protection 가능 plan 확인
- `main` branch protection 적용
- Developer ID Application signing
- hardened runtime
- notarization
- stapling
- `spctl` Gatekeeper 검증
- 깨끗한 사용자 계정 또는 다른 Mac에서 DMG drag-and-drop 설치 검수
- 앱 설정 탭의 optional 권한 도우미 설치/제거 검수

`Stable Release` workflow는 `SIGNED-STABLE` 확인 입력, GitHub Environment approval, Apple signing/notarization secrets가 모두 있을 때만 public release로 진행한다.
