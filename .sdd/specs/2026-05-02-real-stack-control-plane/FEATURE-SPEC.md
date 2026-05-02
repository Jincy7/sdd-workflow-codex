# Feature Spec: Real Stack Control Plane

## Feature ID

`2026-05-02-real-stack-control-plane`

## Outcome

The repository installs the real upstream GSD, Superpowers, and gstack Codex integrations, then adds only a thin control-plane skill that routes work between them.

## Users And Use Cases

- User wants the actual upstream stacks installed, not a similar custom workflow.
- Codex can use GSD for durable planning, Superpowers for execution discipline, and gstack for review/QA/release roles.
- Projects get lightweight routing notes without replacing upstream state systems.

## Non-Goals

- Reimplementing GSD, Superpowers, or gstack.
- Vendoring upstream repos into this repository.
- Hiding heavy upstream install costs such as gstack's Bun build and Playwright browser download.

## gstack Decision Notes

### Office Hours

- Problem: The previous package copied the ideas but did not install the actual tools.
- Fragile assumption: A custom `.sdd/` system could be mistaken for official GSD.
- Better framing: Install upstreams directly and keep local code as a router/control plane.

### CEO Review

- Smallest lovable outcome: `./install.sh` installs all three upstream stacks plus `$sdd-control-plane`.
- Things to cut: custom SDD templates for downstream projects.
- Success signal: real upstream smoke tests pass in a temporary `HOME`, and real install status reports all layers present.

### Engineering Review

- Architecture: `scripts/sdd-control-plane.sh` owns install/status/init; official installers own their own files.
- Data flow: install upstreams -> install routing skill -> initialize project notes -> Codex uses upstream skills.
- Contracts: `status` must detect all four layers.
- Edge cases: Node <22 for GSD, missing Bun for gstack, existing legacy `sdd-workflow` skill.
- Test strategy: mock test for CI-speed checks; real upstream tests for official installer behavior.

### Design Review

- States: installed, missing, skipped, mocked.
- UX: one command for all installs, skip flags for expensive/optional parts.
- Naming: use `sdd-control-plane` so it is not confused with official GSD.

## Acceptance Criteria

- [x] `install.sh` invokes a control-plane installer.
- [x] Installer runs official GSD command for Codex.
- [x] Installer follows official Superpowers Codex clone/symlink method.
- [x] Installer clones official gstack and runs `setup --host codex`.
- [x] Control-plane skill is installed separately as `sdd-control-plane`.
- [x] Project init writes routing notes, not a fake GSD replacement.
- [x] Tests cover mocked install/status/init.
- [x] Real upstream GSD, Superpowers, and gstack installs were smoke-tested in temporary homes.

## Risks

- Risk: gstack install is heavy and downloads Playwright browsers.
- Mitigation: document this and keep a `--skip-gstack` path for quicker setup.

- Risk: GSD currently declares Node >=22 while this machine has Node 20.
- Mitigation: installer warns; real smoke test showed install still completes.

## Verification Plan

- Automated: `./scripts/test_install.sh`.
- Real upstream: `./scripts/test_real_upstreams.sh` and `./scripts/test_real_upstreams.sh --include-gstack`.
- Manual: `./scripts/sdd-control-plane.sh status` after real install.

