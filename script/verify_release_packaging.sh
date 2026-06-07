#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/MacDog.app"
BUILD_SCRIPT="$ROOT_DIR/script/build_and_run.sh"
PACKAGE_SCRIPT="$ROOT_DIR/script/package_release.sh"
FINAL_STATE_SCRIPT="$ROOT_DIR/script/verify_release_final_state.sh"
CLEANUP_SCRIPT="$ROOT_DIR/script/cleanup_release_smoke_state.sh"

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

require_not_matches() {
  local output="$1"
  local unexpected="$2"
  if /usr/bin/grep -Eq "$unexpected" <<<"$output"; then
    die "unexpected release packaging pattern: $unexpected"
  fi
}

require_dmg_background_dimensions() {
  local image_path="$1"
  local info width height
  info="$(/usr/bin/sips -g pixelWidth -g pixelHeight "$image_path" 2>/dev/null)"
  width="$(/usr/bin/awk '/pixelWidth:/ { print $2 }' <<<"$info")"
  height="$(/usr/bin/awk '/pixelHeight:/ { print $2 }' <<<"$info")"
  case "${width}x${height}" in
    760x430|1520x860)
      return 0
      ;;
  esac
  die "unexpected DMG background dimensions: ${width:-missing}x${height:-missing}"
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

script_source="$(cat "$PACKAGE_SCRIPT")"
build_script_source="$(cat "$BUILD_SCRIPT")"
require_not_contains "$script_source" "stagingBounds"
require_not_contains "$script_source" "-12000"
require_not_contains "$script_source" "-11240"
require_not_contains "$script_source" "-11570"
require_not_contains "$script_source" "create_plain_dmg"
require_not_contains "$script_source" "if ! create_styled_dmg"
require_contains "$build_script_source" 'APP_VERSION="${MACDOG_APP_VERSION:-${MACDOG_RELEASE_VERSION:-}}"'
require_contains "$build_script_source" '<string>$APP_VERSION</string>'
require_contains "$build_script_source" '<string>$APP_BUILD</string>'
require_contains "$build_script_source" 'app version required; pass --version VERSION or set MACDOG_APP_VERSION/MACDOG_RELEASE_VERSION'
require_not_matches "$script_source" 'MACDOG_RELEASE_VERSION:-[^}]'
require_contains "$script_source" 'release version required; pass --version VERSION or set MACDOG_RELEASE_VERSION'
require_contains "$script_source" 'MACDOG_RELEASE_VERSION="$VERSION" MACDOG_APP_VERSION="$VERSION"'
require_contains "$script_source" 'verify_app_bundle_version "$APP_BUNDLE" "$VERSION"'
require_contains "$script_source" 'wait_for_dmg_finder_metadata "$mountpoint/.DS_Store"'
require_contains "$script_source" 'mountpoint="/Volumes/$volume_name"'
require_contains "$script_source" 'release DMG mountpoint already exists; eject it before packaging'
require_contains "$script_source" 'LC_ALL=C /usr/bin/grep -aq "icvp" "$ds_store"'
require_contains "$script_source" "MacDog를 Applications 폴더로 드래그하세요"
require_contains "$script_source" "드래그 후 Applications에서 MacDog를 실행하세요"
[[ -x "$FINAL_STATE_SCRIPT" ]] || die "release final state verifier missing or not executable: $FINAL_STATE_SCRIPT"
[[ -x "$CLEANUP_SCRIPT" ]] || die "release smoke cleanup script missing or not executable: $CLEANUP_SCRIPT"
"$FINAL_STATE_SCRIPT" --self-test
"$CLEANUP_SCRIPT" --self-test

output="$(MACDOG_RELEASE_VERSION=9.9.9 "$PACKAGE_SCRIPT" --dry-run)"
require_contains "$output" "MacDog release package dry run"
require_contains "$output" "Version: 9.9.9"
require_contains "$output" "Docker-style drag-and-drop app installer"
require_contains "$output" "MacDog.app (includes bundled codex-usage)"
require_contains "$output" "Applications symlink"
require_contains "$output" "Widget extension: omitted by default"
require_contains "$output" "Widget setup: default release omits WidgetKit"
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
require_contains "$output" "excluded from the current implementation plan"
require_contains "$output" "GitHub Release: upload DMG with checksum and release notes that state the notarization status"
require_not_contains "$output" "Install MacDog.command"
require_not_contains "$output" "Uninstall MacDog.command"
require_not_contains "$output" "Check Install Status.command"
require_not_contains "$output" "README_FIRST.txt"
require_not_contains "$output" "RELEASE_NOTES_DRAFT.md"
require_not_contains "$output" "Privileged Helper.command"

if [[ -d "$APP_BUNDLE" && -n "${MACDOG_RELEASE_VERSION:-}" ]]; then
  version="$MACDOG_RELEASE_VERSION"
  stage="$ROOT_DIR/dist/release/MacDog-$version"
  dmg_path="$ROOT_DIR/dist/release/MacDog-$version.dmg"
  checksum_path="$dmg_path.sha256"
  notes_path="$ROOT_DIR/dist/release/MacDog-$version-release-notes.md"
  trap 'rm -rf "$stage"; rm -f "$dmg_path" "$checksum_path" "$notes_path"' EXIT

  stage_output="$(MACDOG_RELEASE_VERSION="$version" "$PACKAGE_SCRIPT" --skip-build --no-dmg)"
  require_contains "$stage_output" "$stage"
  require_contains "$stage_output" "$notes_path"
  [[ -d "$stage/MacDog.app" ]] || die "staged app bundle missing: $stage/MacDog.app"
  [[ -L "$stage/Applications" ]] || die "staged Applications symlink missing"
  [[ "$(readlink "$stage/Applications")" == "/Applications" ]] || die "staged Applications symlink must point to /Applications"
  [[ -f "$stage/.background/background.png" ]] || die "staged DMG background missing"
  require_dmg_background_dimensions "$stage/.background/background.png"
  [[ -x "$stage/MacDog.app/Contents/MacOS/codex-usage" ]] || die "bundled CLI missing or not executable"
  [[ -f "$stage/MacDog.app/Contents/Resources/MacDog.icns" ]] || die "staged app icon missing"
  [[ ! -e "$stage/MacDog.app/Contents/PlugIns/MacDogWidgetExtension.appex" ]] || die "default release stage must not include WidgetKit extension"
  [[ ! -e "$stage/bin/codex-usage" ]] || die "staged standalone CLI must not exist"
  assert_no_legacy_payload "$stage"

  [[ -f "$notes_path" ]] || die "release notes missing: $notes_path"
  /usr/bin/grep -Fq "\`MacDog.app\`을 \`Applications\`로 드래그" "$notes_path" || die "release notes drag install copy missing"
  /usr/bin/grep -Fq "첫 실행" "$notes_path" || die "release notes first launch setup missing"
  /usr/bin/grep -Fq "다운로드한 설치 파일을 정리" "$notes_path" || die "release notes cleanup copy missing"
  /usr/bin/grep -Fq "MacDog 주체의 관리자 승인창" "$notes_path" || die "release notes helper approval copy missing"
  /usr/bin/grep -Fq "WidgetKit 위젯은 기본 DMG에 포함하지 않습니다" "$notes_path" || die "release notes widget opt-in boundary missing"
  /usr/bin/grep -Fq "현재 구현 계획에서 제외합니다" "$notes_path" || die "release notes Apple Developer exclusion missing"
  /usr/bin/grep -Fq "notarized" "$notes_path" || die "release notes notarization gate missing"
  if /usr/bin/grep -Eq 'Install MacDog\.command|Uninstall MacDog\.command|Check Install Status\.command|README_FIRST|RELEASE_NOTES_DRAFT' "$notes_path"; then
    die "release notes must not reference legacy command payloads"
  fi

  rm -rf "$stage"
  rm -f "$dmg_path" "$checksum_path"
  MACDOG_RELEASE_VERSION="$version" "$PACKAGE_SCRIPT" --skip-build >/dev/null
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
  [[ ! -e "$mountpoint/MacDog.app/Contents/PlugIns/MacDogWidgetExtension.appex" ]] || die "default release DMG must not include WidgetKit extension"
  LC_ALL=C /usr/bin/grep -aq "icvp" "$mountpoint/.DS_Store" || die "release DMG Finder icon view options missing"
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
  if [[ -d "$APP_BUNDLE" ]]; then
    echo "Release packaging artifact verification skipped: MACDOG_RELEASE_VERSION is not set"
  else
    echo "Release packaging stage verification skipped: dist/MacDog.app missing"
  fi
fi

echo "Release packaging verification ok"
