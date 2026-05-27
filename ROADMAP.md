# MacDog Roadmap

## 제품 방향

MacDog는 Codex의 5시간/주간 사용량을 메뉴바에서 즉시 감지하게 해주는 macOS 유틸리티다. RunCat처럼 작은 러너가 메뉴바에 상주하고, 사용량이 높아질수록 더 빠르게 움직인다. 기본 캐릭터는 강아지 러너 `Codex Pup`이며, 클릭하면 현재 사용률, 남은 비율, reset 시각, credit 상태를 보여준다.

현재 프로젝트 이름은 `MacDog`이며, Codex 사용량 모니터는 첫 번째 기능 모듈로 유지한다. 이후에는 Mac 상태와 생활 편의 기능을 강아지 펫 경험 안에 통합한다.

핵심 경험은 다음과 같다.

- 터미널에서는 `codex-usage status` 한 줄로 사용량을 확인한다.
- 메뉴바에서는 러너 속도만 봐도 위험도를 알 수 있다.
- 클릭하면 5시간/주간 사용량을 명확히 본다.
- 메뉴바 우클릭으로 제공하는 제어는 나중에 데스크톱 플로팅 펫에서도 같은 의미로 동작한다.
- Codex Pup의 기본 위치는 메뉴바이고, 사용자가 원할 때만 데스크톱으로 나와 뛰어다닌다.
- MacDog 전환 이후에는 Codex 사용량뿐 아니라 PC 사용량, 배터리 충전 제한, 덮개를 덮었을 때 잠금/잠자기 방지 같은 Mac 유틸리티 기능을 같은 앱 안에서 다룬다.
- 메뉴바 popover는 왼쪽의 현재 상태/주요 기능 영역과 오른쪽의 메뉴 버튼/모듈 전환 영역으로 확장한다.
- 위젯은 빠른 glance 용도이며, 지속 애니메이션은 메뉴바 앱이 담당한다.

## 진행 상태 요약

상태 표기는 다음 기준을 사용한다.

- `구현 완료`: 코드 경로가 존재하고 기본 동작이 연결되어 있다.
- `자동 검증 완료`: 테스트, 빌드, dry-run, 스크립트 검증처럼 자동화 가능한 검증이 통과했다.
- `수동 검수 필요`: macOS UI, 위젯 갤러리, 실제 설치/LaunchAgent처럼 사용자 환경을 직접 바꾸거나 눈으로 확인해야 한다.
- `후속 예정`: 아직 제품 기능으로 구현하지 않았거나 다음 milestone에서 다룬다.
- `실험 기능`: 권한, 시스템 정책, private/저수준 제어 가능성이 있어 기본 기능과 분리한다.

| Milestone | 범위 | 현재 상태 | 남은 항목 |
| --- | --- | --- | --- |
| 0 | 기술 검증 | 구현 완료 | app-server 프로토콜 변경 감시 |
| 1 | CLI MVP | 구현 완료, 자동 검증 완료 | live 조회 실패 시 안내 문구 지속 보강 |
| 2 | Shared Cache | 구현 완료, 자동 검증 완료 | cache schema 변경 시 회귀 테스트 유지 |
| 3 | Menu Bar App MVP | 구현 완료, 자동 검증 완료 | 실제 메뉴바 UI 수동 검수 |
| 4 | RunCat-like Polish | 1차 구현 완료 | 장시간 CPU/RAM/배터리 영향 검증 |
| 5 | 펫 상호작용 계층 | 구현 완료 | 플로팅 펫 고도화와 계속 동기화 |
| 6 | 데스크톱 플로팅/로밍 펫 | 1차 구현 완료, 자동 검증 완료 | 실제 데스크톱 동작 수동 검수 |
| 7 | WidgetKit | 구현 완료, 자동 검증 완료 | 위젯 갤러리 추가와 클릭 동작 수동 검수 |
| 8 | 배포와 설치 | 자동 검증 완료 | 실제 설치/삭제/LaunchAgent 수동 검수 |
| 9 | MacDog 리브랜딩 | 구현 완료, 자동 검증 완료 | 기존 사용자 migration 필요 시 별도 처리 |
| 10 | MacDog 시스템 유틸리티 모듈 | RunCat식 상세 Mac 상태/배터리/잠자기 방지 4대 세션 UI/자동 trigger 1차 확장/closed-display 조사/Charge Limit 지원 감지와 설정 연결 구현 완료 | trigger 세부 설정, 충전 제어 연구 스파이크 |
| 11 | 플로팅 펫 상호작용 고도화 | 우클릭 메뉴 위치와 드래그/로밍 충돌 개선 구현 완료 | 실제 데스크톱 동작 수동 검수 |
| 12 | 확장 기능 | 후속 예정 | history, 알림, custom runner 등 |

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
~/Library/Application Support/MacDog/usage.json
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
코덱스 사용량
5시간  15% 사용 / 85% 남음 / 초기화 01:27
주간    38% 사용 / 62% 남음 / 초기화 토 09:19
플랜    pro
크레딧  0
업데이트 22:44
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
- "5시간 기준", "주간 기준", "최대 기준" 표시 모드 추가
- high usage에서 부드러운 alert affordance 추가
- reduced motion 접근성 옵션 추가
- menu bar notch/overflow 환경 확인
- retina/non-retina asset 품질 확인

완료 기준:

- 기본 UI는 RunCat처럼 가볍고 장난스럽지만, popover는 명확한 개발 도구처럼 보인다.
- 80% 이상 상태가 눈에 띄지만 과하게 산만하지 않다.
- 장시간 실행 시 CPU/RAM 사용량이 낮다.

## Milestone 5: 펫 상호작용 계층

목표: 메뉴바 러너를 "상태 표시 아이콘"에서 "코덱스 펫"으로 확장하되, 모든 상호작용을 나중에 데스크톱 플로팅 펫이 재사용할 수 있는 공통 동작으로 분리한다.

방향:

- 메뉴바는 계속 1차 표시 영역이다.
- 메뉴바는 Codex Pup의 기본 위치 역할을 한다.
- 데스크톱 플로팅 펫은 별도 제품이 아니라 같은 Codex Pup이 사용자의 명령에 따라 밖으로 나온 2차 표시 영역이다.
- 메뉴바 우클릭에서 가능한 기능은 플로팅 펫의 우클릭 메뉴 또는 플로팅 패널에서도 가능해야 한다.
- 팝오버는 사용량 상세와 설정을 보여주는 공통 패널로 유지한다.
- 캐릭터 반응은 사용량 상태를 돕는 수준에 머물고, 사용량 모니터링 도구의 명확성을 해치지 않는다.
- 표시 영역 전환은 명시적이어야 한다. 사용자가 켜면 데스크톱에서 뛰고, 끄면 메뉴바에만 남는다.

공통 동작 계약:

| 동작 | 메뉴바 진입점 | 플로팅 펫 진입점 | 결과 |
| --- | --- | --- | --- |
| 사용량 상세 보기 | 좌클릭, 우클릭 메뉴 | 좌클릭, 우클릭 메뉴 | 같은 사용량 상세 패널 표시 |
| 지금 새로고침 | 우클릭 메뉴, 상세 패널 | 우클릭 메뉴, 상세 패널 | 실시간 새로고침 요청 |
| 러너 속도 기준 | 상세 패널, 우클릭 하위 메뉴 | 상세 패널, 우클릭 하위 메뉴 | `RunnerPreferences.displayBasis` 변경 |
| 움직임 줄이기 | 상세 패널, 우클릭 메뉴 | 상세 패널, 우클릭 메뉴 | `RunnerPreferences.reducedMotion` 변경 |
| 펫 애니메이션 일시 정지 | 우클릭 메뉴 | 우클릭 메뉴 | 애니메이션만 멈추고 polling은 유지 |
| 데스크톱 펫 보기 | 우클릭 메뉴 | 해당 없음 | Codex Pup을 데스크톱 표시 영역에 표시 |
| 메뉴바로 돌아가기 | 우클릭 메뉴 | 우클릭 메뉴 | 데스크톱 표시 영역을 닫고 메뉴바만 유지 |
| 종료 | 우클릭 메뉴 | 우클릭 메뉴 | 앱 종료 |

작업:

- `PetAction` 또는 동등한 명령 모델 정의
- 메뉴바 상태 항목 우클릭 메뉴 추가
- 팝오버 내부 설정과 우클릭 메뉴가 같은 설정 저장소를 사용하게 정리
- 새로고침, 상세 보기, 표시 영역 전환, 종료 같은 앱 명령을 표시 영역에 독립적인 controller로 분리
- 펫 상태 모델 추가: 여유, 활발, 빠름, 질주, 한도, 오래됨, 오류, 새로고침 중
- Codex Pup 상태 라벨과 도움말 문구를 펫 상태 모델에서 생성
- 데스크톱 펫 표시 여부를 설정으로 저장
- 동작별 단위 테스트 또는 controller-level smoke test 추가

완료 기준:

- 메뉴바 좌클릭은 기존처럼 상세 popover를 연다.
- 메뉴바 우클릭은 공통 action 메뉴를 연다.
- 우클릭 메뉴에서 바꾼 설정이 popover와 애니메이션에 즉시 반영된다.
- 이 milestone에서 만든 동작은 데스크톱 표시 영역 구현이 직접 재사용할 수 있다.
- 데스크톱 펫 표시 동작은 Milestone 6의 표시 영역과 연결한다.
- Codex 사용량 JSON schema와 cache schema는 변경하지 않는다.

## Milestone 6: 데스크톱 플로팅/로밍 펫

목표: 메뉴바 Codex Pup과 같은 행동/설정을 공유하는 작은 데스크톱 플로팅 펫을 실험 기능으로 제공한다.

현재 상태:

- 1차 MVP 구현 완료.
- 메뉴바 우클릭의 `데스크톱 펫 보기`로 플로팅 펫을 표시한다.
- 플로팅 펫 우클릭의 `메뉴바로 돌아가기`로 데스크톱 표시 영역을 닫는다.
- 40프레임 sprite resource를 사용한다.
- 플로팅 펫은 click, right-click, drag 위치 저장, 화면 경계 안 로밍 이동을 지원한다.
- 움직임 줄이기와 애니메이션 일시 정지 설정을 반영한다.
- `script/build_and_run.sh --verify-floating-pet-runtime`으로 플로팅 펫 모드 CPU/RSS 샘플을 확인한다.

방향:

- 플로팅 펫은 기본 비활성화 상태로 시작한다.
- 메뉴바 우클릭의 `데스크톱 펫 보기`로 켠다.
- `메뉴바로 돌아가기`를 선택하면 데스크톱 펫은 사라지고 기존 메뉴바 러너만 남는다.
- 작은 borderless `NSPanel` 또는 동등한 AppKit window를 사용한다.
- 드래그로 위치를 옮길 수 있고, 마지막 위치를 저장한다.
- 1차 구현은 작은 플로팅 panel과 화면 안에서 짧게 뛰어다니는 roaming motion을 포함한다.
- 항상 위에 띄우기 여부는 후속 옵션으로 둔다.
- 사용량 조회, cache, preference, action은 메뉴바 앱과 공유한다.

작업:

- 플로팅 펫 window/controller 추가
- Codex Pup runner view를 메뉴바 렌더링과 독립적으로 재사용할 수 있게 정리
- 드래그 이동과 위치 저장 구현
- 플로팅 펫 우클릭 메뉴 연결
- 플로팅 펫 클릭 시 공통 사용량 상세 패널 표시
- 화면 밖 위치 복구 로직 추가
- 움직임 줄이기, 애니메이션 일시 정지, 오래됨/오류 상태 반영
- 로밍 이동은 화면 경계, Dock/menu bar 영역, 다중 모니터를 고려해 제한된 안전 영역 안에서만 움직이게 한다.
- CPU/RAM sample 검증 스크립트에 floating pet 모드 추가

완료 기준:

- 메뉴바에서 가능한 주요 제어가 플로팅 펫에서도 가능하다.
- 플로팅 펫을 꺼도 메뉴바 앱과 CLI 동작에 영향이 없다.
- 사용자가 원하지 않으면 Codex Pup은 메뉴바에서만 움직인다.
- 플로팅 펫 위치가 재실행 후 복원된다.
- 화면 해상도 변경 후에도 펫이 화면 밖에 고정되지 않는다.
- 장시간 실행 시 CPU/RAM 사용량이 낮다.
- UI 확인을 수행한 경우에만 실제 화면 검수 완료로 보고한다.

## Milestone 7: WidgetKit

목표: 데스크톱/알림 센터에서 사용량을 빠르게 확인한다.

현재 상태:

- SwiftPM `MacDogWidget` library에 timeline provider와 small/medium view 지원 코드가 있다.
- 메뉴바 앱 번들은 `macdog://open` URL scheme을 받아 popover를 열 수 있다.
- 실제 `.appex` 배포 경계는 `Docs/WidgetPackaging.md`에 정리했다.
- `MacDog.xcodeproj`에 `MacDogWidgetHost` macOS app target과 `MacDogWidgetExtension` app-extension target이 있다.
- `Apps/MacDogWidgetExtension`에 Widget Extension entrypoint, Info.plist, entitlement가 있다.
- `script/verify_widget_packaging.sh`로 Xcode host/extension build와 embedded `.appex` 산출물을 검증한다.
- `MacDogWidgetPresentationTests`로 empty/stale/error/updated 위젯 상태 표현을 검증한다.
- App Group cache URL helper는 구현했고, extension target은 `group.com.dhseo.macdog.MacDog`를 사용한다.
- 실제 데스크톱/알림 센터 위젯 갤러리 추가와 클릭 UI 검수는 아직 수동 검증 항목으로 남긴다.
- 설치 스크립트는 `MacDog.app`과 CLI를 설치하며, 앱 번들 안에 WidgetKit extension을 포함한다.

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

## Milestone 8: 배포와 설치

목표: 개인 Mac에서 반복 설치 없이 안정적으로 쓴다.

작업:

- CLI 설치 스크립트 작성
- 앱 bundle 생성
- LaunchAgent 옵션 제공
- 로그인 시 자동 실행 옵션 추가
- uninstall 스크립트 작성
- 설치/삭제 후 상태 검증 스크립트 작성
- README 작성
- 문제 해결 가이드 작성

완료 기준:

- 새 터미널에서 `codex-usage status`가 바로 동작한다.
- 앱을 로그인 항목으로 등록할 수 있다.
- 삭제 시 cache/LaunchAgent/symlink 정리가 가능하다.
- 설치/삭제 후 상태를 스크립트로 확인할 수 있다.

## Milestone 9: MacDog 리브랜딩 후속 정리

목표: `MacDog` 이름을 기준으로 repo, package, app identity, 설치 경로를 정리하고 기존 Codex 사용량 기능의 migration 경계를 확정한다.

방향:

- 레포와 프로젝트 이름은 `MacDog`를 기준으로 둔다.
- 기존 Codex 사용량 기능은 `Codex` 또는 `Codex Usage` 모듈로 유지한다.
- 앱 이름, bundle display name, README, ROADMAP, 설치 스크립트, 빌드 산출물 이름을 새 이름에 맞춘다.
- 기존 CLI 명령 `codex-usage`는 호환성을 유지한다.
- 기존 deep link `codexusage://`는 `macdog://` 전환 중 호환 scheme으로만 유지한다.
- 기존 cache/schema/app-server 해석 계약은 리브랜딩 과정에서 깨지 않도록 별도 점검한다.

작업:

- repo/project/display name 변경 범위 결정
- `MacDog` 앱 이름과 bundle id migration 전략 정리
- `Codex Pup` 명칭을 MacDog의 기본 강아지 캐릭터로 유지할지, 기능별 별칭으로 둘지 결정
- README/ROADMAP/스크립트/설치 경로 이름 정리
- 기존 사용자 설정과 cache 경로 migration 또는 backward compatibility 처리

완료 기준:

- 새 사용자가 `MacDog` 이름으로 빌드, 실행, 설치 흐름을 이해할 수 있다.
- 기존 Codex 사용량 기능이 리브랜딩 후에도 동일하게 동작한다.
- 이름 변경으로 기존 cache, preference, CLI 사용자가 갑자기 깨지지 않는다.

## Milestone 10: MacDog 시스템 유틸리티 모듈

목표: Codex 사용량 외에도 MacDog 안에서 매일 쓰는 Mac 상태/편의 기능을 확장한다.

현재 상태:

- Mac 상태 1차 모듈 구현 완료.
- Popover 오른쪽 모듈 전환에서 `Codex`와 `Mac`을 선택해 탐색한다.
- Mac 상태 모듈에 CPU load와 system/user/idle breakdown, 메모리 세부값, 디스크 사용률, 네트워크 누적 I/O와 현재 속도, 로컬 IP를 표시한다.
- 배터리 읽기 전용 상태로 배터리 비율, 충전 여부, 전원 연결 여부, 완충/방전 예상 시간, cycle count, 온도를 표시한다.
- 일반 잠자기 방지는 IOKit power assertion으로 시스템 idle sleep 방지 토글을 제공한다.
- 잠자기 방지 4대 세션 UI는 항상 금지, 충전 중 금지, 시간 기준 금지, Codex 앱 실행 중 금지를 제공한다.
- 시간 기준 세션은 30분, 1시간, 2시간 preset을 제공하고 만료 시 자동으로 꺼진다.
- 자동 trigger 1차 확장은 전원 연결, Codex 앱 실행, 충전 80% 미만, CPU 80% 이상, 네트워크 100KB/s 이상, 외장/네트워크 볼륨 연결 조건을 제공한다.
- Apple native Charge Limit은 macOS 26.4 이상, Apple silicon 조건을 기준으로 지원 가능 여부를 표시한다.
- 충전 한도 설정 연결은 공개 제어 API를 호출하지 않고 macOS 배터리 설정 화면을 여는 방식으로 제공한다.
- 각 모듈 on/off와 세부 설정은 후속 작업으로 남긴다.

후보 모듈:

- PC 사용량: CPU, 메모리, 디스크, 네트워크 상태 표시
- 배터리: 배터리 상태, 충전 중 여부, 충전 제한 또는 충전 상한 관리
- 잠금/잠자기 방지: 덮개를 덮었을 때 잠금 또는 잠자기를 막는 옵션 검토
- 상태별 강아지 반응: 시스템 부하, 배터리, 충전 상태에 따른 움직임/표정 변화
- 모듈별 메뉴 항목: 메뉴바 popover 오른쪽 메뉴 버튼에서 기능 전환 또는 설정 진입

구현 가능성 정리:

- RunCat식 시스템 모니터 UI는 공개 API/시스템 통계 기반으로 확장 가능하다.
  - CPU 총합, system/user/idle, mini graph
  - 메모리 pressure, app/wired/compressed memory
  - 저장공간 사용량, 네트워크 interface/IP/업로드/다운로드 속도
  - 배터리 비율, 전원 상태, cycle count, 온도 등 읽기 전용 세부 정보
- Amphetamine식 일반 잠자기 제어는 제품 기능으로 확장 가능하다.
  - 수동 세션: 아예 잠자기 금지
  - 전원 조건 세션: 충전 중 또는 전원 연결 중 잠자기 금지
  - 시간 조건 세션: 일정 기준 시간 동안 잠자기 금지
  - 앱 조건 세션: 지정한 앱이 실행 중인 동안 잠자기 금지
  - 세션 preset: 제한 없음, N분, N시간, 특정 시각까지
  - 현재 세션 상세, 세션 종료, 세션 남은 시간 표시
  - display sleep 허용/방지, screen saver/lock 관련 옵션
  - trigger: 앱 실행, 전원 연결, 배터리 threshold, CPU threshold, 네트워크/드라이브 조건
  - 후속 trigger 설정: threshold 사용자 조정, 지정 앱 선택, trigger별 종료/대기 상태 표시
- 덮개를 덮었을 때 잠자기 방지는 별도 설계가 필요하다.
  - 일반 IOKit power assertion보다 민감하며, Apple silicon에서는 helper/script 흐름이 필요할 수 있다.
  - 관리자 권한, 설치/삭제, 실패 시 복구, 다른 잠자기 앱과 충돌 가능성을 함께 설계해야 한다.
  - 현재 결론은 [Docs/ClosedDisplayResearch.md](Docs/ClosedDisplayResearch.md)에 기록한다.
- AlDente식 충전 제한 직접 제어는 연구 스파이크로 분리한다.
  - 기존 서드파티 앱은 SMC/IOKit low-level 제어와 privileged helper를 사용하는 방식으로 보인다.
  - MacDog 기본 제품 기능으로 바로 넣지 않고, 공개 API/Shortcuts/시스템 설정 연동 가능성을 먼저 확인한다.
  - SMC/helper 방식은 충전 원복, uninstall, macOS 업데이트 호환성, 배터리 calibration 리스크를 문서화한 뒤 별도 승인으로만 진행한다.

후속 개발 순서:

1. 잠자기 방지 고급 trigger 설정: threshold 사용자 조정, 지정 앱 선택, trigger별 종료 조건
2. Amphetamine식 잠자기 방지 세션 상세 polish
3. display sleep/screen saver/lock 관련 옵션 정리
4. closed-display readiness 표시: 전원, 외부 디스플레이, 외부 입력 장치 감지 가능성 조사
5. Charge Limit 읽기/쓰기 가능성 research spike
6. SMC/helper 방식은 마지막 선택지로 별도 milestone 분리

원칙:

- Codex 사용량 모듈은 첫 기능으로 유지하고, 시스템 모니터링은 MVP 이후 모듈로 추가한다.
- 배터리 충전 제한, 잠자기 방지처럼 macOS 권한이나 시스템 정책이 걸리는 기능은 가능 범위와 위험을 먼저 조사한다.
- 강아지 애니메이션은 정보를 돕는 수준에 머물고, 시스템 설정 변경은 명확한 UI와 확인 흐름을 둔다.
- 각 모듈은 독립적으로 켜고 끌 수 있어야 한다.

완료 기준:

- 메뉴바 popover에서 Codex 사용량과 시스템 유틸리티 모듈을 구분해 탐색할 수 있다.
- 시스템 권한이 필요한 기능은 실패/권한 부족/지원 불가 상태를 명확히 표시한다.
- 장시간 실행 시 CPU/RAM/배터리 영향이 낮다.

## Milestone 11: 플로팅 펫 상호작용 고도화

목표: 데스크톱 강아지를 단순 표시 영역이 아니라 직접 조작 가능한 MacDog 표면으로 만든다.

작업:

- 강아지를 드래그 앤 드롭해서 위치를 옮긴다.
- 드래그 종료 후 위치를 저장하고, 재실행 시 복원한다.
- 우클릭 시 메뉴바에서 쓰던 메뉴/패널을 강아지 위치 기준으로 표시한다.
- 강아지가 화면 오른쪽에 있으면 패널을 왼쪽에, 화면 왼쪽에 있으면 패널을 오른쪽에 띄운다.
- 패널이 화면 밖으로 나가지 않도록 안전 영역 안에서 위치를 보정한다.
- 플로팅 펫 우클릭 메뉴와 메뉴바 우클릭 메뉴가 같은 action 모델을 사용하게 유지한다.

완료 기준:

- 사용자는 메뉴바를 열지 않고도 강아지 위치에서 주요 기능을 실행할 수 있다.
- 드래그 이동 중 자동 로밍이 끼어들지 않는다.
- 우클릭 패널은 강아지를 가리지 않고 화면 안에 표시된다.
- 메뉴바와 플로팅 펫의 기능 차이가 문서화된 예외를 제외하고는 없다.

## Milestone 12: 확장 기능

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
6. pet interaction layer
7. desktop floating pet
8. WidgetKit
9. packaging
10. MacDog rebranding
11. MacDog system utility modules
12. floating pet interaction polish
13. optional expansion features

## 리스크

- Codex app-server 프로토콜이 변경될 수 있다.
- WidgetKit은 실시간 애니메이션에 적합하지 않다.
- 메뉴바 애니메이션은 배터리와 CPU 사용량을 조심해야 한다.
- 데스크톱 플로팅 펫은 화면 점유와 집중 방해 리스크가 있으므로 기본 비활성화로 둔다.
- 메뉴바 action과 플로팅 펫 action이 갈라지면 유지보수 비용이 커지므로 공통 command 모델을 먼저 만든다.
- Codex 사용량 정책은 바뀔 수 있으므로 window duration과 limit id를 응답 기반으로 처리해야 한다.
- MacDog 리브랜딩은 bundle id, cache 경로, 사용자 설정 migration을 건드리므로 단계별 호환성 점검이 필요하다.
- 배터리 충전 제한과 덮개 잠금/잠자기 방지 기능은 macOS 버전, 권한, 하드웨어 지원 여부에 따라 구현 가능 범위가 달라질 수 있다.
- 시스템 유틸리티 모듈이 늘어나면 메뉴바 popover가 복잡해질 수 있으므로 오른쪽 메뉴/모듈 전환 구조를 먼저 정리해야 한다.

## 첫 번째 구현 티켓

1. `scripts/codex-usage`를 만든다.
2. app-server JSON-RPC 통신을 구현한다.
3. `status --json`을 먼저 완성한다.
4. fixture test를 추가한다.
5. text formatter를 추가한다.
6. `doctor`를 추가한다.
