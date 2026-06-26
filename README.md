# MacDog

MacDog는 Codex 사용량과 Mac 상태를 메뉴바에서 바로 확인하는 macOS 유틸리티입니다. 작은 `Codex Pup` 러너가 메뉴바에 상주하고, 클릭하면 Codex 사용량, 현재 자원, 잠들지 않기, 배터리 충전 한도, 앱 설정을 한 popover에서 다룹니다.

기본 캐릭터는 `Codex Pup`입니다. 같은 캐릭터 세트가 메뉴바 러너, 데스크톱 펫, 우측 탭 버튼 이미지에 함께 적용되므로 나중에 캐릭터를 바꿀 때도 한 묶음으로 교체할 수 있습니다.

## 현재 릴리즈

현재 GitHub Release는 [v1.4.0](https://github.com/dhseo90/MacDog/releases/tag/v1.4.0)입니다.

- Published release head: `7327977bb82d41d8f0571e231865ba3251a178c9`
- Published asset: `MacDog-1.4.0.dmg`
- Published DMG SHA-256: `c46f7bde5cb4ad0782943cd479dfe0a3841929b663cc605022b33dd7dcec9142`
- 상태: unsigned/ad-hoc signed GitHub Release입니다. Apple Developer Program 조건이 필요한 public stable 배포는 현재 구현 계획에서 제외하고 별도 milestone에서 다룹니다.
- 확인된 smoke: published DMG checksum, `hdiutil verify`, Finder drag-and-drop 설치, `/Applications/MacDog.app` 첫 실행, CLI/cache LaunchAgent 복구, live fetch/cache 계약, release final-state 검증.
- Re-run verified head: `0714c750df3e5a67e435c670e2f1a9ca45263771`. 이 head에는 과거 window backfill, 지난/비교 탭 유지, 날짜 기반 timeline/marker 라벨, reset-window history append diagnostic이 포함됩니다.
- Replacement local DMG: `dist/release/MacDog-1.4.0.dmg`, SHA-256 `9505a7acdbce80e558d279ad07a8e81699eec160114ba52911da771d725294c3`. 이 DMG는 checksum과 `hdiutil verify`, candidate CLI live fetch/cache smoke를 통과했습니다.
- 남은 release smoke: remote `v1.4.0` tag/asset 교체, published DMG 재다운로드 검증, Finder drag-and-drop 재설치, `/Applications/MacDog.app` 기준 실제 Codex 탭 UI smoke, release final-state 검증.

## 화면

아래 이미지는 현재 SwiftUI popover 구조를 README용 demo snapshot으로 렌더링한 공식 이미지입니다. 실제 사용량 값과 시스템 상태는 사용자 환경에 따라 달라집니다.

<table>
  <tr>
    <th>Codex 사용량</th>
    <th>활성 자원</th>
  </tr>
  <tr>
    <td><img src="Docs/Images/README/PopoverTabs/macdog-popover-codex.png" alt="MacDog Codex usage tab" width="360"></td>
    <td><img src="Docs/Images/README/PopoverTabs/macdog-popover-mac.png" alt="MacDog active resources tab" width="360"></td>
  </tr>
  <tr>
    <th>잠들지 않기</th>
    <th>배터리</th>
  </tr>
  <tr>
    <td><img src="Docs/Images/README/PopoverTabs/macdog-popover-sleep.png" alt="MacDog sleep prevention tab" width="360"></td>
    <td><img src="Docs/Images/README/PopoverTabs/macdog-popover-battery.png" alt="MacDog battery tab" width="360"></td>
  </tr>
  <tr>
    <th>설정</th>
    <th>데스크톱 펫</th>
  </tr>
  <tr>
    <td><img src="Docs/Images/README/PopoverTabs/macdog-popover-settings.png" alt="MacDog settings tab" width="360"></td>
    <td align="center"><img src="Docs/Images/README/macdog-desktop-pet-front.png" alt="MacDog desktop pet front sprite" width="160"></td>
  </tr>
</table>

## 앱 구조

MacDog는 기본 DMG에서 메뉴바 앱과 CLI를 함께 제공합니다. WidgetKit 코드는 보존하지만 기본 앱/DMG에는 포함하지 않고, `--with-widget` opt-in build에서만 검수합니다.

| 영역 | 역할 |
| --- | --- |
| 메뉴바 러너 | Codex 사용량 위험도를 작은 캐릭터 움직임으로 표시합니다. |
| Codex 사용량 탭 | 5시간/주간 사용률, 남은 비율, reset 시각, 알림 기준, pace 예측, 주간 잔여량/지난 window/비교 그래프를 표시합니다. |
| 활성 자원 탭 | CPU, 메모리, 저장 용량, 네트워크 상태를 1초 단위로 갱신합니다. |
| 잠들지 않기 탭 | 끔, 시간 제어, 상태 기준 제어와 보호 옵션을 관리합니다. |
| 배터리 탭 | macOS native Charge Limit 지원 환경에서 80-100% 목표 한도를 읽고 적용합니다. |
| 설정 탭 | 알림, 로그인 실행, 데스크톱 펫, 움직임 줄이기, 러너 일시 정지, 권한 도우미 상태를 관리합니다. |
| 첫 실행 마무리 | `/Applications/MacDog.app` 첫 실행 시 `~/bin/codex-usage`, usage cache LaunchAgent, macOS 로그인 항목을 사용자 영역에 맞게 설치/복구합니다. |

## 설치

사용자 설치는 GitHub Release의 DMG를 기준으로 합니다.

1. [v1.4.0 Release](https://github.com/dhseo90/MacDog/releases/tag/v1.4.0)에서 `MacDog-1.4.0.dmg`를 내려받습니다.
2. DMG를 Finder에서 엽니다.
3. 보이는 `MacDog.app`을 `Applications`로 드래그합니다.
4. `Applications`에서 MacDog를 실행합니다.

Finder 복사 자체는 앱을 실행하지 않습니다. `/Applications/MacDog.app` 첫 실행 시 MacDog가 터미널용 `~/bin/codex-usage` symlink, usage cache LaunchAgent, macOS 로그인 항목을 사용자 설정에 맞게 마무리합니다.

설치 검수 원칙:

- `script/install.sh`, 직접 복사, `hdiutil` mount 후 파일 복사, 앱 번들 직접 교체는 사용자 설치 검수로 기록하지 않습니다.
- 실제 DMG Finder 창에서 `MacDog.app`을 `Applications`로 drag-and-drop하지 못했으면 설치 검수는 미수행으로 기록합니다.
- release smoke 종료 시 `./script/cleanup_release_smoke_state.sh --apply`와 `./script/verify_release_final_state.sh --version <version>`으로 Finder 검색 중복과 stale LaunchAgent를 확인합니다.

## 주요 기능

- Codex 사용량: 5시간/주간 사용률, 남은 비율, 초기화 시각, 마지막 갱신 상태, pace 예측, 현재/지난/비교 그래프를 표시합니다.
- Codex 그래프 공유: 화면에 보이는 그래프를 PNG로 복사하거나 저장합니다. PNG에는 auth/session material, raw app-server 응답, raw log line, local path metadata를 넣지 않습니다.
- Codex 사용량 알림: `UserNotifications` 기반 로컬 알림으로 80%, 95%, 한도 도달, reset 30분 전 이벤트를 알려줍니다.
- Mac 활성 자원: CPU, 메모리, 저장 용량, 네트워크 상태를 보여주고 현재 자원 탭에서는 1초 단위로 갱신합니다.
- 잠들지 않기: 끔, 시간 제어, 상태 기준 제어를 제공하고 전원 연결, Codex 실행 중, 배터리/CPU/메모리 기준, 네트워크 전송, 외장/공유 드라이브 조건을 OR 조건으로 평가합니다.
- 덮개 닫힘 보호: optional 권한 도우미를 설치하면 최초 승인 이후 앱 UI에서 덮개 닫힘 보호 설정을 바꿀 수 있습니다.
- 배터리 충전 한도: macOS native Charge Limit을 지원하는 Apple silicon Mac에서 80-100% 목표 한도를 읽고 적용합니다.
- 데스크톱 펫: 강아지를 데스크톱 위에 띄우고, 드래그 위치 저장, 좌클릭 popover, 우클릭 메뉴, 상태 반응을 제공합니다.
- 설정: Codex 사용량 알림, 로그인 시 MacDog 실행, 데스크톱 펫 표시, 움직임 줄이기, 러너 일시 정지, 권한 도우미 설치/제거 상태를 관리합니다.

## 갱신 주기

- 메뉴바 앱은 app-owned usage cache를 60초마다 다시 읽습니다.
- 캐시가 비어 있거나 사용자가 수동 갱신을 누르면 번들 내부 `codex-usage`를 짧게 실행해 cache를 채웁니다. 실패 후 자동 재시도는 최소 60초 간격으로 제한합니다.
- 첫 실행 마무리가 등록한 usage cache LaunchAgent도 60초마다 `codex-usage status --write-cache --timeout 15`를 실행해 앱 cache를 갱신합니다.
- 성공한 주간 잔여량은 `~/Library/Application Support/MacDog/usage-weekly-history.json`에 샘플링되어 Codex 탭 그래프에 쓰입니다.
- WidgetKit opt-in build에서만 `--mirror-cache`를 추가해 shared cache를 함께 갱신합니다.

## 알림 경계

v1.3.0 알림은 Apple Developer 계정 필요 없이 가능한 `UserNotifications` 기반 로컬 알림입니다. MacDog는 app-owned usage cache를 읽어 80%, 95%, 한도 도달, reset 30분 전 이벤트를 판단하고, raw app-server 응답이나 auth/session material은 다루지 않습니다.

알림은 기본 꺼짐이며 사용자가 설정 탭에서 켜고 macOS 알림 권한을 승인한 뒤에만 발송합니다. 테스트 알림 버튼은 v1.3.0 범위에 넣지 않습니다. `codex-usage status --json`을 포함한 JSON/cache/app-server 계약은 변경하지 않습니다. Apple Developer 계정이 필요한 기능명은 v1.3.0 완료 조건과 후속 이슈에 나열하지 않습니다.

## CLI

설치 후 터미널에서는 `codex-usage`로 현재 Codex 사용량을 확인할 수 있습니다.

```sh
codex-usage status
codex-usage status --json
codex-usage status --write-cache
codex-usage status --write-cache --mirror-cache
codex-usage status --watch 60
codex-usage doctor
```

`status`는 5시간/주간 사용률, 남은 비율, 초기화 시각, plan, 갱신 상태를 출력합니다. plan은 app-server 응답의 raw `planType`만 표시하며, `Plus`/`Pro $100`/`Pro $200` 가격 tier를 추정하지 않습니다. JSON 출력은 앱, optional 위젯, cache writer가 의존하는 계약이므로 breaking change를 만들지 않습니다. `--write-cache` 성공 시 주간 잔여량 history와 v1.4.0 reset window history를 별도 파일로 append합니다. `--mirror-cache`는 WidgetKit opt-in build 검수용입니다.

`doctor`는 Codex CLI/app-server 접근 상태와 함께 현재 응답에 포함된 사용량 묶음 이름과 필드 목록을 구조 요약으로 보여줍니다. raw app-server 응답이나 auth/session material은 출력하지 않습니다.

## 데이터와 개인정보

- Codex 사용량 기준은 로컬 Codex app-server의 `account/rateLimits/read` 응답입니다.
- `primary.windowDurationMins = 300`은 5시간 창, `secondary.windowDurationMins = 10080`은 주간 창으로 해석합니다.
- auth token, refresh token, cookie, session material은 읽거나 저장하지 않습니다.
- cache에는 raw `planType`, 사용률, 초기화 시각, stale/error 상태 같은 표시 정보만 저장합니다.
- `Plus`/`Pro $100`/`Pro $200` 가격 tier는 현재 조회 경로에서 구분할 수 없으므로 표시, 저장, 추정하지 않습니다.
- 주간 잔여량 history에는 기록 시각, 주간 사용률/잔여율, 주간 reset 시각, window duration만 저장합니다.
- v1.4.0 reset window history는 `usage-reset-window-history.json` 별도 파일에 `limitId`, `windowDurationMins`, `resetsAt` 기준 축약 record만 저장하고, 기존 `usage.json`/`usage-weekly-history.json` schema를 바꾸지 않습니다.
- 대량 로그/backfill 경로는 raw log 저장 기능이 아니라 reset window history record 생성 경계만 지원합니다. 앱 UI, 오버레이, 이미지 export는 생성된 record만 읽습니다.
- 메뉴바 앱 UI process는 auth token이나 raw app-server 응답을 다루지 않습니다.

## 개발과 검증

필요 환경:

- macOS 14 이상
- Xcode 또는 Xcode Command Line Tools
- Codex 앱 또는 Codex CLI
- 문서 lint 검증 시 Node.js/npm. 전역 설치 없이 `npx --yes markdownlint-cli2@0.22.1`로 실행합니다.

자주 쓰는 명령:

```sh
MACDOG_APP_VERSION=<version> ./script/check.sh
MACDOG_APP_VERSION=<version> ./script/check.sh --no-run
MACDOG_APP_VERSION=<version> ./script/build_and_run.sh
npx --yes markdownlint-cli2@0.22.1
./script/verify_v140_usage_intelligence_contract.sh --self-test
```

자주 쓰는 스크립트:

| Script | 용도 |
| --- | --- |
| `MACDOG_APP_VERSION=<version> ./script/check.sh` | 전체 로컬 검증. 기본 모드는 앱 실행까지 포함합니다. |
| `MACDOG_APP_VERSION=<version> ./script/check.sh --no-run` | 앱을 실행하지 않고 테스트, 빌드, packaging gate를 검증합니다. |
| `MACDOG_APP_VERSION=<version> ./script/build_and_run.sh` | 앱 번들을 빌드하고 MacDog를 실행합니다. |
| `MACDOG_APP_VERSION=<version> ./script/build_and_run.sh --with-widget` | optional WidgetKit extension을 포함해 앱 번들을 빌드합니다. 기본 빌드는 위젯을 제외합니다. |
| `./script/sample_existing_runtime_resources.sh --samples 5 --interval 1` | 이미 실행 중인 MacDog 프로세스의 CPU/RSS를 read-only로 샘플링합니다. |
| `./script/verify_v140_usage_intelligence_contract.sh --self-test` | v1.4.0 cache/privacy/history, fixture, focused Swift tests를 확인합니다. 앱 UI는 열지 않습니다. |
| `MACDOG_APP_VERSION=<version> ./script/install.sh` | 개발용 로컬 설치를 수행합니다. |
| `MACDOG_APP_VERSION=<version> ./script/install.sh --with-widget` | optional WidgetKit extension과 shared cache mirror를 포함해 설치합니다. |
| `MACDOG_RELEASE_VERSION=<version> ./script/package_release.sh` | GitHub Release 후보 DMG와 checksum을 만듭니다. |

전체 스크립트 의미와 영향 범위는 [Docs/Scripts.md](Docs/Scripts.md)에 정리되어 있습니다.

## 개발용 로컬 설치

개발용 설치 스크립트는 release build를 만들고 `~/Applications/MacDog.app`에 설치합니다. 이 경로는 개발 편의용이며 릴리즈/사용자 설치 검수를 대체하지 않습니다.

```sh
MACDOG_APP_VERSION=<version> ./script/install.sh
MACDOG_APP_VERSION=<version> ./script/install.sh --with-widget
MACDOG_APP_VERSION=<version> ./script/install.sh --dry-run
./script/uninstall.sh --dry-run
```

설치 상태 확인:

```sh
./script/verify_install_state.sh --expect-installed
./script/verify_install_state.sh --expect-current-dist
./script/verify_install_state.sh --explain-current-dist
./script/verify_privileged_helper_state.sh --expect-installed
./script/verify_privileged_helper_xpc.sh --expect-installed
./script/verify_charge_limit.sh --read
```

권한 도우미는 앱 설정 탭에서 설치/제거하는 흐름을 기본으로 합니다. 개발용 `--with-helper`/`--helper-only`는 터미널에서 직접 실행할 때 `sudo`를 사용하며, Codex 같은 비대화형 실행에서는 `osascript` 승인창을 자동으로 띄우지 않습니다.

삭제:

```sh
./script/uninstall.sh
./script/uninstall.sh --reset-preferences
```

기본 삭제는 앱, CLI symlink, user LaunchAgent, usage cache 파일을 제거하고 UserDefaults와 optional 권한 도우미는 유지합니다. `--reset-preferences`는 로그인 자동 실행과 잠들지 않기 관련 MacDog 설정을 함께 초기화합니다.

## 릴리즈 패키징

GitHub Release용 로컬 후보는 `.dmg`와 checksum을 만듭니다.

```sh
MACDOG_RELEASE_VERSION=<version> ./script/package_release.sh --dry-run
MACDOG_RELEASE_VERSION=<version> ./script/package_release.sh
```

릴리즈 DMG의 목표 UX는 Finder에서 `MacDog.app`을 `Applications`로 드래그하는 표준 macOS 설치 방식입니다. DMG는 drag-and-drop 배경 화면을 포함하고, 복사 후 `Applications`에서 MacDog를 실행하라는 한글 안내를 표시합니다.

Apple Developer Program, 서명, 공유 컨테이너 권한이 필요한 public stable 배포와 실제 Widget UI 검수는 현재 구현 계획에서 제외합니다.

세부 배포 경계는 [Docs/ReleasePackaging.md](Docs/ReleasePackaging.md)에 정리합니다.

## 프로젝트 구조

```text
Sources/CodexUsageCore/                 사용량 조회, 모델, cache, formatter
Sources/CodexUsageCLI/                  codex-usage CLI
Sources/MacDog/                         macOS 메뉴바 앱과 데스크톱 펫
Sources/MacDogPrivilegedHelper/         권한 도우미 executable
Sources/MacDogPrivilegedHelperSupport/  helper IPC contract와 허용 명령 정의
Sources/MacDogWidget/                   WidgetKit view/provider
Apps/                                   Widget host/extension target
Tests/                                  core/app/helper 테스트
script/                                 빌드, 실행, 설치, 검증 스크립트
Docs/                                   보조 설계/검증 문서
```

## 문서

- [ROADMAP.md](ROADMAP.md): 개발 로드맵과 잔여 이슈
- [Docs/Scripts.md](Docs/Scripts.md): `script/*.sh` 용도와 영향 범위
- [Docs/ReleasePackaging.md](Docs/ReleasePackaging.md): GitHub Release, DMG, release smoke, 브랜치 정리 경계
- [Docs/GitHubReleaseChecklist.md](Docs/GitHubReleaseChecklist.md): PR 보호 규칙과 GitHub Release 체크리스트
- [Docs/RuntimeVerification.md](Docs/RuntimeVerification.md): CPU/RSS runtime 검증 절차
- [Docs/MenuBarCharacterBaseline.md](Docs/MenuBarCharacterBaseline.md): 메뉴바 캐릭터 기준선
- [Docs/WidgetPackaging.md](Docs/WidgetPackaging.md): optional WidgetKit 패키징 경계
- [Docs/ClosedDisplayResearch.md](Docs/ClosedDisplayResearch.md): 덮개 닫힘 보호 조사와 검증 결과
- [Docs/PrivilegedHelperPlan.md](Docs/PrivilegedHelperPlan.md): 권한 도우미 설치와 IPC contract
- [Docs/ChargeLimitResearch.md](Docs/ChargeLimitResearch.md): Charge Limit 연동 조사 결과
- [Docs/V130NotificationAndTabUIPolish.md](Docs/V130NotificationAndTabUIPolish.md): v1.3.0 알림과 탭 UI 개선 범위
- [Docs/V130ReleaseReadiness.md](Docs/V130ReleaseReadiness.md): v1.3.0 릴리즈 준비 감사와 릴리즈 실행/완료 기록
- [Docs/V140UsageIntelligence.md](Docs/V140UsageIntelligence.md): v1.4.0 과거 사용량, 예측, 오버레이 로드맵
- [Docs/V140ReleaseReadiness.md](Docs/V140ReleaseReadiness.md): v1.4.0 릴리즈 잔여 이슈와 실행 순서
- [AGENTS.md](AGENTS.md): 개발 규칙, 보안 원칙, 검증 체크리스트
- [CONTRIBUTING.md](CONTRIBUTING.md): PR 작성과 검증 기준

## 라이선스

Apache License 2.0. 자세한 내용은 [LICENSE](LICENSE)를 참고합니다.
