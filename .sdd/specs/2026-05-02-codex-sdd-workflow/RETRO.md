# Retro: Codex SDD Workflow

## What Worked

Separating the frameworks by responsibility kept the workflow small and Codex-friendly. Moving the skill source to `skills/sdd-workflow` made the installer package cleaner than keeping it under `.codex/`.

## What Failed Or Slowed Us Down

The YouTube page did not expose a transcript through the browsing view, so external articles and repositories were used to verify the framework split.

## Reusable Knowledge

For Codex, global skills and project-local `.sdd/` complement each other: global workflow instructions can be shared, while state remains isolated per repo.

## Follow-Ups

- Add project-specific install/test/build commands once application code exists.
- Start a fresh Codex session after global skill installation if the skill list does not refresh immediately.

