#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: .sdd/scripts/new_feature.sh short-feature-name" >&2
  exit 1
fi

slug="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"

if [ "${slug}" = "" ]; then
  echo "error: feature name must contain at least one letter or number" >&2
  exit 1
fi

id="$(date +%F)-${slug}"
dir=".sdd/specs/${id}"

mkdir -p "${dir}/tasks"

for file in FEATURE-SPEC.md PLAN.md REVIEW.md VERIFY.md RETRO.md; do
  cp ".sdd/templates/${file}" "${dir}/${file}"
done

echo "${dir}"

