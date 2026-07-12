# v1.7.0 릴리즈 준비 감사

상태: 릴리즈 준비 중 / 구현·자동 검증 완료 / 실제 전환 전후 관측 미수행 / release smoke 미수행
작성일: 2026-07-12
대상 버전: `1.7.0`

## 릴리즈 범위

- Release tag: `v1.7.0`
- Release scope: Codex Pro $100 전환 위험을 위한 사용자 설정 기반 scenario, 별도 5시간 history, plan epoch 분리
- 변경 문서: [V170CodexPro100Transition.md](V170CodexPro100Transition.md)
- 최종 release head: PR merge 후 최신 `origin/main` SHA로 확정

## 실제 전환 미수행 경계

실제 Codex Pro $100 전환과 전환 후 첫 7일 관측은 v1.7.0 릴리즈 선행조건이 아닙니다.
다만 아래 항목을 완료한 것으로 보고하지 않습니다.

- 실제 Pro $100 적합성
- 사용자 설정 기반 예상과 실제 target epoch의 동등성 또는 정확도
- 전환 후 첫 7일 P90 차이

MacDog는 사용자가 입력한 현재/목표 플랜 label, 상대 용량, reserve, 예정/확정 시각을 사용합니다.
가격 tier 또는 실제 한도량을 자동 추정하지 않으며, scenario는 항상 `사용자 설정 기반 예상`으로 표시합니다.

release smoke에서는 `실제 전환 확인`을 켜지 않습니다. 현재 플랜 epoch만 유지하고,
전환 미확정 상태의 설정 저장, readiness summary, 5시간/주간 history 수집 경계만 확인합니다.

Release note에는 다음 사실을 명시합니다.

- v1.7.0은 사용자 설정 기반 downgrade-readiness 도구입니다.
- 실제 Pro $100 전환과 target epoch 관측은 검증하지 않았습니다.
- 표시되는 예상값은 OpenAI가 제공하는 공식 플랜 간 용량 비교가 아닙니다.
- DMG는 ad-hoc/unsigned 배포이며 Developer ID notarization을 완료한 빌드가 아닙니다.

## 릴리즈 전 gate

아래 검증은 release version `1.7.0`을 명시해 실행합니다.

```sh
git diff --check
MACDOG_RELEASE_VERSION=1.7.0 ./script/check.sh --no-run
./script/verify_v170_codex_pro100_transition_contract.sh --self-test
```

추가 확인:

- `dist/MacDog.app`의 `CFBundleShortVersionString`은 `1.7.0`입니다.
- 기본 앱 번들과 DMG에는 WidgetKit extension을 포함하지 않습니다.
- 기존 `status --json`, `usage.json`, weekly/reset-window history schema는 유지됩니다.
- release branch worktree가 clean 상태입니다.

## PR과 release head

1. `v1.7.0 -> main` PR을 생성합니다.
2. `static-gates`, `guardrails`, Code Owner review, conversation resolution을 확인합니다.
3. CI 또는 review 실패는 같은 branch에서 수정·검증·커밋·push합니다.
4. merge 후 최신 `origin/main` SHA를 최종 release head로 기록합니다.
5. release tag를 만들기 전 release head 이후 추가 코드 변경이 없는지 확인합니다.

본인 review 제한만 남은 경우에도 사용자 명시 승인 없이 admin bypass를 사용하지 않습니다.

## Tag와 artifact

1. 원격 `v1.7.0` tag와 stale draft release가 없는지 확인합니다.
2. 최종 release head에 signed annotated `v1.7.0` tag를 만들고 push합니다.
3. GitHub에서 tag가 `Verified`인지 확인합니다.
4. `Release Candidate` workflow로 `MacDog-1.7.0.dmg`와 `.dmg.sha256`을 생성합니다.
5. checksum, `hdiutil verify`, payload version, executable checksum을 확인합니다.
6. 이미 존재하는 signed tag를 사용해 `Draft Release` workflow를 실행합니다.
7. draft의 `isDraft`, `isPrerelease`, `targetCommitish`, tag, asset 목록을 확인합니다.
8. stale draft가 아니고 tag가 `Verified`일 때만 publish합니다.

`Stable Release` workflow는 Apple Developer Program, Developer ID signing, notarization이
별도 승인된 범위가 아니므로 실행하지 않습니다.

## Published DMG release smoke

1. Published DMG와 checksum을 다시 내려받아 checksum과 `hdiutil verify`를 확인합니다.
2. Finder에서 published DMG를 열고 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop합니다.
3. `/Applications/MacDog.app`의 version, executable checksum, 수정 시각, codesign을 확인합니다.
4. 실행 중인 app path가 `/Applications/MacDog.app`인지 확인합니다.
5. menu bar runner, Codex 탭, 설정 탭, popover placement를 직접 확인합니다.
6. 플랜 전환 준비가 미확정 상태이고 `실제 전환 확인`을 켜지 않았는지 확인합니다.
7. 설치된 CLI로 usage fetch/cache 계약과 5시간/주간 history append를 확인합니다.
8. live fetch 실패는 error 또는 stale snapshot으로 분리해 보고합니다.

실제 Finder drag-and-drop 또는 앱 UI를 직접 확인하지 않았다면 해당 항목은 `미수행`으로 보고합니다.

## Release smoke 종료

```sh
./script/cleanup_release_smoke_state.sh --apply
./script/verify_release_final_state.sh --version 1.7.0
```

완료 조건:

- `/Applications/MacDog.app` 외 중복 앱 bundle 0개
- stale DMG mount 0개
- Finder `응용 프로그램` 범위의 `MacDog` 결과 1개
- CLI symlink와 usage cache LaunchAgent가 설치 앱을 가리킴
- README와 ROADMAP의 현재 release 상태 갱신
- branch 삭제는 release 완료 후 사용자 명시 승인이 있을 때만 수행

## 준비 시작 시 확인됨

- `v1.7.0` branch는 원격과 동기화된 clean 상태입니다.
- v1.7.0 구현 commit은 `6084b71394a7c54b52478c029444a87c264ac105`입니다.
- 현재 `main`은 해당 branch보다 1 commit 뒤이며 v1.6.1 release를 포함합니다.
- v1.7.0 PR, CI run, tag, release, artifact는 아직 없습니다.
- Git tag signing 설정은 존재하지만 v1.7.0 tag의 GitHub `Verified` 상태는 아직 확인하지 않았습니다.

## 미수행 보고

```text
미실행:
- 실제 Pro $100 전환: 실행하지 않음
- target epoch 첫 7일 관측: 실행하지 않음
- Release Candidate/Draft Release: 실행하지 않음
- published DMG 재다운로드 검증: 실행하지 않음
- Finder drag-and-drop 설치 smoke: 실행하지 않음
- 설치본 GUI smoke: 실행하지 않음
- release smoke cleanup/final-state: 실행하지 않음
- WidgetKit 실제 UI: 실행하지 않음
- 장시간 테스트: 실행하지 않음
```
