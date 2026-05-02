# Feature Spec: Codex SDD Workflow

## Feature ID

`2026-05-02-codex-sdd-workflow`

## Outcome

The workspace contains a Codex-usable SDD workflow package that installs a global `sdd-workflow` skill and initializes project-local `.sdd/` context for each repository.

## Users And Use Cases

- User installs the global skill once and asks Codex to build features across multiple repositories.
- Long-running tasks keep specs, decisions, project knowledge, review notes, and verification evidence on disk.
- Small tasks can still use a lightweight tier without ceremony.
- Each repository keeps its own `.sdd/` context boundary.

## Non-Goals

- Installing third-party Claude Code plugins globally.
- Reproducing every upstream Superpowers, gstack, or GSD command.
- Adding project-specific app code.

## gstack Decision Notes

### Office Hours

- Problem: Codex needs the workflow without relying on Claude-only slash commands, while keeping project context separated.
- Fragile assumption: Combining three frameworks could create duplicated process.
- Better framing: Split responsibilities into decision, context, and execution layers.

### CEO Review

- Smallest lovable outcome: A repo package with `install.sh` for the global skill and `scripts/init_project.sh` for per-project `.sdd/`.
- Things to cut: Full role theater, exhaustive templates, and global third-party plugin installs.
- Success signal: A user can install the skill, initialize a project, create a spec with one helper, and finish with verification evidence.

### Engineering Review

- Architecture: `skills/sdd-workflow` is copied to `~/.codex/skills`; project initialization creates `AGENTS.md` and `.sdd/`.
- Data flow: request -> tier selection -> spec/decision -> context update -> implementation plan -> review -> verify -> reflect.
- Contracts: Every Standard/Long-running run records acceptance criteria and verification.
- Edge cases: Tiny tasks can skip artifacts; high-risk tasks must not skip decision gates.
- Test strategy: Validate install script, project init script, feature generator, and shell syntax.

### Design Review

- States: Tiny, Standard, Long-running tiers.
- Accessibility: Markdown-first, readable in Codex and any editor.
- Visual/system fit: Minimal file tree with predictable names.

## Acceptance Criteria

- [x] `AGENTS.md` instructs Codex to use the workflow.
- [x] Global skill source exists at `skills/sdd-workflow/SKILL.md`.
- [x] `install.sh` installs the global skill.
- [x] `scripts/init_project.sh` initializes per-project `.sdd/` context.
- [x] GSD state files exist.
- [x] Templates exist for spec, plan, review, verification, milestone, and retro.
- [x] Helper script creates a feature folder.

## Risks

- Risk: The global skill may not be installed before a project is initialized.
- Mitigation: `README.md` documents install order and generated `AGENTS.md` names the `sdd-workflow` skill.

## Verification Plan

- Automated: run `./scripts/test_install.sh` and `.sdd/scripts/new_feature.sh codex-sdd-workflow`.
- Manual: inspect file tree, actual global install path, and git status.
- Evidence to capture: generated spec path, global install path, and git status.

