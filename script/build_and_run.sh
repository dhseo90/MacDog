#!/usr/bin/env bash
set -euo pipefail

MODE="run"
RUN_DURATION=""
WITH_WIDGET="${MACDOG_INCLUDE_WIDGET:-0}"
APP_NAME="MacDog"
BUNDLE_ID="com.dhseo.macdog.MacDog"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="${MACDOG_APP_VERSION:-${MACDOG_RELEASE_VERSION:-1.0.0}}"
APP_BUILD="${MACDOG_APP_BUILD:-1}"

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
CLI_ENTITLEMENTS="$ROOT_DIR/Apps/CodexUsageCLI/CodexUsageCLI.entitlements"

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
usage: $0 [run|--no-run|--verify|--verify-deeplink|--verify-runtime [SECONDS]|--verify-floating-pet-runtime [SECONDS]|--logs|--telemetry|--debug] [--with-widget|--help]

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
  --with-widget               Embed the WidgetKit extension. Default builds omit it.
  --help                      Show this help.

Environment:
  DEVELOPER_DIR defaults to /Applications/Xcode.app/Contents/Developer.
  MACDOG_INCLUDE_WIDGET=1 also enables the WidgetKit extension.

Output:
  App bundle: $APP_BUNDLE
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with-widget)
        WITH_WIDGET=1
        ;;
      -h|--help|help)
        MODE="help"
        ;;
      run|--no-run|no-run|--verify|verify|--verify-deeplink|verify-deeplink|--logs|logs|--telemetry|telemetry|--debug|debug)
        MODE="$1"
        ;;
      --verify-runtime|verify-runtime|--verify-floating-pet-runtime|verify-floating-pet-runtime)
        MODE="$1"
        if [[ $# -gt 1 && "$2" =~ ^[0-9]+$ ]]; then
          RUN_DURATION="$2"
          shift
        fi
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "required tool not found: $1"
}

clean_bundle_xattrs() {
  local bundle="$1"
  /usr/bin/xattr -cr "$bundle" >/dev/null 2>&1 || true
  /usr/bin/find "$bundle" -exec /usr/bin/xattr -d com.apple.FinderInfo {} \; >/dev/null 2>&1 || true
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
  mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_LAUNCH_SERVICES" "$APP_LAUNCH_DAEMONS"
  if [[ "$WITH_WIDGET" == "1" ]]; then
    mkdir -p "$APP_PLUGINS"
  fi
  cp "$build_bin/$APP_NAME" "$APP_BINARY"
  cp "$build_bin/codex-usage" "$APP_CLI_BINARY"
  cp "$build_bin/$HELPER_NAME" "$APP_HELPER_BINARY"
  chmod +x "$APP_BINARY"
  chmod +x "$APP_CLI_BINARY"
  chmod +x "$APP_HELPER_BINARY"
  if [[ -d "$ROOT_DIR/Sources/MacDog/Resources" ]]; then
    /usr/bin/ditto --norsrc --noextattr "$ROOT_DIR/Sources/MacDog/Resources" "$APP_RESOURCES"
  fi
  generate_app_icon

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
  <key>CFBundleIconFile</key>
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
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
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

  if [[ "$WITH_WIDGET" == "1" ]]; then
    embed_widget_extension
  fi
  embed_privileged_helper_launch_daemon

  if [[ "$WITH_WIDGET" == "1" ]]; then
    /usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID.codex-usage" --entitlements "$CLI_ENTITLEMENTS" "$APP_CLI_BINARY" >/dev/null
  else
    /usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID.codex-usage" "$APP_CLI_BINARY" >/dev/null
  fi
  /usr/bin/codesign --force --sign - "$APP_HELPER_BINARY" >/dev/null

  clean_bundle_xattrs "$APP_BUNDLE"
  /usr/bin/codesign --force --sign - "$APP_BUNDLE" >/dev/null
  verify_bundle_signature "$APP_BUNDLE"

  mkdir -p "$DIST_DIR"
  rm -rf "$final_app_bundle"
  /usr/bin/ditto --norsrc --noextattr "$APP_BUNDLE" "$final_app_bundle"
  clean_bundle_xattrs "$final_app_bundle"
  rm -rf "$staging_parent"
  APP_BUNDLE="$final_app_bundle"
  configure_app_bundle_paths
  verify_bundle_signature "$APP_BUNDLE"
}

generate_app_icon() {
  local icon_source="$APP_RESOURCES/DesktopPet/pup-idle-front-0.png"
  local iconset="$APP_RESOURCES/MacDog.iconset"
  local generator="$iconset/generate.swift"

  [[ -f "$icon_source" ]] || die "app icon source missing: $icon_source"
  rm -rf "$iconset"
  mkdir -p "$iconset"

  cat >"$generator" <<'SWIFT'
import AppKit
import Foundation

let sourcePath = CommandLine.arguments[1]
let outputDirectory = CommandLine.arguments[2]

guard let source = NSImage(contentsOfFile: sourcePath) else {
    fatalError("Could not read app icon source: \(sourcePath)")
}

let entries: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

func render(size: Int, name: String) throws {
    let side = CGFloat(size)
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: side, height: side).fill()

    let background = NSRect(x: side * 0.05, y: side * 0.05, width: side * 0.90, height: side * 0.90)
    NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.15, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: background, xRadius: side * 0.20, yRadius: side * 0.20).fill()

    NSColor(calibratedRed: 0.22, green: 0.26, blue: 0.32, alpha: 1.0).setStroke()
    let stroke = NSBezierPath(roundedRect: background.insetBy(dx: side * 0.025, dy: side * 0.025), xRadius: side * 0.17, yRadius: side * 0.17)
    stroke.lineWidth = max(1, side * 0.018)
    stroke.stroke()

    let maxDogWidth = side * 0.82
    let maxDogHeight = side * 0.82
    let sourceSize = source.size
    let scale = min(maxDogWidth / sourceSize.width, maxDogHeight / sourceSize.height)
    let dogSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    let dogRect = NSRect(
        x: (side - dogSize.width) / 2,
        y: (side - dogSize.height) / 2,
        width: dogSize.width,
        height: dogSize.height
    )
    source.draw(in: dogRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not encode app icon entry: \(name)")
    }

    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(name)
    try png.write(to: url)
}

for entry in entries {
    try render(size: entry.0, name: entry.1)
}
SWIFT

  "$XCRUN" swift "$generator" "$icon_source" "$iconset" >/dev/null

  /usr/bin/iconutil -c icns "$iconset" -o "$APP_RESOURCES/MacDog.icns"
  rm -rf "$iconset"
  [[ -f "$APP_RESOURCES/MacDog.icns" ]] || die "failed to generate app icon"
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
  clean_bundle_xattrs "$APP_WIDGET_APPEX"
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

parse_args "$@"

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
    verify_runtime "${RUN_DURATION:-10}"
    ;;
  --verify-floating-pet-runtime|verify-floating-pet-runtime)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    build_bundle
    verify_floating_pet_runtime "${RUN_DURATION:-10}"
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
