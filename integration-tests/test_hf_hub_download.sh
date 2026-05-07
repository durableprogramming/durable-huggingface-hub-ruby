#!/usr/bin/env bash
# Integration test reproducing the exact scenario from issue #1:
#   hf_hub_download fails on every dataset/model file: redirects not followed
#   and streaming concatenates redirect body.
#
# Requires network access to huggingface.co.
# Run from the repo root:  bash integration-tests/test_hf_hub_download.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== hf_hub_download integration test (issue #1) ==="

ruby -I "$REPO_ROOT/lib" - <<'RUBY'
require "huggingface_hub"

path = DurableHuggingfaceHub::FileDownload.hf_hub_download(
  repo_id:   "Trelis/tiny-shakespeare",
  filename:  "input.txt",
  repo_type: "dataset",
)

abort "FAIL: returned path does not exist: #{path}" unless File.exist?(path)

first_line = File.open(path, "rb", &:readline).chomp
if first_line.start_with?("Temporary Redirect")
  abort "FAIL: file is corrupted — starts with redirect body:\n  #{first_line}"
end

puts "PASS: downloaded to #{path}"
puts "      first line: #{first_line[0, 80]}"
RUBY
