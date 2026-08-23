# MacDog Roadmap

## 제품 방향

MacDog는 사용자가 선택한 하나의 AI provider 사용량을 메뉴바에서 즉시 확인하게 해주는 macOS
유틸리티입니다. v1.7.0까지는 Codex 전용이며, v1.8.0은 `Codex` 또는 `Claude` 중 하나만
사용량 mode로 선택합니다. v1.9.0은 설정 visible mode를 `Codex`와 `Grok`만 보여 주고
Claude source는 숨깁니다. 두 provider 동시 사용, 합산, 비교는 고려하지 않습니다.
작은 강아지 러너가 메뉴바에 상주하고 선택한 provider 사용량이 높아질수록 더 빠르게
움직입니다. 기본 캐릭터는 `Codex Pup`이며, 클릭하면 현재 사용률, 남은 비율, reset 시각,
갱신 상태를 보여줍니다.

현재 프로젝트 이름은 `MacDog`이며, Codex 사용량 모니터는 첫 번째 기능 모듈로 유지합니다. Mac 상태, 배터리 충전 제한, 덮개 닫힘 보호, 데스크톱 펫 기능은 같은 앱 안에서 다룹니다.
메뉴바 러너, 데스크톱 펫, popover 탭 버튼 이미지는 같은 캐릭터 세트에서 파생합니다.

핵심 경험은 다음과 같습니다.

- Codex mode에서는 터미널에서 `codex-usage status` 한 줄로 사용량을 확인합니다.
- 메뉴바에서는 러너 속도만 봐도 위험도를 알 수 있습니다.
- 클릭하면 선택한 provider의 단기/주간 사용량과 잔여량 추이를 명확히 봅니다.
- Codex Pup의 기본 위치는 메뉴바이고, 사용자가 원할 때만 데스크톱으로 나와 뛰어다닙니다.
- 메뉴바 popover는 선택 provider 사용량, Mac, Sleep, Battery, Settings 탭으로 나뉩니다.
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
| Menu Bar App | status item, runner, popover, refresh, placement | 구현 완료, 자동 검증 완료, v1.6.0 smoke 완료 | 다음 release에서 실제 앱 화면 재확인 |
| Codex Pup Character | 메뉴바 이미지, 데스크톱 펫, 탭 버튼 이미지 | 구현 완료, 자동 검증 완료 | 캐릭터 변경 시 전체 세트 동시 교체 |
| Desktop Pet | 드래그 저장, 좌클릭 popover, 우클릭 메뉴, 화면 보정 | 구현 완료, 자동 검증 완료 | 캐릭터/펫 변경 시 실제 동작 재확인 |
| Mac Utility Tabs | Mac 상태, 잠들지 않기, 배터리, 설정 탭 | 구현 완료, 자동 검증 완료, v1.6.0 smoke 완료 | 다음 release에서 탭 전환 재확인 |
| Privileged Helper | 덮개 닫힘 보호와 잠금 화면 설정 변경 보조 | 구현 완료, 자동 검증 완료 | signed/stable 배포 UX는 Apple Developer Program 의존 범위라 현재 구현 계획에서 제외 |
| WidgetKit | optional source/opt-in build 경계 | 기본 릴리즈 제외 | App Group provisioning 이후 실제 위젯 UI 검수 |
| Release Packaging | DMG, checksum, GitHub Release 절차, release smoke | v1.8.0 릴리즈 완료, published DMG 재다운로드·Finder 설치·final-state 통과 | 실제 Claude 구독 event가 제공될 때 live smoke 보강 |
| v1.3.0 | 알림 중심 사용량 인지와 탭별 UI 개선 | 릴리즈 완료 | 후속 이슈 없음 |
| v1.4.0 | Usage Intelligence: 과거 사용량, 예측, 오버레이, export | 릴리즈 완료, 자동 검증/CI/published DMG 설치본 UI smoke 완료 | 후속 이슈 없음 |
| v1.5.0 | Usage Reliability & Diagnostics: 사용량 진단, history health, release 운영 안정화 | 릴리즈 완료, 자동 검증/CI/published DMG 설치본 UI smoke 완료 | 후속 이슈 없음 |
| v1.6.0 | Codex Usage & Reset Credits: 현재 사용량 단일 표시와 사용자 초기화권 장별 유효기간 | 릴리즈 완료, 자동 검증/CI/published DMG 설치본 UI smoke 완료 | 후속 이슈 없음 |
| v1.6.1 | History Control Polish: Codex 탭 현재/지난/비교 control compact layout | 릴리즈 완료, published DMG 설치본 UI smoke와 final-state 검증 완료 | cache 로그 rotation 후속 이슈는 `Docs/V161ReleaseReadiness.md`에서 추적 |
| v1.7.0 | Codex 주간 잔여량 페이스메이커 | 릴리즈 완료, 기존 전환 scenario는 과도 구현으로 재분류 | v1.8.0에서 scenario/epoch UI·기능을 제거하고 weekly window day pace와 알림으로 단순화 |
| v1.8.0 | 선택형 Codex/Claude 사용량 mode와 안정화 | 릴리즈 완료, 단일 provider mode·Codex weekly-only·published DMG 설치/final-state 검증 | 실제 Claude 구독 `rate_limits` event live smoke는 미수행으로 분리 |
| v1.9.0 | 선택형 Codex/Grok 사용량 mode와 Claude hide | 1차 구현·문서 정렬 완료, GUI·live Grok billing·published DMG 미수행 | 후속 1~5 코드 완료(부분 GUI), 남은 6: PR merge·signed tag·published release |

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
- v1.4.0 (5) cache writer 축약 append: live fetch/cache writer 성공 시 weekly sample을 13주 보존하고, 지속된 잔여량 회복과 새 current window로 확인된 완료 창만 reset window history record로 reconcile합니다.
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
- README screenshot renderer는 demo/live Codex popover 모두 reset window history를 주입합니다.
- release smoke는 published DMG 설치본에서 Codex 현재/지난/비교 탭, 지난 window picker, hover/tap marker, PNG copy/export를 실제 UI로 확인해야 닫습니다.
- `git diff --check`, 문서 lint, focused `swift test`, 전체 `swift test`, 필요한 경우 Xcode Debug build가 통과합니다.
- 실제 UI 확인을 하지 않았다면 `UI 확인 미수행`으로 보고합니다.

## v1.5.0: Usage Reliability & Diagnostics

`v1.5.0`은 v1.4.0 Usage Intelligence를 확장하되, 새 데이터 계약을 크게 늘리기보다 사용량 진단과 운영 안정성을 강화합니다.
핵심 방향은 `codex-usage doctor`, cache/history health, protocol drift guard, release readiness를 함께 정리해 사용자가 "현재 사용량 데이터가 믿을 만한 상태인지"를 빠르게 판단하게 만드는 것입니다.
P0 데이터/진단 경계는 `Docs/V150UsageReliability.md`에 기록합니다.
릴리즈 잔여 이슈와 실행 스텝은 [Docs/V150ReleaseReadiness.md](Docs/V150ReleaseReadiness.md)에 둡니다.

v1.5.0 구현 범위:

1. v1.4.0에서 추가한 weekly history, reset-window history, pace, graph/export 기능의 데이터 상태를 진단합니다.
2. `codex-usage doctor`를 확장해 app-server 접근뿐 아니라 cache freshness, history append, reset-window record 상태를 설명합니다.
3. live fetch 실패, stale cache, sample 부족, protocol drift 가능성을 구분해 사용자와 개발자가 같은 용어로 볼 수 있게 합니다.
4. weekly reset 이후 이전 window 데이터가 새 window 뒤쪽으로 이어지거나 같은 날짜 marker가 중복 생성되지 않도록 reset boundary 그래프 회귀를 막습니다.
   공식 `resetsAt`이 아직 미래여도 더 새로운 current window가 시작됐으면 이전 reset-start partial window를 `지난` 사용량으로 backfill하고, 다음 reset 이후 남은 7일 구간은 빈 그래프로 둡니다.
   rolling `resetsAt`이나 일시적인 100% 샘플은 리셋으로 확정하지 않으며, 후보 계보가 6시간 지속되거나 공식 current window로 확인될 때만 완료 창 경계로 사용합니다.
5. Codex 탭에는 사용량 그래프를 방해하지 않는 짧은 데이터 상태 표시를 추가합니다.
6. v1.5.0 전용 검증 스크립트와 focused tests로 doctor/cache/history/protocol/release readiness 계약을 묶습니다.
7. 릴리즈 준비 문서는 v1.5.0 자동 검증, 수동 UI smoke, live fetch smoke, published DMG smoke 경계를 분리해 기록합니다.

v1.5.0 확인된 P0 이슈:

- weekly reset이 오늘 발생한 상태에서 마지막 관측 주간 사용량이 32%였는데, reset 이후 그래프가 이전 window 뒤쪽까지 이어지고 동일 날짜의 이전 데이터가 여러 개 생성되는 문제가 보고됐습니다. 새 `resetsAt`이 감지되면 이전 history와 새 timeline을 분리하고, 새 window는 왼쪽 100% 잔여율에서 시작해야 합니다.
- 이 현상은 Codex 탭의 `지난`/비교 사용량 화면에서도 이전 window가 현재 reset 이후 데이터처럼 보이는 오류로 이어질 수 있으므로 v1.5.0 P0 reset boundary 수정 범위에 포함합니다.

v1.5.0 P0-P2 완료 순서:

| Step | 제목 | 우선순위 | 개발 내용 |
| ---: | --- | --- | --- |
| 1 | v1.5.0 (1) v1.5.0 baseline 정렬 | P0 | VERSION/docs/backlog/source roadmap 정렬 |
| 2 | v1.5.0 (2) 지난 사용량/reset boundary 그래프 회귀 수정 | P0 | `resetStartAt = resetsAt - 7일` 기준으로 이전 weekly/reset-window history를 새 window와 분리하고, reset 이후 그래프와 Codex 탭 `지난` 사용량이 이전 32% marker 뒤로 이어지지 않게 하며, 실제 reset으로 중단된 partial window backfill, 남은 7일 구간 blank tail, 동일 날짜/같은 window marker 중복 dedupe를 함께 검증 |
| 3 | v1.5.0 (3) 데이터 계약과 제외 경계 고정 | P0 | `status --json`, `usage.json`, `usage-weekly-history.json`, `usage-reset-window-history.json` breaking change 금지와 raw payload/session material 미저장 경계를 문서와 테스트 기준으로 고정 |
| 4 | v1.5.0 (4) usage health 모델 정의 | P0 | app-server 접근, cache freshness, stale/error, weekly sample, reset-window record, pace sample 상태를 하나의 진단 모델로 분류 |
| 5 | v1.5.0 (5) cache/history health reader 구현 | P0 | app-owned cache 옆 weekly/reset-window history를 읽어 missing, stale, sample 부족, append skipped, retention 상태를 판정 |
| 6 | v1.5.0 (6) `codex-usage doctor` 확장 | P0 | Codex CLI/app-server 결과에 cache path, freshness, history sample 수, reset-window record 수, 마지막 append 상태, 다음 조치 안내를 추가 |
| 7 | v1.5.0 (7) 실패 가이드와 protocol drift 진단 강화 | P0 | schema/protocol drift, Codex app-server unavailable, required window missing, stale cache를 구분하고 raw app-server payload나 auth material을 출력하지 않는 안내를 유지 |
| 8 | v1.5.0 (8) 검증 스크립트와 fixture 묶음 추가 | P0 | `verify_v150_usage_reliability_contract.sh --self-test`로 health model, reset boundary fixture, doctor formatter, privacy guard, focused Swift tests를 한 번에 검증 |
| 9 | v1.5.0 (9) Codex 탭 데이터 상태 UI 반영 | P1 | 그래프 영역을 방해하지 않는 compact status로 최신 cache, history sample 부족, stale/error, protocol drift 가능성을 표시하고 실제 UI 확인 여부를 분리 보고 |
| 10 | v1.5.0 (10) live fetch/cache smoke 진단 정리 | P1 | `verify_usage_fetch_cache_contract.sh` 또는 v1.5 smoke가 success/error snapshot, weekly append, reset-window append diagnostic을 더 읽기 쉽게 보고 |
| 11 | v1.5.0 (11) 운영 회귀 guard 확장 | P1 | runtime sampler, helper 상태, native Charge Limit read-only 회귀, release final-state처럼 사용자 환경을 바꾸지 않는 진단을 v1.5 release readiness에 연결 |
| 12 | v1.5.0 (12) release readiness 문서화 | P1 | v1.5.0 릴리즈 전 자동검증, UI smoke, live fetch smoke, published DMG smoke, 미수행 보고 형식을 `Docs/V150ReleaseReadiness.md`에 분리 |
| 13 | v1.5.0 (13) README/ROADMAP/Docs와 screenshot/test closure | P2 | README와 ROADMAP 용어를 v1.5.0 범위와 맞추고, screenshot renderer/focused tests/문서 lint/전체 검증 결과를 닫음 |

v1.5.0 제외 경계:

- `codex-usage status --json` schema breaking change
- 기존 app-owned cache와 history 파일 schema breaking change
- raw app-server response, raw log line, auth token, cookie, session material, auth header 저장 또는 출력
- `Plus`/`Pro $100`/`Pro $200` 가격 tier 추정
- 공식 Codex 사용량과 로컬 SQLite 추정치 혼합 표시
- 자동 모델 전환 힌트
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning이 필요한 기능
- WidgetKit 실제 UI 완료 조건 포함
- 사용자 명시 요청 없는 장시간 테스트, GUI 앱 실행, 설치/LaunchAgent/helper 변경, push

v1.5.0 완료 기준:

- usage health 모델은 cache/history/protocol/stale/error/sample 부족 상태를 focused Swift tests로 검증합니다.
- weekly reset boundary 회귀는 reset-start 변경 fixture로 이전 window 분리, 새 timeline 100% 시작, 동일 날짜 marker dedupe, interrupted partial window backfill, blank tail final marker 위치를 검증합니다.
- `codex-usage doctor`는 민감정보 없이 cache/history 상태와 다음 조치를 설명합니다.
- v1.5.0 검증 스크립트는 source guard, fixture, focused tests, privacy boundary를 통과합니다.
- Codex 탭 데이터 상태 UI는 demo/screenshot renderer 또는 focused SwiftUI test로 회귀를 막습니다.
- README/ROADMAP/Docs가 v1.5.0 범위와 제외 경계를 같은 용어로 설명합니다.
- `git diff --check`, 문서 lint, focused `swift test`, 전체 `swift test`, 필요한 경우 Xcode Debug build가 통과합니다.
- 실제 UI 확인을 하지 않았다면 `UI 확인 미수행`으로 보고합니다.

v1.5.0 릴리즈 결과:

- Release tag: `v1.5.0`
- Published release head: signed `v1.5.0` tag target
- GitHub Release 상태: publish 완료
- Published asset: `MacDog-1.5.0.dmg`, `MacDog-1.5.0.dmg.sha256`
- 설치 smoke: published DMG를 Finder에서 열고 `MacDog.app`을 `Applications`로 drag-and-drop한 뒤 `/Applications/MacDog.app` 기준 첫 실행, Codex 현재/지난/비교 탭, CLI/cache LaunchAgent, 로그인 항목 선호 상태, release final-state를 확인했습니다.
- 포함된 잔여 수정: `b12dc69`의 로그인 항목 선호 상태 hardening을 v1.5.0 tag/release 범위에 포함했습니다.

## v1.6.0: Codex Usage & Reset Credits

`v1.6.0`은 Codex 탭을 "현재 사용량 확인"에서 "현재 사용량과 사용자 초기화권 확인"으로 확장합니다.
세부 범위는 [Docs/V160CodexRecoveryPlanner.md](Docs/V160CodexRecoveryPlanner.md)에 둡니다.
릴리즈 준비와 수동 smoke 경계는 [Docs/V160ReleaseReadiness.md](Docs/V160ReleaseReadiness.md)에 둡니다.

상태: publish 완료 / Finder 설치 smoke 완료 / final-state 검증 통과

v1.6.0 릴리즈 결과:

- Release tag: `v1.6.0`
- Published release head: signed `v1.6.0` tag target `600b8d546b0bbbbef8b4a8a8e9b01b3f39eab16e`
- GitHub Release 상태: publish 완료
- Published asset: `MacDog-1.6.0.dmg`, `MacDog-1.6.0.dmg.sha256`
- Published DMG SHA-256: `bb443361809c6655002747c6f057f28bf440378ce69b3af2d7209f12b053f242`
- 설치 smoke: published DMG를 Finder에서 열고 `MacDog.app`을 `Applications`로 drag-and-drop한 뒤 `/Applications/MacDog.app` 기준 첫 실행, Codex/활성 자원/잠들지 않기/배터리/설정 탭, 초기화권 만료일, CLI/cache smoke 실행, live fetch timeout 분리 보고, release final-state를 확인했습니다.

v1.6.0 구현 범위:

1. 5시간/주간 사용량 게이지를 한 번만 표시합니다.
2. reset까지 남은 시간을 주 정보로, 실제 초기화 시각을 보조 정보로 표시합니다.
3. 사용자 초기화권 장수를 `rateLimitResetCredits`에서 표시합니다.
4. 초기화권 장별 유효기간을 ChatGPT backend 상세 응답의 `expiresAt` 기준으로 표시합니다.
5. stale/error/waiting 상태를 과장 없이 표시합니다.
6. 기존 현재 위험 기준과 알림 기준 요약은 1번 탭 안에 compact하게 유지합니다.
7. 주간 history 그래프는 보조 정보로 낮추되 `현재`/`지난`/`비교` 모드와 PNG 복사/내보내기 액션은 1번 탭 안에 유지합니다.
8. 메뉴바 tooltip 또는 펫 메뉴의 다음 초기화 glance는 기존 5시간/주간 window에서 직접 계산합니다.
9. CLI 텍스트 출력에서 초기화권 summary를 표시하고 recovery/session plan 문구를 제거합니다.
10. v1.6 verifier, focused tests, README/Docs closure를 완료합니다.

v1.6.0 제외 경계:

- 5시간/주간 사용량을 회복 일정 카드로 중복 표시
- 1시간, 3시간, reset까지 같은 임의 작업 세션 계획
- `codex-usage status --json` schema breaking change
- 기존 app-owned cache와 history 파일 schema breaking change
- raw app-server response, raw log line, auth token, cookie, session material, auth header 저장 또는 출력
- `Plus`/`Pro $100`/`Pro $200` 가격 tier 추정
- 공식 Codex 사용량과 로컬 SQLite 추정치 혼합 표시
- 새 Dashboard 탭
- Apple Developer Program, Developer ID signing, notarization, App Group provisioning이 필요한 기능
- WidgetKit 실제 UI 완료 조건 포함
- 사용자 명시 요청 없는 장시간 테스트, GUI 앱 실행, 설치/LaunchAgent/helper 변경, push

## v1.6.1: History Control Polish

`v1.6.1`은 v1.6.0 Codex 탭의 정보 구조를 유지하면서 주간 잔여량 history mode control의 전환 흔들림을 줄이는 patch release입니다.
세부 범위는 [Docs/V161HistoryControlPolish.md](Docs/V161HistoryControlPolish.md)에 둡니다.
릴리즈 준비와 수동 smoke 경계는 [Docs/V161ReleaseReadiness.md](Docs/V161ReleaseReadiness.md)에 둡니다.

상태: 릴리즈 완료 / Finder 설치 smoke 완료 / Codex history mode UI와 final-state 확인 완료

v1.6.1 구현 범위:

1. `현재`/`지난`/`비교` segmented control을 compact width로 고정합니다.
2. `현재` mode에서는 지난 window dropdown을 표시하지 않습니다.
3. `지난`/`비교` mode에서는 지난 window가 있을 때 dropdown을 표시합니다.
4. Codex 사용량 JSON/cache/history/reset credit schema는 변경하지 않습니다.

v1.6.1 완료 기준:

- `PopoverScreenshotRendererTests`가 current mode의 dropdown 부재와 past mode의 dropdown 표시를 검증합니다.
- README screenshot renderer가 Codex 탭을 정상 렌더링합니다.
- release smoke에서 published DMG 설치본의 Codex 탭 mode 전환을 직접 확인합니다.

v1.6.1 릴리즈 결과:

- Release tag: signed annotated `v1.6.1`
- Published release head: `62147e9d346094bf9d10920bd91b3186bc3e27dc`
- Published asset: `MacDog-1.6.1.dmg`, `MacDog-1.6.1.dmg.sha256`
- Published DMG SHA-256: `e145c34d98133d6f1db7fab100574ecb6c5901e75b867f2fe0e5e4baf5eba959`
- 설치 smoke: Finder drag-and-drop 교체 뒤 설치본 checksum과 codesign을 확인하고 Codex `현재`/`지난`/`비교` mode와 dropdown 표시 조건을 직접 확인했습니다.
- GitHub 검증: Release Candidate와 Draft Release가 통과했고, release head의 비결정적 screenshot test 최초 실패는 동일 tree 재실행에서 통과했습니다.
- final-state: cleanup 뒤 Background Task DB에서 설치 앱과 usage cache LaunchAgent의 `[enabled, allowed, notified]` 상태를 확인했고 `./script/verify_release_final_state.sh --version 1.6.1`이 통과했습니다.

## v1.7.0: Codex 주간 잔여량 페이스메이커

`v1.7.0`의 제품 목적은 특정 유료 플랜의 절대 한도를 예측하는 것이 아니라, 현재 활성화된
Codex 주간 window의 사용률과 잔여량을 7개 day slot으로 나눠 사용 속도를 관리하는 것입니다.
MacDog는 `Pro $100`과 `Pro $200`의 실제 용량 비율을 알 수 없으며 사용자에게 그 비율을
대신 입력하게 하지 않습니다.

상태: `v1.7.0` 릴리즈 완료 / 당시 플랜 전환 scenario·epoch UI는 과도 구현으로 재분류 /
`v1.8.0` 개발 브랜치에서 제거와 페이스메이커 focused test 완료.

목표 동작:

1. weekly window 시작점은 `resetsAt - windowDurationMins`로 계산하고 달력 자정이 아니라
   해당 시각부터 24시간씩 최대 7개 day slot으로 나눕니다.
2. 7일 window의 기본 일일 목표는 전체 사용량의 `1/7`, 약 `14.3%`입니다.
3. 현재 day 사용량, day 목표까지 남은 비율, 주간 누적 목표 대비 실제 사용량을 표시합니다.
4. history sample이 day 시작점을 확인할 만큼 충분할 때만 day 사용량과 초과 여부를 확정합니다.
5. 기존 로컬 알림 master opt-in 아래에서 day 목표 접근·초과와 주간 누적 페이스 초과를
   weekly window/day/event별 한 번만 알립니다.
6. 현재 활성 플랜의 공식 사용률만 사용하며 `$100에서도 충분함` 같은 적합성 예측을 하지 않습니다.

제거 대상:

- 현재/목표 플랜 label, 목표 상대 용량, reserve, 전환 예정일·확정일
- `planEpochID`, 전환 전후 P50/P90/최대 비교와 target epoch 재분류
- 별도 `usage-plan-transition.json` 읽기·쓰기와 5시간 history의 `planEpochID` 연동
- Codex 탭 전환 readiness block, 설정 탭 plan editor, graph epoch overlay, export scenario 범례

호환성 경계:

- 기존 `usage-plan-transition.json`은 자동 삭제하지 않고 더 이상 읽거나 쓰지 않습니다.
- `usage-five-hour-history.json`은 단기 pace와 burst 관측에 계속 사용하되 `planEpochID`는 신규
  계산과 UI에 사용하지 않습니다. 기존 schema는 decode 호환을 유지하고 migration을 테스트합니다.
- 기존 `codex-usage status --json`, `usage.json`, weekly/reset-window history schema는 breaking
  change 없이 유지합니다.
- day pace는 기존 `usage-weekly-history.json`과 weekly reset-window history를 사용하고, 5시간
  pace는 기존 5시간 history의 atomic write, retention, dense dedupe, reset 분리를 재사용합니다.

릴리즈 기록:

- Signed annotated tag: `v1.7.0`, GitHub `Verified`
- Published release head: `9d4c7d610827aa889f6dc9e5845ed4bd0f99ac56`
- Published asset: `MacDog-1.7.0.dmg`, `MacDog-1.7.0.dmg.sha256`
- Published DMG SHA-256: `92fe575cd66fed1c4ee52b6e350b961d27956930cfba98c23adc17d0c7b25a9f`
- Published DMG 설치본 smoke와 release final-state는 완료했지만 당시 포함된 plan transition UI는
  현재 제품 방향에 맞는 기능으로 유지하지 않습니다.

추천 모델: `5.6 Sol`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 2 = 8점. 이미 배포된 파일을
삭제하지 않으면서 scenario·epoch 경계를 제거하고 weekly history 기반 day pace로 교체해야 합니다.

## v1.8.0: 선택형 Codex/Claude 사용량 mode와 안정화

`v1.8.0`은 사용자가 설정에서 `Codex` 또는 `Claude` 중 하나를 현재 사용량 provider로 선택하고,
1번 탭·러너·알림이 선택한 provider만 사용하게 만드는 milestone입니다. v1.7.0의 과도 구현
정리부터 Claude live·설치·GUI·release 안정화까지 이 버전에서 모두 완료합니다. 이 프로젝트는
두 provider 동시 사용을 고려하지 않으며 합산, 비교, 자동 fallback을 구현하지 않습니다.

릴리즈 실행 순서와 미수행 증거 경계는 [Docs/V180ReleaseReadiness.md](Docs/V180ReleaseReadiness.md)에
분리합니다.

릴리즈 상태: v1.7 plan transition/epoch runtime·UI 제거, legacy file inert 보존, 1/7 day 페이스메이커,
5시간 단기 pace와 알림 focused test를 완료했습니다. 단일 `usageProviderMode` preference와 Codex 기본
migration, 설정 mode 한 항목, 선택 provider 1번 탭·러너·알림·Codex live refresh routing도 focused
test로 연결했습니다. Claude sanitizer/cache/history backend, 사용률·잔여율 표시, cache 없음 수동 연결
UI와 bundle/install/final-state bridge gate도 구현했습니다. Codex 5시간 window가 일시 미제공되는
weekly-only partial cache, 주간 history, runner·알림 fallback, 1번 탭 unavailable 표시와 5시간 복구
전이도 v1.8.0에 포함했습니다. 2026-07-13 기준 전체
`swift test --no-parallel` 464개 통과(명시적 opt-in 4개 skip), Xcode Debug no-sign build와
`MACDOG_APP_VERSION=1.8.0 ./script/check.sh --no-run`을 통과했습니다. release head
`14d716a88ea10a77344a4f9aa3651c23b1160f8c`에 signed/Verified `v1.8.0` tag를 만들고 GitHub
Release를 publish했습니다. published DMG checksum·`hdiutil verify`, Finder drag-and-drop 설치,
설치본 version/executable/codesign, CLI·Codex cache LaunchAgent와 final-state를 확인했습니다.
실제 Claude 구독 `rate_limits` event는 현재 환경에서 제공되지 않아 live smoke를 미수행으로
분리하며 fixture·focused test 결과와 혼동하지 않습니다.

- Published release: <https://github.com/dhseo90/MacDog/releases/tag/v1.8.0>
- Signed annotated tag: `v1.8.0`, GitHub `Verified`
- Published release head: `14d716a88ea10a77344a4f9aa3651c23b1160f8c`
- Published DMG SHA-256:
  `056926bd16668c288d132fab7ff8efb545f00d8eefb8f222440e3f389338a3af`
- 설치본 UI: 1번 탭 compact layout, 설정 탭 불필요 UI 제거, `Codex → Claude → Codex`
  전환과 cache LaunchAgent 제거·복구 직접 확인
- Release smoke: Finder drag-and-drop, installed executable/codesign, CLI·cache LaunchAgent,
  cleanup과 `verify_release_final_state.sh --version 1.8.0` 통과, Finder `응용 프로그램` 범위
  `MacDog` 검색 결과 1개 확인

구현 순서:

1. v1.7.0에서 과도 구현된 plan transition scenario·epoch·UI·export 연동을 제거합니다.
   5시간 history는 삭제하지 않고 `planEpochID` 의존만 제거해 단기 pace 관측에 재사용합니다.
2. 설정 탭에는 `사용량 mode: Codex | Claude` 한 항목만 추가하고 별도 Claude 설정 section을
   만들지 않습니다. 기본값과 기존 사용자 migration은 `Codex`입니다.
3. 1번 탭은 선택한 provider 화면 하나만 표시하고 tab 내부 provider picker를 중복 제공하지 않습니다.
4. 러너와 기존 사용량 알림은 선택한 provider를 유일한 source로 사용합니다. 선택하지 않은
   provider cache는 평가하거나 알림을 만들지 않습니다.
5. Codex는 주간 window를 필수로 유지하되 5시간 window가 없으면 weekly-only partial success로
   저장합니다. 1번 탭은 5시간을 `현재 제공되지 않음`으로 표시하고 주간 history·runner·알림을
   계속 갱신하며, 5시간 window 복구 시 history와 pace를 자동 재개합니다.
6. Claude mode는 status line의 `rate_limits.five_hour`·`seven_day` 사용률과 reset 시각을
   sanitize해 사용하며 잔여율은 `100 - used_percentage`로 계산합니다.
7. Claude `context_window` token은 현재 대화 context 정보로만 표시할 수 있으며 구독 quota의
   절대 token 총량으로 표현하지 않습니다.
8. Claude에는 Codex reset credit과 동등한 공식 field가 없으므로 reset credit UI를 만들지
   않습니다. 5시간/7일 reset 시각만 표시합니다.
9. Claude cache가 없으면 1번 탭에 최소 연결 필요 empty state와 수동 연결 command만 제공합니다.
   MacDog는 Claude settings, auth store, Keychain, transcript를 읽거나 수정하지 않습니다.

제거 대상:

- 설정 탭 `플랜 전환`과 상세 `Claude Usage Preview` section
- `Claude Preview 사용`, Claude runner, Claude 알림 별도 toggle
- tab 내부 segmented provider picker와 `Preview` enable 상태
- Codex/Claude 동시 pressure, `max(Codex, Claude)`, 병렬 notification dispatcher
- 선택하지 않은 provider로 자동 fallback하는 동작

보존 대상:

- Claude status line sanitizer와 `macdog-claude-statusline` bridge
- Claude 전용 cache/history/lock, atomic write, stale/error/privacy guard
- Claude 5시간/7일 사용률·잔여율·reset, history와 선택 provider pace
- Codex 5시간 history의 atomic write, retention, dense dedupe, reset 분리
- weekly history와 reset-window day marker 기반 일일·누적 페이스메이커
- 기존 Codex CLI/JSON/cache/history와 reset credit 계약

완료 기준:

- Codex mode와 Claude mode가 한 번에 하나만 활성화됩니다.
- mode 전환 뒤 1번 탭, runner, notification source가 함께 바뀝니다.
- 선택 provider가 stale/error이면 다른 provider로 fallback하지 않고 해당 상태를 표시합니다.
- Claude plan quota와 context token을 혼합하지 않고 reset credit을 합성하지 않습니다.
- `usage-plan-transition.json`은 자동 삭제하지 않고 신규 read/write를 중단합니다.
- 5시간 history는 `planEpochID` 없이 단기 pace에 계속 사용하고 기존 파일 decode 호환을 유지합니다.
- Codex weekly-only partial은 오류가 아니며 주간 cache/history·runner·알림을 계속 갱신합니다.
- Codex 5시간 window를 0%나 과거 값으로 합성하지 않고, 복구 시 5시간 표시·history·pace를 재개합니다.
- 실제 GUI를 열어 확인하지 않았다면 UI 완료로 보고하지 않습니다.

안정화·release 검증 범위:

1. Codex↔Claude mode preference migration, 앱 재시작, cold start, cache 없음 상태를 검증합니다.
2. 실제 Claude 구독의 첫 API 응답 뒤 5시간/7일 `rate_limits`와 reset 경계를 확인합니다.
3. Claude event 중단, partial window, stale, malformed input, 복구 상태 전이를 검증합니다.
4. 선택 provider runner와 알림이 다른 provider cache의 영향을 받지 않는지 반복 검증합니다.
   Claude mode에서는 Codex usage cache LaunchAgent를 unload·제거하고 Codex mode에서만 다시 설치합니다.
5. menu bar runner, 1번 탭, 설정 mode selector, popover placement를 실제 GUI에서 확인합니다.
6. release app bundle의 bridge 포함, 업데이트·uninstall, published DMG Finder 설치와
   cleanup/final-state를 검증합니다.
7. focused test, 전체 `swift test`, Xcode Debug build, release bundle/packaging 검증을 통과합니다.
8. published DMG를 재다운로드해 checksum과 `hdiutil verify`를 확인하고 Finder drag-and-drop
   설치 뒤 `verify_release_final_state.sh --version 1.8.0`을 통과합니다.
9. WidgetKit은 기본 DMG 완료 조건에서 제외하고 기존 opt-in source/test 경계를 유지합니다.
10. 실행하지 않은 live/GUI/설치 검증은 `미수행`으로 분리 보고합니다.

추천 모델: `5.6 Sol`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 2 = 8점. v1.7 제거·호환성과
Claude privacy/live source, 설정·탭·runner·알림의 단일 provider 상태 전이를 함께 검증해야 합니다.

## v1.9.0: 선택형 Codex/Grok 사용량 mode와 Claude hide

`v1.9.0`은 설정 visible mode를 `Codex`와 `Grok`만 보여 주고, 1번 탭·러너·알림이 선택한
provider만 사용하게 만드는 milestone입니다. Claude source, sanitizer, cache,
`macdog-claude-statusline`은 삭제하지 않고 기본 UI에서 숨깁니다. Grok는 SuperGrok /
Grok Build 공유 주간 pool만 다루며 console prepaid, Extra Usage Credits, 5시간 합성을
하지 않습니다.

구현 범위와 제외 경계는 [Docs/V190GrokUsageAndClaudeHide.md](Docs/V190GrokUsageAndClaudeHide.md)에
둡니다. unofficial 원천은 [Docs/V190GrokUsageSourceSpike.md](Docs/V190GrokUsageSourceSpike.md),
weekly-only 입력은 [Docs/V190GrokWeeklyOnlyContract.md](Docs/V190GrokWeeklyOnlyContract.md),
릴리즈 체크리스트는 [Docs/V190ReleaseReadiness.md](Docs/V190ReleaseReadiness.md)에 둡니다.

현재 상태: 1차 구현 `[01/10]`~`[10/10]`과 문서 정렬은 저장소에 있습니다. published GitHub
Release는 여전히 `v1.8.0`입니다. 로컬 후보 DMG에서 Grok 로그인, weekly parse, 주간 숫자
표시는 확인했지만 GUI·live Grok billing·published DMG 미수행 증거는 릴리즈 문서에 남깁니다.
아래 후속 이슈를 닫은 뒤에 published release smoke를 합니다.

구현 순서:

1. v1.9.0 범위와 unofficial Grok 주간 원천, weekly-only 입력, memory-only 인증 예외를
   문서로 고정합니다.
2. `UsageProviderMode`에 `grok`을 추가하고 설정 picker는 `visibleCases`만 보여 줍니다.
3. 저장된 `claude`는 기본 UI에서 `codex`로 되돌립니다. hidden re-enable이 켜진 경우에만
   Claude를 유지합니다.
4. `UsageNotificationRoute`를 `codex`/`grok`/`claude`로 나눕니다. Grok 선택이 Claude나
   Codex cache로 fallback하지 않습니다.
5. `grok-usage.json`과 주간 history를 Codex/Claude 파일과 분리하고 atomic write,
   `0700`/`0600`, token 미저장을 유지합니다.
6. `macdog-grok-usage` writer와 Grok mode LaunchAgent를 연결합니다. Codex mode에서는
   Grok writer가 돌지 않습니다.
7. 1번 탭은 주간 사용률·잔여율·reset·stale/error를 표시하고 5시간은 `현재 제공되지 않음`
   입니다. reset credit UI는 만들지 않습니다.
8. 러너와 80%/95%/한도/reset 30분 전 알림은 선택 provider의 주간 window만 사용합니다.
9. 현재/지난/비교와 pace는 같은 `resetsAt` 안에서 표시 잔여율이 증가하지 않게 그립니다.
10. focused test와 `verify_v190_selected_provider_contract.sh`로 hide, migration, 3분기
    routing, weekly-only, privacy, no-fallback을 고정합니다. `verify_v180_*`는 완료
    릴리즈 계약으로 유지합니다.

제거하거나 숨길 것:

- 설정 picker의 Claude 항목
- 기본 UI의 Claude empty state와 연결 command
- `UsageNotificationRoute`의 `codex` 외 Claude 강제 분기
- Grok 5시간 값 합성
- Grok Extra Usage Credits를 reset credit처럼 표시
- console.x.ai 선불 credit을 SuperGrok 잔여율로 표시
- Codex와 Grok 사용량 합산·비교
- 선택하지 않은 provider cache로 runner/알림 fallback

보존 대상:

- Codex CLI, JSON schema, cache, weekly/five-hour/reset history, reset credit
- Claude sanitizer, `macdog-claude-statusline`, Claude cache/history/privacy test
- 단일 provider preference, 설정 mode 한 항목, no-fallback
- 기존 로컬 알림 opt-in과 dedupe 구조
- WidgetKit source/opt-in 경계. 기본 DMG에는 넣지 않습니다

완료 기준:

- 설정 visible mode가 `Codex`와 `Grok`뿐이다.
- Claude source, test, bridge가 저장소에 남아 있다.
- 1번 탭, runner, 알림 source가 같은 선택 provider를 쓴다.
- Grok는 주간 window만 필수이고 5시간을 합성하지 않는다.
- Grok cache는 Codex/Claude 파일과 분리되어 있다.
- token, cookie, session, `auth.json` 원문이 cache/log/fixture에 없다.
- 선택 provider stale/error에서 다른 provider로 fallback하지 않는다.
- 실행하지 않은 GUI/live/설치를 완료로 쓰지 않는다.

추천 모델: `grok-4.6`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 2 = 8점.
Grok billing 원천이 unofficial이고 인증 예외와 selected-provider 상태 전이가 겹친다.

후속 이슈는 아래 번호 순으로만 진행합니다. 앞 항목이 끝나기 전에 릴리즈 publish를 하지
않습니다. 1차 인증 예외는 읽기 전용이었다. 현재 계약은 Grok `auth.json` sibling 주기이며
writer 코드는 후속 1에서 맞춘다.

공통 규칙: 잔여 사용량 조회(Codex app-server, Grok unofficial billing, hidden Claude
status line)만 provider별로 둔다. 주간 그래프, hover, 현재/지난/비교, 잔여율 표시는
공통 로직을 쓴다. Grok 전용 그래프를 새로 키우지 않는다.

1. Grok `auth.json` sibling 주기 — 코드 완료, GUI 확인 미수행
   `macdog-grok-usage`는 Grok CLI와 같은 `~/.grok/auth.json`을 쓴다. 유효한 access
   token은 읽기만 하고, 만료 또는 billing 401이면 `auth.json.lock` 아래에서 sibling
   adopt 또는 OIDC refresh 후 같은 파일에 atomic merge write한다. 메뉴바는 auth를
   읽지 않는다. 로그인 UI는 `grok login`이다. MacDog 전용 토큰 파일과 메모리 단독
   세션은 만들지 않는다.
   추천 모델: `grok-4.6`
   추론 수준: 매우 높음 (xhigh)
   선정 근거: 영향도 2 + 불확실성 1 + 검증 난이도 2 + 변경 범위 2 = 7점.
   인증·refresh 회전 경계라 상향한다.

2. 1번 탭 주간 그래프 hover — 코드 완료, 오늘 칸 GUI 확인, 이후 날짜는 3번과 함께 확인
   새 hover UX를 만들지 않는다. Grok 탭은 공통 `WeeklyRemainingHistoryBlock`을 쓴다.
   Grok는 `CodexUsageReport`가 없으므로 `currentTimestamp`와 현재 window history
   sample로 `currentSample`을 만든다. 빈 완료일은 Codex와 같이
   `completedDayMarkers`가 마지막 잔여율을 채운다.
   추천 모델: `grok-4.6`
   추론 수준: 중간 (medium)
   선정 근거: 영향도 1 + 불확실성 0 + 검증 난이도 2 + 변경 범위 1 = 4점.

3. 주간 그래프 날짜 칸을 로컬 자정 기준 — 코드 완료, GUI 확인 미수행
   잔여량 선 x축은 기존처럼 `resetStart → resetsAt`이다. hover 칸과 세로 날짜선은
   설정 탭 `날짜 기준`으로 고른다. 기본값은 자정이고, 기존 리셋 시각 24시간
   칸은 옵션으로 남긴다. 한도 창이 자정에 시작하지 않으면 자정 기준에서 첫날·마지막날은
   짧고 칸은 8개일 수 있다. 자정이 지나면 사용량 변화 없이 다음 날짜 칸으로 넘어간다.
   Codex 페이스메이커 day slot과 cache `dayIndex`는 바꾸지 않는다. Codex/Grok/Claude
   그래프가 같은 설정을 쓴다.
   추천 모델: `grok-4.6`
   추론 수준: 높음 (high)
   선정 근거: 영향도 1 + 불확실성 1 + 검증 난이도 2 + 변경 범위 2 = 6점.
   공통 그래프·시간대·회귀라 추론을 올린다.

4. 선택 provider 기준 문구 — 코드 완료, GUI 확인 미수행
   3번 탭 실행 중 토글과 우클릭 메뉴 펫 제목/`사용량 종료`는 선택한 provider 이름이다.
   `Grok`이면 Grok, hidden re-enable로 `Claude`가 켜진 경우에만 Claude로 표시한다.
   선택하지 않은 provider 이름으로 fallback하지 않는다.
   추천 모델: `grok-4.6`
   추론 수준: 중간 (medium)
   선정 근거: 영향도 1 + 불확실성 0 + 검증 난이도 2 + 변경 범위 1 = 4점.
   일반 개발이므로 `grok-4.6`을 유지한다.

5. `uninstall.sh` Grok 잔여물 — 코드 완료, 실제 삭제 실행 미수행
   삭제가 `grok-usage.json`, history, lock과 `com.dhseo.macdog.grok-usage-cache`
   LaunchAgent를 Codex/Claude와 같은 수준으로 제거한다. `--dry-run` 검증만 수행하고
   실제 uninstall은 사용자 승인 뒤에만 실행한다.
   추천 모델: `grok-4.6`
   추론 수준: 중간 (medium)
   선정 근거: 영향도 1 + 불확실성 0 + 검증 난이도 1 + 변경 범위 1 = 3점.

6. published DMG와 final-state
   `v1.9.0` → `main` PR, signed tag, published DMG, Finder 설치, final-state.
   추천 모델: `grok-4.6`
   추론 수준: 높음 (high)
   선정 근거: 영향도 2 + 불확실성 0 + 검증 난이도 2 + 변경 범위 1 = 5점. 릴리즈 영향.

## RunCat UI 참고 방향

RunCat의 참고점은 "메뉴바에 작고 귀여운 러너가 계속 움직이며, 시스템 부하에 따라 속도가
달라지는 상태 표시"입니다. 이 프로젝트는 CPU 부하 대신 현재 선택한 provider 사용률을 속도
입력으로 사용합니다.

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

러너 속도는 선택 provider에서 현재 제공되는 window 사용률 중 더 높은 값을 기준으로 정합니다.
Codex의 장기 window는 주간, Claude의 장기 window는 7일이며 Codex weekly-only이면 주간 값만
사용합니다.

```text
usage = max(availableWindows.usedPercent)
```

선택 provider가 stale/error이면 다른 provider로 fallback하지 않고 runner의 새 pressure 반영을
일시 중지합니다.

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
