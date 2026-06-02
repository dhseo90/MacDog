#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELF_TEST=0

usage() {
  cat <<USAGE
usage: $0 [--self-test]

Verify Codex Pup character asset polish boundaries without launching the GUI.
This checks profile ownership, runner baseline, desktop-pet/tab PNG dimensions
and alpha channels, tab artwork manifest linkage, and README image hygiene/freshness.

Options:
  --self-test  Run the same read-only checks and validate summary output.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_text() {
  local pattern="$1"
  local file="$2"
  local description="$3"
  /usr/bin/grep -Eq -- "$pattern" "$file" || die "missing $description in $file"
}

verify_polish() {
  "$ROOT_DIR/script/verify_character_profile.sh" >/dev/null
  "$ROOT_DIR/script/verify_runner_baseline.sh" >/dev/null
  "$ROOT_DIR/script/verify_readme_screenshots.sh" >/dev/null

  require_text 'Codex Pup' "$ROOT_DIR/README.md" "Codex Pup README identity"
  require_text 'MacDogCharacterProfile\.codexPup' "$ROOT_DIR/Docs/RunnerBaseline.md" "runner baseline profile identity"
  require_text '같은 캐릭터 세트|하나의 캐릭터 프로필' "$ROOT_DIR/ROADMAP.md" "roadmap one-character-set boundary"
  require_text 'RunCat의 고양이 캐릭터를 그대로 복제하지 않습니다' "$ROOT_DIR/ROADMAP.md" "RunCat asset non-copy boundary"

  echo "character-asset-polish:profile-ok Codex Pup owns runner desktop-pet and popover tab assets"
  echo "character-asset-polish:png-contract-ok runner=8x80x48 desktop=40x192x204 tabs=5x256x256 alpha=yes"
  echo "character-asset-polish:readme-image-hygiene-ok"
  echo "character-asset-polish:ui-not-run menu bar runner desktop pet popover tabs and settings preview were not opened by this verifier"
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-character-polish.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local output_file="$temp_dir/output.txt"
  verify_polish >"$output_file"
  require_text 'character-asset-polish:profile-ok' "$output_file" "profile summary"
  require_text 'character-asset-polish:png-contract-ok' "$output_file" "PNG contract summary"
  require_text 'alpha=yes' "$output_file" "alpha summary"
  require_text 'character-asset-polish:ui-not-run' "$output_file" "UI not run boundary"
  echo "character asset polish self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test) SELF_TEST=1 ;;
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

cd "$ROOT_DIR"

if [[ "$SELF_TEST" == "1" ]]; then
  run_self_test
  exit 0
fi

verify_polish
