# Implementation Plan: Codex SDD Workflow

## Scope

Create a repository package that can install a global Codex SDD skill and initialize project-local `.sdd/` state. Do not install third-party plugins or modify unrelated files.

## Task List

- [x] Task 1: create `AGENTS.md`.
  - Behavior: Codex receives project-level workflow instructions.
  - Verification: file exists.
  - Risk: low.
- [x] Task 2: create canonical `skills/sdd-workflow/SKILL.md`.
  - Behavior: workflow is available as a global Codex skill source.
  - Verification: file exists and has valid frontmatter.
  - Risk: medium if a running Codex session does not refresh skills until restart.
- [x] Task 3: create `.sdd/` state and templates for this repo's own dogfood run.
  - Behavior: durable context exists for future work.
  - Verification: file tree exists.
  - Risk: low.
- [x] Task 4: create and run `.sdd/scripts/new_feature.sh`.
  - Behavior: new feature folders can be generated consistently.
  - Verification: script created `.sdd/specs/2026-05-02-codex-sdd-workflow`.
  - Risk: low.
- [x] Task 5: create `install.sh`.
  - Behavior: copies `skills/sdd-workflow` into `~/.codex/skills/sdd-workflow`.
  - Verification: `./scripts/test_install.sh` and real `./install.sh`.
  - Risk: backs up existing skill before replacing.
- [x] Task 6: create `scripts/init_project.sh`.
  - Behavior: initializes `AGENTS.md` and `.sdd/` in target repositories.
  - Verification: `./scripts/test_install.sh`.
  - Risk: skips existing files unless `--force`.
- [x] Task 7: create README and package templates.
  - Behavior: repository is understandable and reusable.
  - Verification: file inspection.
  - Risk: low.

## TDD Targets

- Failing test to add: not applicable; shell/package workflow only.
- Existing test to extend: not applicable.

## Checkpoints

- [x] Spec locked.
- [x] Context updated.
- [x] Install script tested.
- [x] Project init tested.
- [x] Feature generator tested.
- [x] Review complete.
- [x] Verification recorded.

