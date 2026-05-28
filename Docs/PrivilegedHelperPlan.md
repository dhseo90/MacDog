# Privileged Helper Plan

상태: helper 우선 sleep 제어 코드 구현 / helper-only 실제 설치와 XPC read,set 검증 완료 / UI 설정 변경 검증 완료 / 덮개 닫힘 실기 검증 통과
작성일: 2026-05-28

## 목적

MacDog의 `pmset disablesleep` 제어를 AppleScript 관리자 프롬프트 반복 없이 처리한다. 사용자는 helper 설치 때 한 번 승인하고, 이후 잠들지 않기 시간/상태 기준 변경은 앱 UI에서 자연스럽게 처리한다.

## 확인한 기준

- Apple Service Management 문서는 앱 번들 안의 login item, launch agent, launch daemon helper를 `SMAppService`로 관리하는 흐름을 제공한다.
- Apple Service Management 문서 기준 LaunchDaemon은 root로 동작하며, 앱과는 XPC 같은 IPC 요청으로 통신한다.
- `SMJobBless`는 여전히 문서에 남아 있지만 deprecated로 표시되어 있다.

참고:

- <https://developer.apple.com/documentation/servicemanagement/>
- <https://support.apple.com/guide/deployment/manage-login-items-and-background-tasks-on-mac-depdca572563/web>

## 현재 구현 범위

- `MacDogPrivilegedHelperSupport` 모듈을 추가한다.
- helper label, mach service name, bundle 내부 경로, `/Library/PrivilegedHelperTools` 대상 경로를 코드 상수로 고정한다.
- helper IPC request/response JSON contract를 추가한다.
- helper command allowlist를 `SleepDisabled` 조회와 `SleepDisabled 0/1` 변경으로 제한한다.
- `pmset -g live`의 `SleepDisabled` parser를 공유 모듈로 분리해 앱과 helper가 같은 해석을 쓰게 한다.
- `MacDogPrivilegedHelper` executable target을 추가한다.
- helper command handler를 추가해 protocol/version 검사, allowlist command 실행, redacted failure response를 처리한다.
- executable의 기본 실행은 도움말/버전/설치 계획 출력만 수행한다.
- 개발용 `--handle-json-stdin`은 JSON request를 받아 allowlist command만 처리한다.
- `--run-xpc-service` 모드는 Mach service listener를 열고 같은 JSON request/response contract를 XPC로 처리한다.
- `install.sh --dry-run --with-helper`와 `uninstall.sh --dry-run --with-helper`는 helper 설치/삭제 계획을 보여준다.
- XPC listener는 연결 process id로 SecCode requirement를 검사한 뒤 host app만 받는다.
- 기본 runtime requirement는 `com.dhseo.macdog.MacDog` bundle id와 Apple generic anchor를 요구한다.
- 실제 배포 signing team id가 있으면 `MACDOG_HELPER_HOST_TEAM_ID`로 team requirement를 추가한다.
- ad-hoc 개발 host 허용은 `MACDOG_HELPER_ALLOW_ADHOC_HOST=1`을 명시한 경우에만 사용한다.
- helper 설치 상태 모델은 `/Library/PrivilegedHelperTools/com.dhseo.macdog.helper`와 `/Library/LaunchDaemons/com.dhseo.macdog.helper.plist` 존재 여부를 기준으로 `missing`, `partial`, `installed`를 구분한다.
- 앱 쪽 `MacDogPrivilegedHelperClient`는 XPC request/response codec을 공유하고, 덮개 닫힘 보호의 helper 우선 제어 경로에 연결된다.
- 잠들지 않기 탭은 helper 설치 상태를 읽기 전용으로 표시한다.
- `build_and_run.sh --no-run`은 helper executable을 앱 번들의 `Contents/Library/LaunchServices/MacDogPrivilegedHelper`에 포함한다.
- 앱 번들은 helper LaunchDaemon plist를 `Contents/Library/LaunchDaemons/com.dhseo.macdog.helper.plist`에 포함한다.
- helper LaunchDaemon plist는 설치 후 `/Library/PrivilegedHelperTools/com.dhseo.macdog.helper --run-xpc-service`로 실행되도록 작성된다.
- `verify_app_bundle.sh`는 helper executable, LaunchDaemon plist, Mach service, helper code signature를 확인한다.
- `install.sh --with-helper`는 관리자 승인 후 helper executable과 LaunchDaemon plist를 `/Library` 위치에 설치하고 system LaunchDaemon으로 bootstrap한다.
- `install.sh --helper-only`는 host signing requirement 산출에 `dist/MacDog.app`을 사용하고, 전체 install의 `--with-helper`는 설치된 앱 bundle을 사용한다.
- unsigned/ad-hoc 개발 빌드에서는 LaunchDaemon environment에 `MACDOG_HELPER_ALLOW_ADHOC_HOST=1`을 넣어 로컬 테스트가 가능하게 한다.
- signed 배포 빌드에서 team id가 확인되면 `MACDOG_HELPER_HOST_TEAM_ID` requirement로 host app을 제한한다.
- `uninstall.sh --with-helper`는 관리자 승인 후 system LaunchDaemon을 bootout하고 helper executable/plist를 삭제한다.
- `install.sh --helper-only`와 `uninstall.sh --helper-only`는 실행 중인 앱과 user LaunchAgent를 건드리지 않고 helper만 설치/삭제한다.
- `verify_privileged_helper_state.sh`는 helper 파일, LaunchDaemon plist, code signature, launchd load 상태를 읽기 전용으로 확인한다.
- `verify_privileged_helper_xpc.sh`는 앱 번들의 진단 모드를 LaunchServices로 실행해 helper XPC `SleepDisabled` 조회와 `--set 0|1 --restore` 변경/복구 검증을 수행하며, `dist/MacDog.app`을 설치된 앱보다 우선 사용한다.
- `verify_privileged_helper_preflight.sh`는 helper-only dry-run, 생성된 앱 번들, 현재 helper 상태, XPC 진단 경로를 실제 설치 전에 묶어서 확인한다.
- `verify_privileged_helper_reinstall_plan.sh`는 helper-only uninstall/install dry-run, 현재 helper 상태, XPC skip-runtime 조회를 묶어 실제 삭제/재설치 전 승인용 순서를 검증한다.
- 앱의 덮개 닫힘 보호는 helper가 설치된 상태면 XPC helper로 `SleepDisabled` 조회/변경을 먼저 시도한다.
- helper가 없거나 실패하면 기존 직접 `pmset -g live` 조회와 AppleScript 관리자 승인 경로로 fallback한다.
- 2026-05-28에 사용자 승인 후 `install.sh --helper-only` 실제 실행, `/Library/PrivilegedHelperTools/com.dhseo.macdog.helper` 설치, `/Library/LaunchDaemons/com.dhseo.macdog.helper.plist` 등록, `verify_privileged_helper_state.sh --expect-installed` 확인, `verify_privileged_helper_xpc.sh --expect-installed` read-only 조회를 완료했다.
- 2026-05-28에 helper XPC 경유 `SleepDisabled` 변경 검증을 수행했고, `SleepDisabled=0 before=1 after=0 restored=1`로 원복까지 확인했다.
- 2026-05-28에 설치된 앱 실행 상태와 `SleepDisabled=1` 상태에서 짧은 덮개 닫힘 실기 검증을 수행했고, 다시 열었을 때 잠금/슬립 없이 기존 화면이 유지됨을 확인했다.
- 2026-05-28에 Windows PC의 Chrome Remote Desktop 세션으로 MacBook을 제어하는 상태에서 두 번째 덮개 닫힘 약 10분 재검증을 수행했고, 다시 열었을 때 원격 화면이 잠금/슬립 없이 그대로 유지됨을 확인했다.
- 2026-05-28에 MacBook을 연 상태에서 `uninstall.sh --helper-only` 실제 실행, `verify_privileged_helper_state.sh --expect-missing` 확인, `install.sh --helper-only` 실제 재설치, `verify_privileged_helper_state.sh --expect-installed` 확인을 완료했다.
- 2026-05-28에 재설치 후 `verify_privileged_helper_xpc.sh --expect-installed --set 0 --restore`를 실행했고 `SleepDisabled=0 before=1 after=0 restored=1`로 helper XPC 변경/복구를 다시 확인했다.
- 2026-05-28에 대조군으로 `SleepDisabled=0`을 설정하고 덮개를 닫자 즉시 잠금이 걸렸고, 잠시 뒤 검정 화면으로 바뀌었으며, 클릭 시 비밀번호 화면이 표시됨을 확인했다. 이후 `SleepDisabled=1 before=0 after=1`로 복구하고 read-only 조회에서 `SleepDisabled=1`을 확인했다.
- 2026-05-28에 설치된 앱이 20:31 빌드로 남아 있는 상태에서 UI `끔`을 눌렀을 때 비밀번호 프롬프트가 발생했다. 현재 `dist/MacDog.app`와 설치본 해시가 다름을 확인했고, `install.sh`로 최신 21:44 설치본으로 교체했다.
- 2026-05-28에 최신 설치본에서 플로팅 강아지 좌클릭으로 popover를 열고, `잠들지 않기` 탭의 `시간 제어`와 `끔`을 실제 UI로 눌러 검증했다. 기준값 `SleepDisabled=0`에서 `시간 제어` 클릭 후 `SleepDisabled=1`, 이어서 `끔` 클릭 후 `SleepDisabled=0`, 마지막 `시간 제어` 클릭 후 `SleepDisabled=1`을 확인했고, 최신 설치본 UI 왕복 중 비밀번호 프롬프트는 발생하지 않았다.
- 2026-05-28에 helper 명령으로 이미 `SleepDisabled=1`을 만든 상태에서 UI를 켜면 MacDog가 외부 변경값을 소유하지 않으므로, UI를 끄더라도 해당 전역 값을 임의로 `0`으로 내리지 않는 것을 확인했다. 이는 "MacDog가 켠 값만 원복" 정책과 일치한다.

검증 시 주의:

- 원복 없는 `pmset disablesleep` 값 변경
- 장시간 `pmset disablesleep` 값 유지
- 최신 설치본이 실행 중인지 확인하지 않은 상태의 UI 검수 완료 처리

## 다음 구현 순서

1. 설치/업데이트 흐름에서 Terminal 비밀번호 프롬프트 의존을 줄이는 배포 polish를 진행한다.
2. GitHub Release용 더블클릭 설치 artifact의 실제 더블클릭 설치 경로를 검증한다.
3. closed-display 장시간 실기 검증과 배터리 영향 확인을 진행한다.

## 보안 원칙

- helper는 임의 shell command 실행기가 아니다.
- 허용 명령은 `/usr/bin/pmset -g live`, `/usr/bin/pmset -a disablesleep 0`, `/usr/bin/pmset -a disablesleep 1`뿐이다.
- 앱과 helper는 protocol version과 helper version을 검사한다.
- root helper XPC listener는 host app code signing requirement를 통과한 연결만 받는다.
- helper가 실패해도 앱은 기존 IOKit assertion과 원복 경로를 안전하게 처리해야 한다.
- 배터리 충전 제어는 같은 helper IPC 통로를 재사용할 수 있지만 별도 기능 게이트로 분리한다.
