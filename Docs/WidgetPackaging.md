# WidgetKit Packaging Design

This document records the packaging boundary for the Codex Usage Monitor WidgetKit work.

## Current State

- `Sources/CodexUsageWidget` contains reusable WidgetKit code for small and medium widgets.
- The widget reads `CodexUsageCacheStore` snapshots and does not call Codex app-server directly.
- The SwiftPM package builds `CodexUsageWidget` as a library only.
- The install script currently installs the CLI and menu bar app only. It does not build or install a `.appex` widget bundle.

## Packaging Decision

A real macOS widget must ship as a Widget Extension target embedded in an app bundle. The SwiftPM widget library is kept as shared implementation, but distribution needs an Xcode app target and a Widget Extension target.

Proposed bundle layout:

```text
CodexUsageMonitor.app/
  Contents/
    MacOS/CodexUsageMonitor
    PlugIns/
      CodexUsageWidgetExtension.appex/
        Contents/MacOS/CodexUsageWidgetExtension
        Contents/Info.plist
```

Proposed identifiers:

```text
App bundle id:       com.dhseo.mycodex.CodexUsageMonitor
Widget extension id: com.dhseo.mycodex.CodexUsageMonitor.WidgetExtension
Widget kind:         CodexUsageStatusWidget
App Group candidate: group.com.dhseo.mycodex.CodexUsageMonitor
```

## Data Boundary

The widget must continue to read a shared cache only. It must not start `codex app-server`, read Codex auth files, or perform live usage network work.

For the current CLI and menu bar app, the cache path remains:

```text
~/Library/Application Support/CodexUsageMonitor/usage.json
```

For an embedded Widget Extension, the intended production path is an App Group container so the app, cache writer, and extension can share the same `usage.json` across sandbox boundaries.

Shared cache URL hook:

```text
CodexUsageCacheStore.defaultFileURL(appGroupIdentifier:)
```

Implemented status: the helper exists and falls back to the default Application Support path when the App Group container is unavailable. The default non-App-Group path remains for CLI and menu bar personal usage.

## Build Flow

1. Keep `CodexUsageCore` and `CodexUsageWidget` as SwiftPM modules.
2. Add an Xcode macOS app target for the menu bar app.
3. Add a macOS Widget Extension target that imports `CodexUsageWidget`.
4. Embed `CodexUsageWidgetExtension.appex` into `CodexUsageMonitor.app/Contents/PlugIns`.
5. Add matching App Group entitlements to the app target, widget extension target, and cache writer path when signed with a Developer Team.
6. Keep ad-hoc personal install scripts on the menu bar app path until the Xcode widget target is present.

## Verification Plan

- `swift test`
- `xcodebuild build` for the app target and widget extension target
- Verify the final app bundle contains `Contents/PlugIns/CodexUsageWidgetExtension.appex`
- Verify the widget extension reads only the shared cache
- Verify stale, empty, and error cache states in small and medium widget families
- Manually add the widget from the macOS widget gallery
- Click the widget and confirm `codexusage://open` opens the menu bar app popover

## Non-Goals

- Do not add WidgetKit runtime animation.
- Do not make the widget call Codex app-server directly.
- Do not treat the existing SwiftPM widget library as an installed widget by itself.
- Do not add signing, notarization, or LaunchAgent changes as part of the packaging design step.
