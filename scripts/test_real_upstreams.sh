#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export HOME="$tmp_dir/home"

if [ "${1:-}" = "--include-gstack" ]; then
  "$repo_root/install.sh"
else
  "$repo_root/install.sh" --skip-gstack
  echo "Skipped gstack, so the status output above should show gstack as missing. Re-run with --include-gstack for the full heavy upstream test."
fi
