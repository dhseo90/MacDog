# Release Packaging

이 문서는 MacDog를 GitHub Releases에 올릴 더블클릭 설치 artifact로 배포하기 위한 현재 경계와 후속 작업을 기록한다.

## 목표

- 사용자가 GitHub Release에서 파일을 내려받아 더블클릭으로 설치를 시작할 수 있게 한다.
- 1차 artifact는 `.dmg`이며, 내부에 `MacDog.app`, `codex-usage`, 설치 command, 안내 문서, release note draft를 포함한다.
- 공개 배포 전에는 Developer ID signing, hardened runtime, notarization, Gatekeeper 검증을 별도 gate로 둔다.

## 현재 구현 범위

- `script/package_release.sh --dry-run`은 release artifact 계획을 출력한다.
- `script/package_release.sh`는 `dist/MacDog.app`과 release build의 `codex-usage`를 `dist/release/MacDog-<version>`에 staging한다.
- staging 폴더에는 `Install MacDog.command`, `Install Privileged Helper.command`, `Uninstall MacDog.command`, `Uninstall Privileged Helper.command`, `Check Install Status.command`, `README_FIRST.txt`, `RELEASE_NOTES_DRAFT.md`가 포함된다.
- `Install MacDog.command`는 더블클릭 시 사용자 영역에 앱, CLI, LaunchAgent를 설치하고 앱을 연다.
- `Install Privileged Helper.command`는 system 변경 위치와 helper 용도를 안내한 뒤 별도 더블클릭/관리자 승인으로 bundled helper를 `/Library/PrivilegedHelperTools`와 `/Library/LaunchDaemons`에 설치한다.
- `Uninstall MacDog.command`는 사용자 영역의 앱, CLI, LaunchAgent를 제거하며 optional helper는 건드리지 않는다.
- `Uninstall Privileged Helper.command`는 system 변경 위치를 안내한 뒤 별도 더블클릭/관리자 승인으로 optional helper를 `/Library` 위치에서 제거한다.
- `Check Install Status.command`는 앱, CLI, user LaunchAgent, optional helper 설치/로드 상태, 설치된 앱이 DMG payload와 같은 빌드인지, 실행 중인 MacDog가 다른 binary인지 터미널에서 요약한다.
- 설치/업데이트 중 MacDog가 `SleepDisabled=1`을 소유한 상태라면 app 종료 정리 루틴이 값을 0으로 되돌리지 않도록 강제 종료 경로를 사용한다.
- 생성된 `.dmg`는 로컬 검증용 후보이며, 아직 Developer ID signing/notarization을 수행하지 않는다.
- `.dmg` 생성 시 같은 경로에 `.dmg.sha256` checksum을 함께 만든다.
- `.github/workflows/release-candidate.yml`은 수동 실행으로 unsigned `.dmg` 후보와 checksum을 만들고 GitHub Actions artifact로 보관한다.
- `.github/workflows/release-draft.yml`은 `UNSIGNED-DRAFT` 확인 입력을 요구한 뒤 unsigned `.dmg`와 checksum을 GitHub draft release에 첨부한다.
- `.github/workflows/release-stable.yml`은 `SIGNED-STABLE` 확인 입력, GitHub Environment approval, Developer ID Application 인증서 secret, notarization secret이 모두 있어야 signed/notarized `.dmg`를 public GitHub Release로 올린다.
- public stable payload는 `MACDOG_REQUIRE_SIGNED_HELPER_HOST=1`로 생성해 `Install Privileged Helper.command`가 Developer ID로 서명된 `MacDog.app`의 TeamIdentifier 없이는 helper 설치를 거부하게 한다. 로컬 unsigned 후보에서만 ad-hoc host 허용 plist를 생성한다.
- `script/verify_release_packaging.sh`는 dry-run 문구와 staging payload의 파일 구조, release note draft, installer/uninstaller syntax, LaunchAgent plist heredoc 구조, usage cache cleanup, helper 별도 설치/제거 경계, 관리자 승인 문구, 설치 후 상태 확인 command의 freshness smoke를 검증한다.
- `script/verify_release_workflow.sh`는 workflow가 checksum 검증, unsigned release candidate artifact upload, unsigned draft release gate, signed stable release gate를 포함하는지 확인한다.
- `script/verify_distribution_gate.sh`는 unsigned `.dmg`가 public stable release로 오해되지 않도록 문서, package dry-run, draft release workflow, future stable release workflow gate를 검증한다.

2026-05-28 확인:

- `script/package_release.sh --dry-run` 검증 통과
- `script/package_release.sh --skip-build --no-dmg` staging 검증 통과
- `script/package_release.sh --skip-build`로 `dist/release/MacDog-0.1.0.dmg` 생성
- `hdiutil verify dist/release/MacDog-0.1.0.dmg` 통과
- `script/verify_release_packaging.sh` staging payload 검증 통과
- `script/verify_release_workflow.sh`로 release candidate workflow guard 검증 통과
- draft release workflow는 repo에 구성되어 있으나 GitHub Actions에서 실제 실행하지 않았다.
- public stable release workflow는 repo에 구성되어 있으나 GitHub Actions에서 실제 실행하지 않았다.
- public stable release는 Developer ID signing, hardened runtime, notarization, stapling, Gatekeeper 검증을 포함해야 통과하도록 gate를 둔다.
- public stable helper installer gate는 workflow와 packaging verifier에 구성되어 있으나, 실제 Developer ID 서명/TeamIdentifier를 가진 DMG에서 실행 검증하지 않았다.

미확인:

- GitHub Actions runner에서 workflow 실제 실행
- GitHub draft release 생성 workflow 실제 실행
- 생성된 `.dmg`를 Finder에서 열어 더블클릭 설치 실행
- 깨끗한 사용자 계정/다른 Mac에서 설치, LaunchAgent, Gatekeeper 동작 검증
- privileged helper 더블클릭 설치 command의 실제 Finder 실행
- 더블클릭 uninstall command와 helper uninstall command의 실제 Finder 실행

## 아직 하지 않는 것

- GitHub Actions runner에서 public stable workflow 실제 실행
- Apple Developer ID / notarization secrets 실제 등록
- Developer ID signing 결과물 실제 확인
- public stable DMG에서 helper installer가 TeamIdentifier requirement로 설치되는지 실제 확인
- notarization 제출과 stapling 실제 수행
- 깨끗한 사용자 계정/다른 Mac에서 Gatekeeper 검증
- privileged helper를 앱 내부 설치/제거 화면으로 자연스럽게 관리하는 UX

## 배포 흐름 후보

1. `./script/check.sh --no-run`
2. `./script/package_release.sh`
3. 생성된 `dist/release/MacDog-<version>.dmg`를 열어 payload 확인
4. 더블클릭 `Install MacDog.command`로 앱/CLI/LaunchAgent 설치 검증
5. helper가 필요한 덮개 닫힘 보호는 `Install Privileged Helper.command` 또는 앱 내부 설치 UX에서 명확히 승인받는다.
6. `Check Install Status.command`로 app/CLI/LaunchAgent/helper 상태와 실행 중인 MacDog binary 경로를 확인한다.
   - 이 command가 `installed app differs from bundled release payload`를 표시하면 이전 설치본이 남아 있는 상태이므로 UI 검수 전에 다시 설치한다.
7. `shasum -a 256 -c dist/release/MacDog-<version>.dmg.sha256`로 checksum을 확인한다.
8. 제거 검증이 필요하면 `Uninstall MacDog.command`와 `Uninstall Privileged Helper.command`를 각각 실행하고 `Check Install Status.command`로 확인한다.
9. unsigned 검증용 GitHub draft release가 필요하면 `Draft Release` workflow를 `UNSIGNED-DRAFT` 확인 입력과 함께 수동 실행한다.
10. 공개 배포는 GitHub Environment `public-stable-release` 승인을 둔 `Stable Release` workflow에서 `SIGNED-STABLE` 확인 입력과 Apple signing/notarization secrets가 모두 있을 때만 실행한다.

## GitHub Release 완료 기준

- GitHub Actions 또는 로컬 release script가 `.dmg`를 재현 가능하게 생성한다.
- `.dmg.sha256` checksum을 함께 제공하고 검증한다.
- public stable release는 Developer ID Application으로 app/CLI/DMG를 서명하고, notarytool 제출, stapler, spctl Gatekeeper 확인을 통과한다.
- Release note에 지원 OS, unsigned/notarized 여부, helper 권한 이유, uninstall 경로를 적는다.
- `.dmg`를 내려받아 더블클릭 설치하는 흐름을 새 사용자 환경에서 검증한다.
- helper 설치가 포함되는 경우 `/Library/PrivilegedHelperTools`와 `/Library/LaunchDaemons` 변경을 명확히 안내하고 uninstall 복구를 검증한다.
- 더블클릭 제거 흐름이 user component와 optional helper를 분리해 처리하는지 검증한다.
