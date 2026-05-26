#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER_DIR="$ROOT_DIR/Sources/CodexUsageMonitor/Resources/Runner"
EXPECTED_COUNT=8
EXPECTED_WIDTH=80
EXPECTED_HEIGHT=48

actual_count="$(find "$RUNNER_DIR" -maxdepth 1 -name 'pup-runner-*.png' | wc -l | awk '{$1=$1; print}')"
if [[ "$actual_count" != "$EXPECTED_COUNT" ]]; then
  echo "Expected $EXPECTED_COUNT pup runner frames, found $actual_count" >&2
  exit 1
fi

for index in $(seq 0 $((EXPECTED_COUNT - 1))); do
  file="$RUNNER_DIR/pup-runner-$index.png"
  if [[ ! -f "$file" ]]; then
    echo "Missing runner frame: $file" >&2
    exit 1
  fi

  width="$(sips -g pixelWidth "$file" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
  height="$(sips -g pixelHeight "$file" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"

  if [[ "$width" != "$EXPECTED_WIDTH" || "$height" != "$EXPECTED_HEIGHT" ]]; then
    echo "Unexpected size for $file: ${width}x${height}, expected ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}" >&2
    exit 1
  fi
done

echo "Runner baseline ok: $EXPECTED_COUNT frames, ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}px"
