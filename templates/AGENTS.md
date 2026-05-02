# Codex Project Instructions

Use the official installed SDD stack through the `sdd-control-plane` skill.

This file is intended to be a personal Codex overlay unless the team explicitly commits it.

## Context Isolation

- Treat this repository as the context boundary.
- Do not reuse GSD plans, gstack learnings, Superpowers plan files, or project notes from another repository unless the user explicitly provides them.
- When switching projects, re-read this file before choosing workflow state.
- Keep `.planning/`, `.sdd-control/`, and `docs/superpowers/` local unless the team has agreed to share this workflow.

## Personal Artifact Start

- If this repo may have existing personal workflow artifacts, run `scripts/sdd-control-plane.sh artifacts pull .` from the control-plane repo before starting Superpowers planning/execution work.
- Superpowers reads and writes local `docs/superpowers/`; the control plane syncs that directory to the private artifacts repo.
- If artifact resolution is ambiguous, use the stable `.sdd-control/project.json.project_id`.

## Stack Routing

- GSD (`$gsd-*`) owns durable project planning, codebase maps, phases, execution state, and verification.
- Superpowers owns engineering discipline: brainstorming, writing plans, TDD, systematic debugging, verification, and code-review loops.
- gstack (`$gstack-*`) owns role-based review, QA, security, browser workflows, release, and retrospectives.
- `sdd-control-plane` decides which upstream stack to use next; it should not replace the upstream workflows.

## Default Flow

1. Use `$gsd-new-project` if this repository has not been initialized for GSD.
2. Use `$gsd-map-codebase` when codebase context is stale or missing.
3. Use `$gstack-office-hours` and `$gstack-plan-ceo-review` for fuzzy product work.
4. Use `$gsd-spec-phase` or `$gsd-plan-phase` for durable planning.
5. Use Superpowers `test-driven-development` and `executing-plans` during implementation.
6. Use `$gstack-review`, `$gstack-qa`, `$gsd-verify-work`, and Superpowers `verification-before-completion` before completion.
