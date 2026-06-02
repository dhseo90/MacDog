# WidgetKit 패키징 설계

이 문서는 MacDog WidgetKit 작업의 패키징 경계를 기록합니다. WidgetKit은 현재 구현 코드를 삭제하지 않고 보존하지만, App Group provisioning이 필요한 실제 위젯 UI 검수는 Apple Developer Program이 필요하므로 v1.1.0 구현 계획에서 제외합니다.

## 현재 상태

- `Sources/MacDogWidget`에는 small/medium 위젯에 쓰는 재사용 WidgetKit 코드가 있습니다.
- 위젯은 `CodexUsageCacheStore` snapshot만 읽고 Codex app-server를 직접 호출하지 않습니다.
- SwiftPM package는 `MacDogWidget`을 재사용 위젯 구현 library로 빌드합니다.
- `MacDog.xcodeproj`에는 `MacDogWidgetHost` macOS app target과 `MacDogWidgetExtension` app-extension target이 있습니다.
- `Apps/MacDogWidgetExtension`에는 WidgetKit extension target의 entrypoint, Info.plist, entitlements가 있습니다.
- `script/verify_widget_packaging.sh`는 Xcode host/extension target을 빌드하고 `MacDogWidgetHost.app/Contents/PlugIns/MacDogWidgetExtension.appex`를 확인합니다.
- `script/verify_widget_readiness.sh`는 위젯이 shared cache만 읽는지, 메뉴바 앱이 app-owned cache만 읽는지, `--with-widget` opt-in 경로에서만 cache mirror가 연결되는지, `macdog://open` deep link와 empty/stale/error/reset/metadata 표시가 테스트로 고정되어 있는지 확인합니다.
- `script/write_widget_cache_fixture.sh --self-test`는 live cache를 건드리지 않고 수동 widget fixture writer만 검증합니다. 수동 UI 검수에서는 `--shared-cache`로 `updated`, `stale`, `error` fixture를 staged 상태로 만들 수 있습니다.
- `script/verify_widget_manual_ui_plan.sh`는 WidgetKit 수동 UI 검수 전 read-only prerequisite, fixture dry-run target, 갤러리 추가/클릭/stale/error 확인 순서를 한 번에 출력합니다. `--self-test`는 live cache를 건드리지 않고 계획 문구와 fixture dry-run만 검증합니다.
- `script/verify_manual_ui_prerequisites.sh`는 기본 검수에서 WidgetKit을 건너뜁니다. `--with-widget`을 준 경우에만 widget gallery/click 수동 검수 전 read-only prerequisite gate를 실행하고, 기본적으로 설치본이 최신 `dist/MacDog.app`과 다르면 실패합니다.
- 기본 빌드/설치/DMG는 CLI와 `MacDog.app`만 포함합니다. 앱 번들에는 `Contents/PlugIns/MacDogWidgetExtension.appex`를 넣지 않습니다. `script/build_and_run.sh --with-widget`, `script/install.sh --with-widget`, `script/package_release.sh --with-widget`에서만 opt-in으로 포함합니다.

## 패키징 결정

실제 macOS widget은 opt-in 앱 번들 안에 포함된 Widget Extension target으로 배포합니다. SwiftPM widget library는 공유 구현으로 유지하고, `MacDog.xcodeproj`가 WidgetKit host/extension 패키징 검증을 담당합니다. `v1.1.0` 기본 배포물은 App Group provisioning blocker 때문에 WidgetKit을 포함하지 않습니다. 이 blocker는 현재 구현 계획에서 해결 대상이 아니며, Apple Developer Program 사용 가능 상태가 별도 milestone으로 승인될 때만 다시 다룹니다.

`--with-widget`을 준 경우의 예상 bundle 구조는 다음과 같습니다.

```text
MacDog.app/
  Contents/
    MacOS/MacDog
    PlugIns/
      MacDogWidgetExtension.appex/
        Contents/MacOS/MacDogWidgetExtension
        Contents/Info.plist
```

예상 identifier는 다음과 같습니다.

```text
Host bundle id:      com.dhseo.macdog.MacDog
Widget extension id: com.dhseo.macdog.MacDog.WidgetExtension
Widget kind:         MacDogStatusWidget
App Group candidate: group.com.dhseo.macdog.MacDog
```

## 데이터 경계

위젯은 계속 shared cache만 읽어야 합니다. 위젯이 `codex app-server`를 시작하거나, Codex auth file을 읽거나, live usage network 작업을 수행하면 안 됩니다.

현재 CLI와 메뉴바 앱의 cache 경로는 다음과 같습니다.

```text
~/Library/Application Support/MacDog/usage.json
```

내장 Widget Extension의 production 경로는 App Group container입니다. 이렇게 해야 cache writer와 extension이 sandbox 경계를 넘어 같은 `usage.json`을 공유할 수 있습니다.
메뉴바 앱은 app-owned Application Support cache를 읽습니다. 기본 설치형 LaunchAgent와 앱 내부 live refresh는 `codex-usage status --write-cache`를 실행해 Application Support cache만 갱신합니다. `--with-widget`으로 앱 번들 안에 Widget extension이 있을 때만 `--mirror-cache`를 추가해 WidgetKit shared cache를 함께 갱신합니다. 앱 UI process는 live Codex app-server 접근을 시작하거나 Group Containers fallback을 직접 열지 않습니다. local unsigned build에서 App Group API를 사용할 수 없으면 widget 쪽 shared cache fixture는 다음 fallback 경로를 사용합니다.

```text
~/Library/Group Containers/group.com.dhseo.macdog.MacDog/usage.json
```

Shared cache URL hook은 다음과 같습니다.

```text
CodexUsageCacheStore.defaultFileURL(appGroupIdentifier:)
```

구현 상태: helper는 존재하며 App Group container를 사용할 수 없으면 기본 Application Support 경로로 fallback합니다. 기본 non-App-Group 경로는 CLI와 메뉴바 개인 사용 경로로 유지합니다.

주의: local ad-hoc 서명(`Signature=adhoc`, `TeamIdentifier=not set`)으로는 Widget extension이 App Group container를 실제로 읽지 못할 수 있습니다. 위젯 갤러리에서 shared cache 표시를 완료 증거로 남기려면 code signature entitlements와 embedded provisioning profile 양쪽이 `group.com.dhseo.macdog.MacDog` App Group을 허용하는 development 또는 distribution 서명 설치본을 사용합니다. 현재 설치본의 분류는 `script/verify_widget_app_group_signing.sh --allow-blocked`로 확인합니다.

Apple Developer 문서 기준 capability는 platform, program membership, signing certificate에 따라 provisioning profile에 포함될 수 있는지가 달라집니다. App Groups는 App ID에서 capability를 enable하고 group을 assign한 뒤 해당 App ID를 사용하는 provisioning profile을 다시 생성해야 합니다.

참고:

- <https://developer.apple.com/help/account/reference/supported-capabilities-macos>
- <https://developer.apple.com/help/account/identifiers/enable-app-capabilities>

## 빌드 흐름

1. `CodexUsageCore`와 `MacDogWidget`은 SwiftPM module로 유지합니다.
2. `Apps/MacDogWidgetExtension/MacDogWidgetExtension.swift`를 Widget Extension entrypoint로 사용합니다.
3. `MacDog.xcodeproj`로 `MacDogWidgetHost` app target과 `MacDogWidgetExtension` app-extension target을 빌드합니다.
4. Extension target은 `MacDogWidget`을 import합니다.
5. `MacDogWidgetHost.app/Contents/PlugIns` 안의 `MacDogWidgetExtension.appex`를 검증합니다.
6. `--with-widget` opt-in build에서만 검증된 `.appex`를 SwiftPM으로 빌드한 `MacDog.app/Contents/PlugIns`에 복사합니다. 기본 build는 `Contents/PlugIns/MacDogWidgetExtension.appex`가 없어야 합니다.
7. Developer Team으로 서명할 때 app target, widget extension target, cache writer 경로에 같은 App Group entitlement를 추가하고, embedded provisioning profile에도 같은 App Group grant가 포함됐는지 확인합니다.

## 검증 계획

- `swift test`
- `script/verify_widget_packaging.sh` (optional WidgetKit packaging 확인용)
- `xcodebuild -project MacDog.xcodeproj -scheme MacDogWidgetHost -destination 'platform=macOS' -derivedDataPath .build/xcode-widget CODE_SIGNING_ALLOWED=NO build`
- 최종 host bundle에 `Contents/PlugIns/MacDogWidgetExtension.appex`가 있는지 확인합니다.
- 기본 `dist/MacDog.app`에는 `Contents/PlugIns/MacDogWidgetExtension.appex`가 없는지 확인합니다.
- `script/build_and_run.sh --with-widget`로 만든 opt-in `dist/MacDog.app`에는 `Contents/PlugIns/MacDogWidgetExtension.appex`가 있는지 확인합니다.
- Widget extension이 shared cache만 읽는지 확인합니다.
- `script/verify_widget_readiness.sh`를 실행합니다.
- `script/verify_widget_manual_ui_plan.sh --self-test`를 실행합니다.
- 실제 UI 검수 전 `script/verify_widget_manual_ui_plan.sh`를 실행해 opt-in build prerequisite와 fixture dry-run target을 확인합니다.
- `script/write_widget_cache_fixture.sh --self-test`를 실행합니다.
- small/medium widget family의 stale, empty, error, reset countdown, credits, last-update 상태를 확인합니다.
- 수동 stale/error 검수는 `script/write_widget_cache_fixture.sh --state stale --shared-cache` 또는 `script/write_widget_cache_fixture.sh --state error --shared-cache`로 fixture를 만든 뒤 widget gallery/widget surface를 새로고침합니다.
- App Group provisioning이 적용된 opt-in signed distribution packaging이 준비된 뒤 macOS widget gallery에서 위젯을 직접 추가합니다.
- 위젯을 클릭해 `macdog://open`이 메뉴바 앱 popover를 여는지 확인합니다.

## 수동 UI 검수 체크리스트

자동 검증은 실제 macOS WidgetKit surface를 대신하지 않습니다. 아래 항목은 `--with-widget` opt-in build와 App Group provisioning이 준비된 뒤 직접 화면을 보고 확인했을 때만 완료로 기록합니다.

1. `script/build_and_run.sh --with-widget` 또는 `script/install.sh --with-widget`로 opt-in 위젯 빌드를 준비합니다.
2. `script/verify_widget_manual_ui_plan.sh`를 실행해 read-only prerequisite가 통과하는지 확인합니다.
3. macOS widget gallery에서 `MacDogStatusWidget` small/medium 위젯을 추가합니다.
4. 위젯을 클릭해 `macdog://open` deep link가 MacDog popover를 여는지 확인합니다.
5. `script/write_widget_cache_fixture.sh --state updated --shared-cache`를 실행하고 위젯의 `갱신됨` 상태를 확인합니다.
6. `script/write_widget_cache_fixture.sh --state stale --shared-cache`를 실행하고 위젯의 `오래된 캐시` 상태를 확인합니다.
7. `script/write_widget_cache_fixture.sh --state error --shared-cache`를 실행하고 위젯의 `오류: manual widget fixture error` 상태를 확인합니다.
8. 확인 결과에는 small/medium family, deep link 결과, 각 fixture 상태별 실제 표시 문구, 미확인 항목을 분리해 남깁니다.

## 검증 경계

확인됨:

- `Sources/MacDogWidget`의 small/medium presentation code와 empty/stale/error/reset/metadata copy는 `MacDogWidgetPresentationTests`로 자동 검증합니다.
- 위젯 source가 Codex app-server, auth file, live usage network 작업을 직접 수행하지 않는 경계는 `script/verify_widget_readiness.sh`로 확인합니다.
- Xcode host/extension target이 `.appex`를 만들 수 있는지는 `script/verify_widget_packaging.sh`로 확인할 수 있습니다.
- 기본 `MacDog.app` build에서는 WidgetKit extension을 제외하고, opt-in build에서만 `--mirror-cache`를 연결하도록 scripts/tests를 갱신했습니다.
- 2026-05-31에 macOS widget gallery에서 MacDog category와 `MacDogStatusWidget` small/medium preview는 확인했습니다.

미확인/제외:

- 기본 `v1.1.0` DMG와 기본 설치 경로에서는 WidgetKit을 설치하지 않습니다.
- 여기까지 확인된 뒤 실제 위젯 UI 단계는 확인하지 못했습니다.
- 실제 위젯 UI가 shared cache의 updated/stale/error fixture를 읽어 표시하는지는 아직 완료로 볼 수 없습니다.
- 위젯 클릭이 `macdog://open`으로 MacDog popover를 여는 실제 UI 동작은 아직 완료로 볼 수 없습니다.
- 2026-05-31에 small widget이 3개 추가된 현상은 더블클릭 확인 입력이 섞여 단일 클릭 중복 추가 제품 이슈로 확정하지 않았습니다.
- Personal Team build에서는 Widget extension code signature에 App Group entitlement가 보여도 embedded provisioning profile에 `com.apple.security.application-groups` grant가 없어 shared cache UI 검수를 완료할 수 없었습니다.

## 하지 않는 것

- WidgetKit runtime animation은 추가하지 않습니다.
- 위젯이 Codex app-server를 직접 호출하게 만들지 않습니다.
- 기존 SwiftPM widget library만으로 설치된 widget이라고 표현하지 않습니다.
- 이 패키징 설계 단계에서 signing, notarization, LaunchAgent 변경을 추가하지 않습니다.
