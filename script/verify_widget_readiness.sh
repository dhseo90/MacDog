#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIDGET_SOURCE="$ROOT_DIR/Sources/MacDogWidget/MacDogWidget.swift"
WIDGET_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/MacDogWidgetPresentationTests.swift"
MENU_BAR_CONTROLLER="$ROOT_DIR/Sources/MacDog/MenuBarController.swift"
CLI_SOURCE="$ROOT_DIR/Sources/CodexUsageCLI/main.swift"
CACHE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageCache.swift"
APP_MAIN="$ROOT_DIR/Sources/MacDog/MacDogMain.swift"
WIDGET_FIXTURE_WRITER="$ROOT_DIR/script/write_widget_cache_fixture.sh"
WIDGET_EXTENSION_INFO="$ROOT_DIR/Apps/MacDogWidgetExtension/Info.plist"
WIDGET_EXTENSION_ENTITLEMENTS="$ROOT_DIR/Apps/MacDogWidgetExtension/MacDogWidgetExtension.entitlements"
WIDGET_HOST_ENTITLEMENTS="$ROOT_DIR/Apps/MacDogWidgetHost/MacDogWidgetHost.entitlements"
APP_BUNDLE="$ROOT_DIR/dist/MacDog.app"
APP_INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
WIDGET_APPEX="$APP_BUNDLE/Contents/PlugIns/MacDogWidgetExtension.appex"
WIDGET_APPEX_INFO_PLIST="$WIDGET_APPEX/Contents/Info.plist"
VERIFY_APP_BUNDLE="$ROOT_DIR/script/verify_app_bundle.sh"
WIDGET_PACKAGING_DOC="$ROOT_DIR/Docs/WidgetPackaging.md"

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

require_text_match() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if command -v rg >/dev/null 2>&1; then
    rg -q -- "$pattern" "$file" || die "missing WidgetKit readiness guard: $description"
  else
    /usr/bin/grep -Eq -- "$pattern" "$file" || die "missing WidgetKit readiness guard: $description"
  fi
}

reject_text_match() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if command -v rg >/dev/null 2>&1; then
    if rg -q -- "$pattern" "$file"; then
      die "forbidden WidgetKit dependency found: $description"
    fi
  elif /usr/bin/grep -Eq -- "$pattern" "$file"; then
    die "forbidden WidgetKit dependency found: $description"
  fi
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print $1" "$2"
}

require_plist_value() {
  local key="$1"
  local file="$2"
  local expected="$3"
  local description="$4"
  local actual
  actual="$(plist_value "$key" "$file")" || die "missing WidgetKit plist key: $description"
  [[ "$actual" == "$expected" ]] || die "unexpected WidgetKit plist value for $description: expected $expected, got $actual"
}

require_file "$WIDGET_SOURCE"
require_file "$WIDGET_TESTS"
require_file "$MENU_BAR_CONTROLLER"
require_file "$CLI_SOURCE"
require_file "$CACHE_SOURCE"
require_file "$APP_MAIN"
require_file "$WIDGET_FIXTURE_WRITER"
require_file "$WIDGET_EXTENSION_INFO"
require_file "$WIDGET_EXTENSION_ENTITLEMENTS"
require_file "$WIDGET_HOST_ENTITLEMENTS"
require_file "$VERIFY_APP_BUNDLE"
require_file "$WIDGET_PACKAGING_DOC"

require_text_match 'MacDogWidgetDeepLink' "$WIDGET_SOURCE" "widget deep link is centralized"
require_text_match 'macdog://open' "$WIDGET_SOURCE" "widget opens the MacDog URL scheme"
require_text_match '\.widgetURL\(MacDogWidgetDeepLink\.openURL\)' "$WIDGET_SOURCE" "widget uses the shared deep-link constant"
require_text_match '\.supportedFamilies' "$WIDGET_SOURCE" "widget declares supported families"
require_text_match '\.systemSmall' "$WIDGET_SOURCE" "small widget family is supported"
require_text_match '\.systemMedium' "$WIDGET_SOURCE" "medium widget family is supported"
require_text_match 'CodexUsageCacheStore\.defaultFileURL\(appGroupIdentifier:' "$WIDGET_SOURCE" "widget reads the shared cache URL"
require_text_match 'defaultSharedFileURL' "$CACHE_SOURCE" "core exposes the widget shared cache URL"
require_text_match 'defaultMirroredFileURLs' "$CACHE_SOURCE" "core exposes mirrored cache writer URLs"
require_text_match 'CodexUsageCacheStore\.defaultFileURL\(\)' "$MENU_BAR_CONTROLLER" "menu bar app reads the app-owned cache"
reject_text_match 'CodexUsageCacheStore\.defaultSharedFileURL\(\)|CodexUsageCacheStore\.defaultFileURL\(appGroupIdentifier:|CodexUsageCacheStore\.defaultMirroredFileURLs\(\)|CodexAppServerClient|CodexUsageService|account/rateLimits/read|codex app-server' "$MENU_BAR_CONTROLLER" "menu bar app must stay on app-owned cache for Codex usage"
require_text_match 'CodexUsageCacheStore\.defaultMirroredFileURLs\(\)' "$CLI_SOURCE" "CLI cache writer mirrors default and shared caches"
require_text_match '--state updated\|stale\|error' "$WIDGET_FIXTURE_WRITER" "manual fixture writer supports widget state fixtures"
require_text_match '--self-test' "$WIDGET_FIXTURE_WRITER" "manual fixture writer has a non-mutating self-test"
require_text_match 'manual widget fixture error' "$WIDGET_FIXTURE_WRITER" "manual fixture writer can reproduce widget error UI"
require_text_match 'statusText = "캐시 없음"' "$WIDGET_SOURCE" "empty cache state is presented"
require_text_match 'statusText = snapshot\.isStale' "$WIDGET_SOURCE" "stale cache state is presented"
require_text_match 'statusText = "오류:' "$WIDGET_SOURCE" "error cache state is presented"
require_text_match 'let resetText: String' "$WIDGET_SOURCE" "widget presentation tracks reset timing"
require_text_match '초기화까지' "$WIDGET_SOURCE" "widget displays reset countdown copy"
require_text_match 'let metadataText: String' "$WIDGET_SOURCE" "widget presentation tracks medium metadata"
require_text_match '크레딧' "$WIDGET_SOURCE" "widget displays credits metadata"
require_text_match '갱신' "$WIDGET_SOURCE" "widget displays last update metadata"

reject_text_match 'CodexAppServerClient|account/rateLimits/read|auth\.json|codex app-server' "$WIDGET_SOURCE" "widget must not perform live Codex auth or app-server work"

require_text_match 'MacDogWidgetDeepLink\.openURL\.absoluteString' "$WIDGET_TESTS" "deep-link URL is covered by tests"
require_text_match '캐시 없음' "$WIDGET_TESTS" "empty cache widget state is covered by tests"
require_text_match '오래된 캐시' "$WIDGET_TESTS" "stale widget state is covered by tests"
require_text_match '오류:' "$WIDGET_TESTS" "error widget state is covered by tests"
require_text_match 'resetText' "$WIDGET_TESTS" "reset timing is covered by tests"
require_text_match '초기화까지' "$WIDGET_TESTS" "reset countdown copy is covered by tests"
require_text_match 'metadataText' "$WIDGET_TESTS" "medium metadata is covered by tests"
require_text_match '크레딧' "$WIDGET_TESTS" "credits metadata copy is covered by tests"
require_text_match '갱신' "$WIDGET_TESTS" "last update metadata copy is covered by tests"

require_text_match 'application\(_ application: NSApplication, open urls: \[URL\]\)' "$APP_MAIN" "menu bar app handles URL opens"
require_text_match '"macdog", "codexusage"' "$APP_MAIN" "menu bar app accepts macdog and compatibility URL schemes"
require_text_match ':CFBundleURLTypes:0:CFBundleURLSchemes:0' "$VERIFY_APP_BUNDLE" "app bundle verifier checks macdog URL scheme"
require_text_match 'MacDogWidgetExtension\.appex' "$VERIFY_APP_BUNDLE" "app bundle verifier checks embedded widget extension"

require_plist_value ':CFBundleIdentifier' "$WIDGET_EXTENSION_INFO" 'com.dhseo.macdog.MacDog.WidgetExtension' "widget extension bundle id"
require_plist_value ':CFBundlePackageType' "$WIDGET_EXTENSION_INFO" 'XPC!' "widget extension package type"
require_plist_value ':NSExtension:NSExtensionPointIdentifier' "$WIDGET_EXTENSION_INFO" 'com.apple.widgetkit-extension' "WidgetKit extension point"
require_plist_value ':com.apple.security.app-sandbox' "$WIDGET_EXTENSION_ENTITLEMENTS" 'true' "widget extension sandbox entitlement"
require_plist_value ':com.apple.security.application-groups:0' "$WIDGET_EXTENSION_ENTITLEMENTS" 'group.com.dhseo.macdog.MacDog' "widget extension app group"
require_plist_value ':com.apple.security.app-sandbox' "$WIDGET_HOST_ENTITLEMENTS" 'true' "widget host sandbox entitlement"
require_plist_value ':com.apple.security.application-groups:0' "$WIDGET_HOST_ENTITLEMENTS" 'group.com.dhseo.macdog.MacDog' "widget host app group"

require_text_match 'Manually add the widget' "$WIDGET_PACKAGING_DOC" "manual widget gallery verification remains documented"
require_text_match 'Click the widget' "$WIDGET_PACKAGING_DOC" "manual deep-link verification remains documented"

if [[ -d "$APP_BUNDLE" ]]; then
  [[ -f "$APP_INFO_PLIST" ]] || die "dist app Info.plist missing: $APP_INFO_PLIST"
  [[ -d "$WIDGET_APPEX" ]] || die "dist app widget extension missing: $WIDGET_APPEX"
  [[ -f "$WIDGET_APPEX_INFO_PLIST" ]] || die "dist widget Info.plist missing: $WIDGET_APPEX_INFO_PLIST"
  [[ "$(plist_value ':CFBundleURLTypes:0:CFBundleURLSchemes:0' "$APP_INFO_PLIST")" == "macdog" ]] || die "dist app missing macdog URL scheme"
  [[ "$(plist_value ':CFBundleURLTypes:0:CFBundleURLSchemes:1' "$APP_INFO_PLIST")" == "codexusage" ]] || die "dist app missing codexusage URL scheme"
  require_plist_value ':NSExtension:NSExtensionPointIdentifier' "$WIDGET_APPEX_INFO_PLIST" 'com.apple.widgetkit-extension' "dist WidgetKit extension point"
  require_plist_value ':CFBundlePackageType' "$WIDGET_APPEX_INFO_PLIST" 'XPC!' "dist widget extension package type"
else
  echo "dist/MacDog.app not present; source-level WidgetKit readiness checks only"
fi

echo "WidgetKit readiness ok"
echo "Manual checks still required: add the widget from the macOS widget gallery, click it, and inspect stale/error UI on the signed distribution build."
