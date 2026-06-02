# v1.1.0 수동/외부 검수 Runbook

상태: Apple Developer 의존 항목 제외 / 절차 고정 / 실제 수동 검수 ledger 완료

이 문서는 `ROADMAP.md`의 `v1.1.0` 우선 항목을 실제로 완료 처리하기 전에 따라야 하는 수동/외부 검수 순서를 정리합니다. 자동 검증, dry-run, self-test, static gate는 수동 UI 검수나 외부 서비스 실행을 대체하지 않습니다.

2026-06-02 현재 이 runbook의 6개 우선 항목은 `Docs/V110ManualEvidence.md`와 `Docs/V110ManualEvidence.json`에 `확인됨`으로 기록되어 있으며, 완료 ledger는 `script/verify_v110_manual_evidence.sh`로 검증합니다. 이 runbook은 절차와 금지 경계를 보존하기 위한 문서이므로, 이후 같은 항목을 다시 수행할 때도 아래 절차를 따릅니다.

증거 기록 원본은 `Docs/V110ManualEvidence.json`이고, 사람이 읽는 요약은 `Docs/V110ManualEvidence.md`입니다. 실제 검수 뒤에는 아래 형식으로 기록합니다.

```sh
script/record_v110_manual_evidence.sh --item <id> --status <status> --evidence "<실제 확인 내용>"
```

`--status verified`는 필요한 완료 증거를 모두 실제로 확인했을 때만 사용합니다.

## 공통 사전 확인

실제 UI, 설치, GitHub Actions를 건드리기 전 read-only 상태를 확인합니다.

```sh
./script/check.sh --no-run
./script/verify_v110_priority_plan.sh --self-test
./script/verify_v110_manual_evidence.sh --allow-incomplete
./script/verify_v110_manual_execution_readiness.sh --allow-incomplete
```

`./script/check.sh --no-run`은 앱을 새로 실행하지 않지만 build, test, packaging dry-run, 현재 설치 상태 조회를 수행합니다. 출력에 `app-freshness:differs-from-dist`가 있으면 최신 빌드 UI를 봤다고 기록하지 않습니다. 어떤 payload가 다른지 좁힐 때는 `./script/verify_install_state.sh --explain-current-dist`를 실행해 변경/추가/삭제 경로 요약을 기록합니다.
`./script/verify_v110_manual_execution_readiness.sh --allow-incomplete`는 실제 실행 없이 6개 우선 항목이 현재 `ready-for-manual-ui`, `blocked`, `external-required`, `ready-for-additional-runtime-sampling` 중 어디에 있는지 요약합니다.

## Apple Developer 제외 경계

Apple Developer Program, Developer ID 인증서, notarization credential, App Group provisioning, App Store Connect 권한이 필요한 항목은 v1.1.0 구현 계획에서 제외합니다. signed stable DMG, Developer ID signing, notarization, stapling, Gatekeeper 검증, App Group provisioned WidgetKit UI 검수, signed stable 기준 helper UX 검수는 이 runbook의 검수 항목이 아닙니다.

## WidgetKit 보존 경계

WidgetKit은 `v1.1.0` 기본 설치/배포 완료 조건에서 제외합니다. 기본 `MacDog.app`과 기본 DMG에는 `MacDogWidgetExtension.appex`를 포함하지 않고, usage cache LaunchAgent도 `--mirror-cache`를 사용하지 않습니다.

확인된 범위는 `Docs/WidgetPackaging.md`에 남깁니다. 요약하면 source-level WidgetKit view/provider, small/medium presentation, deep link 상수, cache 상태 표현, fixture writer self-test, Xcode host/extension build 일부, 기본 설치 제외 경계까지 확인했습니다. 그 이후 단계인 실제 위젯 UI의 shared cache updated/stale/error 표시, 위젯 클릭 deep link, App Group provisioning 기반 shared cache 접근은 확인하지 못했습니다.

## 1. 요일별 주간 잔여량 그래프 마무리와 실제 UI 검수

Evidence id: `weekly_usage_graph`

사전 확인:

```sh
./script/verify_cache_contract.sh
swift test --filter CodexUsageCacheTests
swift test --filter UsageMonitorStateTests
```

실제 확인:

- 최신 설치본 popover의 Codex 탭을 엽니다.
- 그래프 시작점이 현재 주간 reset 시작 요일에 맞는지 확인합니다.
- 100%, 50%, 0% 라벨과 그래프 영역이 분리되어 보이는지 확인합니다.
- 요일별 세로 구분선, 지나간 요일의 마지막 잔여율 점, 현재 퍼센트 표기, hover tooltip을 확인합니다.
- reset 직후/직전 문구 대신 실제 reset 요일이 표시되는지 확인합니다.

기록 예:

```sh
script/record_v110_manual_evidence.sh --item weekly_usage_graph --status verified --evidence "최신 설치본 Codex 탭에서 요일별 주간 잔여량 그래프, 현재 퍼센트, 과거 요일 점, hover tooltip, 실제 reset 요일 표시 확인"
```

## 2. 깨끗한 drag-and-drop DMG 설치 검수

Evidence id: `clean_drag_and_drop_dmg`

절대 규칙:

- 이 항목의 설치 검수는 최종 DMG를 Finder에서 열고, 사용자가 보는 화면에서 `MacDog.app`을 `Applications`로 실제 drag-and-drop하는 방식만 인정합니다.
- `script/install.sh`, `cp`, `ditto`, `rsync`, hdiutil mount 후 직접 복사, 앱 번들 직접 교체, Finder 창 숨김/화면 밖 조작은 이 항목의 대체 검수로 사용할 수 없습니다.
- 자동화 도구가 실제 drag-and-drop 제스처를 수행하거나 관찰할 수 없으면 이 항목은 `미수행`으로 기록하고 완료 처리하지 않습니다.

사전 확인:

```sh
./script/verify_release_packaging.sh
```

실제 확인:

- 오래된 설치본과 이전 다운로드 산출물이 없는 clean 환경을 준비합니다.
- DMG Finder 창에 `MacDog.app`과 `Applications` symlink만 보이는지 확인합니다.
- Finder에서 `MacDog.app`을 `Applications` symlink로 실제 drag-and-drop합니다.
- `/Applications`에서 앱을 직접 실행한 뒤 첫 실행 user component 마무리 설치가 동작하는지 확인합니다.
- 설치 디스크와 다운로드한 설치 파일 정리 안내가 과도하지 않은지 확인합니다.

기록 예:

```sh
script/record_v110_manual_evidence.sh --item clean_drag_and_drop_dmg --status verified --evidence "clean 환경에서 DMG Finder 구성, 실제 Finder drag-and-drop으로 /Applications 설치, 첫 실행 user component 마무리 설치 확인"
```

## 3. 앱 내부 helper 버튼 실제 클릭 검수

Evidence id: `helper_button_click`

사전 확인:

```sh
./script/verify_manual_ui_prerequisites.sh
./script/verify_privileged_helper_preflight.sh
```

실제 확인:

- 최신 설치본의 `잠들지 않기` 또는 설정 UI에서 helper 설치 버튼을 클릭합니다.
- 필요하면 관리자 승인창의 주체와 문구를 확인합니다.
- 설치 후 helper 상태, 앱 안내 문구, 버튼 상태가 바뀌는지 확인합니다.
- helper 제거 버튼을 클릭하고 제거 후 상태 전환을 확인합니다.

기록 예:

```sh
script/record_v110_manual_evidence.sh --item helper_button_click --status verified --evidence "최신 설치본 UI에서 helper 설치/제거 버튼 실제 클릭, 상태 문구와 helper 상태 전환 확인"
```

## 4. 플로팅 펫 실제 동작 검수

Evidence id: `floating_pet_manual_ui`

사전 확인:

```sh
./script/verify_runtime_contract.sh
```

실제 확인:

- 플로팅 펫을 드래그하고 앱 재표시 뒤 위치 저장을 확인합니다.
- 우클릭 메뉴를 열고 항목 위치와 동작을 확인합니다.
- 화면 밖으로 나갈 수 있는 상황에서 보정 동작을 확인합니다.
- 메뉴바 action과 플로팅 펫 action의 차이 또는 동일성을 확인합니다.

기록 예:

```sh
script/record_v110_manual_evidence.sh --item floating_pet_manual_ui --status verified --evidence "플로팅 펫 드래그 위치 저장, 우클릭 메뉴, 화면 밖 보정, 메뉴바 action 차이 확인"
```

## 5. 런타임 리소스 최적화 검토

Evidence id: `runtime_resource_review`

사전 확인:

```sh
./script/verify_runtime_contract.sh
./script/sample_existing_runtime_resources.sh --samples 5 --interval 1
```

실제 확인:

- 메뉴바 러너만 켠 상태의 CPU/RSS를 기록합니다.
- 플로팅 펫 로밍 상태의 CPU/RSS를 기록합니다.
- popover를 열고 1초 갱신이 켜진 상태의 CPU/RSS를 기록합니다.
- usage cache 60초 polling과 system metrics sampling 작업량을 검토합니다.
- energy impact는 macOS Activity Monitor 또는 Instruments 같은 별도 측정 결과로 기록합니다.

기록 예:

```sh
script/record_v110_manual_evidence.sh --item runtime_resource_review --status partiallyVerified --evidence "기존 실행 앱 CPU/RSS 5샘플 pass, energy impact와 상태별 장시간 측정은 남음"
```

## 6. unsigned GitHub Actions release workflow 실제 실행 검증

Evidence id: `unsigned_release_workflow_run`

사전 확인:

```sh
./script/verify_release_workflow.sh
```

실제 확인:

- release candidate workflow run URL과 결과를 기록합니다.
- unsigned draft release workflow run URL과 결과를 기록합니다.
- 생성된 artifact, checksum, draft release 결과를 기록합니다.
- run URL은 `https://github.com/<owner>/<repo>/actions/runs/<run-id>` 형태의 실제 URL로 기록합니다.
- GitHub draft release 결과는 생성된 release 또는 tag URL을 함께 기록합니다.
- signed stable workflow는 v1.1.0 완료 조건이 아니며 실행 증거로 요구하지 않습니다.

기록 예:

```sh
script/record_v110_manual_evidence.sh --item unsigned_release_workflow_run --status verified --evidence "release candidate workflow run URL https://github.com/dhseo90/MacDog/actions/runs/<id> success, unsigned draft workflow run URL https://github.com/dhseo90/MacDog/actions/runs/<id> success, artifact MacDog-<version>.dmg, checksum MacDog-<version>.dmg.sha256, GitHub draft release https://github.com/dhseo90/MacDog/releases/tag/<tag>"
```

## 금지 경계

- 이 runbook 자체는 수동/외부 검수를 완료하지 않습니다.
- GUI 앱 실행, 설치/삭제, LaunchAgent 등록, helper 변경, GitHub Actions 실행은 각 항목을 수행하기로 명시했을 때만 진행합니다.
- Apple Developer Program이 필요한 signing, notarization, stapling, Gatekeeper, App Group provisioned WidgetKit UI 검수는 v1.1.0 구현 계획에서 제외합니다.
- 실행하지 않은 UI, 설치, workflow 결과를 `확인됨`으로 기록하지 않습니다.
- 자동 검증만으로 `Docs/V110ManualEvidence.json`의 `overallStatus`를 `complete`로 바꾸지 않습니다.
