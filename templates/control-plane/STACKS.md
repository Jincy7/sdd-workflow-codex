# SDD Control Plane Stack

This repository uses the real installed upstream stacks:

| Layer | Upstream | Codex Entry Points | Purpose |
| --- | --- | --- | --- |
| Planning/context | GSD | `$gsd-*` | durable specs, phases, codebase maps, verification |
| Engineering discipline | Superpowers | skill names such as `brainstorming`, `writing-plans`, `test-driven-development` | TDD, debugging, planning, verification discipline |
| Specialist review | gstack | `$gstack-*` | CEO/eng/design/QA/security/release review |
| Routing | SDD control plane | `$sdd-control-plane` | choose and sequence the upstream stacks |
| Personal artifact sync | SDD artifacts | `scripts/sdd-control-plane.sh artifacts ...` | sync local workflow state by stable project id |

## Local Boundary

Keep all project state scoped to this repository. Do not import state from another repo unless explicitly requested.

By default this control-plane setup is personal. Keep `AGENTS.md`, `.sdd-control/`, and GSD `.planning/` out of shared git history unless the team explicitly opts in.

For cross-machine sync, bind the project to a stable id in `.sdd-control/project.json` and sync to the private artifacts repository. Folder names and repo names are aliases, not identity.

After a task, checkpoint the current repo shape with `scripts/sdd-control-plane.sh artifacts checkpoint . --note "<task>"`. If code layout or architecture changed, run `$gsd-map-codebase` first so `.planning/codebase/` reflects the current repo before the checkpoint is pushed.

## Recommended Route

Fuzzy idea -> `$gstack-office-hours` -> `$gstack-plan-ceo-review` -> `$gsd-spec-phase` -> `$gstack-plan-eng-review` -> Superpowers `test-driven-development` -> `$gsd-execute-phase` -> `$gstack-review` -> `$gstack-qa` -> `$gsd-verify-work` -> `$gstack-ship`.
