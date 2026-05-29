# Release Packaging

이 문서는 MacDog를 GitHub Releases에서 내려받아 설치할 수 있는 macOS 배포물로 준비하는 범위를 기록합니다.

## 목표

- 사용자가 GitHub Release에서 `.dmg`를 내려받아 Finder에서 열 수 있게 합니다.
- DMG 안에는 `MacDog.app`과 `Applications` symlink만 넣어 Docker 설치 화면처럼 drag-and-drop 설치 경험을 제공합니다.
- 앱을 `Applications`에서 처음 실행하면 MacDog가 사용자 영역 설치 마무리를 직접 수행합니다.
- optional 권한 도우미 설치/제거는 MacDog UI에서 처리합니다. 권한이 필요하면 MacDog 이름의 관리자 승인창을 띄웁니다.
- 공개 배포 전에는 Developer ID signing, hardened runtime, notarization, stapling, Gatekeeper 검증을 별도 gate로 둡니다.

## 현재 구현 범위

- `script/package_release.sh --dry-run`은 release artifact 계획과 설치 경계를 출력합니다.
- `script/package_release.sh`는 앱 번들 내부 CLI가 포함된 `dist/MacDog.app`을 `dist/release/MacDog-<version>`에 staging합니다.
- staging 폴더에는 `MacDog.app`과 `Applications` symlink만 포함됩니다.
- release note draft는 DMG 안이 아니라 `dist/release/MacDog-<version>-release-notes.md`로 따로 생성됩니다.
- 앱 첫 실행 마무리는 `Applications` 또는 `~/Applications`에 복사된 앱에서만 동작합니다. 개발용 `dist/MacDog.app` 실행에는 적용하지 않습니다.
- 첫 실행 마무리는 `~/bin/codex-usage` symlink, usage cache LaunchAgent, 로그인 자동 실행 LaunchAgent를 사용자 설정에 맞게 설치/복구합니다.
- optional 권한 도우미가 없으면 첫 실행에서 설치 여부를 묻습니다. 사용자가 동의하면 앱 UI가 helper 설치 흐름을 열고, macOS 관리자 승인은 MacDog 주체로 표시됩니다.
- 메뉴바 앱 자동 실행 monitor LaunchAgent는 `loginLaunchEnabled` 설정이 켜져 있을 때만 등록합니다.
- 생성된 `.dmg`는 로컬 검증용 후보이며, 아직 Developer ID signing/notarization을 수행하지 않습니다.
- `.dmg` 생성 시 같은 경로에 `.dmg.sha256` checksum을 함께 만듭니다.
- `.github/workflows/ci.yml`은 PR과 `main` push에서 `./script/check.sh --no-run`을 실행하는 기본 release readiness check입니다.
- `.github/workflows/release-candidate.yml`은 수동 실행으로 unsigned `.dmg` 후보와 checksum을 만들고 GitHub Actions artifact로 보관합니다.
- `.github/workflows/release-draft.yml`은 `UNSIGNED-DRAFT` 확인 입력을 요구한 뒤 unsigned `.dmg`와 checksum을 GitHub draft release에 첨부합니다.
- `.github/workflows/release-stable.yml`은 `SIGNED-STABLE` 확인 입력, GitHub Environment approval, Developer ID Application 인증서 secret, notarization secret이 모두 있어야 signed/notarized `.dmg`를 public GitHub Release로 올립니다.
- `script/verify_release_packaging.sh`는 dry-run 문구, staging payload 구조, Applications symlink, release note draft, legacy command payload 미포함, checksum, DMG 검증을 확인합니다.
- `script/verify_release_workflow.sh`는 workflow가 checksum 검증, unsigned release candidate artifact upload, unsigned draft release gate, signed stable release gate를 포함하는지 확인합니다.
- `script/verify_distribution_gate.sh`는 unsigned `.dmg`가 public stable release로 오해되지 않도록 문서, package dry-run, draft release workflow, future stable release workflow gate를 검증합니다.
- PR 보호 규칙, branch protection, GitHub ruleset 설정은 [GitHubReleaseChecklist.md](GitHubReleaseChecklist.md)에 분리합니다. `script/configure_github_branch_protection.sh --apply`는 repo가 public이거나 private branch protection 가능 plan일 때 적용합니다.

## 확인됨

- `script/package_release.sh --dry-run` 검증 경로가 있습니다.
- `script/package_release.sh --skip-build --no-dmg` staging 검증 경로가 있습니다.
- `script/package_release.sh --skip-build`는 `dist/release/MacDog-<version>.dmg`와 checksum을 생성합니다.
- release workflow는 unsigned draft와 signed stable release gate를 분리합니다.
- optional helper 설치/제거는 앱 UI에서 처리합니다.
- GitHub PR 보호 준비물은 repo 안에 포함되어 있습니다.

## 미확인

- GitHub Actions runner에서 workflow 실제 실행
- GitHub draft release 생성 workflow 실제 실행
- 생성된 `.dmg`를 Finder에서 열어 drag-and-drop 설치 실행
- 깨끗한 사용자 계정/다른 Mac에서 설치, LaunchAgent, Gatekeeper 동작 검증
- MacDog UI의 helper 설치/제거를 signed stable DMG에서 실제 실행

## 아직 하지 않는 것

- Apple Developer ID / notarization secrets 실제 등록
- Developer ID signing 결과물 실제 확인
- notarization 제출과 stapling 실제 수행
- 깨끗한 사용자 계정/다른 Mac에서 Gatekeeper 검증
- App Store 배포 준비
- GitHub repository ruleset 실제 적용. 현재 repo가 private이고 GitHub가 branch protection API를 거절하면 public 전환 또는 plan 변경 전에는 실제 적용할 수 없습니다.

## 배포 흐름 후보

1. `./script/check.sh --no-run`
2. `./script/package_release.sh`
3. 생성된 `dist/release/MacDog-<version>.dmg`를 열어 `MacDog.app`과 `Applications` symlink만 있는지 확인합니다.
4. Finder에서 `MacDog.app`을 `Applications`로 드래그해 설치합니다.
5. `Applications`의 MacDog를 실행하고 첫 실행 마무리가 진행되는지 확인합니다.
6. Codex 사용량 cache, 터미널용 `codex-usage` symlink, usage cache LaunchAgent, 로그인 자동 실행 설정을 확인합니다.
7. optional helper 설치 안내가 MacDog UI로 표시되는지 확인하고, 승인 시 관리자 승인창 주체가 MacDog인지 확인합니다.
8. `shasum -a 256 -c dist/release/MacDog-<version>.dmg.sha256`로 checksum을 확인합니다.
9. 제거 검증이 필요하면 앱 UI에서 optional helper를 먼저 제거하고 앱과 user LaunchAgent/cache를 삭제합니다.
10. unsigned 검증용 GitHub draft release가 필요하면 `Draft Release` workflow를 `UNSIGNED-DRAFT` 확인 입력과 함께 수동 실행합니다.
11. 공개 배포는 GitHub Environment `public-stable-release` 승인을 둔 `Stable Release` workflow에서 `SIGNED-STABLE` 확인 입력과 Apple signing/notarization secrets가 모두 있을 때만 실행합니다.

## GitHub Release 완료 기준

- GitHub Actions 또는 로컬 release script가 `.dmg`를 재현 가능하게 생성합니다.
- `.dmg.sha256` checksum을 함께 제공하고 검증합니다.
- DMG에는 drag-and-drop 설치를 위한 `Applications` symlink가 포함됩니다.
- DMG 안에는 앱 설치에 필요 없는 command 파일이나 임시 안내 파일이 없습니다.
- public stable release는 Developer ID Application으로 app과 DMG를 서명하고, notarytool 제출, stapler, spctl Gatekeeper 확인을 통과합니다.
- Release note에 지원 OS, unsigned/notarized 여부, helper 권한 이유, uninstall 경로를 적습니다.
- `.dmg`를 내려받아 Finder로 설치하는 흐름을 새 사용자 환경에서 검증합니다.
- helper 설치가 포함되는 경우 앱 UI가 `/Library/PrivilegedHelperTools`와 `/Library/LaunchDaemons` 변경을 명확히 안내하고 uninstall 복구를 검증합니다.
