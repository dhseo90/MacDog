# AGENTS.md

MacDog 자동화 에이전트의 작업 규칙이다. 대상은 Swift 사용량 CLI, macOS 메뉴바 앱과
데스크톱 펫, provider별 cache/history, optional WidgetKit, 권한 도우미, 설치·배포 스크립트다.
제품 범위와 진행 상태는 `README.md`, `ROADMAP.md`, 버전별 `Docs/` 문서에서 확인한다.

## 1. 요청과 문맥

| 요청 | 수행 범위 | 별도 지시가 필요한 일 |
| --- | --- | --- |
| 조사·리뷰·상태 확인 | 관련 파일과 상태 조회, 안전한 읽기 전용 진단, 근거 보고 | 제품 수정, 커밋·푸시 |
| 개발·수정 | 지정 기능 구현, 관련 단기 검증, 같은 범위의 결함 수정과 재검증 | 다음 milestone, 계약 확대 |
| 문서 개편 | 지정 문서와 직접 연결된 참조 정리, 문서 검증 | 무관한 제품 구현 |
| 특정 테스트 | 지정 묶음 실행과 결과 보고 | 범위 확대, 임의 제품 수정 |
| 릴리즈 준비 | 실제 상태 대조, 잔여 이슈와 검증 필요성 판단 | 미승인 외부 변경 |
| 커밋·푸시·릴리즈 실행 | 명시된 대상과 동작 | 승인받지 않은 merge·tag·publish·삭제 |

사용자 범위와 순서를 지킨다. 최신 명시 지시가 기존 규칙을 변경하면 그 범위에 적용하며,
이미 주어진 승인을 상태 질문이나 담당자 변경 때문에 다시 받지 않는다. 조회·리뷰만 요청한
경우 수정 권한으로 확대하지 않는다. 상위 실행 환경의 보안·권한 제한을 우회하지 않는다.

`AGENTS.md`는 저장소 실행 정책의 기준이다. README, roadmap, verifier, 과거 evidence가
더 넓은 실행 권한을 주지 않는다. 미해소 충돌은 관련 부분을 특정해 보고하고, 영향 없는
허용 작업은 계속한다. 완료 여부는 문서의 체크 표시와 실제 구현·검증 근거를 대조한다.

구조 변경에는 관련 설계, 저장 변경에는 cache 계약, 배포에는 릴리즈 문서를 읽는다.
작은 수정에 전체 저장소 지도나 모든 과거 기록을 요구하지 않는다. 같은 지침을 매 수정마다
다시 읽거나 승인된 설계를 다시 작성하지 않는다.

Superpowers는 설계·TDD·원인 분석·검토·검증에 필요한 절차를 선택해 활용한다. 스킬은
명시 요청 또는 실제 적용 범위에 맞춰 사용하고 필요한 참조만 읽는다. 도구와 구현 방법은
목표·불변조건·합격 기준 안에서 선택한다. 문서 변경을 모델 설정이나 설치 스킬 변경으로
보고하지 않는다.

## 2. 단계 개발과 실패 처리

시작 전에 요청 범위, 비범위, 불변 계약, 정상·오류·경계 동작, 필요한 검증을 파악한다.
단순 수정은 짧은 설명으로 충분하고, 여러 모듈에 걸친 변경은 기존 버전 문서에 계획을 둔다.
사용자가 지정한 milestone·번호·카테고리 밖 작업을 자동 착수하지 않는다.

각 단계는 구현 → 관련 검증·수정 → 결과 기록 → 승인된 커밋 순서로 닫는다.
첫 초안만 만들고 멈추지 않으며, 이미 승인된 범위의 완료 조건까지 진행한다.

### 2.1 TDD와 재검증

동작 변경과 버그 수정은 실제 결함을 잡는 focused test로 보호한다. TDD의 예상 RED는
실행 전에 특정한 미구현 동작의 assertion 실패여야 한다. 컴파일·의존성·명령·환경 오류나
기존 회귀 실패를 사후에 RED로 이름 바꾸지 않는다. 문구·형식 수정에 의미 없는 테스트를
만들거나 source 문자열 검사만으로 실제 동작을 검증했다고 하지 않는다.

개발 요청은 같은 단계의 안전한 수정·관련 단기 재검증을 포함한다. `/goal` 유무에 관계없이
최초 실패의 명령·원인·영향을 기록하고 다음 조건에서 계속한다.

- 원인이 요청 변경 또는 검증 준비에 있고 기존 계약을 유지하며 고칠 수 있다.
- 테스트가 작업 소유 fixture·임시 저장소를 사용하며 실제 계정·사용자 설정을 변경하지 않는다.
- 추가 외부 권한이나 새 제품 결정이 필요하지 않다.

GREEN과 영향 회귀가 통과하기 전 다음 단계나 커밋으로 넘어가지 않는다. 실패 이력을
최종 성공으로 덮어쓰지 않는다. 같은 원인을 새 근거 없이 반복 수정하지 말고 원인을 재검토한다.

### 2.2 중단 경계

다음 경우 영향받는 작업을 멈추고 실패 명령, 확인/추정 원인, 변경 파일, 남은 상태와
재개 조건을 보고한다. 진행할 수 없는 뒤 단계는 `건너뜀`으로 기록한다.

- 비밀정보 노출, 허용 writer 밖 auth store 접근, 사용자 데이터·권한 경계 침해
- 요청 밖 CLI/JSON/cache/app-server 계약 변경이 필요한 경우
- 삭제 대상·소유권 불명확, 실제 설치·권한 변경에 대한 승인 부재
- 과도한 CPU/RAM 사용이 측정되거나 명백한 정황이 있는 경우
- 원인·안전성을 확인할 수 없거나 같은 실패·교차 회귀가 해소되지 않는 경우
- 필수 도구 부재로 승인되지 않은 대체 검증이나 합격 기준 완화가 필요한 경우

테스트 삭제, 임의 timeout 연장, stale/오류 은폐로 성공을 만들지 않는다.

## 3. 검증과 증거

개발 중에는 변경 기능과 영향 회귀를 검증하고, 범위가 끝난 시점에 아래 최소 검증을 닫는다.
매 수정마다 전체 묶음을 반복하지 않는다. 같은 코드·환경·검증 범위의 결과는 재사용하며,
변경·실패·누락 또는 환경 변화가 근거를 무효화한 부분만 다시 확인한다.

| 변경 범위 | 완료 시 최소 검증 |
| --- | --- |
| 문서 | `git diff --check`, 가능하면 `npx --yes markdownlint-cli2@0.22.1` |
| CLI/parser/JSON | 관련 focused test, `swift test`, diff 검사 |
| cache/history/polling | Swift 테스트, atomic write·schema·stale/error·비밀 미저장 검증 |
| 메뉴바 앱 | focused test, `swift test`, Xcode Debug build, diff 검사 |
| WidgetKit | 관련 Swift 테스트와 opt-in build, diff 검사; 실제 UI 증거와 구분 |
| 설치·배포 스크립트 | diff 검사, 관련 정적 검사·격리 fixture/dry-run; 실제 설치와 구분 |
| 캐릭터 | profile verifier, character/screenshot focused tests, diff 검사 |

서명 없는 앱 빌드 기준:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build \
  -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

명령이 없거나 실행 실패하면 그 상태를 보고한다. 일부 통과·미실행을 전체 PASS로 바꾸지 않는다.
verifier 호출 전 실제 옵션과 부수 효과를 확인한다. wrapper·fixture·정적 검사는 실제 live/UI/
설치를 대체하지 않는다. 고정된 30분·120분 테스트를 다른 프로젝트에서 가져오지 않는다.

일반 단기 fixture 검증은 개발 범위에 포함한다. 장시간 테스트, live 사용량 조회, GUI 앱 실행,
설치 스크립트 실실행, LaunchAgent 등록/제거, helper 설치/삭제, codesign/notarization/`spctl`은
해당 동작의 명시 승인 후 수행한다. `codex-usage status --watch 60`도 장시간 동작이다.

버전 개발·릴리즈 기록에는 검증 명령, exit/result, 대상 코드·환경, 최초 실패와 재검증,
실제 생성한 증거 경로, 미실행 사유를 남긴다. 단순 문서 수정에는 검증 결과 보고로 충분하다.
실제 GUI 검수는 화면·조작·관측 상태와 시각 증거를 기록한다. screenshot renderer 성공은
렌더링 검증이며 설치본 popover 조작 성공이 아니다. 열지 않은 화면은 `UI 확인 미수행`이다.

임시 산출물은 작업 소유 경로에서 만들고, 성공·실패·중단 시 필요한 비민감 증거를 보존한 뒤
소유가 확인된 잔여물을 정리한다. 사용자 파일이나 다른 작업 프로세스를 임의 삭제·종료하지
않는다. 임시 경로를 영구 증거 링크로 제시하지 않는다.

## 4. 비밀정보와 인증 예외

token, access/refresh token, cookie, session material, auth header를 대화·로그·cache·fixture·
문서에 출력하거나 저장하지 않는다. 에이전트는 `~/.codex/auth.json`을 직접 읽지 않는다.
에이전트가 승인 없이 `~/.grok/auth.json` 원문을 열거나 출력하는 것도 금지한다.
raw app-server/billing 응답을 민감정보 검토 없이 저장하지 않는다.

아래 예외는 제품 writer의 제한된 runtime 동작만 허용한다. 에이전트의 원문 조사,
메뉴바 앱의 auth store 접근, 비밀 출력·영구 저장 권한으로 확대하지 않는다.

### 4.1 Codex 초기화권 만료일

`codex-usage`만 다음 순서로 access token을 메모리에서 받아 ChatGPT backend 만료일
요청의 `Authorization` header에 즉시 사용한다.

1. app-server `account/chatgptAuthTokens/refresh`
2. 해당 method 미지원 시 Codex auth store: `$CODEX_HOME/auth.json`,
   `~/.config/codex/auth.json`, `~/.codex/auth.json`, macOS Keychain `Codex Auth`

직접 auth store 읽기는 이 backend 요청 직전 메모리 사용으로 제한한다.
token cache, raw response 저장, fixture/문서 token 저장은 허용하지 않는다.

### 4.2 Grok CLI sibling

`macdog-grok-usage`는 Grok CLI와 같은 `~/.grok/auth.json` 세션을 사용한다.

- billing 직전에 access token을 메모리로 읽어 unofficial `x.ai/billing` 요청에 사용한다.
- 유효한 token이면 refresh하거나 파일을 변경하지 않는다.
- 만료 또는 billing 401일 때만 `auth.json.lock`을 잡고, 디스크의 새 값을 우선 채택한다.
  새 값이 없으면 OIDC refresh 후 같은 파일에 atomic merge write한다.

로그인/로그아웃은 `grok login` / `grok logout`만 사용한다. MacDog 전용 token 파일,
메모리 단독 세션, `XAI_API_KEY`로 주간 pool 조회, 메뉴바 앱의 auth store 읽기/쓰기는 금지한다.

## 5. 사용량과 앱 경계

CLI JSON schema, cache schema, app-server JSON-RPC 해석, 앱/위젯 데이터 경계는 요청 없이
breaking change를 만들지 않는다. 기본 visible provider는 Codex/Grok이며 Claude source,
sanitizer, cache와 hidden/debug 경로는 보존한다. 버전별 UI 동작은 해당 roadmap을 따른다.

복수 provider 기능에서는 활성 집합이 cache/writer와 게이지를 정하고 메인 provider가
상세 그래프·러너·알림·tooltip을 정한다. provider 사용률을 합산하거나 실패한 provider를
다른 provider cache로 대체하지 않는다. 알림은 UserNotifications 기반 로컬 알림이며
기본 꺼짐, 설정 opt-in과 macOS 권한 승인, 기존 dedupe를 유지한다.

### 5.1 Codex 데이터

- 1순위 원천은 app-server `account/rateLimits/read`, 기본 bucket은
  `rateLimitsByLimitId.codex`다. `codex_bengalfox` 등 추가 bucket은 advanced/debug로 분리한다.
- slot 이름과 무관하게 `windowDurationMins = 300`은 5시간, `10080`은 주간이다.
- 성공 cache에는 주간이 필수다. weekly-only 응답은 partial success로 저장하고
  주간 history·runner·알림을 계속 갱신한다.
- 없는 5시간 값을 0%나 마지막 성공 값으로 합성하지 않는다. 통합 게이지에서는 해당 항목을
  숨기고, tooltip 등 다른 표시에서는 `현재 제공되지 않음`으로 둔다.
  복구 시 기존 history를 유지한 채 sample과 pace를 재개한다.
- 잔여율은 `100 - usedPercent`, `resetsAt`은 Unix epoch seconds이며 로컬 시간으로 표시한다.
- 실패 시 마지막 성공 cache와 stale/error를 함께 표시한다. 공식 한도와 로컬 SQLite 추정을 섞지 않는다.
- 같은 `resetsAt` 창의 표시 잔여율은 증가하지 않는다. 공식 reset으로 `resetsAt`이 바뀔 때만
  이전 history와 분리하고 새 timeline을 왼쪽 100%에서 시작한다.

### 5.2 Grok 데이터

- 원천은 unofficial CLI-proxy `x.ai/billing`의 SuperGrok/Grok Build 공유 주간 pool이다.
  공개 REST 공식 구독 잔여율 API로 표현하지 않는다.
- `usedPercent = creditUsagePercent`, 잔여율은 `100 - usedPercent`다.
- Grok 5시간 window는 없으며 합성하지 않는다. 해당 항목을 표시할 때는 `현재 제공되지 않음`이다.
- Extra Usage Credits, Auto Top Up, console prepaid, RPS/TPM, OTEL, TUI parser,
  `XAI_API_KEY`는 기본 UI 입력이 아니다. `MONTHLY`, prepaid, on-demand cycle은 거부한다.
- reset을 모르면 field를 생략한다. `billingPeriodStart + 7일`로 만들지 않는다.
- `grok-usage.json`, `grok-usage-history.json`, `grok-usage.lock`은 Codex/Claude와 분리하며
  directory `0700`, file `0600`, atomic write를 유지한다.
- Grok Extra Usage Credits를 Codex 초기화권처럼 표시하지 않는다.

### 5.3 네이티브 UI와 캐릭터

러너는 메인 provider의 현재 제공되는 5시간/주간 사용률 중 최댓값을 사용하고 weekly-only이면
주간만 사용한다. 메뉴바 아이콘 옆 `%`는 메인 provider 주간 잔여율만 쓰며, 없는 주간 값은
합성하지 않고 숨긴다. 러너 속도와 `%`가 달라도 오류가 아니다. Reduce Motion과 저전력
환경을 고려한다. popover는 읽기 쉬운 개발 도구로 유지하고 high usage 경고가 과도하게
산만하지 않게 한다.

RunCat에서는 작은 러너가 상태에 따라 속도를 바꾸는 경험만 참고한다. 캐릭터·asset·브랜드는
복제하지 않는다. 캐릭터 교체는 runner, desktop pet, popover tab, 설정 미리보기를 한 세트로
취급한다. desktop pet 프레임이 기준이며 메뉴바 이미지는 같은 현재 프레임에서만 파생한다.

모든 이미지에 같은 캐릭터·그림체, 투명 PNG, 여백, 작은 크기에서 읽히는 실루엣을 유지한다.
현재 profile 지정 리소스만 사용하고 profile/manifest/verifier/screenshot test를 함께 갱신한다.
현재 경로는 `Sources/MacDog/Resources/`의 `DesktopPet/`(right/up/down 8프레임,
idle/rest/alert 4프레임), `PopoverTabs/{codex,mac,sleep,battery,settings}-tab.png`,
`CharacterProfiles/codex-pup-tab-art.json`이다. 메뉴바는 `pup-run-right-0.png`~`7.png`에서
파생한다. 임시 생성 이미지는 저장소에 넣지 않고 최종 선택 뒤 작업 소유 임시 리소스를 정리한다.

검증은 `./script/verify_character_profile.sh`,
`swift test --filter MacDogCharacterProfileTests`,
`swift test --filter PopoverScreenshotRendererTests`를 사용한다.
실제 앱 확인은 3장의 GUI 승인 경계를 따른다.

WidgetKit은 glance용 shared cache 소비자다. app-server를 직접 호출하거나 실시간 애니메이션
채널로 사용하지 않는다. source/test/opt-in build를 보존하되 기본 앱/DMG 완료 조건에서 제외한다.
실제 Widget UI, shared cache 표시, stale/error, deep link 검증을 source/build만으로 주장하지 않는다.

## 6. Git과 승인

시작 시 branch, upstream, staged/unstaged/untracked 상태를 확인한다. 기존 변경은 소유자를
확인할 수 없으면 사용자 작업으로 보존한다. 커밋은 명시 승인된 범위만 검증 후 수행하고,
`feat:`, `fix:`, `docs:`, `test:` 등 성격이 드러나는 메시지를 쓴다.
승인은 철회·대체·범위 변경이 없으면 유지된다. 푸시 권한은 커밋 권한과 별도로 확인한다.

미커밋 변경은 금지하지 않습니다. 기존 다른 작업은 자동 stage·stash·revert하지 않는다.
`git status --short`가 비어 있지 않으면 해당 worktree의 PR 생성, PR merge, 로컬/원격 브랜치 삭제를 진행하지 않습니다.
승인된 커밋·푸시는 대상 파일과 전송할 commit을 검토해 무관 변경을 제외한다.
전체 worktree가 dirty이면 이를 명시하며, 해당 범위의 전송 성공을 전체 브랜치 완료로 표현하지 않는다.

푸시 전 remote와 ahead/behind를 확인하고 승인되지 않은 선행 commit이 함께 전송되지 않게 한다.
푸시 후 remote branch SHA를 확인한다. force push, tag 교체, release 삭제, rollback은
각 동작의 명시 승인 없이 하지 않는다.

버전 minor는 0~9만 사용한다. 현재 개발 버전과 기능 범위는 `ROADMAP.md`에서 확인한다.
다음 버전·브랜치는 사용자가 지정하거나 승인할 때 정하며 자동 생성하지 않는다.

## 7. 릴리즈와 실제 설치

적용 시 `Docs/ReleasePackaging.md`, `Docs/GitHubReleaseChecklist.md`, `Docs/Scripts.md`,
해당 버전 release readiness를 읽는다. “준비”는 공개·설치 승인이 아니다.
push/PR/merge/tag/publish/설치/cleanup은 사용자 요청에 명시된 동작과 대상만 수행한다.
포괄 릴리즈 요청도 별도 보호된 admin bypass, force update, 계정 권한 사용을 자동 승인하지 않는다.

Apple Developer Program, Developer ID 인증서, notarization credential, App Group provisioning,
App Store Connect 권한이 필요한 항목은 현재 구현 계획·완료 조건·후속 이슈에 넣지 않는다.
사용자가 권한 보유와 별도 milestone을 승인한 경우만 예외다. `Stable Release` workflow도
이 조건이 갖춰지기 전 실행하지 않는다.

### 7.1 공개 gate

1. branch/version/build metadata, clean 상태, roadmap, 관련 focused/전체 Swift 테스트와
   앱 변경 시 Xcode build를 확인한다. 문서/CI/미수행 상태를 실제 결과로 기록한다.
2. 승인된 release branch push/PR 이후 필수 check와 review를 확인한다. 실패·충돌·미해결
   review가 있으면 다음 외부 단계를 진행하지 않는다. merge 후 최신 main SHA를 기록한다.
3. 모든 릴리즈 수정이 포함된 최종 release head에 signed annotated tag만 만든다.
   local 서명과 GitHub `Verified`(또는 API `verified=true`, `reason=valid`)를 확인한다.
   key가 없거나 검증되지 않으면 publish·asset 교체·tag 이동을 중단한다.
4. 승인된 Release Candidate 또는 packaging으로 DMG와 sha256을 만들고 checksum 및
   `hdiutil verify`를 확인한다. 실패한 packaging의 stage/잔류 mount를 설치원으로 쓰지 않는다.
5. Draft Release는 기존 signed tag만 사용한다. workflow나 `gh release create`가
   unsigned/lightweight tag를 자동 생성하지 않게 한다. draft 상태, prerelease 여부,
   targetCommitish, 최신 head, `MacDog-<version>.dmg`와 `.dmg.sha256` asset을 대조한다.
6. 승인된 publish 뒤 실제 tag/URL/`isDraft=false`와 공개 asset을 확인하고 다시 다운로드해
   checksum·`hdiutil verify`를 확인한다. 공개와 실제 설치·GUI 완료를 구분한다.

admin bypass는 현재 PR에 대한 명시 승인, clean worktree, CI/필수 check 통과,
`MERGEABLE`, 미해결 conversation/requested changes 없음, self-approval 불가에 의한
`REVIEW_REQUIRED`만 남았음을 모두 확인한 경우에만 허용한다. branch protection을 임시
완화하지 않는다. 우회 사유, 명령, merge SHA, CI 상태를 보고한다.

### 7.2 Finder 설치와 정리

최종 published DMG를 새로 다운로드해 검증한 뒤 Finder에서 그 파일을 직접 연다.
자동 표시된 창의 `MacDog.app`을 `Applications`로 실제 drag-and-drop한 경우만 설치 검수다.
`install.sh`, `cp`, `ditto`, `rsync`, mount 후 복사, 숨김/화면 밖 Finder 조작,
`hdiutil attach -noautoopen` 후 sidebar 접근은 대체 증거가 아니다.

설치 전 read-only source volume, payload version과 executable checksum이 승인된 release
head의 artifact와 일치하는지 확인한다. 오래된 payload는 설치하지 않는다.
축소 screenshot 픽셀을 macOS logical 좌표로 간주하지 말고 source/destination 경로를
확인한다. dialog가 닫힌 것만으로 성공을 판정하지 않는다.

설치 후 `/Applications/MacDog.app`의 version, executable checksum, 수정 시각,
서명 검증, 실행 경로를 source와 대조한다. 이 설치본의 runner/popover/tab/placement,
첫 실행 user component, `~/bin/codex-usage`, 활성 provider LaunchAgent를 확인한다.
승인된 live cache smoke에서는 weekly-only 성공, history append, stale/error를 구분한다.

개발용 `dist/MacDog.app`, 다른 worktree의 dist, Desktop, `/private/tmp/macdog-*` 앱은
실행하거나 설치원으로 쓰지 않는다. 설치 종료 시 실제 앱은 `/Applications/MacDog.app`
하나만 남긴다. 중복 앱은 소유·경로 확인 뒤 LaunchServices unregister하고, 보존 필요 시
`.noindex` 안에 `.app.quarantined`처럼 `.app`으로 끝나지 않는 이름으로 격리한다.

승인된 cleanup은 `cleanup_release_smoke_state.sh --apply` 뒤
`verify_release_final_state.sh --version <version>`으로 확인한다.
`~/Applications`, Desktop, 모든 worktree dist, 작업 임시 경로, mounted volume의
중복 앱과 Finder의 명시적 `응용 프로그램` 검색 결과를 확인한다.
관찰하지 못한 drag/GUI/검색은 미수행으로 남긴다.

브랜치 정리는 clean 상태와 main/origin/main 포함 여부를 확인하고 별도 승인 뒤 수행한다.

```bash
git merge-base --is-ancestor <release-branch> main
git merge-base --is-ancestor origin/<release-branch> origin/main
```

하나라도 실패하면 삭제하지 않는다. 삭제 후 local/remote ref 부재를 확인한다.

## 8. 문서·리뷰·보고

README, ROADMAP, AGENTS 용어와 CLI 이름, window 해석, 실제 UI, 현재 release를 대조한다.
README는 제품·설치·핵심 링크에 집중하고 정책은 이 파일, 계획은 버전 문서, 증거는 해당
검증 기록에 둔다. 동일 목록을 여러 파일에 복제하지 않는다. 새 문서는 독자·목적·유지 주기가
기존 문서와 다를 때 만든다. 과거 release 증거는 현재 정책과 구분해 보존한다.

문서를 삭제·병합·개편하기 전에 링크와 verifier 의존성을 검색한다. 전면 리뷰는 대상 전문을
읽고 권한·완료 기준 충돌, 반복 규칙, 오래된 경로·모델·버전, 정책/계획/로그 혼합을 확인한다.
다른 프로젝트의 명령·기술·시간 기준을 그대로 가져오지 않는다. 발견한 문제와 해결·잔여
항목을 보고하며 목록만 읽고 전수 리뷰라고 하지 않는다.

릴리즈 잔여 이슈 조사에서는 버전/branch → roadmap → 구현 → 검증 증거를 대조해
이슈·우선순위·근거·예상 검증·승인 필요 여부를 제시한다. 직접 규칙, 실제 관측, 제안을
구분하고 필수 미실행을 선택 항목으로 낮추지 않는다.

완료 보고는 변경 내용, 검증과 한계, 미해결 항목, 커밋 hash/메시지와 push 대상/결과를
포함한다. 범위가 작으면 간결히 쓴다. 실패·미실행·미확인·부분 완료를 PASS로 바꾸지 않으며
환경 문제와 제품 회귀를 근거 없이 서로 바꾸지 않는다. 오보고를 발견하면 원래 주장,
실제 결과, 영향과 정정을 즉시 알린다.

`푸시 가능: 예/아니오`, 이유, `푸시 수행 여부`를 구분한다. 전체 worktree의 미커밋
변경이 남으면 전체 기준 푸시 가능은 아니오이며, 승인된 특정 commit의 푸시 성공 여부를
별도로 적는다. 장시간/GUI 미실행은 해당 검증이 필요한 작업에서 사유와 함께 적는다.
후속 이슈는 요청 범위의 실제 잔여 항목만 제시하며 없으면 `후속 이슈: 없음`이다.

## 9. 담당자·모델 운용

메인이 범위·구조·cache/인증/시간 불변 계약·합격 기준과 최종 판정을 맡는다.
위임이 허용된 환경에서는 인계 효과가 있는 확정된 기능 단위에만 단일 서브에이전트를
사용할 수 있다. 메인 외 최대 한 개를 순차 재사용하며 하위 생성·재위임을 금지한다.
소유 파일, 입출력, 금지 경계, 검증과 승인 범위를 전달하고 같은 파일 동시 수정을 피한다.
메인은 실제 diff와 근거를 직접 검토한다. 단순 작업에 위임을 강제하지 않는다.

사용자 모델·추론 설정을 우선한다. 문서나 점수만으로 실행 모델을 변경하거나 변경했다고
보고하지 않는다. Codex와 Grok 패밀리를 구분하고 현재 도구/CLI에서 지원하는 정확한
모델명·추론 수준만 추천한다. Codex 후보는 도구 목록, Grok은 `grok models`와 실제
effort 도움말로 확인한다. 확인할 수 없으면 미확인으로 표시한다.

Codex는 사용자 지정이 없고 실제 지원되는 경우 `gpt-6-astra`/`medium`을 복합 작업 후보로 둔다.
Grok 개발은 확인된 `grok-4.6`, 결정적 반복 작업은 확인된 `grok-4.5`를 후보로 둔다.
이는 프로젝트 선택 기준이며 비용·성능 우위를 보장하지 않는다. Grok에 Codex 별칭을 쓰지 않는다.
기존 v1.8.0 이전 문서의 모델명은 역사적 기록으로 보존한다.

이슈·로드맵에서는 해야 할 일과 합격 기준을 먼저 적고 공통 모델 추천은 한 번만 제시한다.
영향도·불확실성·검증 난이도·변경 범위를 근거로 판단하고, 상세 비교 요청 시 각 0~2점과
합계를 제시한다. 점수를 자동 상향 규칙으로 쓰지 않는다. 일반 출발점은 medium이며
추가 추론이 필요하면 미해소 문제와 시도를 설명한다. 보안·데이터 복구·공용 계약은
반복 작업이라는 이유로 검토 강도를 낮추지 않는다. 실제 지원과 승인 범위는 항상 유지한다.

## 참고

- [MediaServer v4.1.0 개발 방법론](https://github.com/dhseo90/MediaServer/blob/v4.1.0/AGENTS.md)
- [OpenAI: Rethinking skills and prompts for GPT-6 Astra](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra)

참조 문서는 개편 근거이며 MacDog 실행 시 추가 정책으로 중복 적용하지 않는다.
