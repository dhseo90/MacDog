#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/script/build_and_run.sh"
EXISTING_RUNTIME_SAMPLER="$ROOT_DIR/script/sample_existing_runtime_resources.sh"
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
require_contains "$ROOT_DIR/Sources/MacDog/FloatingPetRuntimePolicy.swift" "calmMotionTickInterval" "floating pet calm tick policy exists"
require_contains "$ROOT_DIR/Sources/MacDog/FloatingPetRuntimePolicy.swift" "activeMotionTickInterval" "floating pet active tick policy exists"
require_contains "$ROOT_DIR/Sources/MacDog/FloatingPetRuntimePolicy.swift" "fastMotionTickInterval" "floating pet fast tick policy exists"
require_contains "$ROOT_DIR/Sources/MacDog/FloatingPetController.swift" "FloatingPetRuntimePolicy.updateTimerInterval" "floating pet controller uses runtime tick policy"
require_contains "$ROOT_DIR/Sources/MacDog/FloatingPetController.swift" "FloatingPetRuntimePolicy.timerTolerance" "floating pet timer applies policy tolerance"
[[ -x "$EXISTING_RUNTIME_SAMPLER" ]] || die "missing executable runtime sampler: $EXISTING_RUNTIME_SAMPLER"
require_contains "$EXISTING_RUNTIME_SAMPLER" "This script is read-only" "existing runtime sampler declares read-only boundary"
require_contains "$EXISTING_RUNTIME_SAMPLER" "pgrep -x \"\$PROCESS_NAME\"" "existing runtime sampler targets already-running process"
require_contains "$EXISTING_RUNTIME_SAMPLER" "ps -o %cpu= -o rss=" "existing runtime sampler reads CPU and RSS"
require_contains "$EXISTING_RUNTIME_SAMPLER" "result: skipped" "existing runtime sampler can skip missing process without claiming success"
require_contains "$ROOT_DIR/Sources/MacDog/CodexUsageCacheRefreshPolicy.swift" "cacheReadTolerance" "usage cache refresh timer has coalescing tolerance"
require_contains "$ROOT_DIR/Sources/MacDog/MenuBarController.swift" "refreshTimer?.tolerance = CodexUsageCacheRefreshPolicy.cacheReadTolerance" "menu bar usage cache refresh timer applies tolerance"
require_contains "$ROOT_DIR/Sources/MacDog/PopoverMetricsRefreshPolicy.swift" "shouldRunTimer" "popover metrics timer has gating policy"
require_contains "$ROOT_DIR/Sources/MacDog/MenuBarController.swift" "updatePopoverMetricsTimer" "menu bar reconciles popover metrics timer by selected tab"
require_contains "$ROOT_DIR/Sources/MacDog/RunnerPreferences.swift" "requiresSystemMetricsForSleepPreventionTrigger" "sleep prevention preferences separate metric-based triggers"
require_contains "$ROOT_DIR/Sources/MacDog/MenuBarController.swift" "shouldCaptureBackgroundSystemMetrics" "menu bar skips unnecessary background system metrics capture"
require_contains "$ROOT_DIR/Sources/MacDog/UsageMonitorState.swift" "systemMetrics: .unavailable" "empty usage monitor state avoids implicit system metrics capture"

require_contains "$RUNTIME_DOC" "./script/build_and_run.sh --verify-runtime 10" "runtime smoke command is documented"
require_contains "$RUNTIME_DOC" "./script/build_and_run.sh --verify-floating-pet-runtime 10" "floating pet runtime smoke command is documented"
require_contains "$RUNTIME_DOC" "./script/sample_existing_runtime_resources.sh --samples 5 --interval 1" "read-only existing runtime sampler is documented"
require_contains "$RUNTIME_DOC" "CPU max가 50%를 넘으면 실패" "CPU threshold is documented"
require_contains "$RUNTIME_DOC" "RSS max가 250MB를 넘으면 실패" "RSS threshold is documented"
require_contains "$RUNTIME_DOC" "장시간 검증은 앱 실행과 사용자 환경 상태를 바꾸므로 명시 요청이 있을 때만 실행합니다." "manual long-run boundary is documented"
require_contains "$RUNTIME_DOC" "usage cache 60초 timer는 tolerance를 둡니다." "usage cache timer tolerance is documented"
require_contains "$RUNTIME_DOC" "popover 1초 local metrics timer는 Mac/Sleep/Battery 탭에서만 켭니다." "popover metrics timer gating is documented"
require_contains "$RUNTIME_DOC" "60초 usage cache refresh에서 새 system metrics snapshot을 만들지 않습니다." "background system metrics capture policy is documented"
require_contains "$RUNTIME_DOC" "calm 20fps, active 24fps, fast/sprint 30fps" "floating pet adaptive tick policy is documented"

require_contains "$ROADMAP" "script/build_and_run.sh --verify-floating-pet-runtime" "roadmap records floating pet runtime command"
require_contains "$ROADMAP" "runtime 계약은 script/verify_runtime_contract.sh로 자동 검증합니다." "roadmap records static runtime guard"

echo "Runtime verification contract ok"
