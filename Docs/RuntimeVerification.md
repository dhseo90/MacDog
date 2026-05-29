# 런타임 검증

상태: 절차 정리 완료 / 장시간 검증 미수행
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

이 기준은 regression guard이며 정밀한 배터리 benchmark는 아닙니다. 배터리 영향은 같은 작업을 AC 전원과 배터리 환경에서 반복해 비교해야 합니다.

## 미수행 항목

- 60초 이상 장시간 runtime 검증
- 실제 배터리 방전률 비교
- 실제 메뉴바/플로팅 펫 화면 육안 검수
