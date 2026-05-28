# Privileged Helper Plan

상태: helper 우선 sleep 제어 코드와 XPC 검증 발판 구현 / 실제 설치 미실행
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
- `verify_privileged_helper_xpc.sh`는 앱 번들 실행 파일의 read-only 진단 모드로 helper XPC `SleepDisabled` 조회만 확인하며, `dist/MacDog.app`을 설치된 앱보다 우선 사용한다.
- `verify_privileged_helper_preflight.sh`는 helper-only dry-run, 생성된 앱 번들, 현재 helper 상태, XPC 진단 경로를 실제 설치 전에 묶어서 확인한다.
- 앱의 덮개 닫힘 보호는 helper가 설치된 상태면 XPC helper로 `SleepDisabled` 조회/변경을 먼저 시도한다.
- helper가 없거나 실패하면 기존 직접 `pmset -g live` 조회와 AppleScript 관리자 승인 경로로 fallback한다.

이번 단계에서 하지 않는 것:

- helper 설치 명령 실행
- helper 삭제 명령 실행
- LaunchDaemon 실제 등록
- `pmset disablesleep` 값 변경
- 실행 중인 앱 재시작
- 잠들지 않기 설정값 변경
- `/Library/PrivilegedHelperTools`와 `/Library/LaunchDaemons`로 파일 복사
- helper XPC runtime 실기 검증

## 다음 구현 순서

1. 사용자 승인 후 `install.sh --helper-only`를 실제 실행한다.
2. `verify_privileged_helper_state.sh --expect-installed`와 `verify_privileged_helper_xpc.sh --expect-installed`로 상태 표시와 XPC listener를 검증한다.
3. helper 경유 `SleepDisabled` 조회/변경을 실기 검증한다.
4. 실제 덮개 닫힘 장시간 검증을 수행한다.

## 보안 원칙

- helper는 임의 shell command 실행기가 아니다.
- 허용 명령은 `/usr/bin/pmset -g live`, `/usr/bin/pmset -a disablesleep 0`, `/usr/bin/pmset -a disablesleep 1`뿐이다.
- 앱과 helper는 protocol version과 helper version을 검사한다.
- root helper XPC listener는 host app code signing requirement를 통과한 연결만 받는다.
- helper가 실패해도 앱은 기존 IOKit assertion과 원복 경로를 안전하게 처리해야 한다.
- 배터리 충전 제어는 같은 helper IPC 통로를 재사용할 수 있지만 별도 기능 게이트로 분리한다.
