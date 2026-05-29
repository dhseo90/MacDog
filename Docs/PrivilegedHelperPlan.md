# Privileged Helper Plan

상태: helper 우선 sleep 제어 코드 구현 / helper-only 실제 설치와 XPC read,set 검증 완료 / UI 설정 변경 검증 완료 / 장시간 덮개 닫힘 실사용 검증 통과 / drag-and-drop DMG 첫 실행 설치 마무리 구성 / 앱 내부 helper 설치,제거 버튼 1차 구현
작성일: 2026-05-28

## 목적

MacDog의 `pmset disablesleep` 제어를 AppleScript 관리자 프롬프트 반복 없이 처리합니다. 사용자는 helper 설치 때 한 번 승인하고, 이후 잠들지 않기 시간/상태 기준 변경은 앱 UI에서 자연스럽게 처리합니다.

## 확인한 기준

- Apple Service Management 문서는 앱 번들 안의 login item, launch agent, launch daemon helper를 `SMAppService`로 관리하는 흐름을 제공합니다.
- Apple Service Management 문서 기준 LaunchDaemon은 root로 동작하며, 앱과는 XPC 같은 IPC 요청으로 통신합니다.
- `SMJobBless`는 여전히 문서에 남아 있지만 deprecated로 표시되어 있습니다.

참고:

- <https://developer.apple.com/documentation/servicemanagement/>
- <https://support.apple.com/guide/deployment/manage-login-items-and-background-tasks-on-mac-depdca572563/web>

## 현재 구현 범위

- `MacDogPrivilegedHelperSupport` 모듈을 추가합니다.
- helper label, mach service name, bundle 내부 경로, `/Library/PrivilegedHelperTools` 대상 경로를 코드 상수로 고정합니다.
- helper IPC request/response JSON contract를 추가합니다.
- helper command allowlist를 `SleepDisabled` 조회와 `SleepDisabled 0/1` 변경으로 제한합니다.
- `pmset -g live`의 `SleepDisabled` parser를 공유 모듈로 분리해 앱과 helper가 같은 해석을 쓰게 합니다.
- `MacDogPrivilegedHelper` executable target을 추가합니다.
- helper command handler를 추가해 protocol/version 검사, allowlist command 실행, redacted failure response를 처리합니다.
- executable의 기본 실행은 도움말/버전/설치 계획 출력만 수행합니다.
- 개발용 `--handle-json-stdin`은 JSON request를 받아 allowlist command만 처리합니다.
- `--run-xpc-service` 모드는 Mach service listener를 열고 같은 JSON request/response contract를 XPC로 처리합니다.
- `install.sh --dry-run --with-helper`와 `uninstall.sh --dry-run --with-helper`는 helper 설치/삭제 계획을 보여줍니다.
- XPC listener는 연결 process id로 SecCode requirement를 검사한 뒤 host app만 받습니다.
- 기본 runtime requirement는 `com.dhseo.macdog.MacDog` bundle id와 Apple generic anchor를 요구합니다.
- 실제 배포 signing team id가 있으면 `MACDOG_HELPER_HOST_TEAM_ID`로 team requirement를 추가합니다.
- ad-hoc 개발 host 허용은 `MACDOG_HELPER_ALLOW_ADHOC_HOST=1`을 명시한 경우에만 사용합니다.
- helper 설치 상태 모델은 `/Library/PrivilegedHelperTools/com.dhseo.macdog.helper`와 `/Library/LaunchDaemons/com.dhseo.macdog.helper.plist` 존재 여부를 기준으로 `missing`, `partial`, `installed`를 구분합니다.
- 앱 쪽 `MacDogPrivilegedHelperClient`는 XPC request/response codec을 공유하고, 덮개 닫힘 보호의 helper 우선 제어 경로에 연결됩니다.
- 잠들지 않기 탭은 helper 설치 상태를 표시하고, 미설치/부분 설치/설치됨 상태별 다음 조치와 앱 내부 설치/제거 버튼을 제공합니다.
- 앱 내부 helper 설치 버튼은 앱 번들의 embedded helper executable과 생성된 LaunchDaemon plist를 관리자 승인 후 `/Library/PrivilegedHelperTools`와 `/Library/LaunchDaemons`에 설치합니다.
- 앱 내부 helper 제거 버튼은 관리자 승인 후 system LaunchDaemon을 bootout하고 helper executable/plist만 삭제하며 앱, CLI, user LaunchAgent는 건드리지 않습니다.
- 앱 내부 helper 설치 script builder는 signed 배포 빌드의 team id requirement와 unsigned/ad-hoc 개발 빌드의 명시적 `MACDOG_HELPER_ALLOW_ADHOC_HOST=1` 경계를 분리합니다.
- `build_and_run.sh --no-run`은 helper executable을 앱 번들의 `Contents/Library/LaunchServices/MacDogPrivilegedHelper`에 포함합니다.
- 앱 번들은 helper LaunchDaemon plist를 `Contents/Library/LaunchDaemons/com.dhseo.macdog.helper.plist`에 포함합니다.
- helper LaunchDaemon plist는 설치 후 `/Library/PrivilegedHelperTools/com.dhseo.macdog.helper --run-xpc-service`로 실행되도록 작성됩니다.
- `verify_app_bundle.sh`는 helper executable, LaunchDaemon plist, Mach service, helper code signature를 확인합니다.
- `install.sh --with-helper`는 관리자 승인 후 helper executable과 LaunchDaemon plist를 `/Library` 위치에 설치하고 system LaunchDaemon으로 bootstrap합니다.
- `install.sh --with-helper`는 터미널이 있으면 `sudo`, 비대화형/GUI 흐름이면 macOS administrator dialog를 사용합니다.
- `install.sh --helper-only`는 host signing requirement 산출에 `dist/MacDog.app`을 사용하고, 전체 install의 `--with-helper`는 설치된 앱 bundle을 사용합니다.
- unsigned/ad-hoc 개발 빌드에서는 LaunchDaemon environment에 `MACDOG_HELPER_ALLOW_ADHOC_HOST=1`을 넣어 로컬 테스트가 가능하게 합니다.
- signed 배포 빌드에서 team id가 확인되면 `MACDOG_HELPER_HOST_TEAM_ID` requirement로 host app을 제한합니다.
- `uninstall.sh --with-helper`는 관리자 승인 후 system LaunchDaemon을 bootout하고 helper executable/plist를 삭제합니다.
- `install.sh --helper-only`와 `uninstall.sh --helper-only`는 실행 중인 앱과 user LaunchAgent를 건드리지 않고 helper만 설치/삭제합니다.
- install/uninstall/update 흐름에서 MacDog가 `SleepDisabled=1`을 소유한 상태라면 정상 종료 대신 강제 종료해 종료 정리 루틴이 전역 값을 `0`으로 되돌리지 않게 합니다.
- release staging은 helper 설치/제거 command를 따로 만들지 않고, MacDog 설정 탭의 앱 내부 helper 설치/제거 UI로 안내합니다.
- GitHub Release DMG는 `MacDog.app`과 `Applications` symlink만 포함합니다. 앱을 `Applications`에서 처음 실행하면 user component 설치 마무리와 optional helper 설치 안내를 MacDog UI가 처리합니다.
- `verify_privileged_helper_state.sh`는 helper 파일, LaunchDaemon plist, code signature, launchd load 상태를 읽기 전용으로 확인합니다.
- `verify_privileged_helper_xpc.sh`는 앱 번들의 진단 모드를 LaunchServices로 실행해 helper XPC `SleepDisabled` 조회와 `--set 0|1 --restore` 변경/복구 검증을 수행하며, `dist/MacDog.app`을 설치된 앱보다 우선 사용합니다.
- `verify_install_state.sh --expect-current-dist`는 UI 검수 전에 설치된 앱과 `dist/MacDog.app`의 payload가 같은지, 실행 중인 MacDog가 설치된 앱 binary인지 확인해 이전 설치본 실행 문제를 막습니다.
- `verify_manual_ui_prerequisites.sh`는 메뉴바 popover, 플로팅 펫, helper 버튼, WidgetKit 수동 검수 전에 앱 bundle, 캐릭터 asset, 앱 privacy boundary, widget readiness, widget cache fixture self-test, helper preflight, Shortcuts read-only probe, 설치본 freshness를 묶어 확인합니다.
- `verify_privileged_helper_preflight.sh`는 helper-only dry-run, 생성된 앱 번들, 현재 helper 상태, XPC 진단 경로를 실제 설치 전에 묶어서 확인합니다.
- `verify_privileged_helper_reinstall_plan.sh`는 helper-only uninstall/install dry-run, 현재 helper 상태, XPC skip-runtime 조회를 묶어 실제 삭제/재설치 전 승인용 순서를 검증합니다.
- 앱의 덮개 닫힘 보호는 helper가 설치된 상태면 helper 연결로 `SleepDisabled` 조회/변경을 먼저 시도합니다.
- helper가 설치되지 않았을 때만 MacDog 앱이 소유한 관리자 승인 경로를 사용합니다. helper가 설치되어 있는데 연결이나 변경이 실패하면 예전 승인창으로 조용히 우회하지 않고 실패 상태를 표시합니다.
- 2026-05-28에 사용자 승인 후 `install.sh --helper-only` 실제 실행, `/Library/PrivilegedHelperTools/com.dhseo.macdog.helper` 설치, `/Library/LaunchDaemons/com.dhseo.macdog.helper.plist` 등록, `verify_privileged_helper_state.sh --expect-installed` 확인, `verify_privileged_helper_xpc.sh --expect-installed` read-only 조회를 완료했습니다.
- 2026-05-28에 helper 연결을 통한 `SleepDisabled` 변경 검증을 수행했고, `SleepDisabled=0 before=1 after=0 restored=1`로 되돌림까지 확인했습니다.
- 2026-05-28에 설치된 앱 실행 상태와 `SleepDisabled=1` 상태에서 짧은 덮개 닫힘 실기 검증을 수행했고, 다시 열었을 때 잠금/슬립 없이 기존 화면이 유지됨을 확인했습니다.
- 2026-05-28에 Windows PC의 Chrome Remote Desktop 세션으로 MacBook을 제어하는 상태에서 두 번째 덮개 닫힘 약 10분 재검증을 수행했고, 다시 열었을 때 원격 화면이 잠금/슬립 없이 그대로 유지됨을 확인했습니다.
- 2026-05-28에 MacBook을 연 상태에서 `uninstall.sh --helper-only` 실제 실행, `verify_privileged_helper_state.sh --expect-missing` 확인, `install.sh --helper-only` 실제 재설치, `verify_privileged_helper_state.sh --expect-installed` 확인을 완료했습니다.
- 2026-05-28에 재설치 후 `verify_privileged_helper_xpc.sh --expect-installed --set 0 --restore`를 실행했고 `SleepDisabled=0 before=1 after=0 restored=1`로 helper XPC 변경/복구를 다시 확인했습니다.
- 2026-05-28에 대조군으로 `SleepDisabled=0`을 설정하고 덮개를 닫자 즉시 잠금이 걸렸고, 잠시 뒤 검정 화면으로 바뀌었으며, 클릭 시 비밀번호 화면이 표시됨을 확인했습니다. 이후 `SleepDisabled=1 before=0 after=1`로 복구하고 read-only 조회에서 `SleepDisabled=1`을 확인했습니다.
- 2026-05-28에 설치된 앱이 20:31 빌드로 남아 있는 상태에서 UI `끔`을 눌렀을 때 비밀번호 프롬프트가 발생했습니다. 현재 `dist/MacDog.app`와 설치본 해시가 다름을 확인했고, `install.sh`로 최신 21:44 설치본으로 교체했습니다.
- 2026-05-29에 이전 설치본 재발 방지를 위해 개발 설치본 검수 전 `verify_install_state.sh --expect-current-dist` payload freshness guard를 추가했습니다. Release DMG 검수는 기존 설치본과 다운로드 산출물을 지운 뒤 새 DMG를 내려받아 진행하는 방식으로 분리했습니다.
- 2026-05-28에 최신 설치본에서 플로팅 강아지 좌클릭으로 popover를 열고, `잠들지 않기` 탭의 `시간 제어`와 `끔`을 실제 UI로 눌러 검증했습니다. 기준값 `SleepDisabled=0`에서 `시간 제어` 클릭 후 `SleepDisabled=1`, 이어서 `끔` 클릭 후 `SleepDisabled=0`, 마지막 `시간 제어` 클릭 후 `SleepDisabled=1`을 확인했고, 최신 설치본 UI 왕복 중 비밀번호 프롬프트는 발생하지 않았습니다.
- 2026-05-28에 helper 명령으로 이미 `SleepDisabled=1`을 만든 상태에서 UI를 켜면 MacDog가 외부 변경값을 소유하지 않으므로, UI를 끄더라도 해당 전역 값을 임의로 `0`으로 내리지 않는 것을 확인했습니다. 이는 "MacDog가 켠 값만 되돌림" 정책과 일치합니다.
- 2026-05-28 23:50 KST에 전원 연결 기준 슬립 방지, `SleepDisabled=1`, Charge Limit `90%`, 배터리 `95%`, AC 연결, `not charging` 상태로 장시간 에이징을 시작했습니다.
- 2026-05-29 사용자 실사용 확인에서 덮개 닫힘 상태가 슬립/락으로 떨어지지 않았고, 배터리가 `95%`에서 `90%`로 내려갔습니다.
- 2026-05-29에 권한 도우미 설치 상태별 popover 버튼 계약을 자동 테스트로 고정했습니다. 미설치는 `도우미 설치`, 부분 설치는 `제거` 후 `다시 설치`, 설치 완료는 `도우미 제거`만 노출합니다.
- 2026-05-29에 실제 UI 클릭 검수 전 read-only prerequisite gate를 추가해 이전 설치본, 깨진 widget readiness, helper preflight 누락을 먼저 잡도록 했다.

검증 시 주의:

- 되돌림 없는 `pmset disablesleep` 값 변경
- 장시간 `pmset disablesleep` 값 유지
- 개발 설치본에서는 `verify_install_state.sh --expect-current-dist` 없이 최신 설치본 UI 검수 완료 처리

## 다음 구현 순서

1. 앱 내부 helper 설치/제거 버튼을 최신 설치본에서 실제 클릭 검수합니다.
2. GitHub Release용 drag-and-drop DMG의 실제 Finder 설치와 첫 실행 설치 마무리 경로를 검증합니다.
3. 장시간 검증 결과를 기준으로 공개 배포 설치본에서도 같은 helper 상태 진단을 제공합니다.

## 보안 원칙

- helper는 임의 shell command 실행기가 아닙니다.
- 허용 명령은 `/usr/bin/pmset -g live`, `/usr/bin/pmset -a disablesleep 0`, `/usr/bin/pmset -a disablesleep 1`뿐입니다.
- 앱과 helper는 protocol version과 helper version을 검사합니다.
- root helper XPC listener는 host app code signing requirement를 통과한 연결만 받습니다.
- helper가 실패해도 앱은 기존 IOKit assertion과 되돌림 경로를 안전하게 처리해야 합니다.
- 배터리 충전 제어는 같은 helper IPC 통로를 재사용할 수 있지만 별도 기능 게이트로 분리합니다.
