# Codex Project Instructions

Use the global `sdd-workflow` skill for non-trivial product, feature, refactor, bugfix, and release work.

## Context Isolation

- Only use SDD context from this repository's `.sdd/` directory.
- Do not reuse decisions, specs, architecture notes, or project knowledge from other repositories unless the user explicitly provides them in this thread.
- When switching projects, re-read this repository's `AGENTS.md` and `.sdd/state/PROJECT.md` before making assumptions.

## SDD Workflow

Choose the smallest workflow tier that fits:

- Tiny: direct fix plus verification.
- Standard: gstack decision check, GSD context update, Superpowers execution loop.
- Long-running: full SDD run with milestone state, decision log, review, QA, ship, and reflect.

## Operating Rules

- Keep work scoped to the current "lake": one coherent feature, fix, or milestone.
- Use gstack-style roles for judgment: office-hours, CEO, engineering, design, staff review, QA, release, retrospective.
- Use GSD-style durable files for context: project state, decisions, knowledge, feature specs, roadmaps, plans, review notes.
- Use Superpowers-style execution: plan in small tasks, prefer TDD when behavior changes, verify before completion.
- If requirements are unclear, resolve decision risk before coding.
- If context may drift across sessions, update `.sdd/state/` before and after implementation.
- If implementation discovers an uncovered architectural decision, stop and record the decision before continuing.
- Never call a task done until verification evidence is recorded.

