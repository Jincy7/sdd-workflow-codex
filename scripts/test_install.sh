#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export HOME="$tmp_dir/home"
export SDD_CP_MOCK=1
project_dir="$tmp_dir/project"
mkdir -p "$project_dir"

"$repo_root/install.sh" >/tmp/sdd-control-plane-install.log
test -f "$HOME/.codex/skills/sdd-control-plane/SKILL.md"
test -f "$HOME/.codex/get-shit-done/VERSION"
test -L "$HOME/.agents/skills/superpowers"
test -f "$HOME/.codex/skills/gstack-review/SKILL.md"

awk '
  /^---[[:space:]]*$/ { section += 1; next }
  section == 1 && /^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]+[^"'\''|>].*:[[:space:]]/ {
    print FILENAME ":" FNR ": quote YAML values that contain colon-space"
    bad = 1
  }
  END { exit bad }
' "$repo_root/skills/sdd-control-plane/SKILL.md"

"$repo_root/scripts/sdd-control-plane.sh" status >/tmp/sdd-control-plane-status.log
grep -q 'ok   GSD' /tmp/sdd-control-plane-status.log
grep -q 'ok   Superpowers' /tmp/sdd-control-plane-status.log
grep -q 'ok   gstack' /tmp/sdd-control-plane-status.log
grep -q 'ok   Control plane' /tmp/sdd-control-plane-status.log

"$repo_root/scripts/init_project.sh" "$project_dir" >/tmp/sdd-control-plane-init.log
test -f "$project_dir/AGENTS.md"
test -f "$project_dir/.sdd-control/STACKS.md"
test -f "$project_dir/.sdd-control/PROJECT.md"

bash -n "$repo_root/install.sh"
bash -n "$repo_root/scripts/sdd-control-plane.sh"
bash -n "$repo_root/scripts/init_project.sh"
bash -n "$repo_root/scripts/test_install.sh"

echo "All mock control-plane tests passed"
