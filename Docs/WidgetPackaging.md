# WidgetKit Packaging Design

This document records the packaging boundary for the MacDog WidgetKit work.

## Current State

- `Sources/MacDogWidget` contains reusable WidgetKit code for small and medium widgets.
- The widget reads `CodexUsageCacheStore` snapshots and does not call Codex app-server directly.
- The SwiftPM package builds `MacDogWidget` as the reusable widget implementation library.
- `MacDog.xcodeproj` contains a `MacDogWidgetHost` macOS app target and a `MacDogWidgetExtension` app-extension target.
- `Apps/MacDogWidgetExtension` contains the extension entrypoint, Info.plist, and entitlements for the WidgetKit extension target.
- `script/verify_widget_packaging.sh` builds the Xcode host/extension target and verifies `MacDogWidgetHost.app/Contents/PlugIns/MacDogWidgetExtension.appex`.
- `script/verify_widget_readiness.sh` verifies the widget stays on the shared cache path, the menu bar app and CLI mirror writes to the shared cache path, uses the `macdog://open` deep link, keeps empty/stale/error/reset/metadata presentation covered by tests, checks the WidgetKit extension Info.plist and App Group entitlements, and leaves widget gallery/click checks as manual verification.
- `script/write_widget_cache_fixture.sh --self-test` verifies the manual widget cache fixture writer without touching the live cache. Manual UI checks can use the same script with `--shared-cache` to stage `updated`, `stale`, or `error` cache states.
- `script/verify_manual_ui_prerequisites.sh` runs the read-only prerequisite gate before widget gallery/click manual verification and fails by default if the installed app is not the latest `dist/MacDog.app`.
- The install script installs the CLI and `MacDog.app`; the app bundle includes `Contents/PlugIns/MacDogWidgetExtension.appex`.

## Packaging Decision

A real macOS widget ships as a Widget Extension target embedded in an app bundle. The SwiftPM widget library is kept as shared implementation, while `MacDog.xcodeproj` owns the WidgetKit host/extension packaging check.

Proposed bundle layout:

```text
MacDog.app/
  Contents/
    MacOS/MacDog
    PlugIns/
      MacDogWidgetExtension.appex/
        Contents/MacOS/MacDogWidgetExtension
        Contents/Info.plist
```

Proposed identifiers:

```text
Host bundle id:      com.dhseo.macdog.MacDog
Widget extension id: com.dhseo.macdog.MacDog.WidgetExtension
Widget kind:         MacDogStatusWidget
App Group candidate: group.com.dhseo.macdog.MacDog
```

## Data Boundary

The widget must continue to read a shared cache only. It must not start `codex app-server`, read Codex auth files, or perform live usage network work.

For the current CLI and menu bar app, the cache path remains:

```text
~/Library/Application Support/MacDog/usage.json
```

For an embedded Widget Extension, the intended production path is an App Group container so the app, cache writer, and extension can share the same `usage.json` across sandbox boundaries.
The menu bar app now reads the shared cache first and mirrors successful CLI/app cache writes to both the legacy Application Support path and the shared WidgetKit path. If the App Group API is unavailable in a local unsigned build, MacDog uses the stable fallback path:

```text
~/Library/Group Containers/group.com.dhseo.macdog.MacDog/usage.json
```

Shared cache URL hook:

```text
CodexUsageCacheStore.defaultFileURL(appGroupIdentifier:)
```

Implemented status: the helper exists and falls back to the default Application Support path when the App Group container is unavailable. The default non-App-Group path remains for CLI and menu bar personal usage.

## Build Flow

1. Keep `CodexUsageCore` and `MacDogWidget` as SwiftPM modules.
2. Use `Apps/MacDogWidgetExtension/MacDogWidgetExtension.swift` as the Widget Extension entrypoint.
3. Use `MacDog.xcodeproj` to build the `MacDogWidgetHost` app target and `MacDogWidgetExtension` app-extension target.
4. The extension target imports `MacDogWidget`.
5. Verify `MacDogWidgetExtension.appex` in `MacDogWidgetHost.app/Contents/PlugIns`.
6. Copy the verified `.appex` into the SwiftPM-built `MacDog.app/Contents/PlugIns`.
7. Add matching App Group entitlements to the app target, widget extension target, and cache writer path when signed with a Developer Team.

## Verification Plan

- `swift test`
- `script/verify_widget_packaging.sh`
- `xcodebuild -project MacDog.xcodeproj -scheme MacDogWidgetHost -destination 'platform=macOS' -derivedDataPath .build/xcode-widget CODE_SIGNING_ALLOWED=NO build`
- Verify the final host bundle contains `Contents/PlugIns/MacDogWidgetExtension.appex`
- Verify `dist/MacDog.app` contains `Contents/PlugIns/MacDogWidgetExtension.appex`
- Verify the widget extension reads only the shared cache
- Verify `script/verify_widget_readiness.sh`
- Verify `script/write_widget_cache_fixture.sh --self-test`
- Verify stale, empty, error, reset countdown, credits, and last-update states in small and medium widget families
- For manual stale/error checks, stage a fixture with `script/write_widget_cache_fixture.sh --state stale --shared-cache` or `script/write_widget_cache_fixture.sh --state error --shared-cache`, then refresh the widget gallery/widget surface.
- Manually add the widget from the macOS widget gallery after signed distribution packaging is prepared
- Click the widget and confirm `macdog://open` opens the menu bar app popover

## Non-Goals

- Do not add WidgetKit runtime animation.
- Do not make the widget call Codex app-server directly.
- Do not treat the existing SwiftPM widget library as an installed widget by itself.
- Do not add signing, notarization, or LaunchAgent changes as part of the packaging design step.
