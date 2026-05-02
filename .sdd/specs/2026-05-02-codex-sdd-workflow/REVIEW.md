# Review: Codex SDD Workflow

## Staff Engineer Review

- Finding: Per-project context can leak if the global skill stores state globally.
- Fix: The skill explicitly says `.sdd/` must live under the current repository root and not be reused across projects.

## QA Review

- Flow: Install into temporary `CODEX_HOME`, initialize a temporary project, create a sample feature.
- Result: `./scripts/test_install.sh` passed.

## Performance Review

- Concern: Template set could become too heavy for tiny tasks.
- Evidence: Tier selection allows Tiny tasks to skip formal artifacts.

## Security Review

- Concern: Install script overwrites an existing global skill.
- Evidence: Existing target is moved to a timestamped backup before copy.

## Open Questions

- None.

