# MacDog

MacDog는 Codex 사용량과 Mac 상태를 메뉴바에서 바로 확인하는 macOS 유틸리티다. 작은 강아지 러너가 메뉴바에 상주하고, 클릭하면 Codex 사용량, 현재 자원, 잠들지 않기, 배터리 충전 한도, 앱 설정을 한 popover에서 다룬다.

기본 캐릭터는 `Codex Pup`이다. 같은 캐릭터 세트가 메뉴바 러너, 데스크톱 펫, 우측 탭 버튼 이미지에 함께 적용되므로 나중에 캐릭터를 바꿀 때도 한 묶음으로 교체할 수 있다.

## Screenshots

아래 이미지는 현재 SwiftUI popover를 README용 demo snapshot으로 렌더링한 화면이다. 실제 사용량 값은 사용자 환경에 따라 달라진다.

| Codex 사용량 | 활성 자원 |
| --- | --- |
| ![MacDog Codex usage tab](Docs/Images/README/PopoverTabs/macdog-popover-codex.png) | ![MacDog active resources tab](Docs/Images/README/PopoverTabs/macdog-popover-mac.png) |

| 잠들지 않기 | 배터리 |
| --- | --- |
| ![MacDog sleep prevention tab](Docs/Images/README/PopoverTabs/macdog-popover-sleep.png) | ![MacDog battery tab](Docs/Images/README/PopoverTabs/macdog-popover-battery.png) |

| 설정 | 데스크톱 펫 |
| --- | --- |
| ![MacDog settings tab](Docs/Images/README/PopoverTabs/macdog-popover-settings.png) | ![MacDog desktop pet front sprite](Docs/Images/README/macdog-desktop-pet-front.png) |

## Features

- Codex 사용량: 5시간/주간 사용률, 남은 비율, 초기화 시각, 마지막 갱신 상태를 표시한다.
- Mac 활성 자원: CPU, 메모리, 저장 용량, 네트워크 상태를 보여주고 현재 자원 탭에서는 1초 단위로 갱신한다.
- 잠들지 않기: 끔, 시간 제어, 상태 기준 제어를 제공하고 전원 연결, Codex 실행 중, 배터리/CPU/메모리 기준, 네트워크 전송, 외장/공유 드라이브 조건을 OR 조건으로 평가한다.
- 덮개 닫힘 보호: optional 권한 도우미를 설치하면 최초 승인 이후 앱 UI에서 덮개 닫힘 보호 설정을 바꿀 수 있다.
- 배터리 충전 한도: macOS native Charge Limit을 지원하는 Apple silicon Mac에서 80~100% 목표 한도를 읽고 적용한다.
- 데스크톱 펫: 강아지를 데스크톱 위에 띄우고, 드래그 위치 저장, 좌클릭 popover, 우클릭 메뉴, 상태 반응을 제공한다.
- 설정: 로그인 시 MacDog 실행, 데스크톱 펫 표시, 움직임 줄이기, 러너 일시 정지, 권한 도우미 설치/제거 상태를 관리한다.
- WidgetKit: shared cache 기반 small/medium 위젯 코드를 포함한다. 실제 위젯 갤러리 추가와 클릭 검수는 수동 검증 항목이다.

## Quick Start

필요 환경:

- macOS 14 이상
- Xcode 또는 Xcode Command Line Tools
- Codex 앱 또는 Codex CLI

전체 검증:

```sh
./script/check.sh
```

앱 빌드 및 실행:

```sh
./script/build_and_run.sh
```

앱을 띄우지 않고 빌드와 테스트만 확인:

```sh
./script/check.sh --no-run
```

자주 쓰는 스크립트:

| Script | 용도 |
| --- | --- |
| `./script/check.sh` | 전체 로컬 검증. 기본 모드는 앱 실행까지 포함한다. |
| `./script/check.sh --no-run` | 앱을 실행하지 않고 테스트, 빌드, packaging gate를 검증한다. |
| `./script/build_and_run.sh` | 앱 번들을 빌드하고 MacDog를 실행한다. |
| `./script/install.sh` | 개발용 로컬 설치를 수행한다. |
| `./script/package_release.sh` | GitHub Release 후보 DMG와 checksum을 만든다. |

전체 스크립트 의미와 영향 범위는 [Docs/Scripts.md](Docs/Scripts.md)에 정리되어 있다.

## CLI

설치 후 터미널에서는 `codex-usage`로 현재 Codex 사용량을 확인할 수 있다.

```sh
codex-usage status
codex-usage status --json
codex-usage status --write-cache
codex-usage status --watch 60
codex-usage doctor
```

`status`는 5시간/주간 사용률, 남은 비율, 초기화 시각, plan, 갱신 상태를 출력한다. JSON 출력은 앱, 위젯, cache writer가 의존하는 계약이므로 breaking change를 만들지 않는다.

## Local Install

개발용 설치 스크립트는 release build를 만들고 `~/Applications/MacDog.app`에 설치한다. 앱 번들 내부 `codex-usage`를 `~/bin/codex-usage` symlink로 연결하고, usage cache LaunchAgent와 로그인 자동 실행 LaunchAgent를 등록한다.

```sh
./script/install.sh
```

설치 전 변경 대상 확인:

```sh
./script/install.sh --dry-run
./script/uninstall.sh --dry-run
./script/install.sh --dry-run --with-helper
./script/uninstall.sh --dry-run --with-helper
```

설치 상태 확인:

```sh
./script/verify_install_state.sh --expect-installed
./script/verify_install_state.sh --expect-current-dist
./script/verify_privileged_helper_state.sh --expect-installed
./script/verify_privileged_helper_xpc.sh --expect-installed
./script/verify_charge_limit.sh --read
```

권한 도우미는 앱 설정 탭에서 설치/제거하는 흐름을 기본으로 한다. 개발용 `--with-helper`/`--helper-only`는 터미널에서 직접 실행할 때 `sudo`를 사용하며, Codex 같은 비대화형 실행에서는 `osascript` 승인창을 자동으로 띄우지 않는다.

삭제:

```sh
./script/uninstall.sh
```

기본 삭제는 앱, CLI symlink, user LaunchAgent, usage cache 파일을 제거하고 UserDefaults와 optional 권한 도우미는 유지한다.

## Release Package

GitHub Release용 로컬 후보는 `.dmg`와 checksum을 만든다.

```sh
./script/package_release.sh --dry-run
./script/package_release.sh
```

릴리즈 DMG의 목표 UX는 Finder에서 `MacDog.app`을 `Applications`로 드래그하는 표준 macOS 설치 방식이다. 앱 실행 후 설정 탭에서 로그인 자동 실행, 데스크톱 펫, 권한 도우미를 관리한다.

현재 공개 배포 전 gate:

- Developer ID signing
- hardened runtime
- notarization
- stapling
- Gatekeeper 검증
- 깨끗한 사용자 환경에서 DMG 설치/제거 검수

세부 배포 경계는 [Docs/ReleasePackaging.md](Docs/ReleasePackaging.md)에 정리한다.

## Sleep Prevention

MacDog는 일반 idle sleep 방지를 위해 IOKit power assertion을 사용한다. 덮개 닫힘 보호는 `pmset disablesleep` 기반이며 관리자 승인이 필요하다.

권한 도우미가 설치되어 있으면 MacDog가 덮개 닫힘 보호 설정 변경을 대신 처리한다. 권한 도우미가 설치된 상태에서 연결이 실패하면 예전 관리자 승인창으로 조용히 우회하지 않고 실패 상태를 표시한다.

2026-05-29 기준 확인된 실사용 결과:

- `SleepDisabled=1` 상태에서 덮개 닫힘 후 슬립/락으로 떨어지지 않음
- 대조군 `SleepDisabled=0`에서는 덮개를 닫자 즉시 잠금과 검정 화면이 발생
- Chrome Remote Desktop으로 제어 중인 MacBook에서도 장시간 덮개 닫힘 유지 확인

## Battery Charge Limit

macOS 26.4 이상 Apple silicon Mac에서는 native Charge Limit 값을 80~100% 범위로 읽고 적용한다. 이 기능은 배터리를 즉시 강제 방전시키는 기능이 아니라, macOS 충전 상한을 적용해 자연 하강/유지를 맡기는 방식이다.

2026-05-29 기준 개발 Mac에서는 UI에서 목표 한도 `90%`를 적용했고, AC 연결 상태의 배터리가 `95%`에서 `90%`로 내려가는 것을 확인했다.

## Data And Privacy

- Codex 사용량 기준은 로컬 Codex app-server의 `account/rateLimits/read` 응답이다.
- `primary.windowDurationMins = 300`은 5시간 창, `secondary.windowDurationMins = 10080`은 주간 창으로 해석한다.
- auth token, refresh token, cookie, session material은 읽거나 저장하지 않는다.
- cache에는 plan, 사용률, 초기화 시각, stale/error 상태 같은 표시 정보만 저장한다.
- 메뉴바 앱 UI process는 live Codex app-server나 Widget shared cache fallback을 직접 열지 않는다.

## Project Layout

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

## Documentation

- [ROADMAP.md](ROADMAP.md): 개발 로드맵과 잔여 이슈
- [Docs/RunnerBaseline.md](Docs/RunnerBaseline.md): 메뉴바 러너 asset 기준선
- [Docs/WidgetPackaging.md](Docs/WidgetPackaging.md): WidgetKit 패키징 경계
- [Docs/RuntimeVerification.md](Docs/RuntimeVerification.md): CPU/RSS runtime 검증 절차
- [Docs/Scripts.md](Docs/Scripts.md): `script/*.sh` 용도와 영향 범위
- [Docs/ClosedDisplayResearch.md](Docs/ClosedDisplayResearch.md): 덮개 닫힘 보호 조사와 검증 결과
- [Docs/PrivilegedHelperPlan.md](Docs/PrivilegedHelperPlan.md): 권한 도우미 설치와 IPC contract
- [Docs/ChargeLimitResearch.md](Docs/ChargeLimitResearch.md): Charge Limit 연동 조사 결과
- [Docs/ReleasePackaging.md](Docs/ReleasePackaging.md): GitHub Release와 DMG 배포 계획
- [Docs/GitHubReleaseChecklist.md](Docs/GitHubReleaseChecklist.md): PR 보호 규칙과 GitHub Release 체크리스트
- [AGENTS.md](AGENTS.md): 개발 규칙, 보안 원칙, 검증 체크리스트
- [CONTRIBUTING.md](CONTRIBUTING.md): PR 작성과 검증 기준

## License

Apache License 2.0. 자세한 내용은 [LICENSE](LICENSE)를 참고한다.
