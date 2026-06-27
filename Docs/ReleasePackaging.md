# 릴리즈 패키징

이 문서는 MacDog를 GitHub Releases에서 내려받아 설치할 수 있는 macOS 배포물로 준비하는 범위를 기록합니다.

## 목표

- 사용자가 GitHub Release에서 `.dmg`를 내려받아 Finder에서 열 수 있게 합니다.
- DMG의 보이는 항목은 `MacDog.app`과 `Applications` symlink만 두고, 숨김 배경 이미지를 사용해 Docker 설치 화면처럼 drag-and-drop 설치 경험을 제공합니다. 배경에는 드래그 후 `Applications`에서 MacDog를 실행하라는 한글 안내를 직접 표시합니다.
- 앱을 `Applications`에서 처음 실행하면 MacDog가 사용자 영역 설치 마무리를 직접 수행합니다.
- 첫 실행 후 설치 디스크와 다운로드한 설치 파일을 정리할지 묻습니다.
- optional 권한 도우미 설치/제거는 MacDog UI에서 처리합니다. 권한이 필요하면 MacDog 이름의 관리자 승인창을 띄웁니다.
- Apple Developer Program이 필요한 signed/notarized public 배포는 현재 구현 계획에서 제외합니다. 현재 기본 릴리즈는 로컬 ad-hoc DMG와 unsigned GitHub candidate/draft 경로까지만 다룹니다.

## 현재 구현 범위

- `script/package_release.sh --dry-run`은 release artifact 계획과 설치 경계를 출력합니다. `MACDOG_RELEASE_VERSION` 또는 `--version`이 없으면 실패합니다.
- `script/package_release.sh`는 앱 번들 내부 CLI가 포함된 `dist/MacDog.app`을 `dist/release/MacDog-<version>`에 staging합니다. release version은 반드시 명시해야 합니다.
- `script/build_and_run.sh`는 `--version`, `MACDOG_RELEASE_VERSION`, `MACDOG_APP_VERSION` 중 하나로 지정한 값을 앱 번들의 `CFBundleShortVersionString`에 반영합니다. 버전이 없으면 실패합니다.
- `script/package_release.sh --skip-build`는 기존 `dist/MacDog.app`의 `CFBundleShortVersionString`이 release version과 다르면 실패합니다.
- staging 폴더에는 `MacDog.app`, `Applications` symlink, 숨김 `.background/background.png`가 포함됩니다. 배경 이미지는 `MacDog를 Applications 폴더로 드래그하세요`, `드래그 후 Applications에서 MacDog를 실행하세요` 안내를 포함합니다.
- release note draft는 DMG 안이 아니라 `dist/release/MacDog-<version>-release-notes.md`로 따로 생성됩니다.
- 앱 첫 실행 마무리는 `Applications` 또는 `~/Applications`에 복사된 앱에서만 동작합니다. 개발용 `dist/MacDog.app` 실행에는 적용하지 않습니다.
- Finder drag-and-drop 복사 자체는 앱 코드를 실행하지 않습니다. `/Applications/MacDog.app`을 처음 실행한 뒤에만 사용자 영역 설치 마무리와 로그인 항목 등록이 수행됩니다.
- 첫 실행 마무리는 `~/bin/codex-usage` symlink, usage cache LaunchAgent, macOS 로그인 항목을 사용자 설정에 맞게 설치/복구합니다.
- 첫 실행 마무리 이후 `Downloads`/`Desktop`의 `MacDog-*.dmg`, checksum, release note 후보와 마운트된 MacDog 설치 디스크를 정리할지 묻습니다.
- optional 권한 도우미가 없으면 첫 실행에서 설치 여부를 묻습니다. 사용자가 동의하면 앱 UI가 helper 설치 흐름을 열고, macOS 관리자 승인은 MacDog 주체로 표시됩니다.
- 예전 monitor LaunchAgent가 남아 있으면 첫 실행 마무리에서 제거하고, 메뉴바 앱 자동 실행은 `SMAppService.mainApp`으로 등록합니다.
- 생성된 `.dmg`는 GitHub Release에 올릴 수 있는 ad-hoc signed 빌드이며, 아직 Developer ID signing/notarization을 수행하지 않습니다.
- `.dmg` 생성 시 같은 경로에 `.dmg.sha256` checksum을 함께 만듭니다.
- `.github/workflows/ci.yml`은 PR과 `main` push에서 `MACDOG_APP_VERSION=9.9.9 ./script/check.sh --no-run`을 실행하는 기본 release readiness check입니다.
- `.github/workflows/release-candidate.yml`은 수동 실행으로 unsigned `.dmg` 후보와 checksum을 만들고 GitHub Actions artifact로 보관합니다.
- `.github/workflows/release-draft.yml`은 `UNSIGNED-DRAFT` 확인 입력을 요구한 뒤 unsigned `.dmg`와 checksum을 GitHub draft release에 첨부합니다.
- `.github/workflows/release-stable.yml`은 repo에 남아 있지만 Apple Developer Program, Developer ID Application 인증서 secret, notarization secret이 필요하므로 현재 unsigned 릴리즈 완료 조건에서 제외합니다.
- `script/verify_release_packaging.sh`는 dry-run 문구, staging payload 구조, Applications symlink, release note draft, legacy command payload 미포함, checksum, DMG 검증을 확인합니다.
- `script/verify_release_workflow.sh`는 workflow가 checksum 검증, unsigned release candidate artifact upload, unsigned draft release gate, signed stable release gate를 포함하는지 확인합니다.
- `script/cleanup_release_smoke_state.sh --apply`는 release smoke 뒤 남은 MacDog DMG 마운트, `~/Applications/MacDog.app`, stale `~/bin/codex-usage` symlink, stale usage cache LaunchAgent plist/loaded job, `dist/MacDog.app`을 정리합니다. 중복 앱과 stale plist는 삭제하지 않고 `/private/tmp/macdog-duplicate-app-cleanup` 아래로 격리하며, stale loaded job은 unload합니다.
- `script/verify_release_final_state.sh --version <version>`은 `/Applications/MacDog.app`의 앱 버전, 중복 앱 번들, stale `~/bin/codex-usage` symlink, stale usage cache LaunchAgent plist/loaded job, 실제 로그인 항목 상태, 마운트된 MacDog DMG, 남은 `dist/MacDog.app`을 확인합니다.
- `script/verify_distribution_gate.sh`는 unsigned `.dmg`가 notarized 빌드로 오해되지 않고 Apple Developer 의존 항목이 현재 unsigned 릴리즈 계획에서 제외됐는지 검증합니다.
- PR 보호 규칙, branch protection, GitHub ruleset 설정은 [GitHubReleaseChecklist.md](GitHubReleaseChecklist.md)에 분리합니다. `script/configure_github_branch_protection.sh --apply`는 repo가 public이거나 private branch protection 가능 plan일 때 적용합니다.

## 확인됨

- `script/package_release.sh --dry-run` 검증 경로가 있습니다.
- `script/package_release.sh --skip-build --no-dmg` staging 검증 경로가 있습니다.
- `script/package_release.sh --skip-build`는 `dist/release/MacDog-<version>.dmg`와 checksum을 생성합니다.
- 생성된 DMG는 `hdiutil verify`, checksum, mounted app `codesign --deep --strict`, Finder icon view metadata 검증 대상입니다.
- 사용자 설치 검수는 published DMG를 Finder에서 열고 `MacDog.app`을 `Applications`로 실제 drag-and-drop한 경우만 완료로 기록합니다.
- 첫 실행 후 사용자가 설치 파일 정리에 동의하면 MacDog 설치 디스크와 `~/Downloads/MacDog-*` 후보 파일을 정리하는 흐름이 있습니다.
- release workflow는 unsigned candidate/draft 경로를 현재 기본 릴리즈 범위로 두고, signed stable release gate는 Apple Developer 의존 항목으로 제외합니다.
- GitHub Release tag는 unsigned/ad-hoc DMG 여부와 별개로 signed annotated tag여야 하며, GitHub에서 `Verified`로 확인되어야 합니다.
- optional helper 설치/제거는 앱 UI에서 처리합니다.
- GitHub PR 보호 준비물은 repo 안에 포함되어 있습니다.

## v1.3.0 완료 기록

2026-06-24 기준 v1.3.0은 published GitHub Release와 실제 설치 smoke까지 완료했습니다.

- Release tag: `v1.3.0`
- Release head: `a689fe2e5ae6416a5864ebf9097a8890e2d95a4a`
- Published asset: `MacDog-1.3.0.dmg`, `MacDog-1.3.0.dmg.sha256`
- Published DMG checksum: `99103cba8ab2f64b024afb26b4ae37ab046d42410f68ecf69f08038dad145f29`
- Published release metadata: `draft=false`, `prerelease=false`, `target_commitish=a689fe2e5ae6416a5864ebf9097a8890e2d95a4a`
- Published DMG 재다운로드 후 checksum과 `hdiutil verify`를 확인했습니다.
- 사용자가 Finder에서 published DMG를 열고 `MacDog.app`을 `Applications`로 drag-and-drop했습니다.
- 설치된 `/Applications/MacDog.app`의 앱/CLI 바이너리가 mounted DMG 내부 앱/CLI 바이너리와 같은 checksum임을 확인했습니다.
- `/Applications/MacDog.app` 첫 실행 후 `~/bin/codex-usage`, usage cache LaunchAgent, macOS 로그인 항목, 실행 중인 app path가 설치본 기준임을 확인했습니다.
- `./script/verify_usage_fetch_cache_contract.sh --cli /Applications/MacDog.app/Contents/MacOS/codex-usage`가 `usage-fetch:success`로 통과했습니다.
- Popover 실제 UI에서 Codex 사용량, 활성 자원, 잠들지 않기, 배터리, 설정 탭 전환을 확인했습니다.
- `./script/cleanup_release_smoke_state.sh --apply` 뒤 Finder 검색 중복 원인이 제거되어 `MacDog.app`는 `/Applications/MacDog.app` 하나만 남았습니다.
- `./script/verify_release_final_state.sh --version 1.3.0`이 통과했습니다.
- Notification Center 표시 검수는 수행하지 않았습니다. 설정 탭의 알림 상태와 로컬 알림 경계까지만 v1.3.0 smoke 증거로 기록합니다.

## 후속 release smoke

- 다음 릴리즈에서 GitHub Release `.dmg`는 해당 release head 기준 published asset이어야 합니다.
- 다음 릴리즈에서도 published DMG는 checksum과 `hdiutil verify`를 다시 확인합니다.
- 설치 검수가 필요한 릴리즈 종료 작업은 Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop한 경우만 설치 검수로 인정합니다.
- 깨끗한 사용자 계정/다른 Mac에서 설치, LaunchAgent 동작 검증은 필요 시 추가 release smoke로 수행합니다.
- Gatekeeper 동작 검증은 Developer ID signing/notarization이 필요한 signed stable 배포 범위이므로 현재 unsigned 릴리즈에서 제외합니다.

## 아직 하지 않는 것

- Apple Developer ID / notarization secrets 실제 등록은 현재 구현 계획에서 제외
- Developer ID signing 결과물 확인은 현재 구현 계획에서 제외
- notarization 제출과 stapling 수행은 현재 구현 계획에서 제외
- Gatekeeper 검증은 현재 구현 계획에서 제외
- App Store 배포 준비
- GitHub repository ruleset 실제 적용. 현재 repo가 private이고 GitHub가 branch protection API를 거절하면 public 전환 또는 plan 변경 전에는 실제 적용할 수 없습니다.

## 배포 흐름 후보

1. `MACDOG_RELEASE_VERSION=<version> ./script/check.sh --no-run`
2. `MACDOG_RELEASE_VERSION=<version> ./script/package_release.sh`
3. 생성된 `dist/release/MacDog-<version>.dmg`를 열어 `MacDog.app`과 `Applications` symlink가 보이고 drag-and-drop 배경이 적용되는지 확인합니다.
4. Finder에서 `MacDog.app`을 `Applications`로 드래그해 설치합니다.
5. `Applications`의 MacDog를 실행하고 첫 실행 마무리가 진행되는지 확인합니다.
6. 설치 파일 정리 안내가 뜨고, 사용자가 동의하면 설치 디스크와 다운로드한 설치 파일이 정리되는지 확인합니다.
7. Codex 사용량 cache, 터미널용 `codex-usage` symlink, usage cache LaunchAgent, macOS 로그인 항목 실제 상태를 확인합니다.
8. optional helper 설치 안내가 MacDog UI로 표시되는지 확인하고, 승인 시 관리자 승인창 주체가 MacDog인지 확인합니다.
9. `shasum -a 256 -c dist/release/MacDog-<version>.dmg.sha256`로 checksum을 확인합니다.
10. release smoke가 끝나면 `./script/cleanup_release_smoke_state.sh --apply`로 Finder 검색 중복을 유발하는 잔여 DMG/앱 번들을 정리합니다.
11. `./script/verify_release_final_state.sh --version <version>`가 통과해야 release smoke 종료로 기록합니다.
12. 제거 검증이 필요하면 앱 UI에서 optional helper를 먼저 제거하고 앱과 user LaunchAgent/cache를 삭제합니다.
13. unsigned 검증용 GitHub draft release가 필요하면 `Draft Release` workflow를 `UNSIGNED-DRAFT` 확인 입력과 함께 수동 실행합니다.
14. signed stable 공개 배포는 Apple Developer 의존 항목이므로 현재 unsigned 릴리즈 완료 조건에서 제외합니다.

## 릴리즈 종료 체크리스트

사용자가 `vX.Y.Z 릴리즈 준비`, `릴리즈 종료`, `PR부터 릴리즈까지 진행`처럼 버전 릴리즈를 지시하면 아래 흐름을 완료해야 릴리즈 완료로 기록합니다.

1. 릴리즈 대상 브랜치, 현재 브랜치, 이전 릴리즈 브랜치의 존재 여부를 확인합니다.
2. 이전 릴리즈 브랜치가 `main`에 포함되지 않았으면 중단하고 사용자 결정을 받습니다.
3. PR 생성 전 `git diff --check`와 변경 범위의 필수 테스트를 통과시킵니다.
4. 릴리즈 PR을 생성하고 CI와 리뷰 상태를 확인합니다.
5. 리뷰 반영은 같은 브랜치에서 수정, 테스트, 커밋, 푸시로 반복합니다.
6. PR merge 후 `origin/main` 최신 SHA를 release head로 기록합니다.
7. 기존 draft release가 stale target이면 publish하지 않고 삭제 대상으로 보고합니다.
8. 원격 tag `vX.Y.Z`가 없는지 확인합니다. 기존 tag를 재발행하는 경우 기존 release/tag/asset 상태와 재발행 사유를 기록합니다.
9. `Release Candidate` workflow와 `Draft Release` workflow를 최신 release head 기준으로 실행합니다.
10. 최신 release head에 대해 signed annotated tag를 만들고 push한 뒤 GitHub에서 tag가 `Verified`인지 확인합니다.
11. workflow 또는 `gh release create`가 unsigned/lightweight tag를 자동 생성하지 않도록 `--verify-tag` 또는 동등한 검증을 사용합니다.
12. artifact, checksum, draft `isDraft`, `isPrerelease`, `targetCommitish`, asset 목록을 확인합니다.
13. GitHub Releases 화면에서 stale draft가 아니고 tag가 `Verified`임을 확인한 뒤 publish합니다.
14. publish 후 `isDraft=false`, 원격 tag, tag `Verified` 상태를 확인합니다.
15. published DMG를 다시 내려받아 checksum과 `hdiutil verify`를 확인합니다.
16. 설치 검수가 필요한 릴리즈 종료 작업이면 Finder에서 published DMG를 열고 `MacDog.app`을 `Applications`로 실제 drag-and-drop합니다.
17. 첫 실행 후 `~/bin/codex-usage`, usage cache LaunchAgent, 실행 중인 app path가 `/Applications/MacDog.app` 기준인지 확인합니다.
18. 설치된 CLI 또는 빌드된 CLI로 `./script/verify_usage_fetch_cache_contract.sh --cli <codex-usage-path>`를 실행합니다.
19. live fetch 성공 시 5시간/주간 window가 모두 있는 success cache와 `usage-weekly-history.json` sample, `history append: stored ... recordingStartedAt=...` diagnostic을 확인합니다.
20. live fetch 실패 시 error snapshot인지 확인합니다.
21. 5시간/주간 window가 없는 `0% 사용 / 100% 남음` 형태의 success cache가 생성되면 실패로 봅니다.
22. `./script/cleanup_release_smoke_state.sh --apply`로 release smoke 잔여물을 정리합니다.
23. `./script/verify_release_final_state.sh --version X.Y.Z`가 통과해야 release smoke 종료로 봅니다.
24. 릴리즈 publish와 final smoke가 끝난 뒤 release branch를 정리합니다.

브랜치 정리 전에는 반드시 아래 조건을 확인합니다.

```sh
git merge-base --is-ancestor <release-branch> main
git merge-base --is-ancestor origin/<release-branch> origin/main
```

둘 중 하나라도 실패하면 브랜치를 삭제하지 않습니다. 원격 브랜치 삭제는 사용자가 릴리즈 종료 또는 브랜치 정리를 명시적으로 승인한 경우에만 수행합니다.

## GitHub 릴리즈 완료 기준

- GitHub Actions 또는 로컬 release script가 `.dmg`를 재현 가능하게 생성합니다.
- `.dmg.sha256` checksum을 함께 제공하고 검증합니다. DMG는 빌드/패키징 시점의 filesystem metadata 때문에 bit-for-bit checksum이 매 패키징마다 달라질 수 있으므로, 프로젝트 문서의 stale literal 값보다 GitHub Release asset digest와 함께 제공되는 `.sha256` 파일을 최종 checksum source of truth로 둡니다.
- release tag는 최신 release head를 가리키는 signed annotated tag이며 GitHub에서 `Verified`로 확인됩니다.
- DMG에는 drag-and-drop 설치를 위한 `Applications` symlink가 포함됩니다.
- DMG 안에는 앱 설치에 필요 없는 command 파일이나 임시 안내 파일이 없습니다.
- 앱 번들 내부 `CFBundleShortVersionString`은 release version과 일치해야 합니다.
- Finder 검색에서 `/Applications/MacDog.app` 외 중복 앱이 보이지 않고, stale CLI symlink가 남지 않도록 release smoke 종료 후 cleanup/final-state 검증을 통과해야 합니다.
- signed/notarized public stable release는 현재 구현 계획에서 제외합니다.
- Release note에 지원 OS, unsigned/notarized 여부, helper 권한 이유, uninstall 경로를 적습니다.
- 후속 release smoke가 필요하면 `.dmg`를 내려받아 Finder로 설치하는 흐름을 새 사용자 환경에서 검증합니다.
- helper 설치가 포함되는 후속 smoke에서는 앱 UI가 `/Library/PrivilegedHelperTools`와 `/Library/LaunchDaemons` 변경을 명확히 안내하고 uninstall 복구를 검증합니다.
