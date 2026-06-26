#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_PATH="$ROOT_DIR/.build/debug/codex-usage"
TIMEOUT_SECONDS=10

usage() {
  cat <<USAGE
usage: $0 [--cli PATH] [--timeout SECONDS]

Run codex-usage against the live Codex app-server and verify its cache result
cannot be mistaken for a valid success when the required 5-hour or weekly
windows are missing, and that successful cache writes also append weekly
history diagnostics.

This smoke accepts either:
  - a successful fetch with both 5-hour and weekly codex windows
  - a failed fetch that writes an error snapshot without an invalid success report
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cli)
      shift
      [[ $# -gt 0 ]] || die "--cli requires a path"
      CLI_PATH="$1"
      ;;
    --timeout)
      shift
      [[ $# -gt 0 ]] || die "--timeout requires a value"
      TIMEOUT_SECONDS="$1"
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

[[ -x "$CLI_PATH" ]] || die "codex-usage is not executable: $CLI_PATH"
[[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ && "$TIMEOUT_SECONDS" -gt 0 ]] || die "--timeout must be a positive integer"

tmp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-usage-fetch.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
cache_path="$tmp_dir/usage.json"
history_path="$tmp_dir/usage-weekly-history.json"
reset_window_history_path="$tmp_dir/usage-reset-window-history.json"
stdout_path="$tmp_dir/stdout.txt"
stderr_path="$tmp_dir/stderr.txt"

set +e
"$CLI_PATH" status --write-cache --cache-path "$cache_path" --timeout "$TIMEOUT_SECONDS" >"$stdout_path" 2>"$stderr_path"
status=$?
set -e

[[ -f "$cache_path" ]] || {
  cat "$stderr_path" >&2 || true
  die "codex-usage did not write a cache snapshot"
}

/usr/bin/ruby -rjson -e '
  status = Integer(ARGV.fetch(0))
  data = JSON.parse(File.read(ARGV.fetch(1)))
  report = data["report"]
  error = data["error"]

  def required_windows?(report)
    return false unless report.is_a?(Hash)
    limits = report["limits"]
    return false unless limits.is_a?(Hash)
    codex = limits["codex"] || limits.values.first
    return false unless codex.is_a?(Hash)
    windows = [codex["primary"], codex["secondary"]].compact
    has_five_hour = windows.any? { |window| window["kind"] == "fiveHour" || window["windowDurationMins"] == 300 }
    has_weekly = windows.any? { |window| window["kind"] == "weekly" || window["windowDurationMins"] == 10080 }
    has_five_hour && has_weekly
  end

  if status.zero?
    abort("successful fetch cache is missing required codex usage windows") unless required_windows?(report)
    abort("successful fetch cache should not include error") if error
    puts "usage-fetch:success"
  else
    if report && !required_windows?(report)
      abort("failed fetch preserved an invalid success report")
    end
    abort("failed fetch cache must include an error message") unless error.is_a?(Hash) && error["message"].to_s.length.positive?
    puts "usage-fetch:source-unavailable"
  end
' "$status" "$cache_path"

if [[ "$status" == "0" ]]; then
  [[ -f "$history_path" ]] || {
    cat "$stderr_path" >&2 || true
    die "successful fetch wrote cache but did not write adjacent weekly history: $history_path"
  }
  [[ -f "$reset_window_history_path" ]] || {
    cat "$stderr_path" >&2 || true
    die "successful fetch wrote cache but did not write adjacent reset window history: $reset_window_history_path"
  }
  /usr/bin/ruby -rjson -e '
    history = JSON.parse(File.read(ARGV.fetch(0)))
    samples = history["samples"]
    abort("weekly history must contain at least one sample after successful fetch") unless samples.is_a?(Array) && samples.length.positive?
    sample = samples.last
    abort("weekly history sample is missing recordedAt") unless sample["recordedAt"].is_a?(Integer)
    abort("weekly history sample is missing remainingPercent") unless sample["remainingPercent"].is_a?(Numeric)
    abort("weekly history sample is missing resetsAt") unless sample["resetsAt"].is_a?(Integer)
  ' "$history_path"
  /usr/bin/ruby -rjson -e '
    history = JSON.parse(File.read(ARGV.fetch(0)))
    records = history["records"]
    abort("reset window history must contain at least one record after successful fetch") unless records.is_a?(Array) && records.length.positive?
    record = records.last
    abort("reset window history record is missing limitId") unless record["limitId"].is_a?(String)
    abort("reset window history record is missing windowDurationMins") unless record["windowDurationMins"].is_a?(Integer)
    abort("reset window history record is missing resetsAt") unless record["resetsAt"].is_a?(Integer)
    abort("reset window history record is missing sampleCount") unless record["sampleCount"].is_a?(Integer)
    forbidden = %w[token accessToken refreshToken cookie session authorization raw response rawResponse]
    hit = record.keys & forbidden
    abort("reset window history record includes forbidden keys: #{hit.join(",")}") unless hit.empty?
  ' "$reset_window_history_path"
  /usr/bin/grep -Eq 'history append: stored recordedAt=[^[:space:]]+ recordingStartedAt=[^[:space:]]+ remaining=[^[:space:]]+ resetsAt=[^[:space:]]+ path=.*usage-weekly-history\.json' "$stderr_path" || {
    cat "$stderr_path" >&2 || true
    die "successful fetch did not emit weekly history append diagnostic"
  }
  /usr/bin/grep -Eq 'reset window history append: stored recordedAt=[^[:space:]]+ remaining=[^[:space:]]+ resetsAt=[^[:space:]]+ windowDurationMins=10080 sampleCount=[0-9]+ source=live-cache path=.*usage-reset-window-history\.json' "$stderr_path" || {
    cat "$stderr_path" >&2 || true
    die "successful fetch did not emit reset window history append diagnostic"
  }
fi

if [[ "$status" != "0" ]]; then
  /usr/bin/tail -n 20 "$stderr_path" >&2 || true
fi
