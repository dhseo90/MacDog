# Codex Usage Monitor Roadmap

## 제품 방향

Codex Usage Monitor는 Codex의 5시간/주간 사용량을 메뉴바에서 즉시 감지하게 해주는 macOS 유틸리티다. RunCat처럼 작은 러너가 메뉴바에 상주하고, 사용량이 높아질수록 더 빠르게 움직인다. 기본 캐릭터는 강아지 러너 `Codex Pup`이며, 클릭하면 현재 사용률, 남은 비율, reset 시각, credit 상태를 보여준다.

핵심 경험은 다음과 같다.

- 터미널에서는 `codex-usage status` 한 줄로 사용량을 확인한다.
- 메뉴바에서는 러너 속도만 봐도 위험도를 알 수 있다.
- 클릭하면 5시간/주간 사용량을 명확히 본다.
- 위젯은 빠른 glance 용도이며, 지속 애니메이션은 메뉴바 앱이 담당한다.

## RunCat UI 참고 방향

RunCat의 참고점은 "메뉴바에 작고 귀여운 러너가 계속 움직이며, 시스템 부하에 따라 속도가 달라지는 상태 표시"다. 이 프로젝트는 CPU 부하 대신 Codex 사용률을 속도 입력으로 사용한다.

적용할 원칙:

- 메뉴바에서는 텍스트보다 움직임을 우선한다.
- 기본 상태는 방해되지 않아야 한다.
- 사용량이 높아질수록 속도, 색상, popover 경고 단계가 함께 강해진다.
- 러너는 16-22pt 높이에서 선명해야 한다.
- 프레임 애니메이션은 8-16프레임 MVP로 시작하고, 나중에 사용자 커스텀 러너를 지원한다.
- 메뉴바 공간을 많이 쓰지 않는다.
- 기본 캐릭터는 고양이가 아니라 Codex Pup 강아지 실루엣으로 간다.

적용하지 않을 것:

- RunCat의 고양이 캐릭터를 그대로 복제하지 않는다.
- CPU, 메모리, 배터리 등 일반 시스템 모니터링 기능을 MVP에 넣지 않는다.
- WidgetKit 위젯에 실시간 달리기 애니메이션을 기대하지 않는다.

## 사용량 단계

러너 속도는 5시간 사용률과 주간 사용률 중 더 높은 값을 기준으로 정한다.

```text
usage = max(fiveHour.usedPercent, weekly.usedPercent)
```

| 단계 | 사용률 | 메뉴바 속도 | UI 상태 |
| --- | ---: | --- | --- |
| Calm | 0-49% | 천천히 걷기 | 기본색 |
| Active | 50-79% | 가볍게 뛰기 | 약한 강조 |
| Fast | 80-94% | 빠르게 뛰기 | 주황 계열 경고 |
| Sprint | 95-99% | 매우 빠르게 뛰기 | 빨강 계열 경고 |
| Limit | 100%+ | 숨가쁜 루프/정지 경고 | 한도 도달 표시 |

## 캐릭터 로드맵

러너 변경은 "메뉴바 16-22pt 크기에서도 한눈에 읽히는가"를 기준으로 한다.
Spark/Pulse처럼 작은 이펙트만 다른 테마는 메뉴바에서 차이가 약하므로 기본 UI 옵션으로 노출하지 않는다.
현재 앱은 Codex Pup 하나만 유지해 설정이 장난감처럼 느껴지지 않게 한다.

### 1차 캐릭터: Codex Pup

목표: 16-22pt 메뉴바 크기에서도 강아지로 읽히는 단순하고 선명한 실루엣을 만든다.

1. 기본 벡터 실루엣: 몸통, 머리, 귀, 꼬리, 네 다리
2. 8프레임 달리기 루프: 다리 stride, 꼬리 흔들림, 작은 bounce
3. 사용량 단계별 accent: calm template, active accent, fast orange, sprint/limit red
4. `Docs/RunnerBaseline.md`와 `script/verify_runner_baseline.sh`로 frame count, frame size, 상태 단계를 기준선으로 고정
5. 후속 asset polish: retina PNG 또는 SF Symbols fallback 검토
6. 메뉴바에서 차이가 약한 Spark/Pulse 효과 테마는 기본 옵션에서 제외

### 후속 후보

- Terminal Runner: `>_` 터미널 형태를 작게 의인화한 개발자 도구형 러너
- 사용자 커스텀 runner PNG import: MVP 이후 확장 기능으로 유지

## Milestone 0: 기술 검증

목표: 일반 터미널에서 정확한 Codex 사용량을 가져올 수 있음을 확정한다.

작업:

- `codex app-server`를 child process로 실행한다.
- `initialize` JSON-RPC 요청을 보낸다.
- `account/rateLimits/read` JSON-RPC 요청을 보낸다.
- `primary.windowDurationMins = 300`을 5시간 창으로 매핑한다.
- `secondary.windowDurationMins = 10080`을 주간 창으로 매핑한다.
- `rateLimitsByLimitId.codex`를 기본 bucket으로 사용한다.
- `codex_bengalfox` 같은 추가 bucket은 advanced/debug 출력으로 분리한다.

완료 기준:

- Terminal/iTerm/VS Code 터미널에서 같은 결과가 나온다.
- 5시간 사용률, 주간 사용률, reset 시각, plan type, credits balance를 얻는다.
- app-server 실패 시 사람이 이해할 수 있는 오류를 출력한다.

## Milestone 1: CLI MVP

목표: 다른 프로젝트에서도 즉시 쓸 수 있는 사용량 확인 명령을 만든다.

명령:

```sh
codex-usage status
codex-usage status --json
codex-usage status --watch 60
codex-usage doctor
```

작업:

- `scripts/codex-usage` 진입점 작성
- JSON-RPC client 구현
- text formatter 구현
- JSON formatter 구현
- reset 시각 로컬 타임존 변환
- `doctor` 명령으로 Codex CLI 경로, app-server 실행 가능 여부, auth 상태, 응답 schema 확인
- fixture 기반 parser test 작성

완료 기준:

- `codex-usage status`가 사람이 읽기 좋은 요약을 출력한다.
- `codex-usage status --json`이 앱/위젯에서 재사용할 수 있는 안정적인 schema를 출력한다.
- 실패 상태가 exit code와 메시지로 구분된다.

## Milestone 2: Shared Cache

목표: 메뉴바 앱과 위젯이 같은 사용량 snapshot을 읽게 한다.

작업:

- snapshot schema 정의
- cache 저장 위치 생성
- atomic write 구현
- stale 판단 기준 추가
- menu bar 앱 cache read 주기 기본값 60초
- 설치형 cache agent 갱신 주기 기본값 300초
- 마지막 성공 snapshot과 현재 오류 상태를 함께 저장

저장 위치:

```text
~/Library/Application Support/CodexUsageMonitor/usage.json
```

완료 기준:

- CLI가 `--write-cache`로 snapshot을 저장한다.
- cache가 오래되면 stale 상태로 표시된다.
- 민감 정보가 cache에 저장되지 않는다.

## Milestone 3: Menu Bar App MVP

목표: RunCat식 메뉴바 러너로 Codex 사용량 위험도를 시각화한다.

작업:

- SwiftUI + AppKit `NSStatusItem` 앱 생성
- 러너 프레임 asset 8-16개 제작
- usage 단계별 frame interval 매핑
- popover UI 구현
- cache reader 구현
- cache가 없으면 직접 app-server 조회
- stale/error/limit 상태 UI 구현

Popover 정보 구조:

```text
Codex Usage
5h      15% used / 85% left / resets 01:27
Weekly  38% used / 62% left / resets Sat 09:19
Plan    pro
Credits 0
Updated 22:44
```

완료 기준:

- 메뉴바 러너가 항상 작고 선명하게 보인다.
- 사용률 단계에 따라 속도가 변한다.
- 클릭 시 popover가 즉시 열린다.
- 앱이 종료되어도 Codex 상태 파일을 손상시키지 않는다.

## Milestone 4: RunCat-like Polish

목표: 단순 기능을 넘어 매일 켜두고 싶은 느낌을 만든다.

작업:

- 메뉴바 크기에서도 확실히 구분되는 러너 variant 검토
- 단계별 색상 accent 추가
- "5h 기준", "weekly 기준", "max 기준" 표시 모드 추가
- high usage에서 부드러운 alert affordance 추가
- reduced motion 접근성 옵션 추가
- menu bar notch/overflow 환경 확인
- retina/non-retina asset 품질 확인

완료 기준:

- 기본 UI는 RunCat처럼 가볍고 장난스럽지만, popover는 명확한 개발 도구처럼 보인다.
- 80% 이상 상태가 눈에 띄지만 과하게 산만하지 않다.
- 장시간 실행 시 CPU/RAM 사용량이 낮다.

## Milestone 5: WidgetKit

목표: 데스크톱/알림 센터에서 사용량을 빠르게 확인한다.

현재 상태:

- SwiftPM `CodexUsageWidget` library에 timeline provider와 small/medium view 지원 코드가 있다.
- 메뉴바 앱 번들은 `codexusage://open` URL scheme을 받아 popover를 열 수 있다.
- 실제 `.appex` 배포 경계는 `Docs/WidgetPackaging.md`에 정리했다.
- App Group cache URL helper는 구현했지만, 실제 entitlement와 Xcode target 연결은 아직 하지 않았다.
- 실제 macOS `.appex` 위젯 번들, Xcode extension 타깃, 위젯 설치/표시 검증은 아직 포함하지 않는다.
- 설치 스크립트는 menu bar app과 CLI만 설치하며 WidgetKit extension을 배포하지 않는다.

작업:

- Xcode macOS app target과 Widget Extension target 구성
- small 위젯 구현
- medium 위젯 구현
- shared cache reader 구현
- stale/error/empty 상태 구현
- widget click deep link 구현
- menu bar app 열기 또는 상세 화면 이동 구현

위젯 방향:

- small: 가장 높은 사용률, 남은 비율, reset까지 남은 시간
- medium: 5시간/주간 bar 2개, credits, 마지막 업데이트
- 애니메이션은 제한적으로만 사용하고, 상태 정보의 가독성을 우선한다.

완료 기준:

- 위젯이 cache 기반으로 안정적으로 표시된다.
- 앱이 실행 중이지 않아도 마지막 snapshot을 보여준다.
- 위젯을 클릭하면 상세 사용량으로 이동한다.

## Milestone 6: 배포와 설치

목표: 개인 Mac에서 반복 설치 없이 안정적으로 쓴다.

작업:

- CLI 설치 스크립트 작성
- 앱 bundle 생성
- LaunchAgent 옵션 제공
- 로그인 시 자동 실행 옵션 추가
- uninstall 스크립트 작성
- README 작성
- 문제 해결 가이드 작성

완료 기준:

- 새 터미널에서 `codex-usage status`가 바로 동작한다.
- 앱을 로그인 항목으로 등록할 수 있다.
- 삭제 시 cache/LaunchAgent/symlink 정리가 가능하다.

## Milestone 7: 확장 기능

목표: MVP 이후 사용성을 높인다.

후보:

- 사용자 커스텀 runner PNG import
- 사용량 임계값 알림
- 5시간 reset countdown 표시
- 여러 limit bucket 표시
- Spark/GPT-5.3-Codex-Spark 별도 표시
- 사용량 history chart
- 메뉴바 텍스트 표시 옵션
- 자동 모델 전환 힌트

## 우선순위

1. 일반 터미널 CLI
2. cache writer
3. menu bar 러너 MVP
4. popover 상세
5. RunCat-like polish
6. WidgetKit
7. packaging

## 리스크

- Codex app-server 프로토콜이 변경될 수 있다.
- WidgetKit은 실시간 애니메이션에 적합하지 않다.
- 메뉴바 애니메이션은 배터리와 CPU 사용량을 조심해야 한다.
- Codex 사용량 정책은 바뀔 수 있으므로 window duration과 limit id를 응답 기반으로 처리해야 한다.

## 첫 번째 구현 티켓

1. `scripts/codex-usage`를 만든다.
2. app-server JSON-RPC 통신을 구현한다.
3. `status --json`을 먼저 완성한다.
4. fixture test를 추가한다.
5. text formatter를 추가한다.
6. `doctor`를 추가한다.
