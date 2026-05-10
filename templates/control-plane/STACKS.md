# SDD Control Plane Stack

This repository uses the real installed upstream stacks:

| Layer | Upstream | Codex Entry Points | Purpose |
| --- | --- | --- | --- |
| Planning/context | GSD | `$gsd-*` | durable specs, phases, codebase maps, verification |
| Engineering discipline | Superpowers | skill names such as `brainstorming`, `writing-plans`, `test-driven-development` | TDD, debugging, planning, verification discipline |
| Specialist review | gstack | `$gstack-*` | CEO/eng/design/QA/security/release review |
| Routing | SDD control plane | `$sdd-control-plane` | choose and sequence the upstream stacks |
| Planning preview | SDD control plane | `scripts/sdd-control-plane.sh preview .` | render completed spec/plan artifacts as a local HTML tree |
| Personal artifact sync | SDD artifacts | `scripts/sdd-control-plane.sh artifacts ...` | sync local workflow state by stable project id |

## Local Boundary

Keep all project state scoped to this repository. Do not import state from another repo unless explicitly requested.

By default this control-plane setup is personal. Keep `AGENTS.md`, `.sdd-control/`, GSD `.planning/`, and Superpowers `docs/superpowers/` out of shared git history unless the team explicitly opts in.

For cross-machine sync, bind the project to a stable id in `.sdd-control/project.json` and sync to the private artifacts repository. Folder names and repo names are aliases, not identity.

After a task, checkpoint the current repo shape with `scripts/sdd-control-plane.sh artifacts checkpoint . --note "<task>"`. If code layout or architecture changed, run `$gsd-map-codebase` first so `.planning/codebase/` reflects the current repo before the checkpoint is pushed.

## Planning Preview

After `$gsd-spec-phase`, `$gsd-plan-phase`, or a Superpowers planning pass produces local documents, run:

```sh
scripts/sdd-control-plane.sh preview .
```

This writes `.sdd-control/previews/latest.html` from `.planning/phases/` and `docs/superpowers/`. It is only a visual preview; upstream tools still own the planning state.

If those plan/spec artifacts are created or updated, sync the updated preview through the artifact repo:

```sh
scripts/sdd-control-plane.sh artifacts checkpoint . --note "updated plan/spec preview"
```

Run the preview command immediately before the checkpoint so `.sdd-control/previews/latest.html` matches the current upstream artifacts.

## Recommended Route

Fuzzy idea -> `$gstack-office-hours` -> `$gstack-plan-ceo-review` -> `$gsd-spec-phase`/`$gsd-plan-phase` -> `scripts/sdd-control-plane.sh preview .` -> `$gstack-plan-eng-review` -> Superpowers `test-driven-development` -> `$gsd-execute-phase` -> `$gstack-review` -> `$gstack-qa` -> `$gsd-verify-work` -> `$gstack-ship`.
