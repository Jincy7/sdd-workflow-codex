#!/usr/bin/env bash
set -euo pipefail

force=0
mode="personal"
target="."

usage() {
  cat <<'EOF'
usage:
  scripts/init_project.sh [path] [--personal|--team] [--force]

Modes:
  --personal  default. Create local workflow files and hide them via .git/info/exclude.
  --team      Create workflow files without adding local excludes.

Personal mode writes:
  AGENTS.md
  .sdd-control/

and hides these personal workflow artifacts from git status:
  AGENTS.md
  .sdd-control/
  .planning/

If .planning/config.json exists, personal mode sets commit_docs=false.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --force)
      force=1
      ;;
    --personal)
      mode="personal"
      ;;
    --team)
      mode="team"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      target="$1"
      ;;
  esac
  shift
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_dir="$(cd "${target}" && pwd)"

warn() {
  printf 'warning: %s\n' "$*" >&2
}

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

append_personal_excludes() {
  local exclude_path
  local marker="# BEGIN sdd-control-plane personal workflow"

  if ! git -C "$target_dir" rev-parse --git-dir >/dev/null 2>&1; then
    warn "$target_dir is not a git repository; cannot update .git/info/exclude"
    return
  fi

  exclude_path="$(git -C "$target_dir" rev-parse --git-path info/exclude)"
  case "$exclude_path" in
    /*) ;;
    *) exclude_path="$target_dir/$exclude_path" ;;
  esac
  mkdir -p "$(dirname "$exclude_path")"
  touch "$exclude_path"

  if grep -Fq "$marker" "$exclude_path"; then
    echo "kept personal excludes in $exclude_path"
    return
  fi

  {
    printf '\n%s\n' "$marker"
    printf 'AGENTS.md\n'
    printf '.sdd-control/\n'
    printf '.planning/\n'
    printf '# END sdd-control-plane personal workflow\n'
  } >> "$exclude_path"

  echo "wrote personal excludes to $exclude_path"
}

disable_gsd_commit_docs() {
  local config="$target_dir/.planning/config.json"
  [ -f "$config" ] || return 0

  if ! command -v node >/dev/null 2>&1; then
    warn "node is not available; cannot set $config commit_docs=false"
    return
  fi

  node - "$config" <<'NODE'
const fs = require("fs");
const path = process.argv[2];
const data = JSON.parse(fs.readFileSync(path, "utf8"));
if (data.commit_docs !== false) {
  data.commit_docs = false;
  fs.writeFileSync(path, `${JSON.stringify(data, null, 2)}\n`);
  console.log(`set ${path} commit_docs=false`);
} else {
  console.log(`kept ${path} commit_docs=false`);
}
NODE
}

mkdir -p "$target_dir/.sdd-control"

copy_file "$repo_root/templates/AGENTS.md" "$target_dir/AGENTS.md"
copy_file "$repo_root/templates/control-plane/STACKS.md" "$target_dir/.sdd-control/STACKS.md"
copy_file "$repo_root/templates/control-plane/PROJECT.md" "$target_dir/.sdd-control/PROJECT.md"

if [ "$mode" = "personal" ]; then
  append_personal_excludes
  disable_gsd_commit_docs
  echo "Initialized personal SDD control plane context in $target_dir"
  echo "Personal artifacts are hidden through .git/info/exclude, not project .gitignore."
else
  echo "Initialized team-visible SDD control plane context in $target_dir"
fi

echo "Next in Codex: use \$sdd-control-plane, then run \$gsd-new-project if GSD has not initialized this repo yet."
