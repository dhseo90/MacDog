# Contributing

MacDog는 macOS menu bar 앱, CLI, WidgetKit, 권한 도우미, release packaging을 함께 다루므로 변경은 작은 PR 단위로 진행한다.

## 기본 규칙

- `main`에는 직접 커밋하지 않는다.
- 기능, 수정, 문서 변경은 PR로 제안한다.
- PR은 구현 범위, 검증 명령, 미검증 항목을 함께 적는다.
- Codex auth token, refresh token, cookie, session material은 읽거나 출력하거나 저장하지 않는다.
- `codex-usage --json` schema, shared cache schema, helper IPC contract는 breaking change 전에 별도 합의가 필요하다.
- RunCat의 캐릭터, asset, 브랜드 표현을 복제하지 않는다.

## 로컬 검증

일반 변경:

```sh
./script/check.sh --no-run
```

앱 실행까지 포함한 검증:

```sh
./script/check.sh
```

문서만 바꾼 경우에도 최소한 다음을 실행한다.

```sh
git diff --check
./script/verify_readme_screenshots.sh
```

설치, 권한 도우미, 배터리 충전 한도, DMG 생성은 사용자 환경을 바꿀 수 있으므로 PR 설명에 실제 실행 여부를 명확히 남긴다.

## Release 변경

release packaging, GitHub workflow, signing/notarization 관련 변경은 [Docs/GitHubReleaseChecklist.md](Docs/GitHubReleaseChecklist.md)와 [Docs/ReleasePackaging.md](Docs/ReleasePackaging.md)를 함께 확인한다.
