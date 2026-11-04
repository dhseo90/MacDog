# v1.9.4 릴리즈 준비

상태: v1.9.4 공개 순서. 공개 증거는 GitHub Release asset과 signed tag verification이다.
작성일: 2026-11-04
대상 버전: `1.9.4`
기준 브랜치: `v1.9.4`
개발 검증 버전: `MACDOG_APP_VERSION=1.9.4`

제품 계약은 [V194ClaudeLookupAndGrokWeekly.md](V194ClaudeLookupAndGrokWeekly.md)이다.
직전 공개본은 [v1.9.3](https://github.com/dhseo90/MacDog/releases/tag/v1.9.3)이다.

## 이번 릴리즈에 들어가는 것

- Claude 주간 잔여를 공통 게이지와 공통 주간 그래프에 넣는다. 설정 체크는 기본 꺼짐이다.
- Grok `creditUsagePercent`를 월간 이웃 필드와 함께 저장하고, 거절 중 마지막 주간 잔여를 게이지에 남긴다.
- 러너, 메뉴바 `%`, 알림은 fresh 값만 사용한다.

CLI JSON, cache schema, app-server 계약은 바꾸지 않는다.
`Stable Release` workflow는 실행하지 않습니다. Developer ID와 notarization은
이번 완료 조건이 아니다.

## 릴리즈 전 확인

release branch의 clean worktree에서 실행한다.

```sh
git diff --check
npx --yes markdownlint-cli2@0.22.1
./script/verify_v194_release_readiness.sh --self-test
./script/verify_v193_release_readiness.sh --self-test
MACDOG_APP_VERSION=1.9.4 ./script/check.sh --no-run
```

`verify_v193_release_readiness.sh`가 요구하는 v1.9.3 문구는 유지한다.

## 공개 순서

1. `v1.9.4`에서 `main`으로 PR을 만든다. `main`에 직접 push하지 않는다.
2. 필수 CI `static-gates`와 `guardrails`를 확인한다.
3. 작성자 본인 review가 불가해 `REVIEW_REQUIRED`만 남으면, 그 PR에 대한 릴리즈
   승인 아래에서만 admin bypass merge를 한다. branch protection은 완화하지 않는다.
4. merge 후 `origin/main` SHA를 release head로 둔다.
5. 그 head에 signed annotated tag `v1.9.4`만 만들고 push한다. tag는 이 마지막
   커밋만 가리킨다. 중간 커밋에 tag를 만들거나 기존 tag를 옮기지 않는다.
   GitHub `Verified`가 아니면 draft와 publish를 하지 않는다.
6. `Release Candidate`와 `Draft Release`는 그 head에서 실행한다.
   draft는 이미 있는 tag만 쓰고 `UNSIGNED-DRAFT`를 확인값으로 쓴다.
   workflow가 tag를 만들면 안 된다.
7. publish 뒤 Latest가 `v1.9.4`인지, asset이 `MacDog-1.9.4.dmg`와
   `MacDog-1.9.4.dmg.sha256`인지 확인한다.
   checksum의 기준은 GitHub Release asset `MacDog-1.9.4.dmg.sha256`이다.
8. published DMG를 다시 받아 checksum과 `hdiutil verify`를 확인한다.

## 설치

설치 검수는 Finder에서 published DMG를 열고 `MacDog.app`을 `Applications`로
drag-and-drop한 경우만 해당한다. 실행 파일만 교체하거나 `dist/MacDog.app`을
복사한 것은 설치가 아니다. 로컬 DMG 드래그는 공개 DMG 설치가 아니다.

그 뒤에 아래를 통과해야 release smoke를 끝으로 본다.

```sh
./script/cleanup_release_smoke_state.sh --apply
./script/verify_release_final_state.sh --version 1.9.4
```

Finder drag-and-drop을 보지 못했으면 설치 smoke는 `미수행`이다.
그 상태에서는 release branch를 삭제하지 않는다.
하지 않은 설치와 GUI는 완료로 적지 않는다.

## 이미 확인한 로컬 범위

2026-11-03 전체 `swift test`와 Debug build는 통과했다. 2026-11-04 로컬 DMG를
사용자가 Finder에서 드래그했고, 설치본 checksum이 그 로컬 DMG와 같았다.
Claude live `rate_limits`는 계정이 없어 닫았다. 57시간 billing 원문은 없다.
이 항목은 공개 DMG 재설치와 final-state를 대신하지 않는다.

## 브랜치 정리

publish와 final smoke가 끝난 뒤에만 `v1.9.4`를 지운다. 둘 다 성공해야 한다.

```sh
git merge-base --is-ancestor v1.9.4 main
git merge-base --is-ancestor origin/v1.9.4 origin/main
```

하나라도 실패하면 삭제하지 않는다.
