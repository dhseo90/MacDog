# v1.1.0 우선 항목 검증 계획

상태: 우선 항목 리스트업 / read-only 지원 검증 구성 / 수동 evidence ledger 구성 / 실제 UI, 설치, 서명, GitHub 실행 증거는 미수행

이 문서는 `ROADMAP.md`의 `v1.1.0` 우선 항목을 완료 증거 기준으로 다시 정리합니다. 자동화 가능한 검증은 수동 검수를 대체하지 않습니다. 실제 macOS UI, 설치 환경, GitHub Actions, Developer ID signing/notarization/Gatekeeper 결과를 보지 않은 항목은 완료로 기록하지 않습니다. 실제 증거 현황은 `Docs/V110ManualEvidence.md`와 구조화 원본 `Docs/V110ManualEvidence.json`에 별도로 기록하고, `script/verify_v110_manual_evidence.sh --allow-incomplete`로 미완료 상태가 숨지 않는지 확인합니다. 실제 수동/외부 검수 순서는 `Docs/V110ManualRunbook.md`에 고정하고 `script/verify_v110_manual_runbook.sh --self-test`로 항목 누락을 확인합니다. 실제 검수 착수 가능 상태는 `script/verify_v110_manual_execution_readiness.sh --allow-incomplete`로 확인합니다.

## 우선 항목

WidgetKit은 `v1.1.0` 기본 완료 조건에서 제외합니다. source/test와 optional build script는 유지하지만, 기본 앱/DMG 설치에는 포함하지 않고 `--with-widget` opt-in build에서만 검수합니다. 확인된 범위와 미확인 범위는 `Docs/WidgetPackaging.md`에 분리해 기록합니다.

1. 앱 내부 helper 버튼 실제 클릭 검수
   - 완료 증거: 최신 설치본의 `잠들지 않기`/설정 UI에서 helper 설치/제거 버튼을 실제 클릭하고 상태 전환과 안내 문구 확인
   - 지원 검증: `script/verify_manual_ui_prerequisites.sh`, `script/verify_privileged_helper_preflight.sh`, `script/verify_privileged_helper_reinstall_plan.sh`
   - 남은 증거: GUI 클릭, 관리자 승인 흐름, helper 상태 변화 증거

2. signed stable DMG 기준 helper 설치 UX 검수
   - 완료 증거: signed stable DMG에서 helper 승인창 주체가 MacDog로 보이고 설치/제거 경로가 명확함을 확인
   - 지원 검증: `script/verify_distribution_gate.sh`, `script/verify_release_workflow.sh`
   - 남은 증거: signed stable artifact, 실제 UI 승인창 증거

3. 깨끗한 drag-and-drop DMG 설치 검수
   - 완료 증거: 오래된 설치본과 이전 다운로드 산출물이 없는 상태에서 DMG가 `MacDog.app`과 `Applications` symlink만 보여주고, Finder에서 `MacDog.app`을 `Applications`로 실제 drag-and-drop한 뒤 첫 실행 설치 마무리가 동작함을 확인
   - 금지: `script/install.sh`, 직접 복사, hdiutil mount 후 파일 복사, 숨김 Finder 창/화면 밖 UI 조작은 이 항목의 완료 증거가 될 수 없습니다.
   - 지원 검증: `script/verify_release_packaging.sh`, `script/package_release.sh --dry-run`
   - 남은 증거: 깨끗한 사용자 환경 또는 동등한 clean install 환경의 Finder/첫 실행 증거

4. GitHub Actions release workflow 실제 실행 검증
   - 완료 증거: release candidate, draft release, stable release workflow를 실제 GitHub 환경에서 실행한 run URL/result, artifact, checksum, release 생성 결과
   - 지원 검증: `script/verify_release_workflow.sh`
   - 남은 증거: GitHub Actions 실제 실행 결과

5. Developer ID signing, notarization, stapling, Gatekeeper 검증
   - 완료 증거: Developer ID signed artifact, notarization 성공, stapling 성공, `spctl` Gatekeeper assessment 성공
   - 지원 검증: `script/verify_distribution_gate.sh`
   - 남은 증거: Apple Developer ID credentials가 있는 환경에서 실제 signing/notarization/stapling/Gatekeeper 검증 결과

6. 플로팅 펫 실제 동작 검수
   - 완료 증거: desktop UI에서 드래그 위치 저장, 우클릭 메뉴, 화면 밖 보정, 메뉴바와의 action 차이를 실제 조작으로 확인
   - 지원 검증: `FloatingPetMotionBoundsTests`, `PetMenuModelTests`, `script/verify_runtime_contract.sh`
   - 남은 증거: 실제 데스크톱 UI 증거

7. 런타임 리소스 최적화 검토
   - 완료 증거: 앱 실행 중 CPU/RSS/energy impact 측정, 메뉴바 러너 애니메이션, 플로팅 펫 로밍, popover 1초 갱신, usage cache 60초 polling, system metrics sampling 작업량 검토
   - 지원 검증: `script/verify_runtime_contract.sh`, `script/sample_existing_runtime_resources.sh --self-test`, `Docs/RuntimeVerification.md`
   - 남은 증거: 앱 실행 runtime sampling과 최적화 검토 결과

## 로컬 read-only 확인

아래 명령은 우선 항목 목록과 지원 검증 연결만 확인합니다. 실제 UI/설치/서명/GitHub 실행을 수행하지 않습니다.

```sh
script/verify_v110_priority_plan.sh --self-test
script/verify_v110_manual_runbook.sh --self-test
script/render_v110_manual_evidence.sh --check
script/record_v110_manual_evidence.sh --self-test
script/verify_v110_manual_evidence.sh --allow-incomplete
```

실제 수동 검수나 외부 gate를 수행한 뒤에는 확인된 명령, 화면, run URL, 산출물 경로, 미확인 항목을 분리해서 기록합니다.
