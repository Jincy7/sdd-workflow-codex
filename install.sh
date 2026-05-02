#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
codex_home="${CODEX_HOME:-${HOME}/.codex}"
source_dir="${repo_root}/skills/sdd-workflow"
target_dir="${codex_home}/skills/sdd-workflow"

if [ ! -f "${source_dir}/SKILL.md" ]; then
  echo "error: missing ${source_dir}/SKILL.md" >&2
  exit 1
fi

mkdir -p "${codex_home}/skills"

if [ -e "${target_dir}" ]; then
  backup_dir="${target_dir}.backup.$(date +%Y%m%d%H%M%S)"
  mv "${target_dir}" "${backup_dir}"
  echo "Backed up existing skill to ${backup_dir}"
fi

cp -R "${source_dir}" "${target_dir}"

echo "Installed sdd-workflow skill to ${target_dir}"
echo "Initialize a repo with: ${repo_root}/scripts/init_project.sh /path/to/repo"

