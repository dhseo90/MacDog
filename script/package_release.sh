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

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCRUN="/usr/bin/xcrun"

usage() {
  cat <<USAGE
usage: $0 [--dry-run] [--skip-build] [--no-dmg] [--version VERSION]

Build a local GitHub Release candidate payload.
The generated DMG is not notarized and is intended for local validation.
The DMG is staged as a Docker-style drag-and-drop app installer.
First launch from Applications finishes user-level setup and offers helper setup.
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --no-dmg) CREATE_DMG=0 ;;
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
  cat <<DRYRUN
MacDog release package dry run
Version: $VERSION
Build app bundle: $([[ "$SKIP_BUILD" == "1" ]] && echo "skipped" || echo "$ROOT_DIR/script/build_and_run.sh --no-run")
App source: $APP_BUNDLE
Stage directory: $STAGE_DIR
DMG path: $DMG_PATH
SHA-256 path: $CHECKSUM_PATH
Release notes path: $NOTES_PATH
Payload:
  - MacDog.app (includes bundled codex-usage)
  - Applications symlink
  - Hidden DMG background artwork for drag-and-drop layout
Install style: Docker-style drag-and-drop app installer
Drag install: drag MacDog.app to Applications, then launch MacDog.
First launch setup: MacDog creates the user codex-usage symlink, usage cache LaunchAgent, and macOS Login Item when enabled.
First launch cleanup: MacDog can offer to eject the installer disk and delete downloaded installer files.
Privileged helper: first launch offers MacDog-owned helper installation; Settings can install or remove it later.
Signing: local ad-hoc build only; Developer ID signing and notarization are not performed.
Gatekeeper: unsigned candidates are local validation artifacts and must not be published as public stable releases.
GitHub Release: upload DMG only after signing/notarization gate is satisfied for public distribution.
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
let size = NSSize(width: 760, height: 430)
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

let title = "drag and drop"
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 35, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.18, alpha: 0.86)
]
let titleSize = title.size(withAttributes: titleAttributes)
title.draw(
    at: NSPoint(x: (size.width - titleSize.width) / 2, y: 274),
    withAttributes: titleAttributes
)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 260, y: 218))
arrow.curve(
    to: NSPoint(x: 502, y: 218),
    controlPoint1: NSPoint(x: 330, y: 278),
    controlPoint2: NSPoint(x: 438, y: 278)
)
NSColor(calibratedWhite: 0.02, alpha: 0.82).setStroke()
arrow.lineWidth = 7
arrow.lineCapStyle = .round
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 502, y: 218))
arrowHead.line(to: NSPoint(x: 471, y: 238))
arrowHead.line(to: NSPoint(x: 480, y: 198))
arrowHead.close()
NSColor(calibratedWhite: 0.02, alpha: 0.82).setFill()
arrowHead.fill()

let appHint = NSBezierPath(roundedRect: NSRect(x: 98, y: 126, width: 184, height: 184), xRadius: 14, yRadius: 14)
NSColor(calibratedWhite: 1.0, alpha: 0.22).setFill()
appHint.fill()
NSColor(calibratedWhite: 1.0, alpha: 0.48).setStroke()
appHint.lineWidth = 2
appHint.stroke()

let folderHint = NSBezierPath(roundedRect: NSRect(x: 476, y: 130, width: 188, height: 142), xRadius: 15, yRadius: 15)
NSColor(calibratedRed: 0.33, green: 0.78, blue: 1.0, alpha: 0.26).setFill()
folderHint.fill()
NSColor(calibratedWhite: 1.0, alpha: 0.45).setStroke()
folderHint.lineWidth = 2
folderHint.stroke()

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
tell application "Finder"
  open volumePath
  delay 0.5
  set theWindow to container window of volumePath
  set current view of theWindow to icon view
  try
    set toolbar visible of theWindow to false
  end try
  try
    set statusbar visible of theWindow to false
  end try
  set bounds of theWindow to {120, 120, 880, 550}
  set arrangement of icon view options of theWindow to not arranged
  set icon size of icon view options of theWindow to 128
  set background picture of icon view options of theWindow to backgroundPath
  set position of item "$APP_NAME.app" of volumePath to {190, 250}
  set position of item "Applications" of volumePath to {570, 250}
  update volumePath without registering applications
  delay 1
  close theWindow
  delay 1
  open volumePath
  delay 1
  set reopenedWindow to container window of volumePath
  close reopenedWindow
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

create_plain_dmg() {
  /usr/bin/hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null
}

cd "$ROOT_DIR"

if [[ "$SKIP_BUILD" != "1" ]]; then
  ./script/build_and_run.sh --no-run >/dev/null
fi

./script/verify_app_bundle.sh "$APP_BUNDLE" >/dev/null

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
# MacDog $VERSION 릴리즈 노트 초안

상태: unsigned local release candidate입니다.

## 설치

- DMG를 엽니다.
- \`MacDog.app\`을 \`Applications\`로 드래그합니다.
- Applications에서 MacDog를 실행합니다.
- 첫 실행 시 MacDog가 터미널용 \`codex-usage\` symlink, usage cache LaunchAgent, macOS 로그인 항목을 사용자 설정에 맞게 마무리합니다.
- 첫 실행 시 MacDog가 설치 디스크를 추출하고 다운로드한 설치 파일을 정리할지 물어볼 수 있습니다.
- 첫 실행 시 MacDog가 덮개 닫힘 보호용 optional 권한 도우미 설치 여부를 물어봅니다. 동의하면 macOS가 MacDog 주체의 관리자 승인창을 표시합니다.
- optional 권한 도우미는 나중에 MacDog 설정 탭에서도 설치하거나 제거할 수 있습니다.

## 보안과 Gatekeeper

- 이 후보는 로컬 검증용 ad-hoc signed build이며 notarized build가 아닙니다.
- Developer ID signing, hardened runtime, notarization, stapling, Gatekeeper 검증이 끝나기 전에는 public stable release로 배포하지 않습니다.
- optional 권한 도우미는 MacDog에서 명시적으로 승인한 뒤에만 \`/Library/PrivilegedHelperTools/com.dhseo.macdog.helper\`와 \`/Library/LaunchDaemons/com.dhseo.macdog.helper.plist\`를 변경합니다.

## 지원 범위

- Codex 사용량 popover와 CLI를 지원합니다.
- Mac 자원, 잠들지 않기, native Charge Limit UI를 지원합니다.
- Native Charge Limit은 Apple silicon과 macOS 26.4 이상이 필요합니다.

## 삭제

- MacDog를 종료한 뒤 \`/Applications/MacDog.app\`을 휴지통으로 옮깁니다.
- optional 권한 도우미를 설치했다면 앱을 삭제하기 전에 MacDog 설정에서 먼저 제거합니다.
- source checkout 삭제 경로도 사용할 수 있습니다: \`./script/uninstall.sh --with-helper\`
NOTES

if [[ "$CREATE_DMG" == "1" ]]; then
  rm -f "$DMG_PATH" "$CHECKSUM_PATH"
  if ! create_styled_dmg; then
    rm -f "$DMG_PATH"
    create_plain_dmg
  fi
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
