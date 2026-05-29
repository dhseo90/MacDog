#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/script/build_and_run.sh"
RUNTIME_DOC="$ROOT_DIR/Docs/RuntimeVerification.md"
ROADMAP="$ROOT_DIR/ROADMAP.md"

die() {
  echo "error: $*" >&2
  exit 1
}

require_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  grep -Fq -- "$needle" "$file" || die "missing runtime contract text: $label"
}

require_contains "$BUILD_SCRIPT" "--verify-runtime [SECONDS]" "menu bar runtime mode appears in usage"
require_contains "$BUILD_SCRIPT" "--verify-floating-pet-runtime [SECONDS]" "floating pet runtime mode appears in usage"
require_contains "$BUILD_SCRIPT" "sample_runtime_resources \"\$duration\" \"Runtime\"" "menu bar runtime samples CPU/RSS"
require_contains "$BUILD_SCRIPT" "sample_runtime_resources \"\$duration\" \"Floating pet runtime\"" "floating pet runtime samples CPU/RSS"
require_contains "$BUILD_SCRIPT" "ps -o %cpu= -o rss=" "runtime sampler reads CPU and RSS"
require_contains "$BUILD_SCRIPT" "max_cpu > 50 || max_rss > 250000" "runtime sampler enforces CPU/RSS thresholds"
require_contains "$BUILD_SCRIPT" "trap restore_desktop_pet_default EXIT" "floating pet preference is restored"
require_contains "$BUILD_SCRIPT" "defaults write \"\$BUNDLE_ID\" desktopPetEnabled -bool true" "floating pet runtime mode enables desktop pet"

require_contains "$RUNTIME_DOC" "./script/build_and_run.sh --verify-runtime 10" "runtime smoke command is documented"
require_contains "$RUNTIME_DOC" "./script/build_and_run.sh --verify-floating-pet-runtime 10" "floating pet runtime smoke command is documented"
require_contains "$RUNTIME_DOC" "CPU max가 50%를 넘으면 실패" "CPU threshold is documented"
require_contains "$RUNTIME_DOC" "RSS max가 250MB를 넘으면 실패" "RSS threshold is documented"
require_contains "$RUNTIME_DOC" "장시간 검증은 앱 실행과 사용자 환경 상태를 바꾸므로 명시 요청이 있을 때만 실행합니다." "manual long-run boundary is documented"

require_contains "$ROADMAP" "script/build_and_run.sh --verify-floating-pet-runtime" "roadmap records floating pet runtime command"
require_contains "$ROADMAP" "runtime 계약은 script/verify_runtime_contract.sh로 자동 검증합니다." "roadmap records static runtime guard"

echo "Runtime verification contract ok"
