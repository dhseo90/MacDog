#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$ROOT_DIR/Tests/CodexUsageCoreTests/Fixtures/rate_limits_response.json"
SELF_TEST=0

usage() {
  cat <<USAGE
usage: $0 [--fixture PATH] [--self-test]

Verify the local Codex app-server protocol drift guardrails. This script does
not start codex app-server and does not read Codex auth files. It validates the
rateLimits fixture contract and checks that schema/protocol failure guidance
keeps raw app-server payloads and auth material out of logs.

Options:
  --fixture PATH  Validate a captured, redacted account/rateLimits/read result.
  --self-test     Validate parser tolerance with a temporary additive fixture.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

require_text() {
  local pattern="$1"
  local file="$2"
  local description="$3"
  /usr/bin/grep -Eq -- "$pattern" "$file" || die "missing $description in $file"
}

validate_fixture() {
  local fixture="$1"
  require_file "$fixture"

  /usr/bin/ruby -rjson - "$fixture" <<'RUBY'
path = ARGV.fetch(0)
data = JSON.parse(File.read(path))
top = data.fetch("rateLimits")
by_id = data.fetch("rateLimitsByLimitId")
codex = by_id.fetch("codex") { top }

required_bucket_keys = %w[primary secondary credits planType rateLimitReachedType]
missing = required_bucket_keys.reject { |key| codex.key?(key) }
abort("missing codex bucket keys: #{missing.join(",")}") unless missing.empty?

primary = codex.fetch("primary")
secondary = codex.fetch("secondary")
durations = [primary.fetch("windowDurationMins"), secondary.fetch("windowDurationMins")]
abort("expected 300 and 10080 minute windows, got #{durations.inspect}") unless durations.include?(300) && durations.include?(10_080)

[primary, secondary].each do |window|
  abort("usedPercent must be numeric") unless window.fetch("usedPercent").is_a?(Numeric)
  abort("resetsAt key missing") unless window.key?("resetsAt")
end

credits = codex.fetch("credits")
%w[hasCredits unlimited balance].each do |key|
  abort("credits.#{key} missing") unless credits.key?(key)
end

extra_buckets = by_id.keys - ["codex"]
puts "app-server-protocol-drift:fixture-ok codex-window-durations=#{durations.join(",")} extraBuckets=#{extra_buckets.sort.join(",")}"
RUBY
}

validate_source_guards() {
  require_text 'rateLimitsByLimitId\?\["codex"\][[:space:]]*\?\?[[:space:]]*rateLimits' "$ROOT_DIR/Sources/CodexUsageCore/Models/RateLimitModels.swift" "codex bucket fallback"
  require_text 'case 300:' "$ROOT_DIR/Sources/CodexUsageCore/Models/RateLimitModels.swift" "5-hour duration mapping"
  require_text 'case 10_080:' "$ROOT_DIR/Sources/CodexUsageCore/Models/RateLimitModels.swift" "weekly duration mapping"
  require_text 'schema may have changed' "$ROOT_DIR/Sources/CodexUsageCore/Usage/CodexUsageFailureGuide.swift" "schema drift guidance"
  require_text 'protocol may have changed' "$ROOT_DIR/Sources/CodexUsageCore/Usage/CodexUsageFailureGuide.swift" "protocol drift guidance"
  require_text 'Do not paste auth tokens or raw app-server payloads' "$ROOT_DIR/Sources/CodexUsageCore/Usage/CodexUsageFailureGuide.swift" "raw payload redaction guidance"
  require_text 'proxyArguments = \["app-server", "proxy"\]' "$ROOT_DIR/Sources/CodexUsageCore/AppServer/CodexAppServerClient.swift" "Codex app-server proxy transport candidate"
  require_text 'daemon", "version"' "$ROOT_DIR/Sources/CodexUsageCore/AppServer/CodexAppServerClient.swift" "Codex app-server daemon availability probe"
  require_text 'daemonAvailable' "$ROOT_DIR/Tests/CodexUsageCoreTests/CodexAppServerClientTests.swift" "Codex app-server transport drift tests"
  require_text 'rate_limits_response' "$ROOT_DIR/Tests/CodexUsageCoreTests/RateLimitModelsTests.swift" "rate limit fixture test"
  require_text 'codex_bengalfox' "$ROOT_DIR/Tests/CodexUsageCoreTests/RateLimitModelsTests.swift" "advanced bucket fixture assertion"
  require_text 'without inspecting ~/.codex/auth.json' "$ROOT_DIR/Tests/CodexUsageCoreTests/CodexUsageFailureGuideTests.swift" "auth file avoidance test"
  require_text 'account/rateLimits/read' "$ROOT_DIR/README.md" "README data source contract"
  require_text 'live app-server protocol drift' "$ROOT_DIR/ROADMAP.md" "roadmap drift boundary"
}

verify_drift_guards() {
  validate_fixture "$FIXTURE"
  validate_source_guards
  echo "app-server-protocol-drift:source-guards-ok"
  echo "app-server-protocol-drift:transport-guards-ok legacy app-server and daemon-backed proxy are both accounted for"
  echo "app-server-protocol-drift:live-call-not-run"
  echo "app-server-protocol-drift:redaction-boundary no auth token, raw app-server payload, cookie, or session material is required"
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-app-server-drift.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local fixture="$temp_dir/rate_limits_additive.json"
  local output_file="$temp_dir/output.txt"
  cat >"$fixture" <<'FIXTURE'
{
  "rateLimits": {
    "limitId": "legacy",
    "limitName": "Legacy",
    "primary": { "usedPercent": 20, "windowDurationMins": 300, "resetsAt": 1780000000 },
    "secondary": { "usedPercent": 40, "windowDurationMins": 10080, "resetsAt": 1780500000 },
    "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
    "planType": "pro",
    "rateLimitReachedType": null
  },
  "rateLimitsByLimitId": {
    "codex": {
      "limitId": "codex",
      "limitName": "Codex",
      "primary": { "usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1780000000, "newServerField": "ignored" },
      "secondary": { "usedPercent": 34, "windowDurationMins": 10080, "resetsAt": 1780500000 },
      "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
      "planType": "pro",
      "rateLimitReachedType": null,
      "futureBucketMetadata": { "ignored": true }
    },
    "codex_bengalfox": {
      "limitId": "codex_bengalfox",
      "limitName": "Advanced",
      "primary": { "usedPercent": 1, "windowDurationMins": 300, "resetsAt": 1780000000 },
      "secondary": { "usedPercent": 2, "windowDurationMins": 10080, "resetsAt": 1780500000 },
      "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
      "planType": "pro",
      "rateLimitReachedType": null
    }
  },
  "futureTopLevelField": "ignored"
}
FIXTURE

  "$0" --fixture "$fixture" >"$output_file"
  require_text 'app-server-protocol-drift:fixture-ok codex-window-durations=300,10080 extraBuckets=codex_bengalfox' "$output_file" "additive fixture summary"
  require_text 'app-server-protocol-drift:source-guards-ok' "$output_file" "source guard summary"
  require_text 'app-server-protocol-drift:transport-guards-ok' "$output_file" "transport guard summary"
  require_text 'app-server-protocol-drift:live-call-not-run' "$output_file" "live call boundary"
  require_text 'redaction-boundary' "$output_file" "redaction boundary"

  echo "Codex app-server protocol drift self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture)
      shift
      [[ $# -gt 0 ]] || die "--fixture requires a path"
      FIXTURE="$1"
      ;;
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

verify_drift_guards
