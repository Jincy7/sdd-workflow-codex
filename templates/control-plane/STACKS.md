# SDD Control Plane Stack

This repository uses the real installed upstream stacks:

| Layer | Upstream | Codex Entry Points | Purpose |
| --- | --- | --- | --- |
| Planning/context | GSD | `$gsd-*` | durable specs, phases, codebase maps, verification |
| Engineering discipline | Superpowers | skill names such as `brainstorming`, `writing-plans`, `test-driven-development` | TDD, debugging, planning, verification discipline |
| Specialist review | gstack | `$gstack-*` | CEO/eng/design/QA/security/release review |
| Routing | SDD control plane | `$sdd-control-plane` | choose and sequence the upstream stacks |

## Local Boundary

Keep all project state scoped to this repository. Do not import state from another repo unless explicitly requested.

## Recommended Route

Fuzzy idea -> `$gstack-office-hours` -> `$gstack-plan-ceo-review` -> `$gsd-spec-phase` -> `$gstack-plan-eng-review` -> Superpowers `test-driven-development` -> `$gsd-execute-phase` -> `$gstack-review` -> `$gstack-qa` -> `$gsd-verify-work` -> `$gstack-ship`.

