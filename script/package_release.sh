#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacDog"
VERSION="${MACDOG_RELEASE_VERSION:-1.0.0}"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
RELEASE_ROOT="$ROOT_DIR/dist/release"
STAGE_DIR="$RELEASE_ROOT/$APP_NAME-$VERSION"
DMG_PATH="$RELEASE_ROOT/$APP_NAME-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
NOTES_PATH="$RELEASE_ROOT/$APP_NAME-$VERSION-release-notes.md"
BACKGROUND_PATH="$STAGE_DIR/.background/background.png"
DRY_RUN=0
SKIP_BUILD=0
CREATE_DMG=1
WITH_WIDGET=0

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCRUN="/usr/bin/xcrun"
DMG_WINDOW_WIDTH=760
DMG_WINDOW_HEIGHT=430
DMG_ICON_SIZE=150
DMG_APP_ICON_X=190
DMG_APPLICATIONS_ICON_X=570
DMG_ICON_Y=225

usage() {
  cat <<USAGE
usage: $0 [--dry-run] [--skip-build] [--no-dmg] [--version VERSION] [--with-widget]

Build a GitHub Release payload.
The generated DMG is ad-hoc signed and not notarized; release notes must say so clearly.
The DMG is staged as a Docker-style drag-and-drop app installer.
First launch from Applications finishes user-level setup and offers helper setup.
WidgetKit is omitted by default; --with-widget builds an opt-in widget bundle.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

clean_bundle_xattrs() {
  local bundle="$1"
  /usr/bin/xattr -cr "$bundle" >/dev/null 2>&1 || true
  /usr/bin/find "$bundle" -exec /usr/bin/xattr -d com.apple.FinderInfo {} \; >/dev/null 2>&1 || true
}

plist_value() {
  local plist="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null
}

verify_app_bundle_version() {
  local bundle="$1"
  local expected_version="$2"
  local plist="$bundle/Contents/Info.plist"
  local actual_version

  [[ -d "$bundle" ]] || die "app bundle missing: $bundle"
  [[ -f "$plist" ]] || die "app Info.plist missing: $plist"
  actual_version="$(plist_value "$plist" CFBundleShortVersionString || true)"
  [[ -n "$actual_version" ]] || die "app bundle version missing: $plist"
  if [[ "$actual_version" != "$expected_version" ]]; then
    die "app bundle version mismatch: expected $expected_version, got $actual_version ($bundle)"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --no-dmg) CREATE_DMG=0 ;;
    --with-widget) WITH_WIDGET=1 ;;
    --version)
      shift
      [[ $# -gt 0 ]] || die "--version requires a value"
      VERSION="$1"
      STAGE_DIR="$RELEASE_ROOT/$APP_NAME-$VERSION"
      DMG_PATH="$RELEASE_ROOT/$APP_NAME-$VERSION.dmg"
      CHECKSUM_PATH="$DMG_PATH.sha256"
      NOTES_PATH="$RELEASE_ROOT/$APP_NAME-$VERSION-release-notes.md"
      BACKGROUND_PATH="$STAGE_DIR/.background/background.png"
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

if [[ "$DRY_RUN" == "1" ]]; then
  build_plan="$ROOT_DIR/script/build_and_run.sh --no-run"
  if [[ "$WITH_WIDGET" == "1" ]]; then
    build_plan="$build_plan --with-widget"
  fi
  cat <<DRYRUN
MacDog release package dry run
Version: $VERSION
Build app bundle: $([[ "$SKIP_BUILD" == "1" ]] && echo "skipped" || echo "$build_plan")
Widget extension: $([[ "$WITH_WIDGET" == "1" ]] && echo "opt-in bundled" || echo "omitted by default")
App source: $APP_BUNDLE
Stage directory: $STAGE_DIR
DMG path: $DMG_PATH
SHA-256 path: $CHECKSUM_PATH
Release notes path: $NOTES_PATH
Payload:
  - MacDog.app (includes bundled codex-usage)
  - Applications symlink
  - Hidden DMG background artwork for drag-and-drop layout
DMG layout:
  - Window: ${DMG_WINDOW_WIDTH}x${DMG_WINDOW_HEIGHT}
  - Icon size: ${DMG_ICON_SIZE}
  - MacDog.app position: {${DMG_APP_ICON_X}, ${DMG_ICON_Y}}
  - Applications position: {${DMG_APPLICATIONS_ICON_X}, ${DMG_ICON_Y}}
Install style: Docker-style drag-and-drop app installer
Drag install: drag MacDog.app to Applications, then launch MacDog.
First launch setup: MacDog creates the user codex-usage symlink, usage cache LaunchAgent, and macOS Login Item when enabled.
Widget setup: default release omits WidgetKit; opt-in widget builds mirror cache only when the extension is bundled.
First launch cleanup: MacDog can offer to eject the installer disk and delete downloaded installer files.
Privileged helper: first launch offers MacDog-owned helper installation; Settings can install or remove it later.
Signing: local ad-hoc build only; Developer ID signing and notarization are not performed and are excluded from the current implementation plan.
Gatekeeper: GitHub Release notes must clearly say this DMG is not notarized and may show a macOS warning.
GitHub Release: upload DMG with checksum and release notes that state the notarization status.
DRYRUN
  exit 0
fi

generate_dmg_background() {
  local output_path="$1"
  local generator="$RELEASE_ROOT/.macdog-dmg-background.swift"

  mkdir -p "$(dirname "$output_path")"
  cat >"$generator" <<'SWIFT'
import AppKit
import Foundation

let outputPath = CommandLine.arguments[1]
let environment = ProcessInfo.processInfo.environment

func requiredCGFloat(_ name: String) -> CGFloat {
    guard let rawValue = environment[name], let value = Double(rawValue) else {
        fatalError("Missing numeric environment value: \(name)")
    }
    return CGFloat(value)
}

let size = NSSize(
    width: requiredCGFloat("MACDOG_DMG_WINDOW_WIDTH"),
    height: requiredCGFloat("MACDOG_DMG_WINDOW_HEIGHT")
)
let iconSize = requiredCGFloat("MACDOG_DMG_ICON_SIZE")
let appFinderCenter = NSPoint(
    x: requiredCGFloat("MACDOG_DMG_APP_ICON_X"),
    y: requiredCGFloat("MACDOG_DMG_ICON_Y")
)
let applicationsFinderCenter = NSPoint(
    x: requiredCGFloat("MACDOG_DMG_APPLICATIONS_ICON_X"),
    y: requiredCGFloat("MACDOG_DMG_ICON_Y")
)
let image = NSImage(size: size)

func fillPolygon(_ points: [NSPoint], color: NSColor) {
    let path = NSBezierPath()
    guard let first = points.first else { return }
    path.move(to: first)
    for point in points.dropFirst() {
        path.line(to: point)
    }
    path.close()
    color.setFill()
    path.fill()
}

func drawingPoint(fromFinder point: NSPoint) -> NSPoint {
    NSPoint(x: point.x, y: size.height - point.y)
}

func centeredRect(finderCenter: NSPoint, width: CGFloat, height: CGFloat) -> NSRect {
    let center = drawingPoint(fromFinder: finderCenter)
    return NSRect(
        x: center.x - width / 2,
        y: center.y - height / 2,
        width: width,
        height: height
    )
}

func drawSlot(_ rect: NSRect, fillColor: NSColor, strokeColor: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 12
    shadow.shadowOffset = NSSize(width: 0, height: -2)
    shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.08)
    shadow.set()
    fillColor.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    strokeColor.setStroke()
    path.lineWidth = 2.5
    path.stroke()
}

image.lockFocus()
NSColor(calibratedRed: 0.90, green: 0.96, blue: 1.00, alpha: 1.0).setFill()
NSRect(origin: .zero, size: size).fill()

fillPolygon(
    [NSPoint(x: 0, y: 430), NSPoint(x: 260, y: 430), NSPoint(x: 365, y: 315), NSPoint(x: 82, y: 235), NSPoint(x: 0, y: 280)],
    color: NSColor(calibratedRed: 0.54, green: 0.78, blue: 0.95, alpha: 0.62)
)
fillPolygon(
    [NSPoint(x: 0, y: 0), NSPoint(x: 272, y: 0), NSPoint(x: 380, y: 146), NSPoint(x: 92, y: 224), NSPoint(x: 0, y: 166)],
    color: NSColor(calibratedRed: 0.70, green: 0.88, blue: 0.99, alpha: 0.70)
)
fillPolygon(
    [NSPoint(x: 372, y: 430), NSPoint(x: 760, y: 430), NSPoint(x: 760, y: 0), NSPoint(x: 460, y: 0), NSPoint(x: 488, y: 270)],
    color: NSColor(calibratedRed: 0.82, green: 0.93, blue: 1.00, alpha: 0.78)
)
fillPolygon(
    [NSPoint(x: 92, y: 224), NSPoint(x: 365, y: 315), NSPoint(x: 488, y: 270), NSPoint(x: 380, y: 146)],
    color: NSColor(calibratedWhite: 1.0, alpha: 0.76)
)

let slotWidth = iconSize + 92
let slotHeight = iconSize + 56
let itemLabelOffset: CGFloat = 16
let appSlotCenter = NSPoint(x: appFinderCenter.x, y: appFinderCenter.y + itemLabelOffset)
let applicationsSlotCenter = NSPoint(x: applicationsFinderCenter.x, y: applicationsFinderCenter.y + itemLabelOffset)
let appSlot = centeredRect(finderCenter: appSlotCenter, width: slotWidth, height: slotHeight)
let applicationsSlot = centeredRect(finderCenter: applicationsSlotCenter, width: slotWidth, height: slotHeight)

drawSlot(
    appSlot,
    fillColor: NSColor(calibratedWhite: 1.0, alpha: 0.26),
    strokeColor: NSColor(calibratedWhite: 1.0, alpha: 0.58)
)
drawSlot(
    applicationsSlot,
    fillColor: NSColor(calibratedRed: 0.33, green: 0.78, blue: 1.0, alpha: 0.30),
    strokeColor: NSColor(calibratedWhite: 1.0, alpha: 0.52)
)

let title = "Install MacDog"
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 31, weight: .semibold),
    .foregroundColor: NSColor(calibratedWhite: 0.18, alpha: 0.86)
]
let titleSize = title.size(withAttributes: titleAttributes)
title.draw(
    at: NSPoint(x: (size.width - titleSize.width) / 2, y: size.height - 48 - titleSize.height),
    withAttributes: titleAttributes
)

let arrowStartFinder = NSPoint(x: appSlotCenter.x + slotWidth / 2 + 24, y: appFinderCenter.y + 8)
let arrowEndFinder = NSPoint(x: applicationsSlotCenter.x - slotWidth / 2 - 24, y: appFinderCenter.y + 8)
let arrowColor = NSColor(calibratedWhite: 0.02, alpha: 0.82)
let arrow = NSBezierPath()
arrow.move(to: drawingPoint(fromFinder: arrowStartFinder))
arrow.line(to: drawingPoint(fromFinder: arrowEndFinder))
arrowColor.setStroke()
arrow.lineWidth = 8
arrow.lineCapStyle = .round
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: drawingPoint(fromFinder: arrowEndFinder))
arrowHead.line(to: drawingPoint(fromFinder: NSPoint(x: arrowEndFinder.x - 28, y: arrowEndFinder.y - 22)))
arrowHead.move(to: drawingPoint(fromFinder: arrowEndFinder))
arrowHead.line(to: drawingPoint(fromFinder: NSPoint(x: arrowEndFinder.x - 28, y: arrowEndFinder.y + 22)))
arrowColor.setStroke()
arrowHead.lineWidth = 8
arrowHead.lineCapStyle = .round
arrowHead.lineJoinStyle = .round
arrowHead.stroke()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Could not encode DMG background")
}

try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT

  MACDOG_DMG_WINDOW_WIDTH="$DMG_WINDOW_WIDTH" \
  MACDOG_DMG_WINDOW_HEIGHT="$DMG_WINDOW_HEIGHT" \
  MACDOG_DMG_ICON_SIZE="$DMG_ICON_SIZE" \
  MACDOG_DMG_APP_ICON_X="$DMG_APP_ICON_X" \
  MACDOG_DMG_APPLICATIONS_ICON_X="$DMG_APPLICATIONS_ICON_X" \
  MACDOG_DMG_ICON_Y="$DMG_ICON_Y" \
    "$XCRUN" swift "$generator" "$output_path" >/dev/null
  rm -f "$generator"
}

create_styled_dmg() {
  local rw_dmg="$RELEASE_ROOT/$APP_NAME-$VERSION-rw.dmg"
  local mountpoint
  local volume_name="$APP_NAME $VERSION"

  rm -f "$rw_dmg"
  mountpoint="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-dmg-mount.XXXXXX")"

  /usr/bin/hdiutil create \
    -volname "$volume_name" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$rw_dmg" >/dev/null || {
      rm -rf "$mountpoint"
      return 1
    }

  /usr/bin/hdiutil attach "$rw_dmg" \
    -mountpoint "$mountpoint" \
    -noautoopen >/dev/null || {
      rm -f "$rw_dmg"
      rm -rf "$mountpoint"
      return 1
    }

  if ! /usr/bin/osascript <<APPLESCRIPT >/dev/null
set volumePath to POSIX file "$mountpoint" as alias
set backgroundPath to alias "$volume_name:.background:background.png"
set finalBounds to {120, 120, 880, 550}
tell application "Finder"
  open volumePath
  delay 0.2
  set theWindow to container window of volumePath
  set bounds of theWindow to finalBounds
  set current view of theWindow to icon view
  try
    set toolbar visible of theWindow to false
  end try
  try
    set statusbar visible of theWindow to false
  end try
  set arrangement of icon view options of theWindow to not arranged
  set icon size of icon view options of theWindow to $DMG_ICON_SIZE
  set background picture of icon view options of theWindow to backgroundPath
  set position of item "$APP_NAME.app" of volumePath to {$DMG_APP_ICON_X, $DMG_ICON_Y}
  set position of item "Applications" of volumePath to {$DMG_APPLICATIONS_ICON_X, $DMG_ICON_Y}
  update volumePath without registering applications
  try
    close theWindow
  end try
end tell
APPLESCRIPT
  then
    /usr/bin/hdiutil detach "$mountpoint" >/dev/null 2>&1 || true
    rm -f "$rw_dmg"
    rm -rf "$mountpoint"
    return 1
  fi

  clean_bundle_xattrs "$mountpoint/$APP_NAME.app"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$mountpoint/$APP_NAME.app" >/dev/null || {
    /usr/bin/hdiutil detach "$mountpoint" >/dev/null 2>&1 || true
    rm -f "$rw_dmg"
    rm -rf "$mountpoint"
    return 1
  }

  /bin/sync
  /usr/bin/hdiutil detach "$mountpoint" >/dev/null || {
    rm -f "$rw_dmg"
    rm -rf "$mountpoint"
    return 1
  }
  rm -rf "$mountpoint"

  /usr/bin/hdiutil convert "$rw_dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" >/dev/null || {
      rm -f "$rw_dmg"
      return 1
    }
  rm -f "$rw_dmg"
}

create_required_styled_dmg() {
  local max_attempts=3
  local attempt=1

  while (( attempt <= max_attempts )); do
    if create_styled_dmg; then
      return 0
    fi
    rm -f "$DMG_PATH" "$RELEASE_ROOT/$APP_NAME-$VERSION-rw.dmg"
    echo "warning: styled DMG creation failed (attempt $attempt/$max_attempts)" >&2
    if (( attempt < max_attempts )); then
      /bin/sleep 2
    fi
    attempt=$((attempt + 1))
  done

  return 1
}

cd "$ROOT_DIR"

if [[ "$SKIP_BUILD" != "1" ]]; then
  if [[ "$WITH_WIDGET" == "1" ]]; then
    MACDOG_RELEASE_VERSION="$VERSION" MACDOG_APP_VERSION="$VERSION" ./script/build_and_run.sh --no-run --with-widget >/dev/null
  else
    MACDOG_RELEASE_VERSION="$VERSION" MACDOG_APP_VERSION="$VERSION" ./script/build_and_run.sh --no-run >/dev/null
  fi
fi

verify_app_bundle_version "$APP_BUNDLE" "$VERSION"
clean_bundle_xattrs "$APP_BUNDLE"
if [[ "$WITH_WIDGET" == "1" ]]; then
  ./script/verify_app_bundle.sh "$APP_BUNDLE" --with-widget >/dev/null
else
  ./script/verify_app_bundle.sh "$APP_BUNDLE" >/dev/null
fi

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR" "$RELEASE_ROOT"
if [[ "$CREATE_DMG" == "1" ]]; then
  cleanup_release_stage() {
    rm -rf "$STAGE_DIR"
  }
  trap cleanup_release_stage EXIT
fi

/usr/bin/ditto --norsrc --noextattr "$APP_BUNDLE" "$STAGE_DIR/$APP_NAME.app"
clean_bundle_xattrs "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"
generate_dmg_background "$BACKGROUND_PATH"
/usr/bin/chflags hidden "$STAGE_DIR/.background" >/dev/null 2>&1 || true

cat >"$NOTES_PATH" <<NOTES
# MacDog $VERSION 릴리즈 노트

상태: GitHub v$VERSION 로컬/unsigned 검증용 릴리즈 후보입니다. 이 DMG는 ad-hoc signed build이며 Apple notarization은 적용되지 않습니다.

## 설치

- DMG를 엽니다.
- \`MacDog.app\`을 \`Applications\`로 드래그합니다.
- Applications에서 MacDog를 실행합니다.
- 첫 실행 시 MacDog가 터미널용 \`codex-usage\` symlink, usage cache LaunchAgent, macOS 로그인 항목을 사용자 설정에 맞게 마무리합니다.
- 첫 실행 시 MacDog가 설치 디스크를 추출하고 다운로드한 설치 파일을 정리할지 물어볼 수 있습니다.
- 첫 실행 시 MacDog가 덮개 닫힘 보호용 optional 권한 도우미 설치 여부를 물어봅니다. 동의하면 macOS가 MacDog 주체의 관리자 승인창을 표시합니다.
- optional 권한 도우미는 나중에 MacDog 설정 탭에서도 설치하거나 제거할 수 있습니다.
- WidgetKit 위젯은 기본 DMG에 포함하지 않습니다. 위젯은 App Group provisioning 검증이 가능한 환경에서 \`--with-widget\` opt-in build로만 설치합니다.

## 보안과 Gatekeeper

- 이 DMG는 ad-hoc signed build이며 notarized build가 아닙니다.
- macOS Gatekeeper 경고가 표시될 수 있습니다. Developer ID signing, hardened runtime, notarization, stapling, App Group provisioning은 Apple Developer Program이 필요하므로 현재 구현 계획에서 제외합니다.
- optional 권한 도우미는 MacDog에서 명시적으로 승인한 뒤에만 \`/Library/PrivilegedHelperTools/com.dhseo.macdog.helper\`와 \`/Library/LaunchDaemons/com.dhseo.macdog.helper.plist\`를 변경합니다.

## 지원 범위

- Codex 사용량 popover와 CLI를 지원합니다.
- Mac 자원, 잠들지 않기, native Charge Limit UI를 지원합니다.
- Native Charge Limit은 Apple silicon과 macOS 26.4 이상이 필요합니다.
- WidgetKit은 source/자동 검증 일부만 유지합니다. 실제 위젯 UI의 shared cache 표시, stale/error 반영, 클릭 deep link는 App Group provisioning 이후 단계라 현재 지원 범위에 포함하지 않습니다.

## 삭제

- MacDog를 종료한 뒤 \`/Applications/MacDog.app\`을 휴지통으로 옮깁니다.
- optional 권한 도우미를 설치했다면 앱을 삭제하기 전에 MacDog 설정에서 먼저 제거합니다.
- source checkout 삭제 경로도 사용할 수 있습니다: \`./script/uninstall.sh --with-helper\`
NOTES

if [[ "$CREATE_DMG" == "1" ]]; then
  rm -f "$DMG_PATH" "$CHECKSUM_PATH"
  create_required_styled_dmg || die "styled drag-and-drop DMG creation failed"
  (
    cd "$RELEASE_ROOT"
    /usr/bin/shasum -a 256 "$(basename "$DMG_PATH")" >"$(basename "$CHECKSUM_PATH")"
  )
  echo "$DMG_PATH"
  echo "$CHECKSUM_PATH"
  echo "$NOTES_PATH"
else
  echo "$STAGE_DIR"
  echo "$NOTES_PATH"
fi
