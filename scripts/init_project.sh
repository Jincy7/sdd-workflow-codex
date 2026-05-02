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
  mkdir -p "$(dirname "${dst}")"
  if [ -e "${dst}" ] && [ "${force}" -ne 1 ]; then
    echo "skip existing ${dst}"
    return
  fi
  cp "${src}" "${dst}"
  echo "wrote ${dst}"
}

mkdir -p "${target_dir}/.sdd/state" "${target_dir}/.sdd/templates" "${target_dir}/.sdd/scripts" "${target_dir}/.sdd/specs" "${target_dir}/.sdd/milestones"

copy_file "${repo_root}/templates/AGENTS.md" "${target_dir}/AGENTS.md"
copy_file "${repo_root}/templates/SDD-README.md" "${target_dir}/.sdd/README.md"
copy_file "${repo_root}/templates/state/PROJECT.md" "${target_dir}/.sdd/state/PROJECT.md"
copy_file "${repo_root}/templates/state/DECISIONS.md" "${target_dir}/.sdd/state/DECISIONS.md"
copy_file "${repo_root}/templates/state/KNOWLEDGE.md" "${target_dir}/.sdd/state/KNOWLEDGE.md"

for file in FEATURE-SPEC.md PLAN.md REVIEW.md VERIFY.md MILESTONE-ROADMAP.md RETRO.md; do
  copy_file "${repo_root}/templates/sdd/${file}" "${target_dir}/.sdd/templates/${file}"
done

copy_file "${repo_root}/templates/scripts/new_feature.sh" "${target_dir}/.sdd/scripts/new_feature.sh"
chmod +x "${target_dir}/.sdd/scripts/new_feature.sh"

echo "Initialized SDD workspace in ${target_dir}"

