# v1.2.3 이후 설계 작업 계획

## 목적

코어 정리와 문서 정리가 끝난 뒤 바로 기능을 늘리기보다, 실제 구현 경계에 맞춰 다음 설계 산출물을 정리합니다. 이 문서는 구현 착수 지시가 아니라 다음 설계 작업의 순서와 산출물을 고정합니다.

## 설계 입력

- popover는 module routing shell과 module별 panel 파일로 분리됐습니다.
- usage cache refresh와 popover placement 계산은 controller 밖의 작은 타입으로 분리됐습니다.
- Codex usage JSON/cache 계약, app-server 해석, WidgetKit 보존 경계는 변경하지 않았습니다.
- v1.2.1/v1.2.2 release package/download 완료 증거는 이 작업에서 확인하지 않았습니다.

## 설계 순서

1. Module boundary 설계
   - Codex, Mac resources, Sleep, Battery, Settings module이 공유하는 입력 상태와 action boundary를 정리합니다.
   - `UsageMonitorState`를 계속 단일 state로 둘지, module별 view model을 도입할지 판단합니다.
   - 완료 산출물: module boundary 문서와 변경하지 않을 JSON/cache 계약 목록

2. Release operations 설계
   - v1.2.x release를 닫을 때 필요한 GitHub Release asset, checksum, published download, final smoke 증거를 checklist로 재정렬합니다.
   - signed stable workflow는 Apple Developer 의존 항목으로 계속 제외합니다.
   - 완료 산출물: v1.2.x release close checklist와 미수행/건너뜀 보고 기준

3. 제품 방향 재정렬
   - 코어 정리 후 바로 구현할 유틸리티 기능을 고르기 전에, 현재 popover module 구조에서 반복 사용 가치가 큰 흐름을 비교합니다.
   - 후보는 승인 전까지 backlog로만 다루고, 기능 구현은 별도 milestone 지시가 있을 때 시작합니다.
   - 완료 산출물: ROADMAP 재정렬 초안

## 완료 조건

- 문서가 실제 코드 구조와 어긋나지 않습니다.
- Apple Developer Program, notarization, App Group provisioning이 필요한 항목을 현재 구현 완료 조건으로 쓰지 않습니다.
- 실행하지 않은 GUI/설치/릴리즈 검증은 완료로 기록하지 않습니다.
