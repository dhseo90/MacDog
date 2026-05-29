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
DRY_RUN=0
SKIP_BUILD=0
CREATE_DMG=1

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

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
Install style: Docker-style drag-and-drop app installer
Drag install: drag MacDog.app to Applications, then launch MacDog.
First launch setup: MacDog creates the user codex-usage symlink, usage cache LaunchAgent, and login LaunchAgent when enabled.
Privileged helper: first launch offers MacDog-owned helper installation; Settings can install or remove it later.
Signing: local ad-hoc build only; Developer ID signing and notarization are not performed.
Gatekeeper: unsigned candidates are local validation artifacts and must not be published as public stable releases.
GitHub Release: upload DMG only after signing/notarization gate is satisfied for public distribution.
DRYRUN
  exit 0
fi

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
/usr/bin/xattr -cr "$STAGE_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
ln -s /Applications "$STAGE_DIR/Applications"

cat >"$NOTES_PATH" <<NOTES
# MacDog $VERSION Release Notes Draft

Status: unsigned local release candidate.

## Install

- Open the DMG.
- Drag \`MacDog.app\` to \`Applications\`.
- Launch MacDog from Applications.
- On first launch, MacDog finishes user-level setup by creating the terminal \`codex-usage\` symlink, the usage cache LaunchAgent, and the login LaunchAgent when enabled.
- On first launch, MacDog asks whether to install the optional privileged helper for closed-lid sleep prevention. If accepted, macOS shows an administrator approval dialog owned by MacDog.
- The optional helper can also be installed or removed later from the MacDog Settings tab.

## Security And Gatekeeper

- This candidate is ad-hoc signed for local validation and is not notarized.
- Do not publish it as a public stable release until Developer ID signing, hardened runtime, notarization, stapling, and Gatekeeper checks pass.
- The optional privileged helper changes \`/Library/PrivilegedHelperTools/com.dhseo.macdog.helper\` and \`/Library/LaunchDaemons/com.dhseo.macdog.helper.plist\` only after explicit approval from MacDog.

## Supported Scope

- Codex usage popover and CLI.
- Mac resource, sleep-prevention, and native Charge Limit UI.
- Native Charge Limit requires Apple silicon and macOS 26.4 or later.

## Uninstall

- Quit MacDog and move \`/Applications/MacDog.app\` to Trash.
- Remove the optional helper from MacDog Settings before deleting the app if you installed it.
- Source checkout uninstall path remains available: \`./script/uninstall.sh --with-helper\`
NOTES

if [[ "$CREATE_DMG" == "1" ]]; then
  rm -f "$DMG_PATH" "$CHECKSUM_PATH"
  /usr/bin/hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null
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
