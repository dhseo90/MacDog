# AGENTS.md

이 문서는 MacDog 프로젝트에서 자동화 개발 에이전트가 반드시 따라야 하는 작업 규칙입니다.
대상 프로젝트는 Codex 사용량을 일반 터미널에서 확인하는 CLI, macOS menu bar runner 앱, WidgetKit 위젯, shared cache, 설치/배포 스크립트를 포함합니다.

---

## 1. 최우선 원칙

1. 사용자가 지정한 작업 범위를 넘지 않습니다.
2. 사용자가 로드맵/목차/단계 중 특정 카테고리 개발을 지시하면 그 카테고리 범위 안에서만 작업합니다.
3. 다음 로드맵 카테고리는 사용자가 명시적으로 지시하기 전까지 자동 착수하지 않습니다.
4. Codex 사용량 조회 계약, JSON 출력 schema, cache schema, app-server JSON-RPC 요청/응답 해석, macOS 앱/위젯 데이터 경계는 요청 없이 변경하지 않습니다.
5. `~/.codex/auth.json`의 token, access token, refresh token, cookie, session material은 읽거나 출력하거나 cache에 저장하지 않습니다.
6. 장시간 테스트, GUI 앱 실행, 설치 스크립트 실행, LaunchAgent 등록, codesign/notarization, 푸시는 명시 요청 없이 실행하지 않습니다.
7. 실패와 미실행 항목을 숨기지 않습니다.
8. 확인된 사실과 추정은 분리해서 보고합니다.
9. 실패한 단계 이후의 단계는 모두 중단하고 `건너뜀`으로 보고합니다. 단, 사용자가 `/goal`로 end-to-end 목표 달성을 지시한 경우는 3.1의 예외를 따릅니다.
10. 사용자가 설치, 패키징 설치, DMG 설치, drag-and-drop 설치 검수를 요청하면 최종 사용자가 받는 DMG를 실제로 열고 Finder에서 `MacDog.app`을 `Applications`로 드래그앤드롭하는 방식만 설치 검수로 인정합니다.
11. `install.sh`, `cp`, `ditto`, `rsync`, Finder 숨김 조작, 화면 밖 Finder 창, hdiutil mount 후 직접 복사, 앱 번들 직접 교체는 사용자 설치 검수의 대체 수단으로 사용할 수 없습니다. 사용 가능한 도구로 실제 drag-and-drop을 수행할 수 없으면 즉시 중단하고 `미수행`으로 보고합니다.
12. Apple Developer Program, Developer ID 인증서, notarization credential, App Group provisioning, App Store Connect 권한이 필요한 항목은 현재 구현 계획에서 전면 제외합니다. 이러한 항목은 사용자가 Apple Developer Program 사용 가능 상태를 명시하고 별도 milestone으로 승인하기 전까지 ROADMAP/README/검증 ledger의 구현 대상, 완료 조건, 후속 이슈로 넣지 않습니다.
13. 현재 남아 있는 WidgetKit 코드는 보존 대상일 뿐 기본 v1.1.0 구현 범위가 아닙니다. source/test/opt-in build 경계까지만 확인된 것으로 기록하고, App Group provisioning 이후 필요한 실제 위젯 shared cache 표시, stale/error 반영, 클릭 deep link 검수는 확인하지 못했다고 명시합니다.

---

## 2. 거짓 보고 금지

다음 행위는 절대 금지합니다.

- 실행하지 않은 명령을 실행했다고 보고
- 실패한 테스트를 통과로 보고
- 일부만 통과했는데 전체 통과로 보고
- sandbox, macOS 권한, Xcode signing, network, Codex auth 문제를 제품 회귀처럼 단정
- 제품 회귀를 환경 문제라고 임의 축소
- 생성하지 않은 파일, summary, report 경로를 임의 작성
- 커밋하지 않았는데 커밋 해시나 커밋 메시지를 보고
- 푸시하지 않았는데 푸시 완료라고 보고
- macOS 앱 또는 위젯을 실행/확인하지 않았는데 UI 검수 완료라고 보고
- DMG를 실제로 열고 Finder drag-and-drop을 수행하지 않았는데 drag-and-drop 설치 검수 완료라고 보고
- `install.sh` 또는 직접 파일 복사를 수행하고 사용자 설치 방식으로 검수했다고 보고
- Finder 창이나 설치 UI를 화면 밖/숨김 상태로 조작하고 사용자가 보는 설치 흐름을 확인했다고 보고
- raw JSON만 확인하고 menu bar popover 또는 Widget UI를 확인했다고 보고
- Apple Developer Program이 필요한 항목을 현재 구현 계획에 넣거나, 해당 계정/credential 없이 완료 가능하다고 보고
- WidgetKit source/test 또는 opt-in build만 확인하고 실제 위젯 shared cache 표시, stale/error 반영, 클릭 deep link까지 검수했다고 보고
- 문서만 수정하고 CLI/macOS 앱 구현까지 했다고 보고
- 코드만 수정하고 README/ROADMAP/AGENTS 반영까지 했다고 보고

보고 시에는 아래처럼 구분합니다.

```text
확인됨:
- 실제 실행한 명령
- 실제 통과/실패 결과
- 실제 생성된 파일
- 실제 수정한 파일
- 실제 커밋 여부
- 실제 푸시 여부

미확인:
- 실행하지 않은 테스트
- 열어보지 않은 앱/위젯 화면
- 추정 원인
- 후속 확인 필요 항목
```

---

## 3. 다중 단계 작업 규칙

사용자는 한 번에 여러 단계를 요청할 수 있습니다. 이 경우 반드시 아래 규칙을 따릅니다.

1. 단계는 요청된 순서대로만 진행합니다.
2. 각 단계는 개발 → 관련 테스트 → 결과 보고 → 필요 시 커밋 순서로 닫습니다.
3. 한 단계가 실패하면 그 즉시 중단합니다.
4. 실패한 단계 이후의 모든 단계는 실행하지 않습니다.
5. 실행하지 않은 단계는 `건너뜀`으로 표시합니다.
6. 실패 단계의 원인, 실패 명령, 영향 범위, 변경 파일, 후속 조치를 보고합니다.
7. 실패한 단계는 커밋하지 않습니다.
8. 실패 전 이미 통과 후 커밋된 단계는 그대로 유지합니다.
9. 전체 단계가 모두 끝나면 현재 요청 범위 안의 후속 이슈만 추천합니다.
10. 마지막에 푸시 가능 여부를 반드시 보고합니다.

### 3.1 `/goal` 명령의 실패 처리 예외

사용자가 `/goal` 또는 goal option으로 end-to-end 목표 달성을 지시한 경우에는 실패를 최종 중단으로 바로 확정하지 않습니다.

1. 실패 지점에서 원인, 실패 명령, 영향 범위, 변경 파일을 먼저 기록합니다.
2. 같은 목표와 같은 로드맵 범위 안에서 수정 가능한 실패라면 수정 후 해당 단계의 테스트부터 다시 시작합니다.
3. 실패 단계가 통과하기 전에는 뒤 단계를 진행하지 않습니다.
4. 같은 실패가 해결 불가능하거나 사용자 결정이 필요한 경우에만 중단으로 보고하고, 그 뒤 단계는 `건너뜀`으로 표시합니다.
5. 실패 후 재시작한 경우 최종 보고에는 최초 실패, 수정 내용, 재검증 결과를 함께 적습니다.

### 3.2 특정 로드맵 카테고리 이탈 금지

사용자가 `ROADMAP.md`의 특정 milestone, 번호, 카테고리를 지정해 개발을 지시하면 그 요청은 지정된 범위 안에서만 적용합니다.
지정 카테고리 내부의 하위 작업, 코드 수정, 문서 수정, 테스트, 안정화, 커밋은 허용됩니다.
금지 대상은 커밋 자체가 아니라 다른 로드맵 카테고리로 넘어가는 것입니다.

다음 행위는 절대 금지합니다.

- 지정 milestone이 끝났다는 이유로 다음 milestone을 자동 착수
- 지정 milestone의 완료 여부를 확인하지 않고 다음 milestone 개발로 이동
- "다음 본작업은 N번"이라고 단정한 뒤 사용자 승인 없이 N번 구현 시작
- 다른 milestone의 코드 수정, 문서 수정, 테스트 실행, 커밋 생성
- 다른 milestone을 함께 완료했다고 보고

다른 로드맵 카테고리는 사용자가 다음처럼 명시적으로 말한 경우에만 진행합니다.

```text
다음 스텝 진행
Milestone 2 진행
1번 완료 후 2번까지 진행
0~3번 순서대로 진행
```

---

## 4. 단계별 완료 조건

각 단계는 아래 조건을 모두 만족해야 완료로 봅니다.

1. 요청한 구현 범위 완료
2. 관련 테스트 실행
3. 테스트 통과
4. 문서/코드 변경에 대한 `git diff --check` 통과
5. 변경 파일 목록 확인
6. 영향 범위 보고
7. 회귀 가능성 보고
8. 사용자가 커밋을 요청했거나 단계 단위 커밋을 지시한 경우 해당 단계 단위 커밋 완료

문서만 수정한 단계도 최소한 `git diff --check`를 실행합니다.

---

## 5. 커밋 규칙

1. 커밋은 사용자가 요청했거나 단계 규칙에서 명시한 경우에만 수행합니다.
2. 각 단계가 통과한 뒤 해당 단계만 커밋합니다.
3. 여러 단계의 변경을 하나의 커밋에 섞지 않습니다.
4. 실패한 단계는 커밋하지 않습니다.
5. 커밋 메시지는 변경 성격을 명확히 씁니다.
6. 푸시 여부와 푸시 가능 여부 보고는 6장 규칙을 따릅니다.

권장 커밋 메시지 형식:

```text
feat: 기능 추가
fix: 버그 수정
refactor: 구조 정리
docs: 문서 갱신
test: 테스트 추가
chore: 개발 환경 정리
```

보고 형식:

```text
커밋:
- 단계: 1/3
- 메시지: docs: AGENTS 작업 규칙 추가
- 해시: <커밋 해시>
- 푸시: 수행하지 않음
```

커밋하지 않았다면:

```text
커밋:
- 수행하지 않음
- 이유: 사용자 요청 없음 / 테스트 실패 / 변경 없음
```

---

## 6. 푸시 규칙

1. 푸시는 사용자가 명시적으로 요청하기 전까지 금지합니다.
2. "푸시 가능"과 "푸시 완료"를 혼동하지 않습니다.
3. 모든 단계가 통과하고 커밋이 완료되어도 푸시는 하지 않습니다.
4. 마지막 보고에 아래 중 하나를 반드시 씁니다.

```text
푸시 가능: 예
이유: 모든 단계 통과, 모든 변경 커밋 완료, 미커밋 변경 없음
푸시 수행 여부: 수행하지 않음
```

또는

```text
푸시 가능: 아니오
이유: 실패 단계 있음 / 미커밋 변경 있음 / 테스트 미실행 항목 있음
푸시 수행 여부: 수행하지 않음
```

---

## 7. 테스트 정책

작업 종류별 최소 테스트는 아래를 따릅니다.
사용자가 별도 테스트를 지정하면 사용자의 지시를 우선합니다.

### 7.1 문서 전용 변경

```bash
git diff --check
```

가능하면 추가:

```bash
npx --yes markdownlint-cli2@0.22.1
```

Node.js/npm 또는 `markdownlint-cli2` 실행 경로가 없으면 `명령 없음`으로 보고하고 임의로 통과 처리하지 않습니다.

### 7.2 CLI / parser / JSON schema 변경

우선 fixture 기반 테스트를 사용합니다.

```bash
git diff --check
swift test
```

프로젝트가 Swift Package가 아닌 다른 런타임을 채택한 경우 해당 런타임의 공식 테스트 명령을 사용합니다.

```bash
npm test
cargo test
pytest
```

실제 Codex 사용량 live 조회는 사용자의 현재 계정/네트워크 상태에 의존합니다.
live smoke가 필요한 경우 `codex-usage status --json`을 실행하되, 실패 시 auth/network/app-server 원인을 분리해서 보고합니다.

### 7.3 Shared cache / polling 변경

```bash
git diff --check
swift test
```

추가 확인:

- cache JSON schema가 README/AGENTS와 일치하는지
- atomic write가 partial file을 남기지 않는지
- stale/error 상태가 구분되는지
- cache에 token/session material이 없는지

### 7.4 macOS menu bar app 변경

```bash
git diff --check
swift test
xcodebuild build
```

GUI 실행, screenshot, menu bar popover 확인은 사용자 명시 요청 또는 가능한 도구가 있을 때만 수행합니다.
실행하지 않았다면 `UI 확인: 실행하지 않음`으로 보고합니다.

### 7.5 WidgetKit 변경

```bash
git diff --check
swift test
xcodebuild build
```

추가 확인:

- widget이 shared cache만 읽는지
- widget에서 app-server를 직접 호출하지 않는지
- stale/error/empty 상태가 표시되는지
- deep link가 menu bar app 또는 상세 화면으로 이어지는지
- 단, App Group provisioning이나 Apple Developer Program이 필요한 실제 위젯 UI 검수는 현재 구현 계획에서 제외합니다. 위 항목을 source/test/fixture/opt-in build 수준까지만 확인했다면 실제 위젯 UI 완료로 보고하지 않습니다.

### 7.6 설치/배포 변경

```bash
git diff --check
```

설치 스크립트, LaunchAgent 등록, 로그인 항목 등록, codesign, notarization, `spctl` 검증은 사용자 명시 요청 없이 실행하지 않습니다.
Apple Developer Program이 필요한 단계는 현재 구현 계획에서 제외하고, 로컬 개인 사용만으로 가능한 단계와 섞어 완료 조건으로 쓰지 않습니다.
사용자 설치 검수는 `install.sh`가 아니라 최종 DMG를 Finder에서 열고 `MacDog.app`을 `Applications`로 실제 드래그앤드롭하는 절차로만 수행합니다.
이 절차를 직접 수행하지 않았다면 `drag-and-drop 설치 검수: 실행하지 않음`으로 보고하고 완료 처리하지 않습니다.
Finder나 설치 UI를 화면 밖으로 이동하거나 숨겨서 검수하지 않습니다.

### 7.7 장시간 테스트

아래 테스트는 명시 요청이 있을 때만 실행합니다.

```bash
codex-usage status --watch 60
```

장시간 테스트를 실행하지 않았다면 반드시 보고합니다.

```text
장시간 테스트: 실행하지 않음
이유: 사용자 명시 요청 없음
```

---

## 8. 중단 조건

아래 상황이 발생하면 즉시 중단하고 보고합니다.
단, `/goal` 명령의 실패 처리 예외는 3.1을 따릅니다.

1. build 실패
2. 핵심 fixture test 실패
3. `git diff --check` 실패
4. CLI JSON schema 변경이 README/AGENTS/ROADMAP과 불일치
5. cache schema 변경이 앱/위젯 문서와 불일치
6. Codex auth token 또는 session material 노출 징후
7. `~/.codex/auth.json` 직접 읽기 또는 출력 징후
8. app-server response 전체 원문을 민감정보 검토 없이 로그/cache에 저장
9. WidgetKit extension이 shared cache 대신 app-server를 직접 호출
10. menu bar runner가 과도한 CPU/RAM을 사용한다는 측정 또는 명백한 정황
11. 설치/삭제 스크립트가 사용자 홈 또는 시스템 파일을 과도하게 수정할 위험
12. codesign/notarization/LaunchAgent 단계에 사용자 승인이 필요한 경우

중단 보고 형식:

```text
중단 위치:
- 단계: 2/5
- 구간: 테스트
- 실패 명령: swift test

결과:
- 상태: 실패
- 뒤 단계: 3~5 건너뜀

원인:
- 확인된 원인:
- 추정 원인:

변경 파일:
- ...

커밋:
- 수행하지 않음

후속:
- ...
```

---

## 9. Codex 사용량 데이터 규칙

1. 1순위 데이터 소스는 Codex app-server `account/rateLimits/read`입니다.
2. `primary.windowDurationMins = 300`은 5시간 창으로 해석합니다.
3. `secondary.windowDurationMins = 10080`은 주간 창으로 해석합니다.
4. 잔여량은 `100 - usedPercent`로 계산합니다.
5. `resetsAt`은 Unix epoch seconds이며 표시 시 로컬 시간대로 변환합니다.
6. 기본 limit bucket은 `rateLimitsByLimitId.codex`입니다.
7. `codex_bengalfox` 같은 추가 bucket은 advanced/debug 출력으로 분리합니다.
8. CLI `--json` 출력 schema는 앱/위젯/cache가 의존하는 계약이므로 요청 없이 breaking change를 만들지 않습니다.
9. 사용량 조회 실패 시 마지막 성공 cache가 있더라도 stale/error 상태를 함께 표시합니다.
10. 공식 잔여 한도와 로컬 SQLite 추정치를 섞어 표현하지 않습니다.

---

## 10. macOS UI / RunCat 참고 규칙

1. RunCat의 핵심 경험은 "작은 menu bar runner가 상태에 따라 속도를 바꾸는 것"으로만 참고합니다.
2. RunCat의 고양이 캐릭터, asset, 브랜드 표현을 복제하지 않습니다.
3. runner 속도는 기본적으로 `max(5시간 사용률, 주간 사용률)`을 기준으로 합니다.
4. WidgetKit은 실시간 애니메이션 채널이 아니라 glance용 상태 표시로 다룹니다.
5. menu bar app이 지속 애니메이션을 담당합니다.
6. popover는 장난스럽기보다 명확한 개발 도구처럼 보여야 합니다.
7. `Reduce Motion` 또는 저전력 환경을 고려해 애니메이션 완화 옵션을 둡니다.
8. high usage 경고는 눈에 띄되 과하게 산만하지 않아야 합니다.
9. UI 확인을 하지 않았다면 `UI 확인 미수행`으로 보고합니다.

### 10.1 캐릭터 이미지 생성 / 교체 규칙

사용자가 "골든리트리버 컨셉으로 이미지 생성"처럼 캐릭터 컨셉만 지시하면, 에이전트는 아래 기준의 전체 캐릭터 세트를 같은 캐릭터로 생성해야 합니다.
일부 이미지만 새 컨셉으로 바꾸거나, 서로 다른 그림체/종/형태/소품을 섞어서는 안 됩니다.

#### 10.1.1 기준 이미지와 캐릭터 동일성

1. 기준 이미지는 menu bar runner 캐릭터입니다. 최초 승인된 menu bar runner의 얼굴형, 귀, 꼬리, 몸 비율, 색, 무늬, 선 두께, 표정 범위를 해당 캐릭터의 정체성으로 봅니다.
2. desktop pet, popover tab button, 설정 탭 캐릭터 미리보기는 모두 기준 이미지와 같은 캐릭터여야 합니다.
3. 새 이미지가 기준 캐릭터와 다르게 보이면 실패로 봅니다. "비슷한 강아지", 로봇처럼 보이는 이미지, 다른 종처럼 보이는 이미지, 장난감/마스코트처럼 변형된 이미지는 사용할 수 없습니다.
4. 모든 이미지는 투명 배경 PNG여야 하며, 귀/꼬리/머리/발이 잘리지 않도록 충분한 여백을 둡니다.
5. 작은 크기에서 읽히도록 단순한 실루엣과 명확한 색 대비를 유지합니다. 과한 장식, 복잡한 배경, 텍스트 삽입은 금지합니다.
6. 한 캐릭터 세트 안에서는 그림체, 광원, 윤곽선, 채도, 비율이 흔들리면 안 됩니다.

#### 10.1.2 Menu Bar Runner 생성 기준

1. menu bar runner는 캐릭터 세트의 기준 이미지입니다. 가장 먼저 생성하고 사용자 승인을 받아야 합니다.
2. runner는 "달리는 모습"의 반복 애니메이션이어야 합니다.
3. 기본 구성은 `Sources/MacDog/Resources/Runner/pup-runner-0.png`부터 `pup-runner-7.png`까지 8프레임입니다.
4. 8프레임은 같은 캔버스, 같은 기준선, 같은 중심점으로 맞춥니다. 애니메이션 중 캐릭터 크기나 위치가 튀면 실패로 봅니다.
5. 프레임은 옆을 향해 달리는 실루엣을 기본으로 합니다. 머리, 귀, 몸통, 다리, 꼬리 움직임이 자연스럽게 순환해야 합니다.
6. menu bar에서는 매우 작게 보이므로 디테일보다 캐릭터 식별성, 실루엣, 움직임의 리듬을 우선합니다.
7. runner가 승인되기 전에는 desktop pet이나 tab button 최종 리소스를 확정하지 않습니다.

#### 10.1.3 Desktop Pet 생성 기준

1. desktop pet은 승인된 menu bar runner와 같은 캐릭터여야 합니다.
2. 기본 리소스 구조와 프레임 수는 현재 `MacDogCharacterProfile.codexPup.desktopPet` 계약을 따릅니다.
3. 이동 포즈는 다음 세트를 생성합니다.
   - `pup-run-right-0.png` ~ `pup-run-right-7.png`: 오른쪽으로 걷거나 뛰는 8프레임
   - `pup-run-up-0.png` ~ `pup-run-up-7.png`: 위쪽으로 이동하는 8프레임
   - `pup-run-down-0.png` ~ `pup-run-down-7.png`: 아래쪽으로 이동하는 8프레임
4. 왼쪽 이동은 별도 리소스를 만들지 않는 한 오른쪽 이동 프레임의 좌우 반전을 기준으로 합니다. 별도 왼쪽 리소스를 추가하려면 프로필 구조와 테스트를 함께 갱신해야 합니다.
5. 상태 포즈는 다음 세트를 생성합니다.
   - `pup-idle-front-0.png` ~ `pup-idle-front-3.png`: 정면 대기 4프레임
   - `pup-idle-side-0.png` ~ `pup-idle-side-3.png`: 측면 대기 4프레임
   - `pup-rest-0.png` ~ `pup-rest-3.png`: 쉬거나 자는 4프레임
   - `pup-alert-0.png` ~ `pup-alert-3.png`: 주의/알림 상태 4프레임
6. 각 포즈 세트는 같은 캔버스, 같은 캐릭터 크기, 같은 기준선으로 정렬합니다.
7. 데스크톱에서 걸어다닐 때 상하좌우 전환이 어색하지 않아야 하며, 방향별로 다른 캐릭터처럼 보여서는 안 됩니다.

#### 10.1.4 Popover Tab Button 생성 기준

1. tab button 이미지는 `Sources/MacDog/Resources/PopoverTabs`에 256x256 PNG로 생성합니다.
2. tab button은 새 캐릭터를 상상해 그리지 않습니다. 승인된 desktop pet 포즈 또는 동일 캐릭터로 검증된 원본에서 파생합니다.
3. 기본 파일은 다음 5개다.
   - `codex-tab.png`: Codex 사용량 탭
   - `mac-tab.png`: 활성 자원 탭
   - `sleep-tab.png`: 잠들지 않기 탭
   - `battery-tab.png`: 배터리 탭
   - `settings-tab.png`: 설정 탭
4. 각 tab button은 같은 캐릭터를 유지하되 탭 주제가 즉시 구분되어야 합니다.
   - Codex 사용량: 정면 또는 집중하는 포즈 + 코드/터미널을 연상시키는 단순 배지
   - 활성 자원: 달리는 포즈 + CPU/활동을 연상시키는 단순 배지
   - 잠들지 않기: 쉬거나 자는 포즈 + 달/수면을 연상시키는 단순 배지
   - 배터리: 알림/충전 상태 포즈 + 배터리를 연상시키는 단순 배지
   - 설정: 측면 대기 또는 차분한 포즈 + 톱니바퀴를 연상시키는 단순 배지
5. 배지는 작고 단순해야 하며 캐릭터 얼굴, 귀, 꼬리를 가리면 안 됩니다.
6. tab button에는 텍스트를 넣지 않습니다. 64x64로 축소되어도 캐릭터와 탭 주제가 읽혀야 합니다.
7. 각 버튼은 selected border 안에서 상단/하단이 잘리지 않아야 합니다. 렌더 후 실제 popover에서 확인합니다.
8. 모든 tab button은 `MacDogCharacterProfile`과 `codex-pup-tab-art.json` 또는 새 캐릭터의 동등한 manifest에 연결되어야 합니다.

#### 10.1.5 설정 탭 적용 기준

1. 캐릭터를 변경하면 menu bar runner, desktop pet, popover tab button, 설정 탭 캐릭터 미리보기를 하나의 세트로 함께 적용합니다.
2. 설정 탭 캐릭터 미리보기는 현재 선택된 캐릭터의 실제 이미지를 보여야 합니다.
3. 설정 탭에서 선택된 캐릭터가 다른 리소스와 다르게 보이면 실패로 봅니다.
4. fallback 아이콘은 로딩 실패를 드러내는 용도로만 사용합니다. fallback 아이콘을 정상 캐릭터처럼 보이게 두면 안 됩니다.
5. 캐릭터 변경 UI를 추가하거나 바꾸면 `MacDogCharacterProfile`, 관련 manifest, 검증 스크립트, 스크린샷 테스트를 함께 갱신합니다.

#### 10.1.6 임시 이미지와 미사용 리소스 삭제 규칙

1. 이미지 후보 생성 중 만들어진 임시 파일은 저장소에 넣지 않습니다.
2. 임시 이미지는 작업용 임시 디렉터리에만 둡니다. README, ROADMAP, AGENTS, 테스트 fixture, 앱 리소스, 스크린샷 산출물에서 임시 이미지를 참조하지 않습니다.
3. 사용자가 최종 이미지를 선택하면 선택된 파일만 정식 리소스 경로로 복사하거나 재생성합니다.
4. 최종 선택이 끝난 즉시 모든 임시 생성 이미지를 삭제합니다.
5. 삭제 후에는 임시 디렉터리, `Assets/Generated`, 문서 스크린샷 산출물, 앱 리소스 경로에 미사용 이미지가 남아 있지 않은지 확인합니다.
6. 임시 이미지가 산출물 또는 앱 번들에 포함되어 삭제할 수 없으면, 현재 승인된 캐릭터 이미지로 교체한 뒤 기존 임시 이미지를 삭제합니다.
7. 사용자에게 최종 보고할 때는 남아 있는 정식 리소스와 삭제한 임시 리소스를 구분해서 보고합니다.

#### 10.1.7 필수 검증

캐릭터 이미지 세트를 생성하거나 교체한 뒤에는 최소한 아래를 실행합니다.

```bash
git diff --check
./script/verify_character_profile.sh
swift test --filter MacDogCharacterProfileTests
swift test --filter PopoverScreenshotRendererTests
```

가능하면 최신 앱을 실행해 menu bar runner, desktop pet, popover tab button, 설정 탭 미리보기를 직접 확인합니다.
직접 확인하지 않았다면 `UI 확인 미수행`으로 보고합니다.

---

## 11. 보안 / 개인정보 규칙

1. `~/.codex/auth.json`을 직접 읽거나 출력하지 않습니다.
2. access token, refresh token, cookie, session id, auth header를 파일, 로그, UI, cache에 남기지 않습니다.
3. 사용량 snapshot에는 plan, percent, reset time, credits balance, stale/error 상태만 저장합니다.
4. 오류 로그에는 request/response 전체 원문 대신 redacted summary를 남깁니다.
5. 네트워크 dashboard scraping은 마지막 수단으로만 고려하고, 먼저 사용자에게 이유를 설명합니다.
6. GitHub, Apple Developer, notarization credential은 코드나 문서에 넣지 않습니다.

---

## 12. 문서 관리 규칙

문서 변경 시 다음을 확인합니다.

1. README, ROADMAP, AGENTS의 용어가 일치하는지
2. CLI 명령 이름이 일치하는지
3. 사용량 창 해석이 일치하는지
4. RunCat 참고 범위가 과장되거나 asset 복제로 오해되지 않는지
5. Apple Developer Program이 필요한 항목을 현재 구현 계획, v1.1.0 완료 조건, 후속 이슈에서 제외했는지
6. 구현 완료, MVP 예정, 후속 예정, 검증 미수행을 구분했는지
7. 실행하지 않은 검증을 문서에 완료처럼 쓰지 않았는지

문서에서 기능 상태를 표현할 때:

```text
구현 완료
MVP 완료
1차 구현
후속 예정
실험 기능
검증 미수행
```

을 구분합니다.

---

## 13. 보고 형식

각 단계 완료 후 아래 형식으로 보고합니다.

```text
2/5단계 완료

작업:
- ...

변경 파일:
- ...

검증:
- swift test: 통과
- git diff --check: 통과

미실행:
- GUI 실행: 실행하지 않음
- 장시간 테스트: 실행하지 않음

커밋:
- 메시지: ...
- 해시: ...
- 푸시: 수행하지 않음

다음 단계:
- 3/5 진행 가능

푸시 가능: 예/아니오
푸시 수행 여부: 수행하지 않음
```

실패 시:

```text
3/5단계 실패

실패 지점:
- 명령: ...
- 결과: 실패

원인:
- 확인된 원인:
- 추정 원인:

변경 파일:
- ...

커밋:
- 수행하지 않음

중단:
- 4/5~5/5 건너뜀

후속 조치:
- ...

푸시 가능: 아니오
```

---

## 14. 후속 이슈 추천 규칙

전체 단계가 끝나면 후속 이슈를 추천합니다.
단, 후속 이슈는 현재 요청 범위 안에서 실제로 처리 가능한 항목만 언급합니다.

다음 항목은 후속 이슈로 추천하거나 기록하지 않습니다.

- 이번 요청 범위를 벗어난 기능
- 현재 milestone을 벗어난 별도 Phase 후보
- 사용자 승인이 필요한 새 제품 범위
- 이번 단계 완료 판정과 무관한 research/backlog 아이디어

현재 범위 안에 남은 후속 이슈가 없으면 `후속 이슈: 없음`으로 보고합니다.

---

## 15. 절대 금지 요약

상세 규칙은 앞 장을 우선합니다. 아래 항목은 어떤 작업에서도 예외 없이 금지합니다.

- 실패, 미실행 테스트, 미확인 화면, 미커밋/미푸시 상태를 완료처럼 보고
- Codex usage JSON schema, cache schema, app-server 해석 계약을 요청 없이 breaking change
- 장시간 테스트, GUI 앱 실행, 설치/LaunchAgent/codesign/notarization, 푸시를 명시 요청 없이 실행
- 사용자 설치 검수를 `install.sh`, 직접 복사, 숨김 Finder 조작, 화면 밖 UI, hdiutil mount 후 파일 복사로 대체
- 실제 Finder drag-and-drop을 수행하지 않고 DMG 설치 검수 완료로 보고
- Codex token/session/auth material 노출
- RunCat asset/캐릭터/브랜드 복제
- 제품 기능을 문서에서 과장하거나 구현 예정 기능을 구현 완료처럼 표현

---

# MacDog Development Plan

## 목적

Codex 사용량 한도, 특히 5시간 창과 주간 창의 남은 비율을 빠르게 확인하고, macOS에서 RunCat처럼 시각적으로 감지할 수 있는 도구를 만듭니다.

최종 목표는 두 가지입니다.

1. 사용자가 다른 프로젝트에서 "Codex 사용량 체크"라고 요청하면 스크립트가 현재 사용량을 읽어 간단히 응답합니다.
2. MacBook에서 사용량이 100%에 가까워질수록 더 빠르게 뛰는 상태표시/위젯을 제공하고, 클릭하면 현재 5시간/주간 사용량을 보여줍니다.

## 확인된 사실

- 공식 문서 기준 현재 Codex 사용량은 plan, 모델, 작업 크기, 로컬/클라우드 실행 여부에 따라 달라집니다.
- 공식 확인 경로는 Codex usage dashboard이며, 활성 Codex CLI 세션 안에서는 `/status`를 사용할 수 있습니다.
- 로컬 Codex app-server 프로토콜에 `account/rateLimits/read` 요청이 있으며, 응답에는 `primary`, `secondary`, `credits`, `planType`, `rateLimitReachedType`가 포함됩니다.
- `primary.windowDurationMins = 300`이면 5시간 창으로 해석합니다.
- `secondary.windowDurationMins = 10080`이면 주간 창으로 해석합니다.
- 각 창의 `usedPercent`로 사용량을 계산하고, 잔여량은 `100 - usedPercent`로 표시합니다.
- `resetsAt`은 Unix epoch seconds이며 로컬 시간대로 변환해 보여줍니다.

## 핵심 설계

### 데이터 소스 우선순위

1. Codex app-server `account/rateLimits/read`
   - 정확한 현재 한도/사용량 소스입니다.
   - `codex app-server`를 stdio로 실행하고 JSON-RPC 요청을 보냅니다.
   - 최초 연결 후 `initialize` 요청을 보내고, 이후 `account/rateLimits/read`를 호출합니다.

2. Codex CLI `/status`
   - 활성 CLI 세션 내부에서 사람이 확인하는 보조 경로입니다.
   - 자동화 API가 깨졌을 때 문서화된 수동 확인 절차로 유지합니다.

3. 로컬 SQLite 추정치
   - `~/.codex/state_5.sqlite`의 `threads.tokens_used`는 스레드별 토큰 사용량 추정에는 쓸 수 있으나, 공식 잔여 한도는 아닙니다.
   - fallback 진단용으로만 사용하고 UI에는 "estimated" 라벨을 붙입니다.

### CLI 스크립트

전역 실행 가능한 `codex-usage` 명령을 만듭니다.

예상 명령:

```sh
codex-usage status
codex-usage status --json
codex-usage status --watch 60
codex-usage doctor
```

텍스트 출력 예시:

```text
Codex usage
5h:     15% used, 85% remaining, resets 2026-05-26 01:27 KST
Weekly: 38% used, 62% remaining, resets 2026-05-31 09:19 KST
Credits: 0
Plan: pro
```

JSON 출력 예시:

```json
{
  "planType": "pro",
  "limits": {
    "codex": {
      "primary": {
        "usedPercent": 15,
        "remainingPercent": 85,
        "windowDurationMins": 300,
        "resetsAt": 1779726477
      },
      "secondary": {
        "usedPercent": 38,
        "remainingPercent": 62,
        "windowDurationMins": 10080,
        "resetsAt": 1780186777
      }
    }
  }
}
```

다른 프로젝트에서 Codex에게 사용량 확인을 요청할 때는 전역 `AGENTS.md`나 프로젝트 `AGENTS.md`에 다음 운영 지침을 추가합니다.

```md
사용자가 Codex 사용량, 5시간 한도, 주간 한도, 잔여 토큰을 물으면 `codex-usage status`를 실행해 결과를 요약합니다.
```

## macOS 앱/위젯 설계

RunCat과 유사한 "계속 뛰는" 표현은 WidgetKit보다 menu bar app이 적합합니다. WidgetKit 위젯은 업데이트 주기와 애니메이션 제약이 있으므로, 1차 구현은 menu bar status item으로 만들고, 2차 구현에서 WidgetKit 위젯을 추가합니다.

### 1차: Menu Bar Status App

- SwiftUI + AppKit `NSStatusItem` 기반으로 만듭니다.
- 작은 러너 아이콘 또는 프레임 애니메이션을 menu bar에 표시합니다.
- 클릭 시 popover를 열어 현재 사용량을 보여줍니다.
- 표시 항목:
  - 5시간 사용률/잔여율
  - 주간 사용률/잔여율
  - reset 시각
  - plan type
  - credits balance
  - 마지막 갱신 시각
  - 데이터 소스 상태

애니메이션 속도 규칙:

```text
maxUsed = max(primary.usedPercent, secondary.usedPercent)
0-49%    calm
50-79%   active
80-94%   fast
95-99%   sprint
100%+    urgent / limit reached
```

### 2차: WidgetKit Widget

- small / medium 위젯을 제공합니다.
- WidgetKit 제약 때문에 초당 애니메이션은 기대하지 않습니다.
- 위젯은 현재 상태, 잔여율, reset 시각을 보여주고 클릭 시 menu bar app 또는 상세 화면을 엽니다.
- 위젯 데이터는 직접 Codex app-server를 호출하지 않고 shared cache JSON을 읽습니다.

### 백그라운드 갱신

- `CodexUsageCore`가 app-server에서 사용량을 읽습니다.
- menu bar app은 기본 60초마다 갱신합니다.
- LaunchAgent 또는 앱 내 timer가 다음 파일에 최신 snapshot을 씁니다.

```text
~/Library/Application Support/MacDog/usage.json
```

WidgetKit extension은 이 cache를 읽어 표시합니다.

## 권장 저장소 구조

```text
AGENTS.md
scripts/
  codex-usage
Sources/
  CodexUsageCore/
  CodexUsageCLI/
Apps/
  MacDog/
  MacDogWidgetExtension/
Tests/
  CodexUsageCoreTests/
Fixtures/
  rate_limits_response.json
```

Swift Package와 Xcode project 중 하나를 선택합니다. macOS menu bar app과 WidgetKit까지 고려하면 Xcode project가 편하지만, core parser와 CLI는 Swift Package로 분리해 테스트하기 쉽게 만듭니다.

## 구현 단계

### Phase 1: CLI MVP

- app-server stdio client 작성
- `initialize` 요청 구현
- `account/rateLimits/read` 요청 구현
- `primary`와 `secondary`를 5시간/주간 창으로 매핑
- text/json 출력 구현
- `doctor` 명령으로 Codex 설치 경로, app-server 접근, auth 상태, 응답 스키마를 점검
- fixture 기반 parser unit test 작성

완료 기준:

- `codex-usage status`가 5시간/주간 사용률, 잔여율, reset 시각을 출력합니다.
- `codex-usage status --json`이 안정적인 JSON schema로 출력합니다.
- app-server 접근 실패 시 원인과 수동 확인 방법을 출력합니다.

### Phase 2: Cache and Polling

- snapshot schema 정의
- `usage.json` atomic write 구현
- stale 상태 판단 추가
- 네트워크/auth 실패 시 마지막 성공 값을 표시하되 stale 경고를 포함
- LaunchAgent 설치/제거 스크립트 작성

완료 기준:

- 60초 단위 갱신이 가능합니다.
- 앱과 위젯이 같은 cache를 읽습니다.
- 실패 상태에서도 UI가 멈추거나 빈 화면이 되지 않습니다.

### Phase 3: Menu Bar App

- SwiftUI popover UI 구현
- menu bar 애니메이션 프레임 구현
- 사용량에 따른 속도 매핑 구현
- 80%, 95%, 100% 임계값 색상/상태 변경 구현
- 클릭 시 상세 사용량 표시

완료 기준:

- 사용량이 높아질수록 애니메이션 속도가 체감됩니다.
- 5시간/주간 reset 시각이 로컬 시간대로 보입니다.
- 앱이 로그인 토큰이나 민감 정보를 표시하거나 저장하지 않습니다.

### Phase 4: WidgetKit

- small 위젯: 가장 높은 사용률과 reset 시각 표시
- medium 위젯: 5시간/주간 사용량을 모두 표시
- 위젯 클릭 deep link 구현
- stale cache 표시 구현

완료 기준:

- 데스크톱/알림 센터 위젯에서 현재 snapshot을 볼 수 있습니다.
- 위젯 클릭 시 상세 화면으로 이동합니다.
- WidgetKit 업데이트 제약을 사용자에게 오해 없이 반영합니다.

### Phase 5: Packaging

- `install.sh` 또는 signed app bundle 배포 방식 결정
- CLI symlink를 `~/bin/codex-usage`에 설치
- LaunchAgent 설치 옵션 제공
- uninstall 경로 제공
- README에 사용법과 제한사항 작성

## 보안 원칙

- `~/.codex/auth.json`을 직접 읽거나 출력하지 않습니다.
- app-server의 인증 상태를 이용하되 access token을 로그에 남기지 않습니다.
- 사용량 snapshot에는 plan, percent, reset time, credits balance만 저장합니다.
- 오류 로그에는 request/response 전체 원문 대신 redacted summary를 남깁니다.
- 네트워크 dashboard scraping은 마지막 수단으로만 고려합니다.

## 리스크와 대응

- app-server 프로토콜은 내부/실험 성격일 수 있습니다.
  - 대응: `doctor`와 fixture test를 두고, 실패 시 `/status` 안내로 degrade합니다.
- WidgetKit은 RunCat처럼 계속 뛰는 애니메이션에 적합하지 않다.
  - 대응: menu bar app을 주 구현으로 삼고 WidgetKit은 상태 확인용으로 둡니다.
- Codex 한도 정책은 자주 바뀔 수 있습니다.
  - 대응: window duration과 limit id를 하드코딩하지 않고 응답 기반으로 해석합니다.
- 여러 limit id가 반환될 수 있습니다.
  - 대응: 기본은 `codex`, 추가 bucket은 advanced output에 표시합니다.

## 검증 체크리스트

- CLI가 정상 응답을 파싱합니다.
- CLI가 app-server 미실행/인증 실패/네트워크 실패를 설명합니다.
- 5시간 창 reset 시각이 정확히 로컬 시간대로 표시됩니다.
- 주간 창 reset 시각이 정확히 로컬 시간대로 표시됩니다.
- 80%, 95%, 100% 임계값에서 menu bar 상태가 바뀝니다.
- cache가 오래되면 stale로 표시됩니다.
- 위젯은 stale/empty/error 상태를 각각 표시합니다.
- 민감 정보가 파일, 로그, UI에 남지 않습니다.
