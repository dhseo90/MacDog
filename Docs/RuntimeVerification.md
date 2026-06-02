# 런타임 검증

상태: 절차 정리 완료 / v1.1.0 짧은 CPU/RSS/energy 검토 완료 / 장시간 benchmark 미수행
작성일: 2026-05-27

## 목적

MacDog는 메뉴바 애니메이션, 주기적 cache polling, 데스크톱 플로팅 펫을 계속 실행하는 앱입니다. 그래서 기능 검증과 별도로 CPU/RSS가 튀지 않는지 샘플링합니다.

## 짧은 smoke

앱을 실행하고 10초 동안 CPU/RSS를 샘플링합니다.

```sh
./script/build_and_run.sh --verify-runtime 10
```

데스크톱 플로팅 펫을 켠 상태로 10초 동안 CPU/RSS를 샘플링합니다.

```sh
./script/build_and_run.sh --verify-floating-pet-runtime 10
```

이미 실행 중인 설치본이나 개발 빌드를 종료/재실행하지 않고 짧게 확인하려면 read-only 샘플러를 사용합니다.

```sh
./script/sample_existing_runtime_resources.sh --samples 5 --interval 1
```

이 명령은 기본적으로 `MacDog` 프로세스를 찾고, 이미 실행 중인 프로세스의 CPU/RSS만 읽습니다. 앱을 빌드하거나 실행하거나 종료하지 않고, 설정/LaunchAgent/helper/signing 상태도 바꾸지 않습니다. 프로세스가 없으면 실패하며, 자동 검증에서는 `--self-test`만 사용합니다.

## 장시간 검증

장시간 검증은 앱 실행과 사용자 환경 상태를 바꾸므로 명시 요청이 있을 때만 실행합니다.

권장 순서:

```sh
./script/build_and_run.sh --verify-runtime 60
./script/build_and_run.sh --verify-floating-pet-runtime 60
```

더 긴 검증이 필요하면 같은 명령의 duration을 늘립니다.

```sh
./script/build_and_run.sh --verify-runtime 300
./script/build_and_run.sh --verify-floating-pet-runtime 300
```

## 판정 기준

현재 스크립트는 `ps` 기반으로 1초 간격 CPU/RSS를 샘플링합니다.

- CPU max가 50%를 넘으면 실패
- RSS max가 250MB를 넘으면 실패
- 출력에는 sample count, 평균 CPU, 최대 CPU, 평균 RSS, 최대 RSS가 포함됩니다.
- `sample_existing_runtime_resources.sh`는 같은 기준을 이미 실행 중인 프로세스에 read-only로 적용합니다.

이 기준은 regression guard이며 정밀한 배터리 benchmark는 아닙니다. 배터리 영향은 같은 작업을 AC 전원과 배터리 환경에서 반복해 비교해야 합니다.

## 리소스 정책

- usage cache 60초 timer는 tolerance를 둡니다. 정확한 초 단위 실행이 필요 없는 cache read는 macOS가 timer wakeup을 합칠 수 있게 합니다.
- 주간 잔여량 그래프 history는 cache writer 성공 시 별도 파일에 기록합니다. 5분보다 촘촘하고 잔여율 변화가 0.25%p 미만인 샘플은 건너뛰어 1주일 그래프가 과밀해지지 않게 합니다.
- popover 1초 local metrics timer는 Mac/Sleep/Battery 탭에서만 켭니다. Codex/Settings 탭이거나 popover가 닫혀 있으면 1초 timer를 중지합니다.
- popover가 닫혀 있고 플로팅 펫이나 metric 기반 잠들지 않기 trigger가 필요하지 않으면 60초 usage cache refresh에서 새 system metrics snapshot을 만들지 않습니다.
- WidgetKit timeline은 기본 설치/배포에서 제외합니다. `--with-widget` opt-in build에서만 60초 뒤 갱신을 요청하며, 실제 갱신 시각은 macOS 정책에 맡깁니다.
- 플로팅 펫 runtime smoke는 테스트 후 `desktopPetEnabled` preference를 원래 값으로 되돌립니다.
- 플로팅 펫 이동 timer는 calm 20fps, active 24fps, fast/sprint 30fps로 사용량 단계에 따라 조절합니다. reduced motion, limit, 시스템 부하, 배터리/충전 반응처럼 이동하지 않는 상태는 이동 tick 대신 포즈 frame interval만 사용합니다.

## 미수행 항목

- 60초 이상 같은 조건을 유지하는 장시간 runtime benchmark
- 실제 배터리 방전률 비교
- 새 UI 변경 이후에는 메뉴바/플로팅 펫 화면 육안 재검수
