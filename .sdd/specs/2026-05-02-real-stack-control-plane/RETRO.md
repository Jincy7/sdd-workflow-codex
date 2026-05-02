# Retro: Real Stack Control Plane

## What Worked

Testing each official installer in a temporary `HOME` clarified the real side effects and paths before changing the user's home directory.

## What Failed Or Slowed Us Down

The initial repo over-abstracted the idea and created a parallel workflow. gstack's real install is also intentionally heavy because it builds browser tooling.

## Reusable Knowledge

For actual stack composition, the repo should be a control plane, not a framework clone.

## Follow-Ups

- Refresh Codex after global skill installation.
- Consider Node 22 upgrade for official GSD compatibility.

