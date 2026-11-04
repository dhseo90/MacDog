# v1.9.4 Claude 조회와 Grok 주간 잔여

상태: Grok 조회·표시 수정 완료. Claude 게이지 조회는 fixture로 구현했다.
작성일: 2026-11-02
Grok 수정일: 2026-11-02
Claude 조회 구현일: 2026-11-03
대상 버전: `1.9.4`
기준 브랜치: `v1.9.4`
기준 head: `main` `fa2d317`
개발 검증 버전: `MACDOG_APP_VERSION=1.9.4`

버전 정책: minor 구간은 `0~9`까지만 사용한다. 직전 공개 릴리즈는 `v1.9.3`이다.
이 버전의 공개 순서는 [V194ReleaseReadiness.md](V194ReleaseReadiness.md)에 둔다.

## 목표

1. Claude 잔여량 조회를 Codex, Grok과 같은 게이지 분기에 넣는다.
2. Grok 주간 잔여가 다시 비는 원인을 고친다. 마지막 숫자를 억지로 남기는 것으로
   끝내지 않는다.

공통 게이지, 주간 그래프, 메뉴바 잔여율, 러너, 알림은 그대로 둔다.
provider마다 다른 것은 잔여량을 읽는 경로와, 그 값을 주간·5시간 행으로
바꾸는 조회다.

## 확인한 Grok 상태

2026-11-02 21:33 로컬 기준이다. 새 billing 요청은 보내지 않았고, auth 원문과
billing 원문은 열지 않았다.

- cache는 사용 1%, 잔여 99%, reset `2026-11-07 11:50:03`, `issue` 없음,
  조회 시각은 그 시점으로부터 약 19초 전이었다.
- LaunchAgent 로그는 60초마다 한 줄이다. 그 성공 직전까지
  `weekly-window-missing`이 3441회, 약 57시간 이어졌다. 그 줄은 직전 성공인
  주간 2%를 계속 출력했다.
- 같은 로그는 성공 구간과 이 실패 구간이 수 시간에서 수 일 단위로 번갈아
  나타난다. 한 번의 일시 오류가 아니다.
- `recordFailure`는 마지막 `weekly`를 지우지 않고 `issue`만 올린다.
- `freshWeekly`는 `issue`가 있거나, 180초를 넘었거나, `resetsAt`이 지났으면
  `nil`이다. 게이지, Grok 패널, 메뉴바 `%`, 러너, 알림이 이 값을 본다.
  그래서 57시간 동안 cache에 2%가 있어도 화면의 잔여율은 비었다.

수정 전 거절 코드 `weekly-window-missing`은 서로 다른 세 결과를 한 문자열로 저장했다.

| 실제 조건 | 코드 |
| --- | --- |
| `billingCycle` 또는 `currentPeriod.type`에 `month`가 있음 | `weekly-window-missing` |
| `creditUsagePercent`가 없음 | `weekly-window-missing` |
| 사용률이 0~100 밖 | `weekly-window-missing` (`invalidUsagePercent`) |

실패한 응답 원문은 저장하지 않는다. 이번 57시간이 셋 중 무엇이었는지는
cache와 로그만으로 확정하지 못한다.

Grok CLI 1.0.70의 billing 구조는 `creditUsagePercent`, `currentPeriod`,
`monthlyLimit`을 같은 config에 둔다. 수정 전 sanitizer는 그 config에 월간
표식이 있으면 percent가 있어도 주간 window를 버렸다. 21:33의 성공 응답은
이 거절에 걸리지 않았다.

## Grok 수정

원인은 두 층이다. 둘 다 이 브랜치에 반영했다.

1. 조회. `creditUsagePercent`가 0~100이면 그 값을 주간 사용률로 저장한다.
   같은 객체에 월간 표식, `monthlyLimit`, prepaid, on-demand가 있어도
   percent를 버리지 않는다. 월간 한도나 선불 잔액으로 주간 잔여율을
   계산하지 않는다. percent가 없으면 `weekly-window-missing`이다.
   0~100 밖은 `invalid-usage-percent`다. `billingPeriodStart + 7일`로
   `resetsAt`을 만들지 않는다. 원문 응답, token, auth는 저장하지 않는다.
2. 표시. `recordFailure`가 남긴 마지막 `weekly`는 `issue`가 있어도
   게이지와 Grok 패널에 남긴다. `weekly-window-missing`이고 저장된
   주간이 있으면 상태 문구는 `주간 갱신 실패`다. 저장된 주간이 없으면
   `주간 window 없음`이다. 러너, 메뉴바 `%`, 알림은 `freshWeekly`만
   사용한다. issue 없이 180초를 넘기거나 `resetsAt`이 지난 cache는
   계속 숨긴다.

1번은 v1.9.0의 “월간 cycle이면 percent가 있어도 거절” 규칙을 좁힌다.
월간만 있고 주간 percent가 없는 응답은 계속 거절한다.

57시간 구간의 billing 원문은 없다. 그 응답이 월간 표식 때문이었는지는
확정하지 못했다. 고친 것은 percent를 월간 이웃 필드와 함께 버리는 경로와,
거절 중에 남은 주간 잔여를 게이지에서 숨기는 경로다.

## Claude 조회

v1.8.0의 status line 수집, sanitizer, `claude-usage.json`, history,
`macdog-claude-statusline`을 쓴다. 새 폴링과 새 auth 읽기는 만들지 않는다.

| 원천 | 게이지 |
| --- | --- |
| `seven_day` 10080분, `used_percentage`, `resets_at` | 주간. 잔여율은 `100 - usedPercent` |
| `five_hour` 300분 | 메인일 때만 5시간 행 |
| 없는 창 | 숨기거나 미제공. 0이나 다른 provider 값으로 채우지 않음 |
| `context_window` | quota에 넣지 않음 |

수집은 Claude Code가 status line으로 bridge를 부를 때만 일어난다.
LaunchAgent를 추가하지 않는다. 앱은 Claude 설정, auth, Keychain,
transcript를 읽거나 쓰지 않는다. reset credit 행은 만들지 않는다.

선택:

- `UsageProviderMask`에 Claude 비트를 두고 visible 집합에 포함한다.
- 설정 체크는 기본 꺼짐이다. 기존 Codex, Grok 선택은 유지한다.
- 저장된 `claude` mode에 Claude 비트가 없으면 그 mode를 해제하고 기존
  Codex, Grok 마스크를 유지한다. 마스크가 없으면 Codex다. 비트가 이미 있으면
  매 실행 migration이 그 선택을 지우지 않는다. 숨김
  `claudeUsageProviderReenabled`만으로 Claude를 켜지 않는다.
- 메인, 러너, 메뉴바 `%`, 알림, 상세 그래프는 지금과 같이 메인 provider만
  따른다. 메뉴바 `%`는 메인 주간 잔여만 쓰고, Claude 메인의 주간은
  `seven_day`다.
- 상세 주간 그래프는 Grok과 같은 방식의 history 변환으로 공통 그래프에
  넣는다. 예전 `ClaudeUsagePreviewPanel`로 화면을 바꾸지 않는다.
- cache가 없으면 게이지에 연결 대기와 기존 bridge 명령을 보인다.

provider 사용률은 합산하지 않고, 실패한 provider를 다른 cache로 바꾸지
않는다.

## 순서

앞 단계가 실패하면 뒤 단계를 시작하지 않는다.

| Step | 제목 | 상태 | 완료 조건 |
| ---: | --- | --- | --- |
| 1 | 주간 percent 채택 | 완료 | 유효 `creditUsagePercent`는 월간 이웃 필드와 함께 있어도 저장한다. percent가 없으면 `weekly-window-missing`이다. 범위 밖은 `invalid-usage-percent`다. 합성 reset은 없다 |
| 2 | 마지막 잔여 표시 | 완료 | 거절 중 게이지와 Grok 패널은 마지막 성공 잔여를 유지한다. 러너, 메뉴바 `%`, 알림은 fresh가 아니면 멈추고 다른 provider로 가지 않는다 |
| 3 | Claude 선택 | 완료 | 기본 꺼짐. 기존 Codex, Grok 선택은 유지된다. 숨김 재활성화만으로 Claude가 켜지지 않는다 |
| 4 | Claude 게이지 | 완료 | `seven_day`만 주간 행이다. 없는 5시간은 만들지 않고, 메인이 아니면 5시간 행을 숨긴다 |
| 5 | Claude 주간 그래프 | 완료 | 5시간 history는 주간 그래프에 들어가지 않는다. 상세는 `ClaudeUsagePanel`이다 |
| 6 | 검증 | 완료 | 아래 명령을 통과했다. live `rate_limits`, billing 원문, GUI, 설치는 미수행 |

## 검증

Grok 수정 확인. 2026-11-02 22:01 로컬. exit 0.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test \
  --filter GrokBillingSanitizerTests \
  --filter GrokUsageCacheTests \
  --filter CombinedUsageGaugesTests \
  --filter MenuBarWeeklyRemainingLabelTests \
  --filter GrokUsageNotificationPolicyTests \
  --filter UsageMonitorStateTests
```

MacDogTests 120 passed. 그중 CombinedUsageGaugesTests 14,
GrokUsageNotificationPolicyTests 4, MenuBarWeeklyRemainingLabelTests 17,
UsageMonitorStateTests 85.
CodexUsageCoreTests 17 passed. 그중 GrokBillingSanitizerTests 8,
GrokUsageCacheTests 9.

같은 시각의 전체 `swift test`는 exit 1이다. MacDogTests 370 중 assertion
실패 5건은 `PopoverScreenshotRendererTests`의 주간 그래프 `NSPopUpButton`
4개 테스트다. 같은 테스트는 수정 전 `fa2d317`에서도 실패했다. 이 변경이
만든 실패가 아니다. CodexUsageCoreTests 228 passed, 1 skipped.
PrivilegedHelper 테스트는 실패가 없었다.

Debug 빌드는 2026-11-02 22:02 로컬에서 exit 0, `BUILD SUCCEEDED`다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build \
  -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Claude 선택·게이지·주간 그래프와 주간 window popup 수정 확인.
2026-11-03 08:06 로컬. 전체 `swift test` exit 0.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift test
```

MacDogTests 376 executed, 3 skipped, 0 failures.
MacDogPrivilegedHelperSupportTests 29 executed, 0 failures.
CodexUsageCoreTests 228 executed, 1 skipped, 0 failures.

지난 window 메뉴는 `NSPopUpButton`이다. 2026-11-02에 실패했던
`PopoverScreenshotRendererTests` 4개는 이 실행에서 통과했다.

같은 시각 Debug 빌드는 exit 0, `BUILD SUCCEEDED`다. DVTCoreDeviceCore
symbol 경고와 CoreSimulator 버전 경고는 나왔고 빌드 결과는 성공이다.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild build \
  -project MacDog.xcodeproj -scheme MacDog -configuration Debug CODE_SIGNING_ALLOWED=NO
```

`git diff --check`와 `npx --yes markdownlint-cli2@0.22.1`은 exit 0이다.
`verify_v193_codex_remaining_credits_contract.sh --self-test --skip-tests`와
v1.9.0부터 v1.9.2 계약 verifier의 `--skip-tests`도 exit 0이다.

테스트 계정이 없어 Claude `rate_limits` live event는 2026-11-04 사용자 결정으로
닫았다. 57시간 Grok billing 원문은 저장되지 않아 분류하지 않았다.

2026-11-04 로컬 DMG `dist/release/MacDog-1.9.4.dmg`를 Finder에서 열고 사용자가
`MacDog.app`을 `Applications`로 드래그했다. 설치본 실행 파일 4개, 아이콘, 권한
도우미 checksum이 그 DMG와 같았다. 이것은 공개 GitHub DMG 설치가 아니다.

설치 전 임시 바이너리의 사용량 화면에서 Codex 주간 `100% 사용 0% 남음`, Grok 주간
`17% 사용 83% 남음`, Claude 체크 꺼짐을 읽었다. 거절 중 마지막 주간 유지, Claude를
메인으로 둔 화면, 메뉴바 `%` 글자, 설치 직후 팝오버는 확인하지 않았다.

## 제외

- provider 합산, 비교 그래프, 자동 fallback
- Claude auth, Keychain, transcript, 설정 파일 변경
- Claude 주기 조회 LaunchAgent
- Grok 5시간 합성, Extra Usage Credits, prepaid를 주간 잔여로 표시
- billing 원문, token, auth 원문을 cache, log, fixture, 문서에 저장
- 개발 중에는 publish, tag, 설치, LaunchAgent 실등록을 하지 않았다. 공개 순서는
  [V194ReleaseReadiness.md](V194ReleaseReadiness.md)를 따른다
- Claude live `rate_limits` event. 구현은 fixture만 사용하고 계정 조회는 하지 않는다

## 모델

추천 모델: `grok-4.6`
추론 수준: 매우 높음 (xhigh)
선정 근거: 영향도 2 + 불확실성 2 + 검증 난이도 2 + 변경 범위 2 = 8점.
Grok 거절 이유가 저장되지 않은 응답에 있고, Claude를 활성 집합에 넣는
변경이 게이지와 선택 migration에 겹친다.
