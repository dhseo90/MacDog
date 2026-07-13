# AGENTS.md

이 문서는 MacDog 프로젝트에서 자동화 개발 에이전트가 반드시 따라야 하는 작업 규칙입니다.
제품 로드맵과 구현 계획은 `README.md`, `ROADMAP.md`, `Docs/`에 두고, 이 파일은 에이전트 실행 규칙만 다룹니다.

MacDog는 Codex 사용량 CLI, macOS menu bar 앱, optional WidgetKit 코드, shared cache, 권한 도우미, 설치/배포 스크립트를 포함합니다.

---

## 1. 최우선 원칙

1. 사용자가 지정한 작업 범위를 넘지 않습니다.
2. 로드맵 milestone, 번호, 카테고리가 지정되면 그 범위 안에서만 작업합니다.
3. 다음 로드맵 카테고리는 사용자가 명시하기 전까지 자동 착수하지 않습니다.
4. Codex 사용량 조회 계약, `--json` schema, cache schema, app-server JSON-RPC 해석, 앱/위젯 데이터 경계는 요청 없이 breaking change를 만들지 않습니다.
5. `~/.codex/auth.json`은 직접 읽거나 출력하지 않습니다.
6. token, access token, refresh token, cookie, session material, auth header는 읽기/출력/cache/log/fixture/문서 저장 모두 금지합니다.
   단, Codex 사용량 초기화권 만료일 조회를 위해 `codex-usage`가 다음 순서로 access token을
   메모리에서만 받아 ChatGPT backend 요청의 `Authorization` header에 즉시 사용하는 것은
   예외로 허용합니다.
   1. Codex app-server `account/chatgptAuthTokens/refresh`
   2. app-server가 해당 method를 지원하지 않는 경우 Codex auth store
      (`$CODEX_HOME/auth.json`, `~/.config/codex/auth.json`, `~/.codex/auth.json`, macOS Keychain `Codex Auth`)
   이 예외는 token 출력, token cache 저장, raw response 저장, fixture/문서 token 저장을 허용하지 않습니다.
   auth store 직접 읽기는 초기화권 만료일 backend 요청 직전의 메모리 사용으로만 제한합니다.
7. 장시간 테스트, GUI 앱 실행, 설치 스크립트 실행, LaunchAgent 등록, helper 설치/삭제, codesign/notarization, push는 사용자 명시 요청 없이 실행하지 않습니다.
8. Apple Developer Program, Developer ID 인증서, notarization credential, App Group provisioning, App Store Connect 권한이 필요한 항목은 현재 구현 계획, 완료 조건, 후속 이슈에 넣지 않습니다. 사용자가 해당 권한 사용 가능 상태와 별도 milestone을 승인한 경우만 예외입니다.
9. WidgetKit 코드는 보존/opt-in build 대상입니다. 기본 앱/DMG 완료 조건에 넣지 않고, source/test/fixture/opt-in build 수준까지만 확인한 경우 실제 위젯 UI 검수 완료로 보고하지 않습니다.
10. 모든 사용자 응답, 진행 보고, 최종 보고는 한국어로 작성합니다. 명령어, 파일 경로, 코드 식별자, 외부 원문 제목처럼 원문 유지가 필요한 항목만 예외입니다.
11. 개발 작업에는 사용 가능한 경우 Superpowers(supers) 워크플로를 적용해 요구사항 파악, 계획, 테스트, 검증을 진행합니다.
12. 독립적인 조사/구현/검토가 사용자 범위 안에서 병렬 가능하면 서브 에이전트를 사용할 수 있습니다. 서브 에이전트도 이 문서의 보안, 승인, 검증, 보고 규칙을 따릅니다.

---

## 2. 보고 정직성

아래를 완료처럼 보고하지 않습니다.

- 실행하지 않은 명령, 실패한 테스트, 일부만 통과한 검증
- 열어보지 않은 menu bar popover, macOS 앱 UI, Widget UI, DMG Finder 창
- 커밋/푸시하지 않은 변경
- 생성하지 않은 파일, summary, report 경로
- 문서만 수정했는데 CLI/macOS 앱까지 구현했다는 식의 과장
- 코드만 수정했는데 README/ROADMAP/AGENTS 반영까지 끝났다는 식의 과장
- sandbox, macOS 권한, Xcode signing, network, Codex auth 문제를 근거 없이 제품 회귀로 단정
- 제품 회귀를 근거 없이 환경 문제로 축소
- raw JSON만 보고 UI 검수를 완료했다고 보고
- Apple Developer 권한이 필요한 항목을 현재 완료 가능하다고 보고
- WidgetKit source/test 또는 opt-in build만 보고 실제 위젯 shared cache 표시, stale/error 반영, deep link까지 확인했다고 보고
- GitHub에서 `Verified`로 확인하지 않은 release tag를 서명 검증 완료로 보고

보고할 때는 확인된 사실과 미확인/추정을 분리합니다.

```text
확인됨:
- 실제 실행한 명령
- 실제 통과/실패 결과
- 실제 생성/수정/삭제한 파일
- 실제 커밋 여부
- 실제 푸시 여부

미확인:
- 실행하지 않은 테스트
- 열어보지 않은 앱/위젯/설치 화면
- 추정 원인
- 후속 확인 필요 항목
```

### 2.1 로드맵과 후속 이슈의 분석 모델 추천

이슈 로드맵 또는 후속 이슈를 제시할 때는 해당 작업의 복잡도와 위험도에 맞는
권장 분석 모델명, 추론 수준, 선정 근거를 함께 제시합니다.

모델과 추론 수준은 [OpenAI GPT-5.6 모델 가이드](https://developers.openai.com/api/docs/guides/latest-model)를
기준으로 다음과 같이 표기합니다.

- `5.6 Sol`: 최상위 성능이 필요한 flagship 작업
- `5.6 Terra`: 지능과 비용의 균형이 필요한 작업
- `5.6 Luna`: 고효율 반복 작업과 대량 처리
- 공식 명칭은 `Luna`입니다. `Runa`로 표기하지 않습니다.
- 추론 수준은 `none`, `low`, `medium`, `high`, `xhigh`, `max` 중 하나를 사용합니다.
- 보고에는 `없음 (none)`, `낮음 (low)`, `중간 (medium)`, `높음 (high)`,
  `매우 높음 (xhigh)`, `최대 (max)` 형식으로 표기합니다.
- 기본 출발점은 `medium`입니다.
- `high`와 `xhigh`는 추가 추론으로 품질 향상이 필요한 경우 사용합니다.
- `max`는 가장 어려운 품질 우선 작업에만 사용합니다.

#### 모델 선정 점수

영향도, 불확실성, 검증 난이도, 변경 범위를 각각 `0~2점`으로 평가하고 합산합니다.

| 평가 항목 | 0점 | 1점 | 2점 |
| --- | --- | --- | --- |
| 영향도 | 문구·형식 또는 동작 영향 없음 | 국소 기능·내부 동작 영향 | 사용자 데이터·공용 계약·릴리즈 영향 |
| 불확실성 | 절차와 원인이 명확함 | 일부 조사·선택 필요 | 원인 불명·복수 가설·외부 계약 확인 필요 |
| 검증 난이도 | 정적 검사·단일 확인 | focused test·단일 build | 통합·GUI·live data·배포 검증 |
| 변경 범위 | 반복 처리·단일 파일 | 여러 파일 또는 단일 모듈 | 모듈 경계·schema·배포 경계 변경 |

합계에 따른 기본 모델은 다음과 같습니다.

- `0~2점`: `5.6 Luna`
- `3~5점`: `5.6 Terra`
- `6~8점`: `5.6 Sol`

작업 유형 기본값도 함께 적용합니다.

- 반복적이고 판단 변화가 적은 작업은 `5.6 Luna`를 우선합니다.
- 간단한 개발 작업은 `5.6 Terra`를 우선합니다.
- 위 두 유형으로 명확히 낮출 수 없는 일반 작업은 `5.6 Sol`을 기본값으로 합니다.
- 점수표와 작업 유형 기본값이 충돌하면 더 높은 모델을 선택하고 이유를 기록합니다.

#### 위험 상향 규칙

정확도, 동등성, 보안, 데이터 손상 위험은 합산 점수와 별도로 평가합니다.

- 정확도 또는 동등성 계약을 변경·검증하면 기본 점수보다 한 단계 상향할 수 있습니다.
- 인증, 권한, 비밀정보, 취약점 등 보안 경계를 다루면 최소 `5.6 Sol`, `high`를 사용합니다.
- 사용자 데이터 손상·유실·복구 또는 비가역 변경 위험이 있으면 최소 `5.6 Sol`, `xhigh`를 사용합니다.
- 여러 고위험 경계가 겹치고 실패 비용이 매우 큰 경우에만 `max`를 사용합니다.
- 상향 규칙을 적용하면 어떤 위험 때문에 상향했는지 선정 근거에 명시합니다.

추론 수준은 모델 점수와 독립적으로 다음 기준을 적용합니다.

- `none`: 추론이 필요 없는 결정적 변환·단순 실행
- `low`: 판단이 거의 없는 반복 작업
- `medium`: 기본 출발점, 일반적인 구현·문서·검증
- `high`: 복수 파일·통합 경계·회귀 가능성을 함께 검토
- `xhigh`: 복잡한 상태 전이, 정합성, 보안, 데이터 복구처럼 높은 신뢰가 필요
- `max`: 가장 어려운 품질 우선 작업이며 다른 수준으로 충분하지 않을 때만 사용

```text
추천 모델: 5.6 Terra
추론 수준: 높음 (high)
선정 근거: 여러 스크립트와 Docker 빌드 경계를 검증하지만 모델 정확도 계약을 변경하지 않는 통합 작업
```

- 선정 근거에는 가능하면 `영향도 + 불확실성 + 검증 난이도 + 변경 범위 = 합계`를 포함합니다.
- 실제로 선택 가능한 모델명을 사용하고 확인할 수 없는 모델명은 임의로 만들지 않습니다.
- 단순 문서 오탈자처럼 범위와 위험이 작은 작업에는 과도한 모델이나 추론 수준을 추천하지 않습니다.
- 여러 이슈의 난이도가 크게 다르면 이슈별로 각각 추천합니다.
- 남은 이슈가 없어 `후속 이슈: 없음`으로 보고할 때는 모델 추천을 생략할 수 있습니다.

---

## 3. 단계 진행 규칙

여러 단계 요청은 요청된 순서대로만 진행합니다.

1. 각 단계는 개발, 관련 테스트, 결과 보고, 필요 시 커밋 순서로 닫습니다.
2. 한 단계가 실패하면 즉시 중단하고 뒤 단계는 `건너뜀`으로 보고합니다.
3. 실패 단계는 커밋하지 않습니다.
4. 실패 전 이미 통과 후 커밋된 단계는 유지합니다.
5. 전체 단계가 끝나면 현재 요청 범위 안에서 실제로 남은 후속 이슈만 추천합니다.
6. 마지막 보고에는 푸시 가능 여부와 푸시 수행 여부를 반드시 씁니다.

### 3.1 `/goal` 예외

사용자가 `/goal` 또는 goal option으로 end-to-end 목표 달성을 지시한 경우, 수정 가능한 실패를 즉시 최종 중단으로 확정하지 않습니다.

1. 실패 지점에서 원인, 실패 명령, 영향 범위, 변경 파일을 먼저 기록합니다.
2. 같은 목표와 같은 로드맵 범위 안에서 고칠 수 있으면 수정 후 실패 단계의 테스트부터 다시 시작합니다.
3. 실패 단계가 통과하기 전에는 뒤 단계를 진행하지 않습니다.
4. 같은 실패가 해결 불가능하거나 사용자 결정이 필요할 때만 중단하고 뒤 단계는 `건너뜀`으로 보고합니다.
5. 최종 보고에는 최초 실패, 수정 내용, 재검증 결과를 함께 적습니다.

### 3.2 로드맵 범위 이탈 금지

사용자가 `ROADMAP.md`의 특정 milestone, 번호, 카테고리를 지정하면 해당 범위 내부의 코드 수정, 문서 수정, 테스트, 안정화, 커밋만 허용됩니다.

금지:

- 지정 milestone 완료를 이유로 다음 milestone 자동 착수
- 완료 여부 확인 없이 다음 milestone 구현 시작
- 다른 milestone의 코드/문서/테스트/커밋을 함께 처리
- 다른 milestone을 함께 완료했다고 보고

사용자가 `다음 스텝 진행`, `Milestone 2 진행`, `1번 완료 후 2번까지 진행`처럼 명시한 경우에만 다음 범위로 넘어갑니다.

---

## 4. 커밋과 푸시

커밋은 사용자가 요청했거나 단계 규칙에서 명시한 경우에만 수행합니다.

- 각 단계가 통과한 뒤 해당 단계 변경만 커밋합니다.
- 여러 단계의 변경을 하나의 커밋에 섞지 않습니다.
- 실패한 단계는 커밋하지 않습니다.
- 커밋 메시지는 `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:` 같은 명확한 형식을 사용합니다.
- `git status --short`가 비어 있지 않은 worktree에서는 그 worktree의 현재 브랜치에 대한 PR 생성, PR merge, 로컬/원격 브랜치 삭제를 진행하지 않습니다.
- 미커밋 변경은 금지하지 않습니다. 다만 해당 브랜치를 PR/merge/delete 대상으로 삼으려면 먼저 변경 범위를 검토하고, 필요한 변경은 검증 후 커밋하거나 사용자 승인 아래 보류 상태를 명확히 기록해 worktree를 clean 상태로 만든 뒤 진행합니다.

푸시는 사용자가 명시적으로 요청하기 전까지 금지합니다.

### 4.1 PR 리뷰 우회

릴리즈 PR이 작성자 본인 review 금지 때문에 `REVIEW_REQUIRED`로 막힌 경우,
사용자가 `admin bypass`, `관리자 우회 merge`, `2번으로 진행`처럼 명시 승인하면
branch protection의 review requirement를 관리자 권한으로 우회해 merge할 수 있습니다.

허용 조건:

- worktree가 clean 상태입니다.
- PR CI와 필수 status check가 모두 통과했습니다.
- PR이 `MERGEABLE`이고 대화 해결 요구가 남아 있지 않습니다.
- blocker가 self-approval 불가에 따른 review requirement뿐임을 확인했습니다.
- 사용자가 현재 PR에 대해 admin bypass를 명시 승인했습니다.

금지:

- CI 실패, 충돌, unresolved conversation, requested changes 상태에서 admin bypass merge
- 사용자 명시 승인 없는 admin bypass merge
- admin bypass를 대신해 branch protection 설정을 임시 완화하는 행위

보고 시 admin bypass를 사용한 사실, 실행 명령, merge SHA, CI 상태, 우회 사유를 분리해서 기록합니다.

마지막 보고 형식:

```text
커밋:
- 수행함/수행하지 않음
- 메시지:
- 해시:
- 이유:

푸시 가능: 예/아니오
이유:
푸시 수행 여부: 수행하지 않음
```

`푸시 가능: 예`는 모든 단계가 통과하고, 필요한 커밋이 끝났고, 미커밋 변경이 없을 때만 씁니다.

---

## 5. 검증 정책

사용자가 별도 테스트를 지정하면 사용자 지시를 우선합니다.

| 변경 범위 | 최소 검증 |
| --- | --- |
| 문서 전용 | `git diff --check`; 가능하면 `npx --yes markdownlint-cli2@0.22.1` |
| CLI/parser/JSON schema | `git diff --check`, `swift test` 또는 해당 런타임 공식 테스트 |
| shared cache/polling | `git diff --check`, `swift test`, cache schema/atomic write/stale-error/token 미저장 확인 |
| macOS menu bar app | `git diff --check`, `swift test`, `xcodebuild build` |
| WidgetKit | `git diff --check`, `swift test`, `xcodebuild build`; 실제 UI는 App Group provisioning 전 완료로 보고하지 않음 |
| 설치/배포 | `git diff --check`; 설치/LaunchAgent/codesign/notarization/`spctl`은 명시 요청 전 실행 금지 |

문서만 수정한 단계도 최소한 `git diff --check`를 실행합니다.
Node.js/npm 또는 `markdownlint-cli2` 실행 경로가 없으면 `명령 없음`으로 보고하고 통과 처리하지 않습니다.

장시간 테스트는 명시 요청이 있을 때만 실행합니다.

```bash
codex-usage status --watch 60
```

실행하지 않았다면 다음처럼 보고합니다.

```text
장시간 테스트: 실행하지 않음
이유: 사용자 명시 요청 없음
```

---

## 6. 중단 조건

아래 상황이 발생하면 중단하고 보고합니다. `/goal` 요청은 3.1 예외를 따릅니다.

1. build 실패
2. 핵심 fixture test 실패
3. `git diff --check` 실패
4. CLI JSON schema 변경이 README/AGENTS/ROADMAP과 불일치
5. cache schema 변경이 앱/위젯 문서와 불일치
6. Codex auth token 또는 session material 노출 징후
7. `~/.codex/auth.json` 직접 읽기 또는 출력 징후
8. app-server response 전체 원문을 민감정보 검토 없이 로그/cache에 저장
9. WidgetKit extension이 shared cache 대신 app-server를 직접 호출
10. menu bar runner의 과도한 CPU/RAM 사용 측정 또는 명백한 정황
11. 설치/삭제 스크립트가 사용자 홈 또는 시스템 파일을 과도하게 수정할 위험
12. codesign/notarization/LaunchAgent/helper 단계에 사용자 승인이 필요한 경우

중단 보고에는 단계, 구간, 실패 명령, 확인된 원인, 추정 원인, 변경 파일, 커밋 여부, 뒤 단계 `건너뜀`, 후속 조치를 포함합니다.

---

## 7. Codex 사용량 데이터 규칙

1. 1순위 데이터 소스는 Codex app-server `account/rateLimits/read`입니다.
2. slot 이름과 관계없이 `windowDurationMins = 300`은 5시간 창으로 해석합니다.
3. slot 이름과 관계없이 `windowDurationMins = 10080`은 주간 창으로 해석합니다.
4. Codex 주간 window는 성공 cache에 필수이며 5시간 window는 일시 미제공될 수 있습니다.
5. weekly-only 응답은 partial success로 저장하고 주간 history·runner·알림을 계속 갱신합니다.
6. 없는 5시간 window를 0% 또는 마지막 성공 값으로 합성하지 않고 UI에 `현재 제공되지 않음`으로 표시합니다.
7. 5시간 window가 복구되면 기존 5시간 history를 보존한 상태에서 새 sample과 pace를 자동 재개합니다.
8. 잔여량은 `100 - usedPercent`로 계산합니다.
9. `resetsAt`은 Unix epoch seconds이며 표시 시 로컬 시간대로 변환합니다.
10. 기본 limit bucket은 `rateLimitsByLimitId.codex`입니다.
11. `codex_bengalfox` 같은 추가 bucket은 advanced/debug 출력으로 분리합니다.
12. 사용량 조회 실패 시 마지막 성공 cache가 있어도 stale/error 상태를 함께 표시합니다.
13. 공식 잔여 한도와 로컬 SQLite 추정치를 섞어 표현하지 않습니다.
14. 주간 잔여량 그래프는 같은 `resetsAt` window 안에서 표시 잔여율이 증가하지 않도록 그립니다.
15. OpenAI가 주간 한도를 실제 리셋해 `resetsAt`이 바뀐 경우에만 이전 history와 분리하고 새 타임라인을 왼쪽 100%에서 시작합니다.

---

## 8. macOS UI와 캐릭터 경계

- RunCat은 "작은 menu bar runner가 상태에 따라 속도를 바꾸는 경험"만 참고합니다.
- RunCat의 고양이 캐릭터, asset, 브랜드 표현은 복제하지 않습니다.
- runner 속도는 현재 제공되는 5시간/주간 window 사용률 중 최댓값을 기준으로 하며, weekly-only이면 주간 값만 사용합니다.
- WidgetKit은 실시간 애니메이션 채널이 아니라 glance용 상태 표시로 다룹니다.
- menu bar app이 지속 애니메이션을 담당합니다.
- popover는 장난스럽기보다 명확한 개발 도구처럼 보여야 합니다.
- `Reduce Motion` 또는 저전력 환경을 고려해 애니메이션 완화 옵션을 둡니다.
- high usage 경고는 눈에 띄되 과하게 산만하지 않아야 합니다.
- UI 확인을 하지 않았다면 `UI 확인 미수행`으로 보고합니다.

### 8.1 캐릭터 이미지 생성/교체

캐릭터 컨셉 변경 요청이 있으면 menu bar runner, desktop pet, popover tab button, 설정 탭 미리보기를 하나의 캐릭터 세트로 다룹니다.

필수 원칙:

- 기준 이미지는 desktop pet이며, menu bar 이미지는 같은 desktop pet 현재 프레임에서만 파생합니다.
- 모든 이미지는 같은 캐릭터, 같은 그림체, 투명 배경 PNG, 충분한 여백, 작은 크기에서 읽히는 실루엣을 유지합니다.
- 임시 생성 이미지는 저장소에 넣지 않고, 최종 선택 후 임시 리소스를 삭제합니다.
- 캐릭터 이미지는 현재 캐릭터 프로필이 지정한 리소스만 사용합니다.
- 새 캐릭터 UI/manifest를 바꾸면 `MacDogCharacterProfile`, manifest, 검증 스크립트, screenshot test를 함께 갱신합니다.

현재 기본 리소스 계약:

- menu bar: 별도 전용 PNG 없음. `Sources/MacDog/Resources/DesktopPet/pup-run-right-0.png` ~ `pup-run-right-7.png`에서 파생
- desktop pet: `Sources/MacDog/Resources/DesktopPet/` 아래 right/up/down 8프레임, idle/rest/alert 4프레임 세트
- tab button: `Sources/MacDog/Resources/PopoverTabs/{codex,mac,sleep,battery,settings}-tab.png`
- manifest: `Sources/MacDog/Resources/CharacterProfiles/codex-pup-tab-art.json`

캐릭터 세트 변경 후 최소 검증:

```bash
git diff --check
./script/verify_character_profile.sh
swift test --filter MacDogCharacterProfileTests
swift test --filter PopoverScreenshotRendererTests
```

가능하면 최신 앱을 열어 runner, desktop pet, tab button, 설정 탭 미리보기를 직접 확인합니다. 직접 확인하지 않았다면 `UI 확인 미수행`으로 보고합니다.

---

## 9. 설치, 배포, 릴리즈

설치/배포 세부 절차는 `Docs/ReleasePackaging.md`, `Docs/GitHubReleaseChecklist.md`, `Docs/Scripts.md`를 기준으로 합니다.

사용자 설치 검수 원칙:

- 최종 사용자가 받는 DMG를 실제로 열고 Finder에서 보이는 `MacDog.app`을 `Applications`로 드래그앤드롭한 경우만 설치 검수로 인정합니다.
- `install.sh`, `cp`, `ditto`, `rsync`, Finder 숨김 조작, 화면 밖 Finder 창, hdiutil mount 후 직접 복사, 앱 번들 직접 교체는 사용자 설치 검수의 대체 수단으로 금지합니다.
- 실제 drag-and-drop을 수행하거나 관찰할 수 없으면 즉시 `미수행`으로 보고합니다.

### 9.1 설치원, Finder, 중복 앱 경계

- 설치원은 새로 다운로드해 checksum과 `hdiutil verify`를 통과한 최종 `.dmg`만 허용합니다.
- `package_release.sh`가 Finder AppleEvent timeout, retry 실패, mountpoint 잔류로 종료된 경우
  마운트된 read-write 볼륨이나 stage directory를 설치원으로 사용하지 않습니다.
- 설치 DMG는 Finder에서 실제 `.dmg` 파일을 열어 자동으로 표시된 창을 사용합니다.
  `hdiutil attach -noautoopen` 뒤 sidebar의 volume을 여는 흐름은 저장된 Finder window
  metadata가 적용되지 않을 수 있으므로 설치 검수의 대체 경로로 사용하지 않습니다.
- 설치 전 source volume이 read-only인지, DMG payload version과 executable checksum이
  승인된 release head와 일치하는지 확인합니다. payload가 현재 release head보다 오래되면
  화면 검토에만 사용하고 `/Applications`에 설치하지 않습니다.
- Finder 자동화 좌표는 축소된 app screenshot 픽셀을 실제 macOS logical screen 좌표로
  간주하지 않습니다. 창 밖 또는 다른 Finder 창으로 드래그할 때는 source와 destination의
  실제 경로를 확인하고, 좌표 추정만으로 성공을 판정하지 않습니다.
- drag-and-drop 뒤 `/Applications/MacDog.app`의 version, executable checksum, 수정 시각,
  codesign 검증, 실행 중 app path가 설치 source와 일치해야만 설치 성공으로 보고합니다.
  Finder `대치` dialog가 닫힌 사실만으로 성공으로 보고하지 않습니다.
- 개발용 `dist/MacDog.app`, 다른 git worktree의 `dist/MacDog.app`, Desktop 복사본,
  `/private/tmp/macdog-*` app bundle을 실행하거나 Finder 설치원으로 사용하지 않습니다.
  이런 번들은 LaunchServices 또는 Finder 검색에 중복 앱으로 노출될 수 있습니다.
- 설치 종료 시 실제 앱은 `/Applications/MacDog.app` 하나만 남아야 합니다.
  `~/Applications`, Desktop, 모든 git worktree의 `dist`, `/private/tmp/macdog-*`,
  mounted volume에 남은 `MacDog.app`은 cleanup 대상입니다.
- cleanup 전에 `/Applications/MacDog.app`을 제외한 app bundle을 LaunchServices에서
  unregister하고, quarantine할 때는 `.app.quarantined`처럼 `.app`으로 끝나지 않는
  이름과 `.noindex` directory를 사용합니다.
- Finder 검색은 Applications folder에서 시작해도 기본 범위가 `Mac`일 수 있습니다.
  `cleanup_release_smoke_state.sh --apply` 뒤 `verify_release_final_state.sh`를 실행하고,
  `응용 프로그램` 범위를 명시적으로 선택한 `MacDog` 검색 결과 URL이
  `/Applications/MacDog.app` 하나인지 직접 확인합니다.

릴리즈 준비/종료 요청이 있을 때는 버전별 세부 문서와 별개로 아래 공용 순서를 따릅니다.
아래 조건을 모두 완료해야 릴리즈 완료로 봅니다.

1. 커밋 준비
   - `git status --short --branch`와 `git diff --stat`로 현재 변경 범위와 브랜치를 확인합니다.
   - `git status --short`가 비어 있지 않으면 현재 브랜치의 PR 생성, merge, 브랜치 삭제를 진행하지 않습니다.
   - 새 파일은 `??` 또는 staged `A` 항목까지 확인하고, 버전별 로드맵/릴리즈 문서가 요구하는 핵심 source, test, docs가 누락되지 않았는지 확인합니다.
   - PR 생성 전 `git diff --check`, 범위별 focused test, 전체 `swift test`를 통과시킵니다.
   - macOS 앱 변경이 있으면 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO` 또는 현재 repo의 공식 Xcode build 명령을 통과시킵니다.
   - 검증 실패 시 즉시 중단하고 커밋하지 않습니다.
   - 검증 통과 후에만 릴리즈 범위 변경을 커밋합니다.
2. 릴리즈 브랜치와 PR
   - 현재 변경이 `main`에 직접 있으면 릴리즈용 브랜치로 분리합니다.
   - release branch worktree가 clean 상태가 아니면 `<release-branch>` PR 생성, PR merge, branch cleanup을 진행하지 않습니다.
   - `<release-branch>`를 push하고 `<release-branch> -> main` PR을 생성합니다.
   - PR CI와 리뷰를 확인합니다.
   - 리뷰 또는 CI 실패 시 같은 브랜치에서 수정, 테스트, 커밋, push를 반복합니다.
   - merge 후 `origin/main` 최신 SHA를 `<version>` release head로 기록합니다.
3. 패키징과 GitHub Release
   - GitHub Release 업데이트와 패키징은 릴리즈 준비의 필수 단계입니다.
   - 원격 tag `v<version>`이 없는지 확인합니다. 기존 tag를 재발행하는 경우에는 기존 release/tag/asset 상태와 재발행 사유를 먼저 기록합니다.
   - GitHub에서 `Verified`로 표시될 signed annotated tag를 만들 수 있는 signing key와 git 설정이 준비됐는지 확인합니다.
   - signing key가 없거나 GitHub가 tag signature를 `Verified`로 확인하지 못하면 release publish, asset 교체, tag 이동을 중단합니다.
   - `Release Candidate` workflow 또는 로컬 packaging script를 최신 release head 기준으로 실행합니다.
   - 생성된 `.dmg`와 `.dmg.sha256` artifact를 확인하고, 다운로드 후 checksum과 `hdiutil verify`를 확인합니다.
   - release tag `v<version>`은 최신 release head에 대해 로컬에서 signed annotated tag로 만든 뒤 원격에 push합니다.
   - `Draft Release` workflow는 승인된 unsigned/stable 입력값으로 실행하되, 원격에 이미 존재하는 signed tag만 사용해야 합니다. workflow나 `gh release create`가 unsigned/lightweight tag를 자동 생성하게 두지 않습니다.
   - draft release의 `isDraft`, `isPrerelease`, `targetCommitish`, asset 목록을 확인합니다.
   - draft asset에는 `MacDog-<version>.dmg`와 `MacDog-<version>.dmg.sha256`가 포함되어야 합니다.
   - stale draft가 아니고 `targetCommitish`가 최신 release head이며 GitHub tag verification이 `Verified`일 때만 publish합니다.
   - publish 후 `isDraft=false`, tag `v<version>` 생성, published asset download URL을 확인합니다.
   - published asset을 다시 다운로드해 checksum과 `hdiutil verify`를 재확인합니다.
4. 릴리즈 tag 기준
   - release tag `v<version>`은 반드시 최종 release head, 즉 릴리즈에 포함될 마지막 커밋을 가리켜야 합니다.
   - 마지막 커밋 이후 tag가 생성됐는지 확인합니다.
   - release tag는 lightweight tag가 아니라 signed annotated tag여야 하며, GitHub에서 `Verified`로 확인되어야 합니다.
   - tag가 최신 release head가 아닌 다른 SHA를 가리키거나 GitHub에서 `Verified`가 아니면 publish하지 않고 중단합니다.
5. 실제 설치와 GUI smoke
   - 설치 검수는 published DMG를 Finder에서 열고, Finder 창에 보이는 `MacDog.app`을 `Applications`로 실제 drag-and-drop한 경우만 인정합니다.
   - `install.sh`, `cp`, `ditto`, `rsync`, `hdiutil mount` 후 직접 복사는 설치 검수 대체 수단으로 인정하지 않습니다.
   - published DMG payload checksum이 최신 release head와 일치하는지 확인하고, 불일치하면 설치하지 않습니다.
   - drag-and-drop 뒤 설치 source와 `/Applications/MacDog.app` executable checksum이 일치하는지 확인합니다.
   - `/Applications/MacDog.app` 기준으로 앱 실행, menu bar runner, popover, 주요 tab 전환, popover placement, 첫 실행 user component 상태를 확인합니다.
   - `~/bin/codex-usage`, usage cache LaunchAgent, 실행 중 app path가 `/Applications/MacDog.app` 기준인지 확인합니다.
   - `./script/verify_usage_fetch_cache_contract.sh --cli <codex-usage-path>`로 cache 계약을 확인합니다.
   - live fetch 성공 시 weekly history append diagnostic과 history sample을 확인합니다. 5시간 window가
     없고 주간만 있는 partial success도 정상으로 분리 확인합니다.
   - live fetch 실패 시 stale/error snapshot인지 분리해서 보고합니다.
6. Release smoke 종료
   - `./script/cleanup_release_smoke_state.sh --apply`로 smoke 잔여물을 정리합니다.
   - `./script/verify_release_final_state.sh --version <version>`을 실행합니다.
   - `/Applications/MacDog.app` 외 Desktop, 모든 git worktree `dist`, `/private/tmp/macdog-*`, mounted volume의 중복 app bundle이 0개인지 확인합니다.
   - Finder `응용 프로그램` 범위의 `MacDog` 검색 결과가 `/Applications/MacDog.app` 하나인지 직접 확인합니다.
   - branch cleanup 전 `git status --short --branch`로 현재 worktree가 clean 상태인지 확인합니다.
   - release branch가 `main`과 `origin/main`에 포함됐는지 확인한 뒤에만 브랜치 정리를 진행합니다.
   - 로컬/원격 release branch 삭제는 사용자가 릴리즈 종료 또는 브랜치 정리를 명시적으로 승인한 경우에만 수행합니다.
   - 정리 후 `git branch -a`로 release branch 잔여 여부를 확인합니다.

브랜치 삭제 전 필수 확인:

```bash
git merge-base --is-ancestor <release-branch> main
git merge-base --is-ancestor origin/<release-branch> origin/main
```

둘 중 하나라도 실패하면 브랜치를 삭제하지 않고 중단합니다. 원격 브랜치 삭제는 사용자가 릴리즈 종료 또는 브랜치 정리를 명시적으로 승인한 경우에만 수행합니다.

`Stable Release` workflow는 Apple Developer Program, Developer ID signing, notarization, App Group provisioning 조건이 별도 승인되기 전까지 실행하지 않습니다.

---

## 10. 문서 관리

문서 변경 시 확인합니다.

1. README, ROADMAP, AGENTS의 용어가 일치하는지
2. CLI 명령 이름이 일치하는지
3. 사용량 창 해석이 일치하는지
4. RunCat 참고 범위가 과장되거나 asset 복제로 오해되지 않는지
5. Apple Developer Program이 필요한 항목이 현재 구현 계획, 완료 조건, 후속 이슈에 들어가지 않았는지
6. `구현 완료`, `MVP 완료`, `1차 구현`, `후속 예정`, `실험 기능`, `검증 미수행`이 구분되는지
7. 알림 문서가 `UserNotifications` 로컬 알림, 기본 꺼짐, 설정 탭 opt-in, macOS 알림 권한 승인, JSON/cache/app-server 계약 유지와 일치하는지
8. 실행하지 않은 검증을 완료처럼 쓰지 않았는지

문서가 스크립트의 검증 대상이면 삭제/병합 전에 참조를 확인하고, 필요한 경우 검증 스크립트 또는 상위 문서를 함께 갱신합니다.

---

## 11. 최종 보고 형식

작업 성공 시:

```text
작업:
- ...

변경 파일:
- ...

검증:
- git diff --check: 통과
- ...

미실행:
- GUI 실행: 실행하지 않음
- 장시간 테스트: 실행하지 않음

커밋:
- 수행함/수행하지 않음
- 이유:

푸시 가능: 예/아니오
이유:
푸시 수행 여부: 수행하지 않음
```

작업 실패 시:

```text
중단 위치:
- 단계:
- 구간:
- 실패 명령:

결과:
- 상태: 실패
- 뒤 단계: 건너뜀

원인:
- 확인된 원인:
- 추정 원인:

변경 파일:
- ...

커밋:
- 수행하지 않음

푸시 가능: 아니오
푸시 수행 여부: 수행하지 않음
```

후속 이슈는 현재 요청 범위 안에서 실제로 처리 가능한 항목만 제시합니다. 남은 항목이 없으면 `후속 이슈: 없음`으로 보고합니다.
