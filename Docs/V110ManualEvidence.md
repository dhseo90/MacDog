# v1.1.0 수동/외부 검수 증거 현황

상태: 미완료

이 문서는 `v1.1.0` 우선 항목을 실제 완료로 볼 수 있는 증거를 기록하는 ledger입니다. 구조화된 원본은 `Docs/V110ManualEvidence.json`이며, 이 Markdown 문서는 사람이 검수할 때 읽기 쉬운 요약입니다. 자동 검증, dry-run, self-test는 수동 UI 검수나 외부 서비스 실행을 대체하지 않습니다. 실제로 보지 않은 화면, 실행하지 않은 GitHub Actions run, 수행하지 않은 signing/notarization/Gatekeeper 검증은 `확인됨`으로 바꾸지 않습니다.

기록 명령: `script/record_v110_manual_evidence.sh --item <id> --status <status> --evidence <text>`

## 1. 앱 내부 helper 버튼 실제 클릭 검수

상태: 미확인

필요 완료 증거:
- 최신 설치본에서 helper 설치 버튼 실제 클릭
- 최신 설치본에서 helper 제거 버튼 실제 클릭
- 설치/제거 후 helper 상태 전환과 안내 문구 확인
- 관리자 승인창이 표시된 경우 주체와 문구 확인

현재 증거:
- script/verify_manual_ui_prerequisites.sh
- script/verify_privileged_helper_preflight.sh
- script/verify_privileged_helper_reinstall_plan.sh
- 2026-05-31 read-only manual UI preflight: helper readiness passed under Xcode toolchain, but installed /Applications/MacDog.app differs from dist/MacDog.app; helper install/remove buttons were not clicked
- 2026-05-31 ./script/verify_install_state.sh --explain-current-dist: installed /Applications/MacDog.app differs only at Contents/MacOS/MacDog; helper buttons still not clicked

남은 검수:
- 실제 앱 UI 클릭
- helper 상태 변화 확인
- 관리자 승인 흐름 확인

## 2. signed stable DMG 기준 helper 설치 UX 검수

상태: 미확인

필요 완료 증거:
- signed stable DMG 산출물 경로와 checksum
- helper 설치 승인창 주체가 MacDog로 표시됨
- helper 설치/제거 경로와 사용자 안내 문구 확인

현재 증거:
- script/verify_distribution_gate.sh
- script/verify_release_workflow.sh

남은 검수:
- Developer ID signed stable artifact 생성
- signed build에서 helper 승인 UI 확인

## 3. 깨끗한 drag-and-drop DMG 설치 검수

상태: 미확인

필요 완료 증거:
- 오래된 설치본과 이전 다운로드 산출물이 없는 clean install 환경 설명
- DMG Finder 창에 MacDog.app과 Applications symlink만 표시됨
- Finder에서 MacDog.app을 Applications로 실제 drag-and-drop 수행
- /Applications에서 첫 실행 설치 마무리와 user component 상태 확인

현재 증거:
- script/verify_release_packaging.sh
- script/package_release.sh --dry-run

남은 검수:
- clean 환경에서 실제 Finder drag-and-drop 설치
- 첫 실행 설치 마무리 확인

## 4. GitHub Actions release workflow 실제 실행 검증

상태: 미확인

필요 완료 증거:
- release candidate workflow run URL과 결과
- draft release workflow run URL과 결과
- stable release workflow run URL과 결과
- 생성된 artifact, checksum, GitHub Release 결과

현재 증거:
- script/verify_release_workflow.sh
- 2026-05-31 script/verify_v110_manual_evidence.sh --self-test: weak GitHub Actions evidence without real actions/runs URLs, artifact/checksum, and release URL is rejected; actual workflow not run

남은 검수:
- 실제 GitHub Actions workflow dispatch
- artifact, checksum, release 결과 확인

## 5. Developer ID signing, notarization, stapling, Gatekeeper 검증

상태: 미확인

필요 완료 증거:
- Developer ID signing에 사용한 stable artifact 식별자
- xcrun notarytool submit 성공 결과
- xcrun stapler staple 및 xcrun stapler validate 성공 결과
- spctl Gatekeeper assessment 성공 결과

현재 증거:
- script/verify_distribution_gate.sh
- 2026-05-31 script/verify_v110_manual_evidence.sh --self-test: weak Developer ID evidence without 64-char SHA-256, notarytool submit, stapler, and spctl accepted results is rejected; actual signing/notarization/Gatekeeper not run

남은 검수:
- Apple Developer ID credential이 있는 환경에서 signing 수행
- notarization, stapling, Gatekeeper 검증 수행

## 6. 플로팅 펫 실제 동작 검수

상태: 부분 확인

필요 완료 증거:
- 플로팅 펫 드래그 후 위치 저장 확인
- 우클릭 메뉴 확인
- 화면 밖 보정 확인
- 메뉴바와 플로팅 펫 action 차이 또는 동일성 확인

현재 증거:
- FloatingPetMotionBoundsTests
- PetMenuModelTests
- script/verify_runtime_contract.sh
- ROADMAP.md의 좌클릭 popover와 말풍선 방향 확인 기록
- 2026-05-31 Computer Use attempted MacDog UI state read for actual floating pet verification, but LSUIElement/menu bar app timed out without observable key window; no new floating pet UI behavior verified
- 2026-05-31 ./script/verify_install_state.sh --explain-current-dist: installed /Applications/MacDog.app differs only at Contents/MacOS/MacDog; latest floating pet UI still not verified

남은 검수:
- 드래그 위치 저장 실제 확인
- 우클릭 메뉴 실제 확인
- 화면 밖 보정 실제 확인
- 메뉴바 action 차이 실제 확인

## 7. 런타임 리소스 최적화 검토

상태: 부분 확인

필요 완료 증거:
- 앱 실행 중 CPU, RSS, energy impact 측정 결과
- 메뉴바 러너 애니메이션 검토
- 플로팅 펫 로밍 검토
- popover 1초 갱신 검토
- usage cache 60초 polling 검토
- system metrics sampling 검토
- 최적화 적용 여부와 재검증 결과

현재 증거:
- 60초 cache refresh timer tolerance
- 불필요한 background system metrics capture 회피
- 플로팅 펫 이동 timer를 calm 20fps, active 24fps, fast/sprint 30fps로 조절
- script/verify_runtime_contract.sh
- script/sample_existing_runtime_resources.sh --self-test
- script/check.sh --no-run
- 2026-05-31 script/sample_existing_runtime_resources.sh --samples 3 --interval 1 on existing /Applications/MacDog.app pid 6261: cpu_avg=0.87%, cpu_max=1.90%, rss_avg=90.7MiB, rss_max=90.8MiB, result=pass
- 2026-05-31 script/sample_existing_runtime_resources.sh --samples 5 --interval 1 on existing /Applications/MacDog.app pid 6261: cpu_avg=0.82%, cpu_max=1.40%, rss_avg=91.1MiB, rss_max=91.1MiB, result=pass
- 2026-05-31 ./script/check.sh --no-run passed after runtime policy updates; Swift tests 195 passed, 1 skipped, 0 failures; UI-specific runtime sampling and energy impact still not run
- 2026-05-31 popover 1초 local metrics timer gating added: timer runs only while popover is shown on Mac/Sleep/Battery tabs, and stops on Codex/Settings or closed popover; PopoverMetricsRefreshPolicyTests passed with Xcode toolchain

남은 검수:
- 플로팅 펫/Popover 상태별 추가 runtime sampling
- energy impact 확인
- 60초 이상 장시간 runtime 검증
