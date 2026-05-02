---
name: sdd-control-plane
description: "Use this skill to orchestrate the real installed SDD stack in Codex: official GSD for planning/context, official Superpowers for engineering discipline, and official gstack for role-based review, QA, and release gates."
---

# SDD Control Plane

This is an orchestration layer, not a replacement for the upstream stacks.

Use the installed upstream skills directly:

- GSD (`$gsd-*`) owns durable project planning, codebase maps, phases, execution state, and verification.
- Superpowers owns engineering discipline: brainstorming, writing plans, TDD, systematic debugging, verification, branch finishing, and code-review loops.
- gstack (`$gstack-*`) owns role-based pressure testing: office hours, CEO review, engineering review, design review, QA, security, release, browser-driven checks, and retros.

## Boundary Rule

Treat the current repository root as the context boundary.

- Do not mix planning state, learnings, or review artifacts across repositories.
- Re-read this repo's `AGENTS.md` before assuming stack routing.
- Let official GSD create and own its own project planning files.
- Use this control plane only to choose which upstream skill should run next.
- Treat project initialization as personal by default: keep `AGENTS.md`, `.sdd-control/`, GSD `.planning/`, and Superpowers `docs/superpowers/` in `.git/info/exclude` unless the team explicitly opts in.

## Default Route

For non-trivial product or engineering work:

1. Intake and project state:
   - If the repo is not initialized for GSD, use `$gsd-new-project`.
   - If the codebase map is stale or missing, use `$gsd-map-codebase`.
   - If work is already in progress, use `$gsd-resume-work` or `$gsd-progress`.
2. Product and scope pressure:
   - Use `$gstack-office-hours` for fuzzy ideas.
   - Use `$gstack-plan-ceo-review` to cut scope or sharpen the wedge.
3. Spec and plan:
   - Use `$gsd-discuss-phase`, `$gsd-spec-phase`, or `$gsd-plan-phase` for durable planning.
   - Use Superpowers `brainstorming` and `writing-plans` when the task needs detailed implementation sequencing.
4. Architecture and design review:
   - Use `$gstack-plan-eng-review` for architecture, data flow, edge cases, and tests.
   - Use `$gstack-plan-design-review` for UI/UX work.
   - Use `$gstack-plan-devex-review` for API, SDK, CLI, docs, and onboarding work.
5. Execution:
   - Use `$gsd-execute-phase` for GSD-managed phases.
   - Use Superpowers `test-driven-development`, `executing-plans`, and `subagent-driven-development` for implementation discipline.
6. Debugging:
   - Use `$gsd-debug` or Superpowers `systematic-debugging`.
   - Use `$gstack-investigate` when production-style root-cause analysis matters.
7. Review and QA:
   - Use `$gstack-review` or `$gsd-code-review`.
   - Use `$gstack-cso` for security-sensitive work.
   - Use `$gstack-qa` for browser/user-flow QA and `$gstack-qa-only` when reporting without edits.
8. Ship:
   - Use `$gsd-verify-work` and Superpowers `verification-before-completion`.
   - Use `$gstack-ship` for PR/release flow when appropriate.
   - Use `$gstack-retro` or `$gsd-extract-learnings` after substantial work.

## Conflict Resolution

- If two stacks offer the same step, prefer GSD when the output must become durable project state.
- Prefer Superpowers when the goal is disciplined coding behavior inside the current task.
- Prefer gstack when a specialist review lens or browser/release workflow is needed.
- Prefer prefixed gstack skills (`$gstack-*`) to avoid collisions with GSD or Superpowers names.

## Artifact Sync

Use the control-plane artifact workflow when personal SDD/GSD state needs to move across machines or when the same codebase may appear under different repository names.

- Stable identity is `.sdd-control/project.json.project_id`, not the repo folder name.
- Aliases such as `compass` and `uhdc-compass` are metadata.
- Sync target comes from `~/.sdd-control/config.json`, `SDD_ARTIFACTS_REPO`, or an explicit `--repo`.
- Synced artifacts are `AGENTS.md`, `.sdd-control/`, `.planning/`, and Superpowers `docs/superpowers/`.
- Treat `docs/superpowers/` specs as personal drafts by default. Promote only reviewed, team-relevant specs into the project's shared docs tree.
- GitHub tokens are read from `gh auth token` at runtime when `--gh-user` or `SDD_ARTIFACTS_GH_USER` is set; tokens are never written to project artifacts.

Commands:

```sh
scripts/sdd-control-plane.sh artifacts configure --repo <artifacts-repo-url> --gh-user <github-user>
scripts/sdd-control-plane.sh artifacts init . --project-id <stable-id> --alias <old-name> --alias <new-name>
scripts/sdd-control-plane.sh artifacts push .
scripts/sdd-control-plane.sh artifacts checkpoint . --note "<completed task>"
scripts/sdd-control-plane.sh artifacts pull . --project-id <stable-id>
scripts/sdd-control-plane.sh artifacts status .
```

After meaningful code changes, use this sync route:

1. Use `$gsd-progress` or `$gsd-verify-work` to update phase/progress state.
2. If the repo structure, architecture, stack, integrations, conventions, or testing shape changed, use `$gsd-map-codebase`.
3. If reusable lessons emerged, use `$gsd-extract-learnings`.
4. Run `scripts/sdd-control-plane.sh artifacts checkpoint . --note "<task>"`.

The checkpoint command captures current branch, HEAD, dirty files, and codebase-map staleness. It does not rewrite GSD semantic docs; official GSD owns that update.

## Minimum Completion Gate

Do not call work complete until:

- The relevant GSD phase or project state is updated, if GSD was used.
- Tests/build/lint/manual checks requested by the upstream plan have run.
- Review/QA findings are either fixed or explicitly recorded.
- Remaining risks are stated plainly.
