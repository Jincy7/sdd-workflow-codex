#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

export CODEX_HOME="${tmp_dir}/codex-home"
project_dir="${tmp_dir}/project"
mkdir -p "${project_dir}"

"${repo_root}/install.sh" >/dev/null
test -f "${CODEX_HOME}/skills/sdd-workflow/SKILL.md"

"${repo_root}/scripts/init_project.sh" "${project_dir}" >/dev/null
test -f "${project_dir}/AGENTS.md"
test -f "${project_dir}/.sdd/state/PROJECT.md"
test -x "${project_dir}/.sdd/scripts/new_feature.sh"

(
  cd "${project_dir}"
  ".sdd/scripts/new_feature.sh" sample-feature >/dev/null
  spec_dir="$(find .sdd/specs -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  test -f "${spec_dir}/FEATURE-SPEC.md"
  test -f "${spec_dir}/PLAN.md"
  test -f "${spec_dir}/VERIFY.md"
)

bash -n "${repo_root}/install.sh"
bash -n "${repo_root}/scripts/init_project.sh"
bash -n "${repo_root}/templates/scripts/new_feature.sh"

echo "All install tests passed"

