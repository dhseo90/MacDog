#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIDGET_SOURCE="$ROOT_DIR/Sources/MacDogWidget/MacDogWidget.swift"
WIDGET_TESTS="$ROOT_DIR/Tests/CodexUsageCoreTests/MacDogWidgetPresentationTests.swift"
MENU_BAR_CONTROLLER="$ROOT_DIR/Sources/MacDog/MenuBarController.swift"
CLI_SOURCE="$ROOT_DIR/Sources/CodexUsageCLI/main.swift"
CACHE_SOURCE="$ROOT_DIR/Sources/CodexUsageCore/Cache/CodexUsageCache.swift"
APP_MAIN="$ROOT_DIR/Sources/MacDog/MacDogMain.swift"
USER_COMPONENT_INSTALLER="$ROOT_DIR/Sources/MacDog/UserComponentInstaller.swift"
WIDGET_FIXTURE_WRITER="$ROOT_DIR/script/write_widget_cache_fixture.sh"
WIDGET_MANUAL_UI_PLAN="$ROOT_DIR/script/verify_widget_manual_ui_plan.sh"
WIDGET_APP_GROUP_SIGNING="$ROOT_DIR/script/verify_widget_app_group_signing.sh"
INSTALL_SCRIPT="$ROOT_DIR/script/install.sh"
BUILD_SCRIPT="$ROOT_DIR/script/build_and_run.sh"
PACKAGE_SCRIPT="$ROOT_DIR/script/package_release.sh"
WIDGET_EXTENSION_INFO="$ROOT_DIR/Apps/MacDogWidgetExtension/Info.plist"
WIDGET_EXTENSION_ENTITLEMENTS="$ROOT_DIR/Apps/MacDogWidgetExtension/MacDogWidgetExtension.entitlements"
WIDGET_HOST_ENTITLEMENTS="$ROOT_DIR/Apps/MacDogWidgetHost/MacDogWidgetHost.entitlements"
APP_BUNDLE="$ROOT_DIR/dist/MacDog.app"
APP_INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
WIDGET_APPEX="$APP_BUNDLE/Contents/PlugIns/MacDogWidgetExtension.appex"
WIDGET_APPEX_INFO_PLIST="$WIDGET_APPEX/Contents/Info.plist"
VERIFY_APP_BUNDLE="$ROOT_DIR/script/verify_app_bundle.sh"
WIDGET_PACKAGING_DOC="$ROOT_DIR/Docs/WidgetPackaging.md"
EXPECT_BUNDLED="${MACDOG_EXPECT_WIDGET:-0}"

usage() {
  cat <<USAGE
usage: $0 [--expect-bundled]

Verify WidgetKit source readiness and the default packaging boundary. The
default app bundle must omit WidgetKit; --expect-bundled checks an opt-in
WidgetKit bundle.
USAGE
}

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --expect-bundled|--with-widget)
      EXPECT_BUNDLED=1
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

require_file "$WIDGET_SOURCE"
require_file "$WIDGET_TESTS"
require_file "$MENU_BAR_CONTROLLER"
require_file "$CLI_SOURCE"
require_file "$CACHE_SOURCE"
require_file "$APP_MAIN"
require_file "$USER_COMPONENT_INSTALLER"
require_file "$WIDGET_FIXTURE_WRITER"
require_file "$WIDGET_MANUAL_UI_PLAN"
require_file "$WIDGET_APP_GROUP_SIGNING"
require_file "$INSTALL_SCRIPT"
require_file "$BUILD_SCRIPT"
require_file "$PACKAGE_SCRIPT"
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
require_text_match 'CodexUsageCacheStore\.defaultMirroredFileURLs\(\)' "$CLI_SOURCE" "CLI cache writer can explicitly mirror default and shared caches"
require_text_match 'isWidgetBundled' "$MENU_BAR_CONTROLLER" "installed app live refresh mirrors cache only when WidgetKit is bundled"
require_text_match 'mirrorWidgetCache' "$USER_COMPONENT_INSTALLER" "first-run cache LaunchAgent mirrors cache only when WidgetKit is bundled"
require_text_match '--with-widget' "$INSTALL_SCRIPT" "install script exposes opt-in WidgetKit install"
require_text_match '--with-widget' "$BUILD_SCRIPT" "build script exposes opt-in WidgetKit bundle"
require_text_match '--with-widget' "$PACKAGE_SCRIPT" "release packaging exposes opt-in WidgetKit bundle"
require_text_match 'Widget cache mirror: enabled' "$INSTALL_SCRIPT" "install script documents opt-in WidgetKit cache mirror"
require_text_match '--state updated\|stale\|error' "$WIDGET_FIXTURE_WRITER" "manual fixture writer supports widget state fixtures"
require_text_match '--self-test' "$WIDGET_FIXTURE_WRITER" "manual fixture writer has a non-mutating self-test"
require_text_match 'manual widget fixture error' "$WIDGET_FIXTURE_WRITER" "manual fixture writer can reproduce widget error UI"
require_text_match 'verify_manual_ui_prerequisites\.sh' "$WIDGET_MANUAL_UI_PLAN" "manual WidgetKit UI plan runs the read-only preflight"
require_text_match 'verify_widget_app_group_signing\.sh' "$WIDGET_MANUAL_UI_PLAN" "manual WidgetKit UI plan checks App Group signing"
require_text_match '--skip-preflight' "$WIDGET_MANUAL_UI_PLAN" "manual WidgetKit UI plan can self-test without installed-app prerequisites"
require_text_match 'macOS widget gallery' "$WIDGET_MANUAL_UI_PLAN" "manual WidgetKit UI plan includes widget gallery verification"
require_text_match 'MacDogStatusWidget' "$WIDGET_MANUAL_UI_PLAN" "manual WidgetKit UI plan names the widget kind"
require_text_match 'macdog://open' "$WIDGET_MANUAL_UI_PLAN" "manual WidgetKit UI plan includes deep-link verification"
require_text_match '--state updated --shared-cache' "$WIDGET_MANUAL_UI_PLAN" "manual WidgetKit UI plan includes updated fixture verification"
require_text_match '--state stale --shared-cache' "$WIDGET_MANUAL_UI_PLAN" "manual WidgetKit UI plan includes stale fixture verification"
require_text_match '--state error --shared-cache' "$WIDGET_MANUAL_UI_PLAN" "manual WidgetKit UI plan includes error fixture verification"
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
require_text_match '--with-widget|--expect-widget' "$VERIFY_APP_BUNDLE" "app bundle verifier checks WidgetKit only when requested"

require_plist_value ':CFBundleIdentifier' "$WIDGET_EXTENSION_INFO" 'com.dhseo.macdog.MacDog.WidgetExtension' "widget extension bundle id"
require_plist_value ':CFBundlePackageType' "$WIDGET_EXTENSION_INFO" 'XPC!' "widget extension package type"
require_plist_value ':NSExtension:NSExtensionPointIdentifier' "$WIDGET_EXTENSION_INFO" 'com.apple.widgetkit-extension' "WidgetKit extension point"
require_plist_value ':com.apple.security.app-sandbox' "$WIDGET_EXTENSION_ENTITLEMENTS" 'true' "widget extension sandbox entitlement"
require_plist_value ':com.apple.security.application-groups:0' "$WIDGET_EXTENSION_ENTITLEMENTS" 'group.com.dhseo.macdog.MacDog' "widget extension app group"
require_plist_value ':com.apple.security.app-sandbox' "$WIDGET_HOST_ENTITLEMENTS" 'true' "widget host sandbox entitlement"
require_plist_value ':com.apple.security.application-groups:0' "$WIDGET_HOST_ENTITLEMENTS" 'group.com.dhseo.macdog.MacDog' "widget host app group"

require_text_match 'Manually add the widget|macOS widget gallery에서 위젯을 직접 추가' "$WIDGET_PACKAGING_DOC" "manual widget gallery verification remains documented"
require_text_match 'Click the widget|위젯을 클릭' "$WIDGET_PACKAGING_DOC" "manual deep-link verification remains documented"
require_text_match 'verify_widget_manual_ui_plan\.sh --self-test' "$WIDGET_PACKAGING_DOC" "manual WidgetKit UI plan self-test remains documented"

if [[ -d "$APP_BUNDLE" ]]; then
  [[ -f "$APP_INFO_PLIST" ]] || die "dist app Info.plist missing: $APP_INFO_PLIST"
  [[ "$(plist_value ':CFBundleURLTypes:0:CFBundleURLSchemes:0' "$APP_INFO_PLIST")" == "macdog" ]] || die "dist app missing macdog URL scheme"
  [[ "$(plist_value ':CFBundleURLTypes:0:CFBundleURLSchemes:1' "$APP_INFO_PLIST")" == "codexusage" ]] || die "dist app missing codexusage URL scheme"
  if [[ "$EXPECT_BUNDLED" == "1" ]]; then
    [[ -d "$WIDGET_APPEX" ]] || die "opt-in dist app widget extension missing: $WIDGET_APPEX"
    [[ -f "$WIDGET_APPEX_INFO_PLIST" ]] || die "dist widget Info.plist missing: $WIDGET_APPEX_INFO_PLIST"
    require_plist_value ':NSExtension:NSExtensionPointIdentifier' "$WIDGET_APPEX_INFO_PLIST" 'com.apple.widgetkit-extension' "dist WidgetKit extension point"
    require_plist_value ':CFBundlePackageType' "$WIDGET_APPEX_INFO_PLIST" 'XPC!' "dist widget extension package type"
  else
    [[ ! -e "$WIDGET_APPEX" ]] || die "default dist app must omit WidgetKit extension: $WIDGET_APPEX"
  fi
else
  echo "dist/MacDog.app not present; source-level WidgetKit readiness checks only"
fi

echo "WidgetKit readiness ok"
echo "기본 설치 경계: WidgetKit은 기본 번들에서 제외되고 --with-widget opt-in build에서만 포함됩니다."
echo "수동 검수 필요: opt-in signed/provisioned build에서 macOS widget gallery 추가, 클릭, stale/error UI를 직접 확인해야 합니다."
