# v1.1.0 우선 항목 검증 계획

상태: Apple Developer 의존 항목 제외 / 구현 가능 항목 재구성 / 실제 UI, 설치, unsigned GitHub 실행 증거는 미수행

이 문서는 `ROADMAP.md`의 `v1.1.0` 우선 항목을 완료 증거 기준으로 다시 정리합니다. 자동화 가능한 검증은 수동 검수를 대체하지 않습니다. 실제 macOS UI, 실제 Finder drag-and-drop 설치, 실제 GitHub Actions run URL을 보지 않은 항목은 완료로 기록하지 않습니다. 실제 증거 현황은 `Docs/V110ManualEvidence.md`와 구조화 원본 `Docs/V110ManualEvidence.json`에 별도로 기록하고, `script/verify_v110_manual_evidence.sh --allow-incomplete`로 미완료 상태가 숨지 않는지 확인합니다. 실제 수동/외부 검수 순서는 `Docs/V110ManualRunbook.md`에 고정하고 `script/verify_v110_manual_runbook.sh --self-test`로 항목 누락을 확인합니다. 실제 검수 착수 가능 상태는 `script/verify_v110_manual_execution_readiness.sh --allow-incomplete`로 확인합니다.

## 제외 항목

Apple Developer Program, Developer ID 인증서, notarization credential, App Group provisioning, App Store Connect 권한이 필요한 항목은 v1.1.0 구현 계획에서 제외합니다. 따라서 signed stable DMG, Developer ID signing, notarization, stapling, Gatekeeper 검증, App Group provisioned WidgetKit UI 검수, signed stable 기준 helper UX 검수는 이 문서의 완료 항목이 아닙니다.

WidgetKit은 현재 구현 코드를 남겨둡니다. 확인된 범위는 source/test/fixture/opt-in build 경계이며, 그 이후인 실제 위젯 UI의 shared cache updated/stale/error 표시, 위젯 클릭 deep link, App Group provisioning 기반 shared cache 접근은 확인하지 못했습니다. 확인된 범위와 미확인 범위는 `Docs/WidgetPackaging.md`에 분리해 기록합니다.

## 우선 항목

1. 요일별 주간 잔여량 그래프 마무리와 실제 UI 검수
   - 완료 증거: 최신 설치본 popover에서 reset 시작 요일, 요일별 구분선, 지나간 요일의 마지막 잔여율 점, 현재 퍼센트 표기, hover tooltip이 의도대로 보임
   - 지원 검증: `MacDogWeeklyHistory`/cache 관련 Swift tests, `script/verify_cache_contract.sh`
   - 남은 증거: 최신 설치본 UI에서 그래프 실제 표시 확인

2. 깨끗한 drag-and-drop DMG 설치 검수
   - 완료 증거: 오래된 설치본과 이전 다운로드 산출물이 없는 상태에서 DMG가 `MacDog.app`과 `Applications` symlink만 보여주고, Finder에서 `MacDog.app`을 `Applications`로 실제 drag-and-drop한 뒤 첫 실행 설치 마무리가 동작함을 확인
   - 금지: `script/install.sh`, 직접 복사, hdiutil mount 후 파일 복사, 숨김 Finder 창/화면 밖 UI 조작은 이 항목의 완료 증거가 될 수 없습니다.
   - 지원 검증: `script/verify_release_packaging.sh`, `script/package_release.sh --dry-run`
   - 남은 증거: 깨끗한 사용자 환경 또는 동등한 clean install 환경의 Finder/첫 실행 증거

3. 앱 내부 helper 버튼 실제 클릭 검수
   - 완료 증거: 최신 설치본의 `잠들지 않기`/설정 UI에서 helper 설치/제거 버튼을 실제 클릭하고 상태 전환과 안내 문구 확인
   - 지원 검증: `script/verify_manual_ui_prerequisites.sh`, `script/verify_privileged_helper_preflight.sh`, `script/verify_privileged_helper_reinstall_plan.sh`
   - 남은 증거: GUI 클릭, 관리자 승인 흐름, helper 상태 변화 증거

4. 플로팅 펫 실제 동작 검수
   - 완료 증거: desktop UI에서 드래그 위치 저장, 우클릭 메뉴, 화면 밖 보정, 메뉴바와의 action 차이를 실제 조작으로 확인
   - 지원 검증: `FloatingPetMotionBoundsTests`, `PetMenuModelTests`, `script/verify_runtime_contract.sh`
   - 남은 증거: 실제 데스크톱 UI 증거

5. 런타임 리소스 최적화 검토
   - 완료 증거: 앱 실행 중 CPU/RSS/energy impact 측정, 메뉴바 러너 애니메이션, 플로팅 펫 로밍, popover 1초 갱신, usage cache 60초 polling, system metrics sampling 작업량 검토
   - 지원 검증: `script/verify_runtime_contract.sh`, `script/sample_existing_runtime_resources.sh --self-test`, `Docs/RuntimeVerification.md`
   - 남은 증거: 앱 실행 runtime sampling과 최적화 검토 결과

6. unsigned GitHub Actions release workflow 실제 실행 검증
   - 완료 증거: release candidate workflow와 unsigned draft release workflow의 실제 GitHub run URL/result, artifact, checksum, draft release 결과
   - 지원 검증: `script/verify_release_workflow.sh`
   - 남은 증거: GitHub Actions 실제 실행 결과
   - 제외: signed stable workflow는 Apple Developer 의존 항목이므로 v1.1.0 완료 조건이 아닙니다.

## 로컬 read-only 확인

아래 명령은 우선 항목 목록과 지원 검증 연결만 확인합니다. 실제 UI/설치/GitHub 실행을 수행하지 않습니다.

```sh
script/verify_v110_priority_plan.sh --self-test
script/verify_v110_manual_runbook.sh --self-test
script/render_v110_manual_evidence.sh --check
script/record_v110_manual_evidence.sh --self-test
script/verify_v110_manual_evidence.sh --allow-incomplete
```

실제 수동 검수나 외부 실행을 수행한 뒤에는 확인된 명령, 화면, run URL, 산출물 경로, 미확인 항목을 분리해서 기록합니다.
