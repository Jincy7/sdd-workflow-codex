# Project Control Plane Notes

## Project Purpose

TBD.

## Installed Stack Expectations

- GSD installed globally for Codex.
- Superpowers installed via the official Codex symlink.
- gstack installed globally for Codex with prefixed `gstack-*` skills.
- `sdd-control-plane` installed globally for routing.

## Personal Workflow Mode

This file is intended to live in a local, git-ignored overlay unless the team has explicitly chosen to share SDD control-plane state.

Recommended local excludes:

- `AGENTS.md`
- `.sdd-control/`
- `.planning/`

Recommended GSD personal setting:

- `.planning/config.json` -> `commit_docs: false`

## Verification Commands

- Control plane status: `scripts/sdd-control-plane.sh status` from the control plane repo.
- GSD check in Codex: `$gsd-help`.
- gstack check in Codex: `$gstack-office-hours` or `$gstack-review`.
- Superpowers check in Codex: ask for a task that triggers `using-superpowers` or `test-driven-development`.
