#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/MacDog.app"

die() {
  echo "error: $*" >&2
  exit 1
}

require_contains() {
  local output="$1"
  local expected="$2"
  if [[ "$output" != *"$expected"* ]]; then
    die "missing expected release packaging text: $expected"
  fi
}

require_matches() {
  local output="$1"
  local expected="$2"
  if ! /usr/bin/grep -Eq "$expected" <<<"$output"; then
    die "missing expected release packaging pattern: $expected"
  fi
}

require_not_contains() {
  local output="$1"
  local unexpected="$2"
  if [[ "$output" == *"$unexpected"* ]]; then
    die "unexpected release packaging text: $unexpected"
  fi
}

assert_no_legacy_payload() {
  local stage="$1"
  [[ ! -e "$stage/Install MacDog.command" ]] || die "legacy installer command must not be staged"
  [[ ! -e "$stage/Uninstall MacDog.command" ]] || die "legacy uninstaller command must not be staged"
  [[ ! -e "$stage/Check Install Status.command" ]] || die "legacy status command must not be staged"
  [[ ! -e "$stage/README_FIRST.txt" ]] || die "legacy README_FIRST must not be staged"
  [[ ! -e "$stage/RELEASE_NOTES_DRAFT.md" ]] || die "legacy release notes draft must not be staged"
  [[ ! -e "$stage/Install Privileged Helper.command" ]] || die "legacy helper installer command must not be staged"
  [[ ! -e "$stage/Uninstall Privileged Helper.command" ]] || die "legacy helper uninstaller command must not be staged"
  if find "$stage" -maxdepth 1 -type f -name '*.command' -print -quit | /usr/bin/grep -q .; then
    die "release DMG must not stage .command files"
  fi
}

output="$("$ROOT_DIR/script/package_release.sh" --dry-run)"
require_contains "$output" "MacDog release package dry run"
require_contains "$output" "Docker-style drag-and-drop app installer"
require_contains "$output" "MacDog.app (includes bundled codex-usage)"
require_contains "$output" "Applications symlink"
require_contains "$output" "Drag install: drag MacDog.app to Applications"
require_contains "$output" "DMG layout:"
require_contains "$output" "Window: 760x430"
require_contains "$output" "Icon size: 150"
require_contains "$output" "MacDog.app position: {190, 225}"
require_contains "$output" "Applications position: {570, 225}"
require_contains "$output" "First launch setup:"
require_contains "$output" "user codex-usage symlink"
require_contains "$output" "usage cache LaunchAgent"
require_contains "$output" "macOS Login Item when enabled"
require_contains "$output" "Hidden DMG background artwork"
require_contains "$output" "First launch cleanup:"
require_contains "$output" "Privileged helper: first launch offers MacDog-owned helper installation"
require_contains "$output" "Developer ID signing and notarization are not performed"
require_contains "$output" "GitHub Release: upload DMG with checksum and release notes that state the notarization status"
require_not_contains "$output" "Install MacDog.command"
require_not_contains "$output" "Uninstall MacDog.command"
require_not_contains "$output" "Check Install Status.command"
require_not_contains "$output" "README_FIRST.txt"
require_not_contains "$output" "RELEASE_NOTES_DRAFT.md"
require_not_contains "$output" "Privileged Helper.command"

if [[ -d "$APP_BUNDLE" ]]; then
  version="verify"
  stage="$ROOT_DIR/dist/release/MacDog-$version"
  dmg_path="$ROOT_DIR/dist/release/MacDog-$version.dmg"
  checksum_path="$dmg_path.sha256"
  notes_path="$ROOT_DIR/dist/release/MacDog-$version-release-notes.md"
  trap 'rm -rf "$stage"; rm -f "$dmg_path" "$checksum_path" "$notes_path"' EXIT

  stage_output="$(MACDOG_RELEASE_VERSION="$version" "$ROOT_DIR/script/package_release.sh" --skip-build --no-dmg)"
  require_contains "$stage_output" "$stage"
  require_contains "$stage_output" "$notes_path"
  [[ -d "$stage/MacDog.app" ]] || die "staged app bundle missing: $stage/MacDog.app"
  [[ -L "$stage/Applications" ]] || die "staged Applications symlink missing"
  [[ "$(readlink "$stage/Applications")" == "/Applications" ]] || die "staged Applications symlink must point to /Applications"
  [[ -f "$stage/.background/background.png" ]] || die "staged DMG background missing"
  background_info="$(/usr/bin/sips -g pixelWidth -g pixelHeight "$stage/.background/background.png" 2>/dev/null)"
  require_matches "$background_info" "pixelWidth:[[:space:]]+1520"
  require_matches "$background_info" "pixelHeight:[[:space:]]+860"
  [[ -x "$stage/MacDog.app/Contents/MacOS/codex-usage" ]] || die "bundled CLI missing or not executable"
  [[ -f "$stage/MacDog.app/Contents/Resources/MacDog.icns" ]] || die "staged app icon missing"
  [[ ! -e "$stage/bin/codex-usage" ]] || die "staged standalone CLI must not exist"
  assert_no_legacy_payload "$stage"

  [[ -f "$notes_path" ]] || die "release notes missing: $notes_path"
  /usr/bin/grep -Fq "\`MacDog.app\`을 \`Applications\`로 드래그" "$notes_path" || die "release notes drag install copy missing"
  /usr/bin/grep -Fq "첫 실행" "$notes_path" || die "release notes first launch setup missing"
  /usr/bin/grep -Fq "다운로드한 설치 파일을 정리" "$notes_path" || die "release notes cleanup copy missing"
  /usr/bin/grep -Fq "MacDog 주체의 관리자 승인창" "$notes_path" || die "release notes helper approval copy missing"
  /usr/bin/grep -Fq "notarized" "$notes_path" || die "release notes notarization gate missing"
  if /usr/bin/grep -Eq 'Install MacDog\.command|Uninstall MacDog\.command|Check Install Status\.command|README_FIRST|RELEASE_NOTES_DRAFT' "$notes_path"; then
    die "release notes must not reference legacy command payloads"
  fi

  rm -rf "$stage"
  rm -f "$dmg_path" "$checksum_path"
  MACDOG_RELEASE_VERSION="$version" "$ROOT_DIR/script/package_release.sh" --skip-build >/dev/null
  [[ -f "$dmg_path" ]] || die "release DMG missing after package generation"
  [[ -f "$checksum_path" ]] || die "release checksum missing after package generation"
  checksum_line="$(cat "$checksum_path")"
  [[ "$checksum_line" == *"  MacDog-$version.dmg" ]] || die "checksum file must use DMG basename"
  [[ "$checksum_line" != *"$ROOT_DIR"* ]] || die "checksum file must not contain build-machine absolute path"
  (
    cd "$ROOT_DIR/dist/release"
    /usr/bin/shasum -a 256 -c "$(basename "$checksum_path")" >/dev/null
  )
  /usr/bin/hdiutil verify "$dmg_path" >/dev/null
  mountpoint="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-release-verify-mount.XXXXXX")"
  /usr/bin/hdiutil attach "$dmg_path" -mountpoint "$mountpoint" -noautoopen >/dev/null
  cleanup_mount() {
    /usr/bin/hdiutil detach "$mountpoint" >/dev/null 2>&1 || true
    rm -rf "$mountpoint"
  }
  trap 'cleanup_mount; rm -rf "$stage"; rm -f "$dmg_path" "$checksum_path" "$notes_path"' EXIT
  [[ -d "$mountpoint/MacDog.app" ]] || die "release DMG app missing after mount"
  [[ -L "$mountpoint/Applications" ]] || die "release DMG Applications symlink missing after mount"
  [[ -f "$mountpoint/.background/background.png" ]] || die "release DMG background missing after mount"
  /usr/bin/strings -a "$mountpoint/.DS_Store" | /usr/bin/grep -Fq ".icvp" || die "release DMG Finder icon view options missing"
  if /usr/bin/find "$mountpoint/MacDog.app" -exec /bin/sh -c '
for path do
  if /usr/bin/xattr -p com.apple.FinderInfo "$path" >/dev/null 2>&1; then
    printf "%s\n" "$path"
  fi
done
' sh {} + | /usr/bin/grep -q .; then
    die "release DMG app contains forbidden com.apple.FinderInfo xattr"
  fi
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$mountpoint/MacDog.app" >/dev/null
  cleanup_mount
  trap 'rm -rf "$stage"; rm -f "$dmg_path" "$checksum_path" "$notes_path"' EXIT
else
  echo "Release packaging stage verification skipped: dist/MacDog.app missing"
fi

echo "Release packaging verification ok"
