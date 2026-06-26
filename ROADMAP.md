# MacDog Roadmap

## 제품 방향

MacDog는 Codex의 5시간/주간 사용량을 메뉴바에서 즉시 감지하게 해주는 macOS 유틸리티입니다. 작은 강아지 러너가 메뉴바에 상주하고, 사용량이 높아질수록 더 빠르게 움직입니다. 기본 캐릭터는 `Codex Pup`이며, 클릭하면 현재 사용률, 남은 비율, reset 시각, 갱신 상태를 보여줍니다.

현재 프로젝트 이름은 `MacDog`이며, Codex 사용량 모니터는 첫 번째 기능 모듈로 유지합니다. Mac 상태, 배터리 충전 제한, 덮개 닫힘 보호, 데스크톱 펫 기능은 같은 앱 안에서 다룹니다.
메뉴바 러너, 데스크톱 펫, popover 탭 버튼 이미지는 같은 캐릭터 세트에서 파생합니다.

핵심 경험은 다음과 같습니다.

- 터미널에서는 `codex-usage status` 한 줄로 사용량을 확인합니다.
- 메뉴바에서는 러너 속도만 봐도 위험도를 알 수 있습니다.
- 클릭하면 5시간/주간 사용량과 주간 잔여량 추이를 명확히 봅니다.
- Codex Pup의 기본 위치는 메뉴바이고, 사용자가 원할 때만 데스크톱으로 나와 뛰어다닙니다.
- 메뉴바 popover는 Codex, Mac, Sleep, Battery, Settings 탭으로 나뉩니다.
- WidgetKit 코드는 보존하지만 기본 릴리즈 범위에서는 제외합니다. 현재 확인 범위는 source/test/opt-in build 경계까지이며, Apple Developer Program과 App Group provisioning이 필요한 실제 위젯 UI는 확인하지 못했습니다. 이 검수는 현재 구현 계획에서 제외합니다.

## 진행 상태 요약

상태 표기는 다음 기준을 사용합니다.

- `구현 완료`: 코드 경로가 존재하고 기본 동작이 연결되어 있습니다.
- `자동 검증 완료`: 테스트, 빌드, dry-run, 스크립트 검증처럼 자동화 가능한 검증이 통과했습니다.
- `수동 검수 필요`: macOS UI, 위젯 갤러리, 실제 설치/LaunchAgent처럼 사용자 환경을 직접 바꾸거나 눈으로 확인해야 합니다.
- `후속 예정`: 아직 제품 기능으로 구현하지 않았거나 다음 milestone에서 다룹니다.
- `실험 기능`: 권한, 시스템 정책, private/저수준 제어 가능성이 있어 기본 기능과 분리합니다.

| 영역 | 범위 | 현재 상태 | 남은 항목 |
| --- | --- | --- | --- |
| Codex Usage CLI | app-server 사용량 조회, JSON 출력, cache writer, doctor | 구현 완료, 자동 검증 완료 | live app-server protocol drift 발생 시 fixture 갱신 |
| Shared Cache | app-owned cache, weekly history, stale/error snapshot | 구현 완료, 자동 검증 완료 | cache schema 변경 시 회귀 테스트 유지 |
| Menu Bar App | status item, runner, popover, refresh, placement | 구현 완료, 자동 검증 완료, v1.3.0 smoke 완료 | 다음 release에서 실제 앱 화면 재확인 |
| Codex Pup Character | 메뉴바 이미지, 데스크톱 펫, 탭 버튼 이미지 | 구현 완료, 자동 검증 완료 | 캐릭터 변경 시 전체 세트 동시 교체 |
| Desktop Pet | 드래그 저장, 좌클릭 popover, 우클릭 메뉴, 화면 보정 | 구현 완료, 자동 검증 완료 | 캐릭터/펫 변경 시 실제 동작 재확인 |
| Mac Utility Tabs | Mac 상태, 잠들지 않기, 배터리, 설정 탭 | 구현 완료, 자동 검증 완료, v1.3.0 smoke 완료 | 다음 release에서 탭 전환 재확인 |
| Privileged Helper | 덮개 닫힘 보호와 잠금 화면 설정 변경 보조 | 구현 완료, 자동 검증 완료 | signed/stable 배포 UX는 Apple Developer Program 의존 범위라 현재 구현 계획에서 제외 |
| WidgetKit | optional source/opt-in build 경계 | 기본 릴리즈 제외 | App Group provisioning 이후 실제 위젯 UI 검수 |
| Release Packaging | DMG, checksum, GitHub Release 절차, release smoke | v1.3.0 published asset 교체와 release smoke 완료 | 다음 release에서 published DMG 기준 smoke 반복 |
| v1.3.0 | 알림 중심 사용량 인지와 탭별 UI 개선 | 릴리즈 완료 | 후속 이슈 없음 |
| v1.4.0 | Usage Intelligence: 과거 사용량, 예측, 오버레이, export | P0-P2 구현 완료, 자동 검증 완료 | 실제 v1.4.0 앱 UI smoke와 release smoke |

## v1.3.0: 알림 중심 사용량 인지와 탭별 UI 개선

`v1.3.0`은 MacDog를 열지 않아도 Codex 사용량 위험 구간을 놓치지 않고, popover를 열었을 때 각 탭의 현재 상태와 다음 행동이 더 빨리 읽히게 만드는 범위입니다.

세부 구현 범위와 검증 경계는 [Docs/V130NotificationAndTabUIPolish.md](Docs/V130NotificationAndTabUIPolish.md)에 둡니다.
릴리즈 준비 감사와 릴리즈 실행 스텝은 [Docs/V130ReleaseReadiness.md](Docs/V130ReleaseReadiness.md)에 둡니다.
이 섹션은 v1.3.0의 알림/탭 UI 작업 범위, 제외 경계, 검증 기준, 완료 결과를 고정합니다.

v1.3.0 구현 범위:

1. Codex 사용량 알림 MVP를 로컬 알림으로 다룹니다.
   - 80% 이상: 사용량 높음
   - 95% 이상: 한도 임박
   - limit 상태: 한도 도달
   - reset 30분 전: 회복 시점 안내
2. 알림은 사용자가 설정 탭에서 켜고 macOS 알림 권한을 승인한 뒤에만 발송합니다.
3. 같은 window 안에서 같은 이벤트 알림이 반복 폭주하지 않도록 이벤트별 1회 dedupe와 reset 경계를 둡니다.
4. Codex 탭은 5시간/주간 reset countdown, 현재 위험 기준, 알림 기준을 더 명확히 보여줍니다.
5. Mac, 잠들지 않기, 배터리, 설정 탭은 각각 현재 상태 요약과 다음 행동을 먼저 보이게 정리합니다.
6. 설정 탭에는 테스트 알림 버튼을 넣지 않습니다. UI 복잡성을 줄이고 실제 알림 검수는 별도 UI 검수 단계로 분리합니다.
7. 필요한 구조 정리는 알림 정책, 알림 상태 저장, 탭별 view model/section helper처럼 v1.3.0 기능을 직접 돕는 범위로 제한합니다.
8. Apple Developer 계정이 필요한 기능명은 v1.3.0 로드맵, 완료 조건, 후속 이슈에 나열하지 않습니다.

v1.3.0 완료 순서:

- v1.3.0 (1) Apple Developer 계정 필요 여부와 로컬 알림 경계를 먼저 고정합니다.
- v1.3.0 (2) 알림 정책 모델과 이벤트별 1회 dedupe 계약을 테스트로 고정합니다.
- v1.3.0 (3) 설정 탭 알림 섹션과 권한 상태 UI를 추가하되 테스트 알림 버튼은 제외합니다.
- v1.3.0 (4) cache refresh 이후 로컬 알림 발송 경로를 연결합니다.
- v1.3.0 (5) Codex 탭 1차 UI 개선을 끝내고 첫 UI 검수를 수행합니다.
- v1.3.0 (6) Mac, 잠들지 않기, 배터리, 설정 탭 UI 개선을 순서대로 진행합니다.
- v1.3.0 (7) 전체 탭 UI 검수와 screenshot/focused test 회귀 확인을 수행합니다.
- v1.3.0 (8) README/ROADMAP/AGENTS 용어와 제외 경계를 정리하고 구현 범위 검증을 닫습니다.

v1.3.0 릴리즈 결과:

- Release tag: `v1.3.0`
- Release head: `a689fe2e5ae6416a5864ebf9097a8890e2d95a4a`
- GitHub Release 상태: publish 완료
- Published asset: `MacDog-1.3.0.dmg`, `MacDog-1.3.0.dmg.sha256`
- 설치 smoke: published DMG를 Finder에서 열고 `MacDog.app`을 `Applications`로 drag-and-drop한 뒤 `/Applications/MacDog.app` 기준 첫 실행, popover 주요 탭 전환, CLI/cache LaunchAgent, 로그인 항목, release final-state를 확인했습니다.
- Finder 검색 중복: release smoke cleanup 뒤 `/Applications/MacDog.app` 하나만 남는 것을 확인했습니다.

v1.3.0 Apple Developer 계정 필요 여부와 로컬 알림 경계:

- 결론: v1.3.0 알림 MVP는 Apple Developer 계정 없이 가능한 `UserNotifications` 기반 로컬 알림만 사용합니다.
- MacDog 앱이 app-owned usage cache를 읽어 사용자 Mac 안에서 알림 이벤트를 판단합니다.
- 알림은 기본 꺼짐이며, 사용자가 설정 탭에서 켜고 macOS 알림 권한을 승인한 뒤에만 표시합니다.
- Apple Developer 계정이 필요한 기능명은 v1.3.0 문서/로드맵/검증 항목/후속 이슈에 나열하지 않습니다.
- 로컬 알림만으로 구현할 수 없다는 사실이 확인되면 해당 단계에서 중단하고 뒤 단계는 진행하지 않습니다.
- Codex 사용량 JSON/cache/app-server 계약은 변경하지 않습니다.

v1.3.0 제외 경계:

- `codex-usage status --json` schema 변경
- app-owned cache schema 변경
- Codex app-server JSON-RPC 해석 계약 변경
- 새 Codex bucket을 기본 UI에 추가
- Apple Developer Program이 필요한 기능 또는 배포/권한 흐름
- Apple Developer 계정이 필요한 기능명 또는 후속 이슈 나열
- 장기 history export
- 자동 모델 전환 힌트
- 사용자 명시 요청 없는 GUI 실행, 설치/LaunchAgent/helper 변경, DMG drag-and-drop 설치 검수, 장시간 테스트, push

v1.3.0 완료 기준:

- 알림 정책과 dedupe 규칙이 fixture/unit test로 검증됩니다.
- 알림 설정 UI가 권한 요청, 켜짐/꺼짐, reset 30분 전 알림 여부를 명확히 표시합니다.
- 각 탭의 UI 개선은 demo/screenshot renderer 또는 focused SwiftUI test로 회귀를 막습니다.
- 실제 UI 검수는 release smoke 증거로만 기록합니다. 실행하지 않았다면 `UI 확인 미수행`으로 보고합니다.
- README/ROADMAP/AGENTS와 v1.3.0 세부 문서의 알림, cache, Apple Developer 계정 경계 용어가 일치합니다.
- Apple Developer 계정이 필요한 기능명, 장기 history export, 자동 모델 전환 힌트가 v1.3.0 완료 조건/후속 이슈에 섞이지 않았음을 확인합니다.
- `git diff --check`, 관련 focused `swift test`, 전체 `swift test`, 필요한 경우 Xcode Debug build가 통과합니다.
- `./script/verify_v130_local_notification_boundary.sh --self-test`가 통과합니다.
- `./script/verify_v130_release_readiness.sh --self-test`가 v1.3.0 잔여 이슈 정리와 릴리즈 실행 스텝을 확인합니다.

## v1.4.0: Usage Intelligence

`v1.4.0`은 Codex 사용량을 "현재 잔여량 확인"에서 "과거 패턴과 현재 속도를 함께 이해하는 도구"로 확장합니다.
세부 이슈와 데이터 경계는 [Docs/V140UsageIntelligence.md](Docs/V140UsageIntelligence.md)에 둡니다.
릴리즈 잔여 이슈와 실행 스텝은 [Docs/V140ReleaseReadiness.md](Docs/V140ReleaseReadiness.md)에 둡니다.

v1.4.0 구현 범위:

1. reset window 기준 과거 사용량 요약을 최소 데이터셋으로 저장합니다.
   - 기존 `usage.json` cache schema와 `usage-weekly-history.json` v1 그래프 계약은 breaking change 없이 유지합니다.
   - 새 history record는 `limitId`, `windowDurationMins`, `resetsAt`를 key로 삼습니다.
   - raw log가 아니라 그래프/비교에 필요한 축약값만 저장합니다.
2. 현재 사용 속도를 기반으로 reset 전 예상 사용률과 위험도를 계산합니다.
   - 최근 sample delta로 현재 pace를 계산합니다.
   - reset까지 남은 시간 기준 예상 final usage를 표시합니다.
   - sample이 부족하면 예측하지 않고 "샘플 대기" 상태로 둡니다.
3. 과거 weekly window를 0-7일 timeline에 오버레이합니다.
   - 각 7일 끝의 사용률/잔여율 marker를 표시합니다.
   - window final usage를 별도 marker로 표시합니다.
   - hover/tap으로 과거 데이터 값을 확인합니다.
4. 과거 데이터와 오버레이 그래프를 이미지로 export하거나 복사합니다.
   - export 이미지는 선택 window, 날짜 범위, 사용률/잔여율 marker만 포함합니다.
   - auth/session material, raw app-server 응답, raw log line, local path는 포함하지 않습니다.
5. 대량 로그나 backfill 처리는 "v1.4.0 최소 history record 생성"을 기준으로 합니다.
   - UI와 분석은 생성된 history record만 읽습니다.
   - raw log 원본 저장, token/session material 저장, 로컬 SQLite 추정치와 공식 사용량 혼합은 제외합니다.
6. 플랜/가격 tier 인사이트는 v1.4.0 범위에서 제외합니다.
   - 현재 조회 경로는 `Plan: pro` 같은 raw `planType` 수준만 확인됐습니다.
   - `Pro $100`/`Pro $200` 구분 근거가 없으므로 v1.4.0 이슈로 넣지 않습니다.

v1.4.0 P0-P2 완료 순서:

- v1.4.0 (1) v1.4.0 baseline 정렬: VERSION/docs/backlog/source roadmap을 맞춥니다.
- v1.4.0 (2) 플랜 tier 제외 경계 고정: `Plus`/`Pro $100`/`Pro $200` 구분 불가를 확정하고 raw `planType` 기존 표시만 유지합니다.
- v1.4.0 (3) reset window history 계약: `limitId`, `windowDurationMins`, `resetsAt` 기준 최소 history record schema를 정의하고 기존 cache/history 파일은 breaking change 없이 유지합니다.
- v1.4.0 (4) history store 구현: 별도 history 파일, atomic write, retention, dedupe, schema migration, 민감정보 미저장 테스트를 갖춥니다.
- v1.4.0 (5) cache writer 축약 append: live fetch/cache writer 성공 시 weekly sample을 reset window history record로 축약 저장합니다.
- v1.4.0 (6) 현재 pace 예측: 최근 sample delta로 reset 전 예상 final usage를 계산하고 sample 부족/stale/error 상태를 분리합니다.
- v1.4.0 (7) 과거 window 오버레이 모델: 과거 weekly window 선택, 0-7일 timeline 정규화, 7일 끝 marker, final usage marker를 생성합니다.
- v1.4.0 (8) Codex 탭 UI 반영: 지난 window picker, 현재/지난/비교 전환, hover/tap label을 연결합니다.
- v1.4.0 (9) 그래프 이미지 export/copy: 화면에 보이는 그래프를 PNG로 복사/저장하고 민감정보 metadata를 제외합니다.
- v1.4.0 (10) 대량 로그/backfill 경계: raw log 저장 없이 생성된 history record만 UI/분석에 사용합니다.
- v1.4.0 (11) 검증 스크립트와 fixture: cache/privacy/history 계약, fixture, focused Swift tests를 묶습니다.
- v1.4.0 (12) 릴리즈 준비 문서/UI smoke: README/ROADMAP/Docs와 screenshot renderer 계약을 정리하고 실제 UI 확인 여부를 분리 보고합니다.

v1.4.0 제외 경계:

- `codex-usage status --json` schema breaking change
- 기존 `usage.json` cache schema breaking change
- raw app-server response 저장
- auth token, cookie, session material, auth header 저장 또는 출력
- 공식 Codex 사용량과 로컬 SQLite 추정치 혼합 표시
- `Plus`/`Pro $100`/`Pro $200` 플랜 tier 인사이트
- 대량 raw log를 앱 runtime cache나 image export metadata에 보관
- Apple Developer 계정이 필요한 기능 또는 배포/권한 흐름
- WidgetKit 실제 UI 완료 조건 포함

v1.4.0 완료 기준:

- reset window history 저장소는 atomic write, retention, dedupe, schema migration test를 갖습니다.
- 현재 pace와 예상 final usage는 sample 부족/오류/stale 상태를 분리해 test로 검증합니다.
- 과거 그래프 오버레이는 reset window별 필터링, 0-7일 정규화, 7일 끝 marker, final usage marker를 focused Swift tests로 검증합니다.
- 이미지 export는 auth/session material, raw app-server 응답, raw log, local path를 포함하지 않는지 테스트합니다.
- README/ROADMAP/Docs가 v1.4.0 데이터 경계와 cache/privacy 계약을 같은 용어로 설명합니다.
- `./script/verify_v140_usage_intelligence_contract.sh --self-test`가 fixture, source guard, focused Swift tests를 통과합니다.
- README screenshot renderer는 demo/live Codex popover 모두 reset window history를 주입하지만, 실제 popover UI smoke는 별도 수동 검수로 남깁니다.
- `git diff --check`, 문서 lint, focused `swift test`, 전체 `swift test`, 필요한 경우 Xcode Debug build가 통과합니다.
- 실제 UI 확인을 하지 않았다면 `UI 확인 미수행`으로 보고합니다.

## RunCat UI 참고 방향

RunCat의 참고점은 "메뉴바에 작고 귀여운 러너가 계속 움직이며, 시스템 부하에 따라 속도가 달라지는 상태 표시"입니다. 이 프로젝트는 CPU 부하 대신 Codex 사용률을 속도 입력으로 사용합니다.

적용할 원칙:

- 메뉴바에서는 텍스트보다 움직임을 우선합니다.
- 기본 상태는 방해되지 않아야 합니다.
- 사용량이 높아질수록 속도, 색상, popover 경고 단계가 함께 강해집니다.
- 러너는 16-22pt 높이에서 선명해야 합니다.
- 프레임 애니메이션은 현재 캐릭터 세트의 8프레임을 사용합니다.
- 메뉴바 공간을 많이 쓰지 않습니다.
- 기본 캐릭터는 고양이가 아니라 Codex Pup 강아지 실루엣으로 갑니다.

적용하지 않을 것:

- RunCat의 고양이 캐릭터를 그대로 복제하지 않습니다.
- WidgetKit 위젯에 실시간 달리기 애니메이션을 기대하지 않습니다.

## 사용량 단계

러너 속도는 5시간 사용률과 주간 사용률 중 더 높은 값을 기준으로 정합니다.

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

## 런타임 검증 경계

짧은 runtime smoke가 필요하면 아래 명령으로 앱 실행과 CPU/RSS 샘플링을 함께 확인합니다.

```sh
MACDOG_APP_VERSION=<version> script/build_and_run.sh --verify-runtime 10
MACDOG_APP_VERSION=<version> script/build_and_run.sh --verify-floating-pet-runtime 10
```

이미 실행 중인 앱을 건드리지 않고 읽기 전용 샘플만 확인하려면 아래 명령을 사용합니다.

```sh
script/sample_existing_runtime_resources.sh --samples 5 --interval 1
```

runtime 계약은 script/verify_runtime_contract.sh로 자동 검증합니다.
장시간 검증은 앱 실행과 사용자 환경 상태를 바꾸므로 명시 요청이 있을 때만 실행합니다.

## 캐릭터 로드맵

러너 변경은 "메뉴바 16-22pt 크기에서도 한눈에 읽히는가"를 기준으로 합니다.
현재 앱은 Codex Pup 하나만 유지해 설정이 장난감처럼 느껴지지 않게 합니다.
