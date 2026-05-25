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

- 작은 러너가 macOS 메뉴바에 상주한다.
- 시스템 신호에 따라 러너 속도가 변한다.
- 애니메이션은 가볍고, 한눈에 들어오고, 방해되지 않아야 한다.

이 프로젝트에서 속도 입력은 CPU 사용량이 아니라 Codex 사용량이다. 5시간 사용률과 주간 사용률 중 더 높은 값이 러너 속도를 결정한다.

## 문서

- [ROADMAP.md](ROADMAP.md): 개발 로드맵과 milestone 계획
- [AGENTS.md](AGENTS.md): 구현 계획, 아키텍처, 보안 원칙, 검증 체크리스트

## 현재 상태

CLI MVP 구현 단계다. 로컬 Codex app-server 사용량 조회와 `codex-usage status --json` live smoke를 검증했고, 다음 단계는 shared cache와 macOS menu bar 앱 구현이다.

## 라이선스

아직 정하지 않았다.
