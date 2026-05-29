# WidgetKit 패키징 설계

이 문서는 MacDog WidgetKit 작업의 패키징 경계를 기록합니다.

## 현재 상태

- `Sources/MacDogWidget`에는 small/medium 위젯에 쓰는 재사용 WidgetKit 코드가 있습니다.
- 위젯은 `CodexUsageCacheStore` snapshot만 읽고 Codex app-server를 직접 호출하지 않습니다.
- SwiftPM package는 `MacDogWidget`을 재사용 위젯 구현 library로 빌드합니다.
- `MacDog.xcodeproj`에는 `MacDogWidgetHost` macOS app target과 `MacDogWidgetExtension` app-extension target이 있습니다.
- `Apps/MacDogWidgetExtension`에는 WidgetKit extension target의 entrypoint, Info.plist, entitlements가 있습니다.
- `script/verify_widget_packaging.sh`는 Xcode host/extension target을 빌드하고 `MacDogWidgetHost.app/Contents/PlugIns/MacDogWidgetExtension.appex`를 확인합니다.
- `script/verify_widget_readiness.sh`는 위젯이 shared cache만 읽는지, 메뉴바 앱이 app-owned cache만 읽는지, CLI가 두 cache 경로에 쓰기를 mirror하는지, `macdog://open` deep link와 empty/stale/error/reset/metadata 표시가 테스트로 고정되어 있는지 확인합니다. 위젯 갤러리 추가와 클릭 검수는 수동 검증으로 남깁니다.
- `script/write_widget_cache_fixture.sh --self-test`는 live cache를 건드리지 않고 수동 widget fixture writer만 검증합니다. 수동 UI 검수에서는 `--shared-cache`로 `updated`, `stale`, `error` fixture를 staged 상태로 만들 수 있습니다.
- `script/verify_manual_ui_prerequisites.sh`는 widget gallery/click 수동 검수 전에 read-only prerequisite gate를 실행하고, 기본적으로 설치본이 최신 `dist/MacDog.app`과 다르면 실패합니다.
- 설치 스크립트는 CLI와 `MacDog.app`을 설치합니다. 앱 번들에는 `Contents/PlugIns/MacDogWidgetExtension.appex`가 포함됩니다.

## 패키징 결정

실제 macOS widget은 앱 번들 안에 포함된 Widget Extension target으로 배포합니다. SwiftPM widget library는 공유 구현으로 유지하고, `MacDog.xcodeproj`가 WidgetKit host/extension 패키징 검증을 담당합니다.

예상 bundle 구조는 다음과 같습니다.

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
메뉴바 앱은 app-owned Application Support cache를 읽습니다. CLI/cache writer는 성공한 write를 legacy Application Support 경로와 shared WidgetKit 경로에 함께 mirror하고, 앱 UI process는 live Codex app-server 접근을 시작하거나 Group Containers fallback을 직접 열지 않습니다. local unsigned build에서 App Group API를 사용할 수 없으면 widget 쪽 shared cache는 다음 fallback 경로를 사용합니다.

```text
~/Library/Group Containers/group.com.dhseo.macdog.MacDog/usage.json
```

Shared cache URL hook은 다음과 같습니다.

```text
CodexUsageCacheStore.defaultFileURL(appGroupIdentifier:)
```

구현 상태: helper는 존재하며 App Group container를 사용할 수 없으면 기본 Application Support 경로로 fallback합니다. 기본 non-App-Group 경로는 CLI와 메뉴바 개인 사용 경로로 유지합니다.

## 빌드 흐름

1. `CodexUsageCore`와 `MacDogWidget`은 SwiftPM module로 유지합니다.
2. `Apps/MacDogWidgetExtension/MacDogWidgetExtension.swift`를 Widget Extension entrypoint로 사용합니다.
3. `MacDog.xcodeproj`로 `MacDogWidgetHost` app target과 `MacDogWidgetExtension` app-extension target을 빌드합니다.
4. Extension target은 `MacDogWidget`을 import합니다.
5. `MacDogWidgetHost.app/Contents/PlugIns` 안의 `MacDogWidgetExtension.appex`를 검증합니다.
6. 검증된 `.appex`를 SwiftPM으로 빌드한 `MacDog.app/Contents/PlugIns`에 복사합니다.
7. Developer Team으로 서명할 때 app target, widget extension target, cache writer 경로에 같은 App Group entitlement를 추가합니다.

## 검증 계획

- `swift test`
- `script/verify_widget_packaging.sh`
- `xcodebuild -project MacDog.xcodeproj -scheme MacDogWidgetHost -destination 'platform=macOS' -derivedDataPath .build/xcode-widget CODE_SIGNING_ALLOWED=NO build`
- 최종 host bundle에 `Contents/PlugIns/MacDogWidgetExtension.appex`가 있는지 확인합니다.
- `dist/MacDog.app`에 `Contents/PlugIns/MacDogWidgetExtension.appex`가 있는지 확인합니다.
- Widget extension이 shared cache만 읽는지 확인합니다.
- `script/verify_widget_readiness.sh`를 실행합니다.
- `script/write_widget_cache_fixture.sh --self-test`를 실행합니다.
- small/medium widget family의 stale, empty, error, reset countdown, credits, last-update 상태를 확인합니다.
- 수동 stale/error 검수는 `script/write_widget_cache_fixture.sh --state stale --shared-cache` 또는 `script/write_widget_cache_fixture.sh --state error --shared-cache`로 fixture를 만든 뒤 widget gallery/widget surface를 새로고침합니다.
- signed distribution packaging이 준비된 뒤 macOS widget gallery에서 위젯을 직접 추가합니다.
- 위젯을 클릭해 `macdog://open`이 메뉴바 앱 popover를 여는지 확인합니다.

## 하지 않는 것

- WidgetKit runtime animation은 추가하지 않습니다.
- 위젯이 Codex app-server를 직접 호출하게 만들지 않습니다.
- 기존 SwiftPM widget library만으로 설치된 widget이라고 표현하지 않습니다.
- 이 패키징 설계 단계에서 signing, notarization, LaunchAgent 변경을 추가하지 않습니다.
