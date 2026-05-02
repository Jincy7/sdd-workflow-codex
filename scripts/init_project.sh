#!/usr/bin/env bash
set -euo pipefail

force=0
target="${1:-.}"

if [ "${target}" = "--force" ]; then
  force=1
  target="${2:-.}"
elif [ "${2:-}" = "--force" ]; then
  force=1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_dir="$(cd "${target}" && pwd)"

copy_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ "$force" -ne 1 ]; then
    echo "skip existing $dst"
    return
  fi
  cp "$src" "$dst"
  echo "wrote $dst"
}

mkdir -p "$target_dir/.sdd-control"

copy_file "$repo_root/templates/AGENTS.md" "$target_dir/AGENTS.md"
copy_file "$repo_root/templates/control-plane/STACKS.md" "$target_dir/.sdd-control/STACKS.md"
copy_file "$repo_root/templates/control-plane/PROJECT.md" "$target_dir/.sdd-control/PROJECT.md"

echo "Initialized SDD control plane project context in $target_dir"
echo "Next in Codex: use \$sdd-control-plane, then run \$gsd-new-project if GSD has not initialized this repo yet."

