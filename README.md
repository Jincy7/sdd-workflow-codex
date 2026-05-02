# SDD Workflow for Codex

A Codex-compatible SDD workflow that combines the strongest parts of three agent workflow styles:

- gstack for decision-making and role-based review.
- GSD for durable, project-local context in `.sdd/`.
- Superpowers for plan execution, TDD, code review, and verification.

The global skill is shared across projects, but every project's context stays isolated in that project's own `.sdd/` folder.

## Install Global Skill

From this repository:

```sh
./install.sh
```

This copies `skills/sdd-workflow` to:

```text
~/.codex/skills/sdd-workflow
```

To install into a different Codex home:

```sh
CODEX_HOME=/path/to/codex-home ./install.sh
```

## Initialize A Project

Inside any repository:

```sh
/path/to/sdd-workflow-codex/scripts/init_project.sh .
```

This creates:

```text
AGENTS.md
.sdd/
  state/
  templates/
  scripts/
```

Existing files are not overwritten unless `--force` is passed.

## Create A Feature Spec

After project initialization:

```sh
.sdd/scripts/new_feature.sh login-rate-limit
```

This creates:

```text
.sdd/specs/YYYY-MM-DD-login-rate-limit/
```

## Workflow Summary

1. Decide with gstack-style role lenses.
2. Stabilize context in `.sdd/`.
3. Execute with small Superpowers-style tasks.
4. Review, QA, verify, and record evidence before completion.

## Test

```sh
./scripts/test_install.sh
```

