#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JSON_REPORT="$ROOT_DIR/Docs/V110ManualEvidence.json"
OUTPUT="$ROOT_DIR/Docs/V110ManualEvidence.md"
MODE="check"

usage() {
  cat <<USAGE
usage: $0 [--check|--write|--self-test] [--json PATH] [--output PATH]

Render the v1.1.0 manual/external evidence Markdown ledger from the structured
JSON source. This script does not open GUI apps, install MacDog, run GitHub
Actions, codesign, notarize, staple, run Gatekeeper assessment, or push.

Options:
  --check      Fail when the Markdown ledger does not match the JSON source.
  --write      Regenerate the Markdown ledger from the JSON source.
  --self-test  Validate rendering and mismatch detection with temporary files.
  --json PATH  Structured evidence JSON source.
  --output PATH Markdown evidence ledger path.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

render_markdown() {
  local json_path="$1"
  /usr/bin/ruby -rjson - "$json_path" <<'RUBY'
json_path = ARGV.fetch(0)
data = JSON.parse(File.read(json_path))

status_label = {
  "incomplete" => "미완료",
  "complete" => "완료"
}.fetch(data.fetch("overallStatus"))

puts "# v1.1.0 수동/외부 검수 증거 현황"
puts
puts "상태: #{status_label}"
puts
puts "이 문서는 `v1.1.0` 우선 항목을 실제 완료로 볼 수 있는 증거를 기록하는 ledger입니다. 구조화된 원본은 `Docs/V110ManualEvidence.json`이며, 이 Markdown 문서는 사람이 검수할 때 읽기 쉬운 요약입니다. 자동 검증, dry-run, self-test는 수동 UI 검수나 외부 서비스 실행을 대체하지 않습니다. 실제로 보지 않은 화면, 실행하지 않은 GitHub Actions run, 수행하지 않은 signing/notarization/Gatekeeper 검증은 `확인됨`으로 바꾸지 않습니다."
puts
puts "기록 명령: `#{data.fetch("recordCommand")}`" if data["recordCommand"]
puts

data.fetch("items").each_with_index do |item, index|
  puts "## #{index + 1}. #{item.fetch("title")}"
  puts
  puts "상태: #{item.fetch("statusLabel")}"
  puts
  puts "필요 완료 증거:"
  item.fetch("requiredEvidence").each do |entry|
    puts "- #{entry}"
  end
  puts
  puts "현재 증거:"
  item.fetch("currentEvidence").each do |entry|
    puts "- #{entry}"
  end
  puts
  puts "남은 검수:"
  item.fetch("remainingVerification").each do |entry|
    puts "- #{entry}"
  end
  puts unless index == data.fetch("items").length - 1
end
RUBY
}

check_rendered() {
  local json_path="$1"
  local output_path="$2"
  [[ -f "$json_path" ]] || die "missing JSON evidence source: $json_path"
  [[ -f "$output_path" ]] || die "missing Markdown evidence output: $output_path"

  local temp_file
  temp_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macdog-v110-render.XXXXXX")"

  render_markdown "$json_path" >"$temp_file"
  if ! /usr/bin/diff -u "$output_path" "$temp_file"; then
    rm -f "$temp_file"
    echo "error: Markdown evidence ledger is out of sync with JSON source; run $0 --write" >&2
    return 1
  fi
  rm -f "$temp_file"
}

write_rendered() {
  local json_path="$1"
  local output_path="$2"
  [[ -f "$json_path" ]] || die "missing JSON evidence source: $json_path"
  render_markdown "$json_path" >"$output_path"
  echo "rendered $output_path from $json_path"
}

run_self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/macdog-v110-render.XXXXXX")"
  trap 'rm -rf "$temp_dir"' RETURN

  local json_path="$temp_dir/evidence.json"
  local markdown_path="$temp_dir/evidence.md"

  cat >"$json_path" <<'JSON'
{
  "version": "v1.1.0",
  "overallStatus": "incomplete",
  "items": [
    {
      "id": "helper_button_click",
      "title": "앱 내부 helper 버튼 실제 클릭 검수",
      "status": "unverified",
      "statusLabel": "미확인",
      "requiredEvidence": ["helper 설치 버튼 실제 클릭"],
      "currentEvidence": ["script/verify_privileged_helper_preflight.sh"],
      "remainingVerification": ["실제 앱 UI 클릭"]
    }
  ]
}
JSON

  render_markdown "$json_path" >"$markdown_path"
  check_rendered "$json_path" "$markdown_path"

  printf '\n추가 줄\n' >>"$markdown_path"
  if check_rendered "$json_path" "$markdown_path" >/dev/null 2>&1; then
    die "render check unexpectedly passed after Markdown drift"
  fi

  echo "v1.1.0 manual evidence renderer self-test ok"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check" ;;
    --write) MODE="write" ;;
    --self-test) MODE="self-test" ;;
    --json)
      [[ $# -ge 2 ]] || die "--json requires a path"
      JSON_REPORT="$2"
      shift
      ;;
    --output)
      [[ $# -ge 2 ]] || die "--output requires a path"
      OUTPUT="$2"
      shift
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

cd "$ROOT_DIR"

case "$MODE" in
  check) check_rendered "$JSON_REPORT" "$OUTPUT" ;;
  write) write_rendered "$JSON_REPORT" "$OUTPUT" ;;
  self-test) run_self_test ;;
esac
