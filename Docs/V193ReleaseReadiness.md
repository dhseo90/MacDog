# v1.9.3 릴리즈 준비

상태: v1.9.3 GitHub Release 공개. Finder 설치와 final-state 확인.
작성일: 2026-10-01
대상 버전: `1.9.3`
기준 브랜치: `v1.9.3`
개발 검증 버전: `MACDOG_APP_VERSION=1.9.3`

제품 계약은 [V193CodexRemainingCredits.md](V193CodexRemainingCredits.md)이다.
직전 공개본은 [v1.9.2](https://github.com/dhseo90/MacDog/releases/tag/v1.9.2)이다.

## 이번 릴리즈에 들어가는 것

- Codex 1번 탭의 잔여 크레딧 항목, 빈 항목 숨김, 정수 표시
- 데이터 상태를 바닥에 두고 빈 높이를 주간 그래프에만 주는 배치
- README 팝오버 스크린샷의 상하좌우 여백

CLI, cache, 인증 방식, Grok 주간 그래프 높이는 바꾸지 않는다.
`Stable Release` workflow는 실행하지 않습니다. Developer ID와 notarization은
이번 완료 조건이 아니다.

## 릴리즈 전 확인

release branch의 clean worktree에서 실행한다.

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v193_codex_remaining_credits_contract.sh --self-test
./script/verify_v193_release_readiness.sh --self-test
./script/verify_readme_screenshots.sh
MACDOG_APP_VERSION=1.9.3 ./script/check.sh --no-run
```

`verify_v192_release_readiness.sh`가 요구하는 v1.9.2 문구는 유지한다.
README의 현재 릴리즈 문장만 v1.9.3으로 옮긴다.

## 공개 순서

1. `v1.9.3`에서 `main`으로 PR을 만든다. `main`에 직접 push하지 않는다.
2. 필수 CI `static-gates`와 `guardrails`를 확인한다.
3. 작성자 본인 review가 불가해 `REVIEW_REQUIRED`만 남으면, 그 PR에 대한 릴리즈
   승인 아래에서만 admin bypass merge를 한다. branch protection은 완화하지 않는다.
4. merge 후 `origin/main` SHA를 release head로 둔다.
5. 그 head에 signed annotated tag `v1.9.3`만 만들고 push한다.
   GitHub `Verified`가 아니면 draft와 publish를 하지 않는다.
6. `Release Candidate`와 `Draft Release`는 그 head에서 실행한다.
   draft는 이미 있는 tag만 쓰고 `UNSIGNED-DRAFT`를 확인값으로 쓴다.
   workflow가 tag를 만들면 안 된다.
7. publish 뒤 Latest가 `v1.9.3`인지, asset이 DMG와 `.dmg.sha256`인지 확인한다.
   checksum의 기준은 GitHub Release asset `MacDog-1.9.3.dmg.sha256`이다.
8. published DMG를 다시 받아 checksum과 `hdiutil verify`를 확인한다.

## 설치

설치 검수는 Finder에서 published DMG를 열고 `MacDog.app`을 `Applications`로
drag-and-drop한 경우만 해당한다. 실행 파일만 교체하거나 `dist/MacDog.app`을
복사한 것은 설치가 아니다.

그 뒤에 아래를 통과해야 release smoke를 끝으로 본다.

```sh
./script/cleanup_release_smoke_state.sh --apply
./script/verify_release_final_state.sh --version 1.9.3
```

Finder drag-and-drop을 보지 못했으면 설치 smoke는 `미수행`이다.
그 상태에서는 release branch를 삭제하지 않는다.

## 브랜치 정리

publish와 final smoke가 끝난 뒤에만 `v1.9.3`을 지운다. 둘 다 성공해야 한다.

```sh
git merge-base --is-ancestor v1.9.3 main
git merge-base --is-ancestor origin/v1.9.3 origin/main
```

하나라도 실패하면 삭제하지 않는다.

## 이 브랜치에서 확인한 것

2026-10-01에 `main` `7207bc96f52505c0f4151cfc077e2fd979671fed`를 공개했다.
첫 PR CI는 README에 이전 release head가 없어 `static-gates`가 실패했고,
`c118891fd41f53dc468bfb511351a6e84f368a13`에서 고친 뒤 통과했다.
Release Candidate `36866062558`, Draft Release `36866066802`, main CI
`36865700339`, guardrails `36865699899`는 그 머지 커밋에서 통과했다.
태그 이름과 같은 브랜치에서 시작된 workflow는 취소했다. 공개 DMG는 그 실행이 아니다.

signed tag `e135271f905da1de7dca985898ea7a93589853c0`는 GitHub `Verified`다.
다시 받은 DMG의 SHA-256은
`257e54c19ea4739456ace7ec2a90ee50e57ad2725389139e7720b3dbf4aece22`이고
`hdiutil verify`는 VALID다. 이미지 안 앱 버전은 1.9.3이다.

사용자가 공개 DMG에서 설치했다고 확인했다. 드래그 동작은 직접 보지 않았다.
설치본은 `/Applications/MacDog.app` 1.9.3이고, 실행 파일 SHA-256
`62dc05de0ab550cb925a1cf4ead984fb7bd4d134d8214c410b17c652325c6f81`은
공개 DMG와 같다. `cleanup_release_smoke_state.sh --apply` 뒤
`verify_release_final_state.sh --version 1.9.3`은 통과했다.
이 기록 merge 뒤 ancestor이면 `v1.9.3` 브랜치를 삭제한다.

로컬에서 제품 변경과 스크린샷도 확인했다.

- `git diff --check` 통과
- `npx --yes markdownlint-cli2@0.22.1` 45 files, 0 errors
- `./script/verify_readme_screenshots.sh` 통과. 팝오버 그림은 사방 12pt 여백
- 잔여 크레딧 표시, 한 페이지, Grok 그래프 높이, 스크린샷 여백 테스트 통과
- Xcode Debug build, `CODE_SIGNING_ALLOWED=NO`: `BUILD SUCCEEDED`
- 로컬 `swift test --no-parallel`은 MacDogTests 368개 중 picker 테스트 4개가
  실패했다. `NSPopUpButton`이 뷰에 없다. history 뷰는 이번 diff에 없고,
  v1.9.2 로컬 기록과 같은 실패다. CodexUsageCoreTests 226개와 helper 29개는
  실패가 없었다. GitHub Actions 결과가 이 로컬 실패의 최종 기준이다
- 설치본 팝오버를 손으로 열지는 않았다. 렌더 성공은 GUI 검수가 아니다

## 증거

하지 않은 설치와 GUI는 완료로 적지 않는다.

| 증거 | 상태 |
| --- | --- |
| 제품 계약 | [V193CodexRemainingCredits.md](V193CodexRemainingCredits.md) |
| README 스크린샷 여백 | 렌더가 상하좌우 여백을 두고, 초기화권·잔여 크레딧·데이터 상태가 그 안에 있는지 확인 |
| signed annotated tag | `e135271f905da1de7dca985898ea7a93589853c0` → `7207bc96f52505c0f4151cfc077e2fd979671fed`, GitHub `Verified` |
| Published DMG | Latest `v1.9.3`, release ID `400978180`. SHA-256 `257e54c19ea4739456ace7ec2a90ee50e57ad2725389139e7720b3dbf4aece22`. `hdiutil verify` VALID |
| Finder drag-and-drop | 사용자가 공개 DMG에서 설치했다고 확인. 설치본 1.9.3, 실행 파일 checksum이 DMG와 같음 |
| final-state | `verify_release_final_state.sh --version 1.9.3` 통과 |
| Mac/Sleep/Battery 탭 직접 조작 | 미수행. 이번 완료 조건 아님 |
