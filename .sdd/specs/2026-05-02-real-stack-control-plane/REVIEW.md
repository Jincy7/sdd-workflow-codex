# Review: Real Stack Control Plane

## Staff Engineer Review

- Finding: The previous naming made the custom workflow look like the product.
- Fix: Rename to `sdd-control-plane` and remove the custom `sdd-workflow` skill source.

## QA Review

- Flow: Mock install into temp `HOME`, run status, initialize temp project.
- Result: `./scripts/test_install.sh` passed.

## Performance Review

- Concern: Full gstack setup is slow and downloads large browser binaries.
- Evidence: temp install built Bun artifacts and downloaded Playwright Chromium/headless shell.
- Fix: provide `--skip-gstack` and a separate real test flag.

## Security Review

- Concern: GSD modifies Codex config/hooks.
- Evidence: official installer writes `~/.codex/config.toml` and hooks.
- Fix: backup `~/.codex/config.toml` before running official GSD.

- Concern: gstack installs skills as symlinks, which status initially undercounted.
- Fix: status now counts both directories and symlinks.

## Open Questions

- None.
