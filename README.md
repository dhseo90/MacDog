# MyCodex

Codex Usage Monitor는 Codex의 5시간/주간 사용량을 일반 터미널에서 확인하고, macOS 메뉴바에서 시각적으로 감지하기 위한 유틸리티 프로젝트다.

1차 목표는 `codex-usage` 명령으로 현재 Codex 사용량을 빠르게 확인하는 것이다. 2차 목표는 RunCat UI를 참고한 macOS 메뉴바 앱을 만드는 것이다. 작은 러너가 메뉴바에 상주하고, Codex 사용량이 100%에 가까워질수록 더 빠르게 움직인다.

## 목표

- 일반 터미널에서 Codex 5시간/주간 사용량 확인
- 다른 개발 프로젝트에서도 재사용 가능한 CLI 제공
- macOS 메뉴바에서 현재 사용량 표시
- 사용량 압박이 높아질수록 빨라지는 RunCat식 러너 UI 구현
- 빠른 확인용 WidgetKit 위젯 추가
- Codex 인증 토큰을 저장하거나 노출하지 않는 구조 유지

## CLI

```sh
codex-usage status
codex-usage status --json
codex-usage status --write-cache
codex-usage status --watch 60
codex-usage doctor
```

출력 예시:

```text
Codex usage
5h:     15% used, 85% remaining, resets 2026-05-26 01:27 KST
Weekly: 38% used, 62% remaining, resets 2026-05-31 09:19 KST
Credits: 0
Plan: pro
```

## 데이터 소스

우선 데이터 소스는 로컬 Codex app-server JSON-RPC 프로토콜이다.

```text
account/rateLimits/read
```

응답에는 사용량 창, reset 시각, plan type, credits, limit 상태가 포함된다. CLI는 300분 창을 5시간 사용량 창으로, 10080분 창을 주간 사용량 창으로 해석한다.

app-server 경로가 바뀌거나 실패하면, 도구는 오류 원인을 설명하고 Codex usage dashboard 또는 활성 Codex CLI 세션의 `/status`로 수동 확인하는 방법을 안내한다.

## macOS UI 방향

메뉴바 앱은 RunCat의 핵심 상호작용을 참고한다.

- 작은 강아지 러너인 Codex Pup이 macOS 메뉴바에 상주한다.
- 시스템 신호에 따라 러너 속도가 변한다.
- 애니메이션은 가볍고, 한눈에 들어오고, 방해되지 않아야 한다.

이 프로젝트에서 속도 입력은 CPU 사용량이 아니라 Codex 사용량이다. 5시간 사용률과 주간 사용률 중 더 높은 값이 러너 속도를 결정한다.

## 캐릭터 방향

기본 캐릭터는 `Codex Pup`이다. RunCat의 고양이 캐릭터를 복제하지 않고, 작은 강아지 실루엣과 달리는 프레임으로 사용량 압박을 표현한다.

- Calm: 천천히 산책하는 느낌
- Active/Fast: 다리와 꼬리 움직임이 빨라지는 질주
- Sprint/Limit: 빨간 accent와 경고 표시로 한도 임박 표현

## 설치

설치 스크립트는 release build, `.app` 번들 생성, CLI 설치, 로그인 시 자동 실행 LaunchAgent 등록을 수행한다.
설치된 cache agent는 다른 Codex 작업에 부담을 주지 않도록 기본 5분 주기로 shared cache를 갱신한다. Shared cache는 기본 6분 이후 stale로 간주해 정상 갱신 주기와 작은 지연을 허용한다.

```sh
./script/install.sh
```

설치 전 변경 대상만 확인:

```sh
./script/install.sh --dry-run
./script/uninstall.sh --dry-run
```

설치 위치:

```text
~/Applications/CodexUsageMonitor.app
~/bin/codex-usage
~/Library/LaunchAgents/com.dhseo.mycodex.monitor.plist
~/Library/LaunchAgents/com.dhseo.mycodex.usage-cache.plist
```

삭제:

```sh
./script/uninstall.sh
```

개발 중 deep link smoke 확인:

```sh
./script/verify_runner_baseline.sh
./script/render_runner_comparison.sh
./script/build_and_run.sh --verify-deeplink
./script/build_and_run.sh --verify-runtime 10
```

## 문서

- [ROADMAP.md](ROADMAP.md): 개발 로드맵과 milestone 계획
- [AGENTS.md](AGENTS.md): 구현 계획, 아키텍처, 보안 원칙, 검증 체크리스트

## 현재 상태

CLI MVP, shared cache, macOS menu bar 앱 MVP, Codex Pup 러너, 설치/삭제 스크립트를 포함한다.

macOS menu bar 앱 MVP는 SwiftPM `CodexUsageMonitor` executable로 빌드된다. 설치 스크립트는 `~/Applications/CodexUsageMonitor.app` 설치본을 ad-hoc signing하고 서명 검증을 수행한다.
메뉴바 앱은 Codex Pup 러너, max/5h/weekly 기준 선택, reduced motion 옵션을 포함한다.
Runner speed의 기본 기준은 주간 사용량이며, 사용자가 직접 바꾼 선택값은 이후 실행에서도 유지된다.
popover는 80% 이상 사용량과 95% 이상 near-limit 상태를 별도 경고 줄로 표시한다.
WidgetKit 지원 코드는 SwiftPM `CodexUsageWidget` library로 빌드된다. 현재 설치 스크립트는 `.appex` 위젯 번들을 만들거나 설치하지 않는다. 메뉴바 앱 번들은 `codexusage://open` URL scheme을 받아 popover를 열 수 있다. 실제 데스크톱/알림 센터 위젯 추가와 실행 검수는 Xcode extension 타깃을 붙인 뒤 별도 수동 확인 단계에서 진행한다.

## 라이선스

아직 정하지 않았다.
