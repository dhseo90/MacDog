# v1.1.0 수동/외부 검수 증거 현황

상태: 완료

이 문서는 `v1.1.0` 우선 항목을 실제 완료로 볼 수 있는 증거를 기록하는 ledger입니다. 구조화된 원본은 `Docs/V110ManualEvidence.json`이며, 이 Markdown 문서는 사람이 검수할 때 읽기 쉬운 요약입니다. 자동 검증, dry-run, self-test는 수동 UI 검수나 외부 서비스 실행을 대체하지 않습니다. 실제로 보지 않은 화면, 실제로 수행하지 않은 Finder drag-and-drop 설치, 실행하지 않은 unsigned GitHub Actions run은 `확인됨`으로 바꾸지 않습니다. Apple Developer Program이 필요한 항목은 v1.1.0 구현 계획에서 제외합니다.

기록 명령: `script/record_v110_manual_evidence.sh --item <id> --status <status> --evidence <text>`

## 1. 요일별 주간 잔여량 그래프 마무리와 실제 UI 검수

상태: 확인됨

필요 완료 증거:

- 최신 설치본 Codex 탭에서 요일별 주간 잔여량 그래프 실제 확인
- 주간 reset 시작 요일과 그래프 시작점 정렬 확인
- 100%, 50%, 0% 라벨과 그래프 영역 분리 확인
- 요일별 구분선과 지나간 요일 마지막 잔여율 점 확인
- 현재 퍼센트 표기와 hover tooltip 확인
- reset 직후/직전 대신 실제 reset 요일 표시 확인

현재 증거:

- 주간 잔여량 history cache 경로 추가
- Codex 탭 그래프 UI 1차 구현
- 요일별 구분선, 과거 일자 점, 현재 퍼센트 표기, hover tooltip 요구사항 반영
- CodexUsageCacheTests와 UsageMonitorStateTests에 주간 history 관련 자동 검증 포함
- 2026-06-02 최신 /Applications/MacDog.app 실행본 Codex 탭에서 요일별 주간 잔여량 그래프 확인. reset 시작 요일과 timeline은 6/1 월 -> 6/8 월로 표시되고, 100% 50% 0% 라벨과 그래프 영역이 분리됨. 요일별 세로 구분선, 지나간 요일 마지막 잔여율 점, 현재 퍼센트 표시(6/2 화 93%), hover tooltip/현재 점 표시 확인.
- 2026-06-02 사용자 지적 반영: 월요일 marker hover tooltip이 오늘/current percent label을 가리던 겹침을 수정. 새 dist/MacDog.app에서 hover tooltip은 왼쪽, current percent(91%)는 오른쪽에 분리 표시되어 요일별 주간 잔여량 그래프 label 충돌이 사라진 것을 실제 화면 캡처로 확인.
- 2026-06-02 v1.1.0 DMG drag-and-drop 갱신 후 최신 /Applications/MacDog.app에서 macdog://open으로 Codex 탭 popover를 실제 확인했습니다. 메뉴바 runner가 표시됐고, Codex 탭의 5시간/주간 사용률, 주간 잔여량 그래프, 6/1 월 -> 6/8 월 timeline, 현재 잔여율 표시가 최신 설치본에서 보였습니다.

남은 검수:

- 없음

## 2. 깨끗한 drag-and-drop DMG 설치 검수

상태: 확인됨

필요 완료 증거:

- 오래된 설치본과 이전 다운로드 산출물이 없는 clean install 환경 설명
- DMG Finder 창에 MacDog.app과 Applications symlink만 표시됨
- Finder에서 MacDog.app을 Applications로 실제 drag-and-drop 수행
- /Applications에서 첫 실행 설치 마무리와 user component 상태 확인

현재 증거:

- script/verify_release_packaging.sh
- script/package_release.sh --dry-run
- 2026-06-01 MacDog-1.1.0.dmg 생성과 hdiutil verify 통과
- 2026-06-01 Finder에서 MacDog 1.1.0 DMG 창이 보이고 MacDog.app과 Applications만 표시되는 것 확인
- 2026-06-01 실제 drag-and-drop 설치는 사용자 최종 승인 전 요청 변경으로 수행하지 않음
- 2026-06-02 최신 dist 기준 MacDog-1.1.0.dmg를 --version 1.1.0으로 재생성했고 hdiutil verify와 dist/release 디렉터리 기준 shasum -a 256 -c를 통과했습니다. DMG Finder 창에서 MacDog.app과 Applications symlink만 표시되는 clean release payload를 확인한 뒤 MacDog.app을 Applications로 실제 drag-and-drop했고, Finder의 기존 MacDog 대치 확인에서 대치를 선택했습니다. 설치 후 /Applications/MacDog.app은 dist/MacDog.app과 일치했고 app-owned codex-usage symlink/cache LaunchAgent/login launch 상태와 첫 실행 user component 마무리 상태가 유지됐으며, DMG 볼륨은 eject했습니다.

남은 검수:

- 없음

## 3. 앱 내부 helper 버튼 실제 클릭 검수

상태: 확인됨

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
- 2026-06-02 최신 /Applications/MacDog.app 설정 탭에서 helper 제거 버튼 클릭 확인: 권한 도우미 설치됨/준비됨 상태에서 도우미 제거를 눌렀고 앱 내부 alert에 제거 대상 /Library/PrivilegedHelperTools/com.dhseo.macdog.helper 및 /Library/LaunchDaemons/com.dhseo.macdog.helper.plist 표시 확인. 관리자 승인창은 MacDog 주체로 표시됐고 사용자 승인 후 helper:missing 확인. 이어서 helper 설치 버튼 클릭 확인: 권한 도우미 미설치/설치 필요 상태에서 도우미 설치를 눌렀고 앱 내부 alert에 변경할 시스템 위치와 반복 승인 감소 안내 표시 확인. 관리자 승인창은 MacDog 주체로 표시됐고 사용자 승인 후 helper:installed launchd:loaded, helper XPC read SleepDisabled=1, 설정 탭 권한 도우미 설치됨/권한 도우미 준비됨/도우미 제거 버튼 복귀 확인.

남은 검수:

- 없음

## 4. 플로팅 펫 실제 동작 검수

상태: 확인됨

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
- 2026-06-02 /Applications/MacDog.app에서 설정의 데스크톱 펫 표시를 실제 클릭해 플로팅 펫 표시 확인. 실제 마우스 드래그 후 desktopPetOriginX/Y가 531,149에서 30,294로 변경되어 드래그 위치 저장 확인. 플로팅 펫 우클릭 메뉴 실제 확인: 사용량 상세 보기, 캐시 다시 읽기, 움직임 줄이기, 애니메이션 일시 정지, 메뉴바로 돌아가기, 코덱스 사용량 종료 표시. 화면 밖 방향으로 실제 드래그 후 저장값이 X=0, Y=847로 화면 안 경계에 보정되어 화면 밖 보정 확인. 플로팅 펫 메뉴에서 메뉴바로 돌아가기 action을 실제 클릭해 desktopPetEnabled=0 및 플로팅 펫 창 숨김 확인. PetMenuModelTests 통과로 메뉴바/데스크톱 action 차이 확인, FloatingPetMotionBoundsTests 및 verify_runtime_contract.sh 통과.

남은 검수:

- 없음

## 5. 런타임 리소스 최적화 검토

상태: 확인됨

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
- 2026-06-02 /Applications/MacDog.app 실행 중 runtime CPU RSS energy impact 확인. 메뉴바 러너만 상태(desktopPetEnabled=0, MacDog window count=0): sample_existing_runtime_resources.sh --samples 5 --interval 1 통과, CPU avg 1.08%, max 1.80%, RSS avg/max 172.7MiB. 플로팅 펫 로밍 상태(desktopPetEnabled=1, 96x102 pet window only): CPU avg 5.74%, max 8.10%, RSS avg 174.1MiB, max 175.6MiB 통과. Popover refresh review 확인: Mac/활성 자원 탭을 실제 선택해 CPU/메모리/네트워크 수치 표시 및 1초 갱신 상태에서 CPU avg 5.68%, max 6.50%, RSS avg/max 172.9MiB 통과. energy impact 확인: top -l 5 POWER samples 0.0, 5.0, 6.7, 6.6, 7.0(max 7.0) while floating pet running. system metrics sampling 확인 및 usage cache 60초 polling/timer tolerance는 verify_runtime_contract.sh 통과로 검토. sample_existing_runtime_resources.sh --self-test는 sandbox /bin/ps 제한으로 1회 실패 후 권한 밖 재실행 통과. optimization 최적화 결정 확인: CPU/RSS threshold 미초과, popover 1초 metrics는 Mac 탭에서만 활성, popover 닫힘+펫 off 상태는 background system metrics capture를 건너뛰는 기존 정책 유지; 추가 코드 변경 없음.

남은 검수:

- 없음

## 6. unsigned GitHub Actions release workflow 실제 실행 검증

상태: 확인됨

필요 완료 증거:

- release candidate workflow run URL과 결과
- unsigned draft release workflow run URL과 결과
- 생성된 artifact와 checksum 결과
- GitHub draft release 결과

현재 증거:

- script/verify_release_workflow.sh
- 2026-06-02 release candidate workflow run URL [https://github.com/dhseo90/MacDog/actions/runs/26826717317](https://github.com/dhseo90/MacDog/actions/runs/26826717317) success on main headSha eed2212cb9706e33dba48418b93634a4dcc4ec2f. Verify, Package DMG, Verify DMG, Verify checksum, Upload release candidate artifact 단계 모두 success. artifact MacDog-1.1.0.dmg and checksum MacDog-1.1.0.dmg.sha256 confirmed via GitHub artifact MacDog-1.1.0-unsigned-release-candidate; downloaded to /tmp/macdog-v110-candidate.HIhk9S; shasum -a 256 -c passed; hdiutil verify passed.
- 2026-06-02 unsigned draft release workflow run URL [https://github.com/dhseo90/MacDog/actions/runs/26815189716](https://github.com/dhseo90/MacDog/actions/runs/26815189716) success exercised the draft release workflow path. Final v1.1.0 release was retargeted to main head eed2212cb9706e33dba48418b93634a4dcc4ec2f, assets were clobber-replaced with the latest candidate, and GitHub release [https://github.com/dhseo90/MacDog/releases/tag/v1.1.0](https://github.com/dhseo90/MacDog/releases/tag/v1.1.0) was published; tagName v1.1.0, isDraft=false, isPrerelease=true, targetCommitish=eed2212cb9706e33dba48418b93634a4dcc4ec2f, assets MacDog-1.1.0.dmg and MacDog-1.1.0.dmg.sha256 uploaded with /download/v1.1.0 URLs. Downloaded published release assets to /tmp/macdog-v110-published.9CRTcn; shasum -a 256 -c passed; hdiutil verify passed.
- 2026-06-02 earlier release workflow failures were fixed before the final v1.1.0 main release candidate and published release verification.
- signed stable workflow는 Apple Developer 의존 항목이라 v1.1.0 완료 조건에서 제외

남은 검수:

- 없음
