# Codex Project Instructions

This repository builds an SDD control plane for Codex.

## Current Goal

Install and orchestrate the real upstream stack:

- Official GSD for Codex.
- Official Superpowers for Codex.
- Official gstack for Codex.
- A thin `sdd-control-plane` skill that routes between them.

## Boundaries

- Do not describe this repo as a replacement implementation of GSD, Superpowers, or gstack.
- Do not duplicate upstream workflow logic when the upstream skill can own it.
- Keep project initialization minimal: `AGENTS.md` plus `.sdd-control/` routing notes.
- Use prefixed gstack skills (`gstack-*`) to avoid collisions.

## Verification

- Fast test: `./scripts/test_install.sh`.
- Real upstream test without gstack: `./scripts/test_real_upstreams.sh`.
- Full real upstream test: `./scripts/test_real_upstreams.sh --include-gstack`.
- Status check: `./scripts/sdd-control-plane.sh status`.

