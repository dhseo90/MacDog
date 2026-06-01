#!/usr/bin/env bash
set -euo pipefail

PROCESS_NAME="MacDog"
PID=""
SAMPLES=5
INTERVAL_SECONDS=1
CPU_THRESHOLD=50
RSS_THRESHOLD_MIB=250
REPORT_PATH=""
ALLOW_NOT_RUNNING=0
SELF_TEST=0

usage() {
  cat <<USAGE
usage: $0 [--samples N] [--interval SECONDS] [--process-name NAME|--pid PID] [--report PATH]
       $0 --duration SECONDS
       $0 --self-test

Sample CPU/RSS for an already-running process. The default target is MacDog.
This script is read-only: it does not build, launch, quit, install, uninstall,
register LaunchAgents, codesign, notarize, run Gatekeeper checks, or change
MacDog preferences.

Options:
  --samples N              Number of samples. Default: 5.
  --interval SECONDS       Delay between samples. Default: 1.
  --duration SECONDS       Shorthand for --samples SECONDS --interval 1.
  --process-name NAME      Process name to find with pgrep -x. Default: MacDog.
  --pid PID                Sample a specific process id.
  --cpu-threshold PERCENT  Fail if max CPU is above this value. Default: 50.
  --rss-threshold-mib MIB  Fail if max RSS is above this value. Default: 250.
  --report PATH            Write the summary to PATH in addition to stdout.
  --allow-not-running      Exit 0 with a skipped summary when the process is absent.
  --self-test              Validate sampler behavior without requiring MacDog.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

is_positive_integer() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( 10#$1 > 0 ))
}

is_non_negative_number() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

is_positive_number() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]] && /usr/bin/awk -v value="$1" 'BEGIN { exit !(value > 0) }'
}

find_target_pid() {
  if [[ -n "$PID" ]]; then
    /bin/kill -0 "$PID" >/dev/null 2>&1 || die "process id is not running: $PID"
    return 0
  fi

  PID="$(/usr/bin/pgrep -x "$PROCESS_NAME" | /usr/bin/head -n 1 || true)"
  if [[ -z "$PID" ]]; then
    if [[ "$ALLOW_NOT_RUNNING" == "1" ]]; then
      cat <<SKIPPED
runtime resource sample
processName: $PROCESS_NAME
result: skipped
reason: process not running
SKIPPED
      exit 0
    fi
    die "process not running: $PROCESS_NAME"
  fi
}

sample_process() {
  is_positive_integer "$SAMPLES" || die "--samples must be a positive integer: $SAMPLES"
  is_non_negative_number "$INTERVAL_SECONDS" || die "--interval must be a non-negative number: $INTERVAL_SECONDS"
  is_positive_number "$CPU_THRESHOLD" || die "--cpu-threshold must be positive: $CPU_THRESHOLD"
  is_positive_number "$RSS_THRESHOLD_MIB" || die "--rss-threshold-mib must be positive: $RSS_THRESHOLD_MIB"

  find_target_pid

  local process_path
  process_path="$(/bin/ps -o comm= -p "$PID" | /usr/bin/awk '{$1=$1; print}')"

  local samples=()
  local cpu
  local rss
  local line
  local i
  for ((i = 0; i < SAMPLES; i++)); do
    line="$(/bin/ps -o %cpu= -o rss= -p "$PID" | /usr/bin/awk 'NF >= 2 { print $1, $2 }')"
    [[ -n "$line" ]] || die "process disappeared while sampling: $PID"
    read -r cpu rss <<<"$line"
    samples+=("$cpu $rss")
    if (( i + 1 < SAMPLES )); then
      /bin/sleep "$INTERVAL_SECONDS"
    fi
  done

  local summary
  local status
  set +e
  summary="$(printf "%s\n" "${samples[@]}" | /usr/bin/awk \
    -v process_name="$PROCESS_NAME" \
    -v pid="$PID" \
    -v process_path="$process_path" \
    -v samples="$SAMPLES" \
    -v interval="$INTERVAL_SECONDS" \
    -v cpu_threshold="$CPU_THRESHOLD" \
    -v rss_threshold_mib="$RSS_THRESHOLD_MIB" '
      NR == 1 || $1 > max_cpu { max_cpu = $1 }
      NR == 1 || $2 > max_rss { max_rss = $2 }
      { sum_cpu += $1; sum_rss += $2 }
      END {
        if (NR == 0) {
          exit 2
        }
        avg_cpu = sum_cpu / NR
        avg_rss_mib = (sum_rss / NR) / 1024
        max_rss_mib = max_rss / 1024
        passed = (max_cpu <= cpu_threshold && max_rss_mib <= rss_threshold_mib)
        printf("runtime resource sample\n")
        printf("processName: %s\n", process_name)
        printf("pid: %s\n", pid)
        printf("processPath: %s\n", process_path)
        printf("samples: %d\n", samples)
        printf("intervalSeconds: %s\n", interval)
        printf("cpuAvgPercent: %.2f\n", avg_cpu)
        printf("cpuMaxPercent: %.2f\n", max_cpu)
        printf("rssAvgMiB: %.1f\n", avg_rss_mib)
        printf("rssMaxMiB: %.1f\n", max_rss_mib)
        printf("thresholds: cpuMax<=%.2f rssMaxMiB<=%.1f\n", cpu_threshold, rss_threshold_mib)
        printf("result: %s\n", passed ? "pass" : "fail")
        exit passed ? 0 : 1
      }
    ')"
  status=$?
  set -e

  printf "%s\n" "$summary"
  if [[ -n "$REPORT_PATH" ]]; then
    printf "%s\n" "$summary" >"$REPORT_PATH"
  fi
  return "$status"
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-runtime-sample.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local report="$temp_dir/report.txt"
  "$0" --pid "$$" --samples 1 --interval 0 --report "$report" >/dev/null
  /usr/bin/grep -Fq "result: pass" "$report" || die "self-test report did not pass"
  /usr/bin/grep -Fq "pid: $$" "$report" || die "self-test report did not sample current shell"

  "$0" --process-name "MacDogSamplerSelfTestMissing" --allow-not-running >/dev/null
  if "$0" --process-name "MacDogSamplerSelfTestMissing" >/dev/null 2>&1; then
    die "self-test missing process unexpectedly passed"
  fi

  echo "existing runtime resource sampler self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --samples)
      [[ $# -ge 2 ]] || die "--samples requires a value"
      SAMPLES="$2"
      shift
      ;;
    --interval)
      [[ $# -ge 2 ]] || die "--interval requires a value"
      INTERVAL_SECONDS="$2"
      shift
      ;;
    --duration)
      [[ $# -ge 2 ]] || die "--duration requires a value"
      is_positive_integer "$2" || die "--duration must be a positive integer: $2"
      SAMPLES="$2"
      INTERVAL_SECONDS=1
      shift
      ;;
    --process-name)
      [[ $# -ge 2 ]] || die "--process-name requires a value"
      PROCESS_NAME="$2"
      shift
      ;;
    --pid)
      [[ $# -ge 2 ]] || die "--pid requires a value"
      [[ "$2" =~ ^[0-9]+$ ]] || die "--pid must be an integer: $2"
      PID="$2"
      shift
      ;;
    --cpu-threshold)
      [[ $# -ge 2 ]] || die "--cpu-threshold requires a value"
      CPU_THRESHOLD="$2"
      shift
      ;;
    --rss-threshold-mib)
      [[ $# -ge 2 ]] || die "--rss-threshold-mib requires a value"
      RSS_THRESHOLD_MIB="$2"
      shift
      ;;
    --report)
      [[ $# -ge 2 ]] || die "--report requires a path"
      REPORT_PATH="$2"
      shift
      ;;
    --allow-not-running) ALLOW_NOT_RUNNING=1 ;;
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

if [[ "$SELF_TEST" == "1" ]]; then
  run_self_test
  exit 0
fi

sample_process
