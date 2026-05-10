#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export HOME="$tmp_dir/home"
export SDD_CP_MOCK=1
project_dir="$tmp_dir/project"
mkdir -p "$project_dir"
git -C "$project_dir" init -q
mkdir -p "$project_dir/.planning"
printf '%s\n' '{"commit_docs":true}' > "$project_dir/.planning/config.json"
mkdir -p "$project_dir/docs/superpowers/specs"
printf '%s\n' '# Sample Superpowers Spec' > "$project_dir/docs/superpowers/specs/sample.md"
mkdir -p "$project_dir/docs/superpowers/plans"
cat > "$project_dir/docs/superpowers/plans/sample-plan.md" <<'EOF'
# Sample Superpowers Plan

**Goal:** Ship a visible planning preview.

## Task 1: Render Preview

- [ ] **Step 1: Generate HTML**
- [ ] **Step 2: Verify tree output**
EOF
mkdir -p "$project_dir/.planning/phases/01-preview-flow"
cat > "$project_dir/.planning/phases/01-preview-flow/01-SPEC.md" <<'EOF'
# Phase 1: Preview Flow - Specification

## Goal

Show plan and spec artifacts as a readable tree.

## Requirements

1. **Preview command**: Generate an HTML tree preview after planning.
   - Acceptance: The generated document includes requirements and acceptance criteria.

## Acceptance Criteria

- [ ] Preview includes the spec title.
- [ ] Preview escapes <script>alert("x")</script> text.
EOF
cat > "$project_dir/.planning/phases/01-preview-flow/01-01-PLAN.md" <<'EOF'
---
phase: 01-preview-flow
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/preview.js
requirements: [PREVIEW-01]
---

<objective>
Create a static visual preview for completed planning artifacts.
</objective>

<tasks>
<task type="auto">
  <name>Task 1: Build preview renderer</name>
  <files>scripts/preview.js</files>
  <verify>node scripts/preview.js .</verify>
  <acceptance_criteria>
    - Preview contains a tree.
    - Preview contains plan tasks.
  </acceptance_criteria>
  <done>HTML preview is written.</done>
</task>
</tasks>
EOF
mkdir -p "$HOME/.codex/skills/old-skill.backup.20000101000000"
printf '%s\n' '---' 'name: old-skill' 'description: invalid: unquoted' '---' > "$HOME/.codex/skills/old-skill.backup.20000101000000/SKILL.md"

"$repo_root/install.sh" >/tmp/sdd-control-plane-install.log
test -f "$HOME/.codex/skills/sdd-control-plane/SKILL.md"
test -f "$HOME/.codex/get-shit-done/VERSION"
test -L "$HOME/.agents/skills/superpowers"
test -f "$HOME/.codex/skills/gstack-review/SKILL.md"
test ! -e "$HOME/.codex/skills/old-skill.backup.20000101000000"
test -f "$HOME/.codex/skill-backups/old-skill.backup.20000101000000/SKILL.md"

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

"$repo_root/scripts/sdd-control-plane.sh" preview "$project_dir" >/tmp/sdd-control-plane-preview.log
preview_path="$project_dir/.sdd-control/previews/latest.html"
test -f "$preview_path"
grep -q 'SDD Planning Preview' "$preview_path"
grep -q 'Phase 1: Preview Flow - Specification' "$preview_path"
grep -q 'Preview command' "$preview_path"
grep -q 'Task 1: Build preview renderer' "$preview_path"
grep -q 'Sample Superpowers Plan' "$preview_path"
grep -q '&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;' "$preview_path"
grep -q 'id="cy"' "$preview_path"
grep -q 'cytoscape@3.33.3' "$preview_path"
grep -q 'cytoscape-dagre@2.5.0' "$preview_path"
grep -q 'const PREVIEW_GRAPH =' "$preview_path"
grep -q 'cy.on("tap", "node"' "$preview_path"
grep -q 'id="reset-overview"' "$preview_path"
grep -q 'id="collapse-all"' "$preview_path"
grep -q 'id="expand-all"' "$preview_path"
grep -q 'id="full-view"' "$preview_path"
grep -q 'function applyVisibleGraph' "$preview_path"
grep -q 'function toggleNodeCollapse' "$preview_path"
grep -q 'let currentRankDir = "LR"' "$preview_path"
grep -q 'function setRootDepthState(maxDepth = 1)' "$preview_path"
grep -q 'function expandSelectedNodeOneLevel' "$preview_path"
grep -q 'function collapseSelectedNodeOneLevel' "$preview_path"
grep -q 'class="inspector-actions"' "$preview_path"
grep -q 'makeInspectorButton("go-document", "Move")' "$preview_path"
grep -q 'id="back-to-graph"' "$preview_path"
grep -q 'function scrollToSelectedDocument' "$preview_path"
grep -q 'selectGraphNode(event.target, false)' "$preview_path"
grep -q "$preview_path" /tmp/sdd-control-plane-preview.log

"$repo_root/scripts/init_project.sh" "$project_dir" >/tmp/sdd-control-plane-init.log
test -f "$project_dir/AGENTS.md"
test -f "$project_dir/.sdd-control/STACKS.md"
test -f "$project_dir/.sdd-control/PROJECT.md"
grep -q 'BEGIN sdd-control-plane personal workflow' "$project_dir/.git/info/exclude"
grep -q '^AGENTS.md$' "$project_dir/.git/info/exclude"
grep -q '^.sdd-control/$' "$project_dir/.git/info/exclude"
grep -q '^.planning/$' "$project_dir/.git/info/exclude"
grep -q '^docs/superpowers/$' "$project_dir/.git/info/exclude"
test "$(git -C "$project_dir" status --short -- AGENTS.md .sdd-control .planning docs/superpowers)" = ""
test "$(node -e 'const fs=require("fs"); const p=process.argv[1]; console.log(JSON.parse(fs.readFileSync(p,"utf8")).commit_docs)' "$project_dir/.planning/config.json")" = "false"

team_dir="$tmp_dir/team-project"
mkdir -p "$team_dir"
git -C "$team_dir" init -q
"$repo_root/scripts/init_project.sh" --team "$team_dir" >/tmp/sdd-control-plane-team-init.log
test -f "$team_dir/AGENTS.md"
! grep -q 'BEGIN sdd-control-plane personal workflow' "$team_dir/.git/info/exclude"
test -n "$(git -C "$team_dir" status --short -- AGENTS.md .sdd-control)"

artifacts_dir="$tmp_dir/artifacts"
artifacts_remote="$tmp_dir/artifacts-remote.git"
git init --bare -q "$artifacts_remote"
"$repo_root/scripts/sdd-control-plane.sh" artifacts init "$project_dir" \
  --dir "$artifacts_dir" \
  --repo "$artifacts_remote" \
  --project-id compass-a2a \
  --display-name "Compass A2A Gateway" \
  --alias compass \
  --alias uhdc-compass \
  --no-push >/tmp/sdd-control-plane-artifacts-init.log
test -f "$project_dir/.sdd-control/project.json"
test -f "$artifacts_dir/projects/compass-a2a/manifest.json"
test -f "$artifacts_dir/projects/compass-a2a/planning/config.json"
test -f "$artifacts_dir/projects/compass-a2a/sdd-control/project.json"
test -f "$artifacts_dir/projects/compass-a2a/superpowers/specs/sample.md"
test -f "$artifacts_dir/registry/projects.json"
grep -q 'uhdc-compass' "$artifacts_dir/projects/compass-a2a/manifest.json"
grep -q '"local_name": "project"' "$artifacts_dir/projects/compass-a2a/manifest.json"
! grep -q 'artifacts_repo' "$project_dir/.sdd-control/project.json"
! grep -q 'artifacts_repo' "$artifacts_dir/projects/compass-a2a/manifest.json"

renamed_dir="$tmp_dir/uhdc-compass"
mkdir -p "$renamed_dir"
git -C "$renamed_dir" init -q
"$repo_root/scripts/sdd-control-plane.sh" artifacts pull "$renamed_dir" \
  --dir "$artifacts_dir" \
  --repo "$artifacts_remote" >/tmp/sdd-control-plane-artifacts-pull-resolved.log 2>&1
grep -q 'Resolved artifact project_id=compass-a2a' /tmp/sdd-control-plane-artifacts-pull-resolved.log
test -f "$renamed_dir/docs/superpowers/specs/sample.md"
test "$(node -e 'const fs=require("fs"); const p=process.argv[1]; console.log(JSON.parse(fs.readFileSync(p,"utf8")).project_id)' "$renamed_dir/.sdd-control/project.json")" = "compass-a2a"

rm -rf "$project_dir/.planning" "$project_dir/.sdd-control" "$project_dir/AGENTS.md" "$project_dir/docs/superpowers"
"$repo_root/scripts/sdd-control-plane.sh" artifacts pull "$project_dir" \
  --dir "$artifacts_dir" \
  --repo "$artifacts_remote" \
  --project-id compass-a2a >/tmp/sdd-control-plane-artifacts-pull.log
test -f "$project_dir/AGENTS.md"
test -f "$project_dir/.sdd-control/project.json"
test -f "$project_dir/.planning/config.json"
test -f "$project_dir/docs/superpowers/specs/sample.md"
test "$(node -e 'const fs=require("fs"); const p=process.argv[1]; console.log(JSON.parse(fs.readFileSync(p,"utf8")).project_id)' "$project_dir/.sdd-control/project.json")" = "compass-a2a"

"$repo_root/scripts/sdd-control-plane.sh" artifacts checkpoint "$project_dir" \
  --dir "$artifacts_dir" \
  --repo "$artifacts_remote" \
  --note "finished sample task" \
  --no-push >/tmp/sdd-control-plane-artifacts-checkpoint.log
test -f "$project_dir/.sdd-control/REPO-SNAPSHOT.md"
test -f "$project_dir/.sdd-control/repo-snapshot.json"
test -f "$artifacts_dir/projects/compass-a2a/sdd-control/REPO-SNAPSHOT.md"
grep -q 'finished sample task' "$project_dir/.sdd-control/REPO-SNAPSHOT.md"
grep -q '"dirty": false' "$project_dir/.sdd-control/repo-snapshot.json"
grep -q '"local_name": "project"' "$project_dir/.sdd-control/repo-snapshot.json"

bash -n "$repo_root/install.sh"
bash -n "$repo_root/scripts/sdd-control-plane.sh"
bash -n "$repo_root/scripts/init_project.sh"
bash -n "$repo_root/scripts/artifacts.sh"
bash -n "$repo_root/scripts/test_install.sh"
node --check "$repo_root/scripts/preview.js"

echo "All mock control-plane tests passed"
