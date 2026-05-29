#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MacDog"
BUNDLE_ID="com.dhseo.macdog.MacDog"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
HELPER_NAME="MacDogPrivilegedHelper"
HELPER_LABEL="com.dhseo.macdog.helper"
HELPER_MACH_SERVICE="$HELPER_LABEL.xpc"
HELPER_DESTINATION="/Library/PrivilegedHelperTools/$HELPER_LABEL"
WIDGET_HOST_APP="$ROOT_DIR/.build/xcode-widget/Build/Products/Debug/MacDogWidgetHost.app"
WIDGET_APPEX="$WIDGET_HOST_APP/Contents/PlugIns/MacDogWidgetExtension.appex"
WIDGET_EXTENSION_ENTITLEMENTS="$ROOT_DIR/Apps/MacDogWidgetExtension/MacDogWidgetExtension.entitlements"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCRUN="/usr/bin/xcrun"

configure_app_bundle_paths() {
  APP_CONTENTS="$APP_BUNDLE/Contents"
  APP_LIBRARY="$APP_CONTENTS/Library"
  APP_MACOS="$APP_CONTENTS/MacOS"
  APP_RESOURCES="$APP_CONTENTS/Resources"
  APP_PLUGINS="$APP_CONTENTS/PlugIns"
  APP_LAUNCH_SERVICES="$APP_LIBRARY/LaunchServices"
  APP_LAUNCH_DAEMONS="$APP_LIBRARY/LaunchDaemons"
  APP_BINARY="$APP_MACOS/$APP_NAME"
  APP_CLI_BINARY="$APP_MACOS/codex-usage"
  INFO_PLIST="$APP_CONTENTS/Info.plist"
  APP_HELPER_BINARY="$APP_LAUNCH_SERVICES/$HELPER_NAME"
  APP_HELPER_PLIST="$APP_LAUNCH_DAEMONS/$HELPER_LABEL.plist"
  APP_WIDGET_APPEX="$APP_PLUGINS/MacDogWidgetExtension.appex"
}

configure_app_bundle_paths

usage() {
  cat <<USAGE
usage: $0 [run|--no-run|--verify|--verify-deeplink|--verify-runtime [SECONDS]|--verify-floating-pet-runtime [SECONDS]|--logs|--telemetry|--debug|--help]

Build and run the MacDog SwiftPM macOS app.

Commands:
  run                         Build release app bundle and launch it.
  --no-run                    Build release app bundle and print its path.
  --verify                    Build, launch, and verify the app process exists.
  --verify-deeplink           Verify app launch and macdog://open handling.
  --verify-runtime [SECONDS]  Verify launch and sample runtime CPU. Default: 10.
  --verify-floating-pet-runtime [SECONDS]
                              Verify launch with desktop pet enabled and sample CPU/RSS. Default: 10.
  --logs                      Build, launch, and stream app logs.
  --telemetry                 Build, launch, and stream subsystem logs.
  --debug                     Build and launch the executable under lldb.
  --help                      Show this help.

Environment:
  DEVELOPER_DIR defaults to /Applications/Xcode.app/Contents/Developer.

Output:
  App bundle: $APP_BUNDLE
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "required tool not found: $1"
}

check_prerequisites() {
  [[ -x "$XCRUN" ]] || die "xcrun not found at $XCRUN"
  require_tool pgrep
  require_tool pkill
  require_tool awk
  require_tool ps
  "$XCRUN" --find swift >/dev/null || die "Swift toolchain unavailable through xcrun"
}

build_bundle() {
  check_prerequisites
  "$XCRUN" swift build -c release --product "$APP_NAME"
  "$XCRUN" swift build -c release --product "$HELPER_NAME"
  "$XCRUN" swift build -c release --product codex-usage
  local build_bin
  build_bin="$("$XCRUN" swift build -c release --show-bin-path)"

  local final_app_bundle
  local staging_parent
  final_app_bundle="$DIST_DIR/$APP_NAME.app"
  staging_parent="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-build.XXXXXX")"
  APP_BUNDLE="$staging_parent/$APP_NAME.app"
  configure_app_bundle_paths

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_PLUGINS" "$APP_LAUNCH_SERVICES" "$APP_LAUNCH_DAEMONS"
  cp "$build_bin/$APP_NAME" "$APP_BINARY"
  cp "$build_bin/codex-usage" "$APP_CLI_BINARY"
  cp "$build_bin/$HELPER_NAME" "$APP_HELPER_BINARY"
  chmod +x "$APP_BINARY"
  chmod +x "$APP_CLI_BINARY"
  chmod +x "$APP_HELPER_BINARY"
  if [[ -d "$ROOT_DIR/Sources/MacDog/Resources" ]]; then
    /usr/bin/ditto --norsrc --noextattr "$ROOT_DIR/Sources/MacDog/Resources" "$APP_RESOURCES"
  fi

  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>MacDog</string>
  <key>CFBundleDisplayName</key>
  <string>MacDog</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>$BUNDLE_ID</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>macdog</string>
        <string>codexusage</string>
      </array>
    </dict>
  </array>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

  embed_widget_extension
  embed_privileged_helper_launch_daemon

  /usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID.codex-usage" "$APP_CLI_BINARY" >/dev/null
  /usr/bin/codesign --force --sign - "$APP_HELPER_BINARY" >/dev/null

  /usr/bin/xattr -cr "$APP_BUNDLE" >/dev/null 2>&1 || true
  /usr/bin/codesign --force --sign - "$APP_BUNDLE" >/dev/null
  verify_bundle_signature "$APP_BUNDLE"

  mkdir -p "$DIST_DIR"
  rm -rf "$final_app_bundle"
  /usr/bin/ditto --norsrc --noextattr "$APP_BUNDLE" "$final_app_bundle"
  /usr/bin/xattr -cr "$final_app_bundle" >/dev/null 2>&1 || true
  rm -rf "$staging_parent"
  APP_BUNDLE="$final_app_bundle"
  configure_app_bundle_paths
  verify_bundle_signature "$APP_BUNDLE"
}

verify_bundle_signature() {
  local source_bundle="$1"
  local verify_parent
  local verify_bundle
  verify_parent="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-signature.XXXXXX")"
  verify_bundle="$verify_parent/$(basename "$source_bundle")"

  /usr/bin/ditto --norsrc --noextattr "$source_bundle" "$verify_bundle"
  local status=0
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$verify_bundle" >/dev/null || status=$?
  rm -rf "$verify_parent"
  return "$status"
}

embed_widget_extension() {
  "$ROOT_DIR/script/verify_widget_packaging.sh" >/dev/null
  [[ -d "$WIDGET_APPEX" ]] || die "built widget extension not found: $WIDGET_APPEX"

  rm -rf "$APP_WIDGET_APPEX"
  /usr/bin/ditto --norsrc --noextattr "$WIDGET_APPEX" "$APP_WIDGET_APPEX"
  /usr/bin/xattr -cr "$APP_WIDGET_APPEX" >/dev/null 2>&1 || true
  /usr/bin/codesign --force --sign - --entitlements "$WIDGET_EXTENSION_ENTITLEMENTS" "$APP_WIDGET_APPEX" >/dev/null
}

embed_privileged_helper_launch_daemon() {
  cat >"$APP_HELPER_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$HELPER_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$HELPER_DESTINATION</string>
    <string>--run-xpc-service</string>
  </array>
  <key>MachServices</key>
  <dict>
    <key>$HELPER_MACH_SERVICE</key>
    <true/>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/Library/Logs/MacDog/helper.out.log</string>
  <key>StandardErrorPath</key>
  <string>/Library/Logs/MacDog/helper.err.log</string>
</dict>
</plist>
PLIST
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

verify_app() {
  open_app
  sleep 2
  pgrep -x "$APP_NAME" >/dev/null
}

verify_deeplink() {
  local scheme
  scheme="$(/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes:0:CFBundleURLSchemes:0" "$INFO_PLIST")"
  [[ "$scheme" == "macdog" ]]
  /usr/bin/open "macdog://open"
  sleep 1
  pgrep -x "$APP_NAME" >/dev/null
}

verify_runtime() {
  local duration="${1:-10}"
  sample_runtime_resources "$duration" "Runtime"
}

sample_runtime_resources() {
  local duration="${1:-10}"
  local label="${2:-Runtime}"
  if ! [[ "$duration" =~ ^[0-9]+$ ]] || (( duration <= 0 )); then
    die "runtime duration must be a positive integer: $duration"
  fi

  local pid
  pid="$(pgrep -x "$APP_NAME" | head -n 1)"
  [[ -n "$pid" ]]

  local samples=()
  local cpu
  local rss
  for ((i = 0; i < duration; i++)); do
    read -r cpu rss < <(ps -o %cpu= -o rss= -p "$pid" | awk '{$1=$1; print}')
    [[ -n "$cpu" && -n "$rss" ]]
    samples+=("$cpu $rss")
    sleep 1
  done

  printf "%s\n" "${samples[@]}" | awk -v label="$label" '
    NR == 1 || $1 > max_cpu { max_cpu = $1 }
    NR == 1 || $2 > max_rss { max_rss = $2 }
    { sum_cpu += $1; sum_rss += $2 }
    END {
      avg_cpu = sum_cpu / NR
      avg_rss_mib = (sum_rss / NR) / 1024
      max_rss_mib = max_rss / 1024
      printf("%s resource samples: count=%d cpu_avg=%.2f%% cpu_max=%.2f%% rss_avg=%.1fMiB rss_max=%.1fMiB\n", label, NR, avg_cpu, max_cpu, avg_rss_mib, max_rss_mib)
      if (max_cpu > 50 || max_rss > 250000) {
        exit 1
      }
    }
  '
}

restore_desktop_pet_default() {
  case "${PREVIOUS_DESKTOP_PET_STATE:-unset}" in
    true|false)
      /usr/bin/defaults write "$BUNDLE_ID" desktopPetEnabled -bool "$PREVIOUS_DESKTOP_PET_STATE" >/dev/null 2>&1 || true
      ;;
    unset)
      /usr/bin/defaults delete "$BUNDLE_ID" desktopPetEnabled >/dev/null 2>&1 || true
      ;;
  esac
}

prepare_floating_pet_runtime() {
  PREVIOUS_DESKTOP_PET_STATE="unset"
  local previous
  if previous="$(/usr/bin/defaults read "$BUNDLE_ID" desktopPetEnabled 2>/dev/null)"; then
    if [[ "$previous" == "1" || "$previous" == "true" || "$previous" == "TRUE" ]]; then
      PREVIOUS_DESKTOP_PET_STATE="true"
    else
      PREVIOUS_DESKTOP_PET_STATE="false"
    fi
  fi
  trap restore_desktop_pet_default EXIT
  /usr/bin/defaults write "$BUNDLE_ID" desktopPetEnabled -bool true
}

verify_floating_pet_runtime() {
  local duration="${1:-10}"
  prepare_floating_pet_runtime
  open_app
  sleep 2
  pgrep -x "$APP_NAME" >/dev/null
  sample_runtime_resources "$duration" "Floating pet runtime"
}

case "$MODE" in
  -h|--help|help)
    usage
    ;;
  run)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    open_app
    ;;
  --no-run|no-run)
    build_bundle
    echo "$APP_BUNDLE"
    ;;
  --verify|verify)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    verify_app
    ;;
  --verify-deeplink|verify-deeplink)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    verify_app
    verify_deeplink
    ;;
  --verify-runtime|verify-runtime)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    verify_app
    verify_runtime "${2:-10}"
    ;;
  --verify-floating-pet-runtime|verify-floating-pet-runtime)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    verify_floating_pet_runtime "${2:-10}"
    ;;
  --logs|logs)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --debug|debug)
    build_bundle
    /usr/bin/lldb -- "$APP_BINARY"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
