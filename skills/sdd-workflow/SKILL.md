---
name: sdd-workflow
description: Use this skill when doing spec-driven development in Codex with a combined gstack decision layer, GSD context layer, and Superpowers execution layer. It keeps `.sdd/` state in the current repository root so context is isolated per project.
---

# SDD Workflow

This skill turns a request into a complete Codex-compatible SDD loop:

1. gstack decides what should be built and locks the approach.
2. GSD anchors durable context in the current repository's `.sdd/` directory.
3. Superpowers executes with small plans, TDD, review, and verification.

## Project Context Rule

Always treat the current repository root as the context boundary.

- Read and write SDD artifacts only under this repo's `.sdd/`.
- Do not reuse `.sdd/` decisions, specs, or knowledge from another repo unless the user explicitly provides them.
- If `.sdd/` is missing, ask to initialize it or run `scripts/init_project.sh` from this workflow package if available.
- Re-read this repo's `AGENTS.md` and `.sdd/state/PROJECT.md` when switching projects.

## Tier Selection

Use the smallest tier that protects quality:

- Tiny: one-file or low-risk edits. Skip formal artifacts, but still verify.
- Standard: normal feature, bugfix, refactor, UI change, or data-flow change. Use feature spec, decision log, plan, verification.
- Long-running: multi-session, multi-agent, architecture, release, or high-risk work. Use every stage and update milestone state.

## Stage 0: Intake

Create or update `.sdd/state/PROJECT.md` if the project purpose, stack, commands, or boundaries are not yet known.

Classify:

- Outcome: user-visible result or engineering invariant.
- Scope: exact files, modules, or flows likely affected.
- Risk: data loss, security, migrations, billing, auth, performance, UX.
- Verification: tests, manual QA, screenshots, browser checks, build, lint, metrics.

If the task is fuzzy, run Stage 1 before coding.

## Stage 1: gstack Decision

Use these role lenses selectively:

- Office Hours: Should this be built? What assumption is most fragile?
- CEO Review: What is the smallest lovable outcome? What should be cut?
- Engineering Review: Architecture, data flow, contracts, failure modes, test strategy.
- Design Review: UX states, empty/error/loading states, accessibility, visual fit.

Write the locked result to `.sdd/specs/<feature-id>/FEATURE-SPEC.md`.

Gate: do not build until the spec states non-goals, acceptance criteria, risks, and verification.

## Stage 2: GSD Context

Update durable context before implementation:

- `.sdd/state/PROJECT.md`: stack, commands, repo map, current conventions.
- `.sdd/state/DECISIONS.md`: architectural/product decisions with rationale.
- `.sdd/state/KNOWLEDGE.md`: reusable facts learned from the codebase.
- `.sdd/milestones/M###-ROADMAP.md`: slices for long-running work.

For Standard tasks, create `.sdd/specs/<feature-id>/PLAN.md`.
For Long-running tasks, also create task files in `.sdd/specs/<feature-id>/tasks/`.

## Stage 3: Superpowers Execution

Plan tasks that are independently verifiable. Each task should name:

- Files to inspect or edit.
- Behavior to change.
- Test or verification command.
- Rollback or risk note when relevant.

When behavior changes, prefer RED-GREEN-REFACTOR:

1. Write or identify a failing test.
2. Confirm the failure is meaningful.
3. Implement the smallest correct change.
4. Confirm tests pass.
5. Refactor only with passing tests.

Use parallel subagents only for independent, non-overlapping work.

## Stage 4: Review And QA

Run review lenses before completion:

- Staff Engineer: production failure modes, race conditions, permissions, edge cases.
- QA Lead: user flows, invalid input, empty/loading/error states.
- Performance: obvious N+1, large bundle, slow path, unnecessary re-render or query.
- Security: secrets, injection, authz/authn, unsafe commands, sensitive logs.

Record findings and fixes in `.sdd/specs/<feature-id>/REVIEW.md`.

## Stage 5: Ship

Before final response:

- Run the agreed verification.
- Check git status.
- Update docs or state files touched by the behavior.
- Record final evidence in `.sdd/specs/<feature-id>/VERIFY.md`.

If tests cannot run, record why and what risk remains.

## Stage 6: Reflect

For Long-running work, update `.sdd/state/KNOWLEDGE.md` with reusable lessons and add a brief retro to `.sdd/specs/<feature-id>/RETRO.md`.

## Artifact Naming

Use lowercase feature IDs:

`YYYY-MM-DD-short-name`

Example:

`.sdd/specs/2026-05-02-login-rate-limit/FEATURE-SPEC.md`

