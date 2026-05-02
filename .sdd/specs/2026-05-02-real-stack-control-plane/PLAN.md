# Implementation Plan: Real Stack Control Plane

## Scope

Replace the custom workflow package with a real upstream installer and routing layer.

## Task List

- [x] Task 1: verify upstream install commands from official sources.
  - Behavior: know actual GSD, Superpowers, and gstack Codex paths.
  - Verification: official docs and temp-home smoke tests.
  - Risk: upstream docs can change.
- [x] Task 2: create `scripts/sdd-control-plane.sh`.
  - Behavior: install, update, status, and project init entry points.
  - Verification: mocked install test and shell syntax checks.
  - Risk: official installers may mutate `~/.codex/config.toml`; backup before GSD.
- [x] Task 3: replace `sdd-workflow` skill with `sdd-control-plane`.
  - Behavior: route to upstream skills instead of duplicating their workflows.
  - Verification: skill exists and installs to `~/.codex/skills/sdd-control-plane`.
  - Risk: existing legacy skill may linger; installer moves it aside.
- [x] Task 4: simplify project initialization templates.
  - Behavior: write `AGENTS.md` and `.sdd-control/` notes only.
  - Verification: `scripts/test_install.sh`.
  - Risk: users still need to run `$gsd-new-project` in Codex.
- [x] Task 5: update docs.
  - Behavior: README says this installs the real upstream stack.
  - Verification: file review.
  - Risk: docs must stay clear that the control plane is not upstream.

## TDD Targets

- Mocked installer must create detectable markers for all layers.
- Status command must report all layers as `ok` in mocked install.
- Project init must create only routing artifacts.

## Checkpoints

- [x] Upstream GSD temp install passed.
- [x] Upstream Superpowers temp install passed.
- [x] Upstream gstack temp install passed.
- [x] Mock tests pass.
- [x] Real install on user HOME complete.
- [ ] Commit and push complete.
