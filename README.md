# MacDog

메뉴바에서 Codex/Grok 사용량과 Mac 상태를 보는 macOS 앱입니다. 캐릭터는 `Codex Pup`
한 세트입니다.

`1.9.1`은 설정에서 `Codex`와 `Grok`을 하나 또는 둘 다 켜고 메인을 지정합니다.
합산·비교·자동 fallback은 하지 않습니다.

`1.9.0` 제품의 설정 visible mode는 `Codex`와 `Grok`만 보여 주고 Claude source는 숨깁니다.
published `v1.9.0`은 provider를 하나만 고릅니다.

## 설치

현재 GitHub Release는 [v1.9.1](https://github.com/dhseo90/MacDog/releases/tag/v1.9.1)입니다.
[MacDog-1.9.1.dmg](https://github.com/dhseo90/MacDog/releases/tag/v1.9.1)를 받아 Finder에서
`MacDog.app`을 `Applications`로 드래그한 뒤 실행합니다.

첫 실행이 `~/bin/codex-usage`, 활성 provider LaunchAgent, 로그인 항목을 맞춥니다. 둘 다
켜면 Codex/Grok writer를 함께 두고, 하나만 켜면 해당 writer만 남깁니다.

개발용 `install.sh`나 파일 복사는 사용자 설치 검수가 아닙니다. 서명된 public stable 배포는
Apple Developer Program이 필요하므로 현재 구현 계획에서 제외합니다.

## 화면

v1.9.1 demo snapshot입니다. 값은 환경마다 다릅니다.

<table>
  <tr>
    <th>Codex 사용량</th>
    <th>Grok 사용량</th>
  </tr>
  <tr>
    <td><img src="Docs/Images/README/PopoverTabs/macdog-popover-codex.png" alt="MacDog Codex usage tab" width="360"></td>
    <td><img src="Docs/Images/README/PopoverTabs/macdog-popover-grok.png" alt="MacDog Grok usage tab" width="360"></td>
  </tr>
  <tr>
    <th>활성 자원</th>
    <th>잠들지 않기</th>
  </tr>
  <tr>
    <td><img src="Docs/Images/README/PopoverTabs/macdog-popover-mac.png" alt="MacDog active resources tab" width="360"></td>
    <td><img src="Docs/Images/README/PopoverTabs/macdog-popover-sleep.png" alt="MacDog sleep prevention tab" width="360"></td>
  </tr>
  <tr>
    <th>배터리</th>
    <th>설정</th>
  </tr>
  <tr>
    <td><img src="Docs/Images/README/PopoverTabs/macdog-popover-battery.png" alt="MacDog battery tab" width="360"></td>
    <td><img src="Docs/Images/README/PopoverTabs/macdog-popover-settings.png" alt="MacDog settings tab with provider checkboxes" width="360"></td>
  </tr>
  <tr>
    <th>데스크톱 펫</th>
    <th></th>
  </tr>
  <tr>
    <td align="center"><img src="Docs/Images/README/macdog-desktop-pet-front.png" alt="MacDog desktop pet front sprite" width="160"></td>
    <td></td>
  </tr>
</table>

## 무엇을 보나

| 화면 | 내용 |
| --- | --- |
| 메뉴바 | 메인 provider 사용량으로 러너 속도. 설정이 켜져 있으면 주간 잔여율 `%` |
| 사용량 | 활성 provider 게이지 카드. 메인의 주간 그래프, Codex 초기화권 또는 Grok pace |
| 활성 자원 | CPU, 메모리, 저장, 네트워크 |
| 잠들지 않기 | 끔 / 시간 / 상태 기준 |
| 배터리 | Apple silicon native Charge Limit 80–100% |
| 설정 | Codex/Grok 체크, 메인, 상세 그래프, 메뉴바 `%`, 날짜 기준, 알림, 로그인, 펫 |

Codex 5시간이 있으면 주간 아래에 붙이고, 없으면 숨깁니다. weekly-only는 정상 partial success입니다.
Grok는 SuperGrok / Grok Build 주간 pool만 보고 5시간은 만들지 않습니다.

## CLI

```sh
codex-usage status
codex-usage status --json
codex-usage status --write-cache
codex-usage doctor
macdog-grok-usage status
macdog-grok-usage status --write-cache
```

Codex 원천은 app-server `account/rateLimits/read`입니다. 주간 history는
`usage-weekly-history.json`, 완료 창 축약은 `usage-reset-window-history.json`입니다.

## 개발

```sh
MACDOG_APP_VERSION=1.9.1 ./script/check.sh --no-run
MACDOG_APP_VERSION=1.9.1 ./script/build_and_run.sh
```

명령 전체는 [Docs/Scripts.md](Docs/Scripts.md), 로컬 설치는
[Docs/Onboarding/DevelopmentEnvironment.md](Docs/Onboarding/DevelopmentEnvironment.md)입니다.

## 현재 릴리즈

GitHub Releases Latest: `v1.9.1`. signed tag target
`a9cdfebf82ec822a4cda77dd2a55afb6e703458b`. 이전 공개본은
[v1.9.0](https://github.com/dhseo90/MacDog/releases/tag/v1.9.0)
(`b7072003830798bb1603768c4efb0b41409100f6`)과
[v1.8.0](https://github.com/dhseo90/MacDog/releases/tag/v1.8.0)
(`14d716a88ea10a77344a4f9aa3651c23b1160f8c`)입니다.

증거는 [Docs/V191ReleaseReadiness.md](Docs/V191ReleaseReadiness.md)에 있습니다.
v1.9.1 계약은 [Docs/V191MultiProviderUsage.md](Docs/V191MultiProviderUsage.md)입니다.

## 알림 경계

v1.3.0 알림은 Apple Developer 계정 필요 없이 가능한 UserNotifications 로컬 알림입니다.
기본은 꺼짐이며 설정 탭에서 켜고 macOS 알림 권한을 승인한 뒤에만 발송합니다.
테스트 알림 버튼은 넣지 않습니다. JSON/cache/app-server 계약은 변경하지 않습니다.
Apple Developer 계정이 필요한 기능명은 나열하지 않습니다.

## 문서

| 읽을 것 | 내용 |
| --- | --- |
| [Docs/Onboarding/README.md](Docs/Onboarding/README.md) | 인수인계 시작 |
| [ROADMAP.md](ROADMAP.md) | 계획과 잔여 이슈 |
| [AGENTS.md](AGENTS.md) | 실행 정책, 비밀정보, cache 계약 |
| [Docs/Scripts.md](Docs/Scripts.md) | 스크립트 |
| [Docs/ReleasePackaging.md](Docs/ReleasePackaging.md) | DMG와 릴리즈 흐름 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | PR |

버전 기록: [V191](Docs/V191MultiProviderUsage.md) ·
[V191ReleaseReadiness](Docs/V191ReleaseReadiness.md) ·
[V190](Docs/V190GrokUsageAndClaudeHide.md) ·
[V190ReleaseReadiness](Docs/V190ReleaseReadiness.md) ·
[V180](Docs/V180ClaudeUsageParityPreview.md) ·
[V180ReleaseReadiness](Docs/V180ReleaseReadiness.md) ·
[V170](Docs/V170CodexPro100Transition.md) ·
[V170ReleaseReadiness](Docs/V170ReleaseReadiness.md) ·
[V161](Docs/V161HistoryControlPolish.md) ·
[V161ReleaseReadiness](Docs/V161ReleaseReadiness.md) ·
[V160](Docs/V160CodexRecoveryPlanner.md) ·
[V160ReleaseReadiness](Docs/V160ReleaseReadiness.md) ·
[V150](Docs/V150UsageReliability.md) ·
[V150ReleaseReadiness](Docs/V150ReleaseReadiness.md) ·
[V140](Docs/V140UsageIntelligence.md) ·
[V140ReleaseReadiness](Docs/V140ReleaseReadiness.md) ·
[V130](Docs/V130NotificationAndTabUIPolish.md) ·
[V130ReleaseReadiness](Docs/V130ReleaseReadiness.md)

## 라이선스

Apache License 2.0. [LICENSE](LICENSE).
