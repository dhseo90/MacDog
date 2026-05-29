# Release Packaging

이 문서는 MacDog를 GitHub Releases에서 내려받아 설치할 수 있는 macOS 배포물로 준비하는 범위를 기록한다.

## 목표

- 사용자가 GitHub Release에서 `.dmg`를 내려받아 Finder에서 열 수 있게 한다.
- DMG 안에는 `MacDog.app`과 `Applications` symlink를 넣어 표준 drag-and-drop 설치 경험을 제공한다.
- 로컬 검증용으로는 `Install MacDog.command`, `Uninstall MacDog.command`, `Check Install Status.command`를 함께 제공한다.
- optional 권한 도우미 설치/제거는 별도 helper `.command`가 아니라 MacDog 설정 탭에서 처리한다.
- 공개 배포 전에는 Developer ID signing, hardened runtime, notarization, stapling, Gatekeeper 검증을 별도 gate로 둔다.

## 현재 구현 범위

- `script/package_release.sh --dry-run`은 release artifact 계획을 출력한다.
- `script/package_release.sh`는 앱 번들 내부 CLI가 포함된 `dist/MacDog.app`을 `dist/release/MacDog-<version>`에 staging한다.
- staging 폴더에는 `MacDog.app`, `Applications` symlink, `Install MacDog.command`, `Uninstall MacDog.command`, `Check Install Status.command`, `README_FIRST.txt`, `RELEASE_NOTES_DRAFT.md`가 포함된다.
- `Install MacDog.command`는 로컬 검증용 full install 경로다. 더블클릭하면 사용자 영역에 앱, 앱 번들 내부 CLI를 가리키는 터미널용 symlink, user LaunchAgent를 설치하고 앱을 연다.
- 메뉴바 앱 자동 실행 monitor LaunchAgent는 `loginLaunchEnabled` 설정이 켜져 있을 때만 등록한다.
- `Uninstall MacDog.command`는 사용자 영역의 앱, 터미널용 CLI symlink, LaunchAgent, cache 파일을 제거하며 optional 권한 도우미는 건드리지 않는다.
- `Check Install Status.command`는 앱, 앱 번들 내부 CLI, 터미널용 symlink, user LaunchAgent, optional helper 설치/로드 상태, 설치된 앱이 DMG payload와 같은 빌드인지, 실행 중인 MacDog가 다른 binary인지 터미널에서 요약한다.
- 설치/업데이트 중 MacDog가 `SleepDisabled=1`을 소유한 상태라면 app 종료 정리 루틴이 값을 0으로 되돌리지 않도록 강제 종료 경로를 사용한다.
- 생성된 `.dmg`는 로컬 검증용 후보이며, 아직 Developer ID signing/notarization을 수행하지 않는다.
- `.dmg` 생성 시 같은 경로에 `.dmg.sha256` checksum을 함께 만든다.
- `.github/workflows/release-candidate.yml`은 수동 실행으로 unsigned `.dmg` 후보와 checksum을 만들고 GitHub Actions artifact로 보관한다.
- `.github/workflows/release-draft.yml`은 `UNSIGNED-DRAFT` 확인 입력을 요구한 뒤 unsigned `.dmg`와 checksum을 GitHub draft release에 첨부한다.
- `.github/workflows/release-stable.yml`은 `SIGNED-STABLE` 확인 입력, GitHub Environment approval, Developer ID Application 인증서 secret, notarization secret이 모두 있어야 signed/notarized `.dmg`를 public GitHub Release로 올린다.
- `script/verify_release_packaging.sh`는 dry-run 문구, staging payload 구조, Applications symlink, release note draft, installer/uninstaller syntax, LaunchAgent plist heredoc 구조, usage cache cleanup, helper 별도 command 제거, command 파일의 `osascript` 승인창 미사용, 설치 후 상태 확인 command의 freshness smoke를 검증한다.
- `script/verify_release_workflow.sh`는 workflow가 checksum 검증, unsigned release candidate artifact upload, unsigned draft release gate, signed stable release gate를 포함하는지 확인한다.
- `script/verify_distribution_gate.sh`는 unsigned `.dmg`가 public stable release로 오해되지 않도록 문서, package dry-run, draft release workflow, future stable release workflow gate를 검증한다.
- PR 보호 규칙, branch protection, GitHub ruleset 설정은 [GitHubReleaseChecklist.md](GitHubReleaseChecklist.md)에 분리한다.

## 확인됨

- `script/package_release.sh --dry-run` 검증 경로가 있다.
- `script/package_release.sh --skip-build --no-dmg` staging 검증 경로가 있다.
- `script/package_release.sh --skip-build`는 `dist/release/MacDog-<version>.dmg`와 checksum을 생성한다.
- release workflow는 unsigned draft와 signed stable release gate를 분리한다.
- optional helper 설치/제거는 앱 설정 탭으로 안내한다.

## 미확인

- GitHub Actions runner에서 workflow 실제 실행
- GitHub draft release 생성 workflow 실제 실행
- 생성된 `.dmg`를 Finder에서 열어 drag-and-drop 설치 실행
- 깨끗한 사용자 계정/다른 Mac에서 설치, LaunchAgent, Gatekeeper 동작 검증
- MacDog 설정 탭의 helper 설치/제거를 signed stable DMG에서 실제 실행

## 아직 하지 않는 것

- Apple Developer ID / notarization secrets 실제 등록
- Developer ID signing 결과물 실제 확인
- notarization 제출과 stapling 실제 수행
- 깨끗한 사용자 계정/다른 Mac에서 Gatekeeper 검증
- App Store 배포 준비
- GitHub repository ruleset 실제 적용

## 배포 흐름 후보

1. `./script/check.sh --no-run`
2. `./script/package_release.sh`
3. 생성된 `dist/release/MacDog-<version>.dmg`를 열어 `MacDog.app`과 `Applications` symlink를 확인한다.
4. Finder에서 `MacDog.app`을 `Applications`로 드래그해 설치한다.
5. MacDog를 실행하고 설정 탭에서 로그인 자동 실행, 데스크톱 펫, 권한 도우미 상태를 확인한다.
6. 터미널용 CLI symlink와 user LaunchAgent까지 검증해야 하면 `Install MacDog.command`를 실행한다.
7. `Check Install Status.command`로 app/번들 내부 CLI/터미널 symlink/LaunchAgent/helper 상태와 실행 중인 MacDog binary 경로를 확인한다.
8. `shasum -a 256 -c dist/release/MacDog-<version>.dmg.sha256`로 checksum을 확인한다.
9. 제거 검증이 필요하면 앱 설정 탭에서 optional helper를 먼저 제거하고, `Uninstall MacDog.command`로 user component를 제거한다.
10. unsigned 검증용 GitHub draft release가 필요하면 `Draft Release` workflow를 `UNSIGNED-DRAFT` 확인 입력과 함께 수동 실행한다.
11. 공개 배포는 GitHub Environment `public-stable-release` 승인을 둔 `Stable Release` workflow에서 `SIGNED-STABLE` 확인 입력과 Apple signing/notarization secrets가 모두 있을 때만 실행한다.

## GitHub Release 완료 기준

- GitHub Actions 또는 로컬 release script가 `.dmg`를 재현 가능하게 생성한다.
- `.dmg.sha256` checksum을 함께 제공하고 검증한다.
- DMG에는 drag-and-drop 설치를 위한 `Applications` symlink가 포함된다.
- public stable release는 Developer ID Application으로 app과 DMG를 서명하고, notarytool 제출, stapler, spctl Gatekeeper 확인을 통과한다.
- Release note에 지원 OS, unsigned/notarized 여부, helper 권한 이유, uninstall 경로를 적는다.
- `.dmg`를 내려받아 Finder로 설치하는 흐름을 새 사용자 환경에서 검증한다.
- helper 설치가 포함되는 경우 앱 설정 탭이 `/Library/PrivilegedHelperTools`와 `/Library/LaunchDaemons` 변경을 명확히 안내하고 uninstall 복구를 검증한다.
