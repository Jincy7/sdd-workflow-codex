# SDD Control Plane for Codex

This repo installs and orchestrates the real upstream SDD stack for Codex:

- [GSD](https://github.com/gsd-build/get-shit-done) for durable planning, context engineering, phases, and verification.
- [Superpowers](https://github.com/obra/superpowers) for engineering discipline: brainstorming, TDD, debugging, plan execution, and verification loops.
- [gstack](https://github.com/garrytan/gstack) for role-based product, architecture, design, QA, security, and release gates.

The repo's own `sdd-control-plane` skill does not replace those tools. It routes work to the right upstream skill at the right time.

## Install Everything

```sh
./install.sh
```

What this does:

1. Runs official GSD install for Codex:
   ```sh
   npx --yes get-shit-done-cc@latest --codex --global
   ```
2. Installs official Superpowers for Codex:
   ```sh
   git clone https://github.com/obra/superpowers.git ~/.codex/superpowers
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/superpowers/skills ~/.agents/skills/superpowers
   ```
3. Installs official gstack for Codex:
   ```sh
   git clone https://github.com/garrytan/gstack.git ~/.gstack/repos/gstack
   ~/.gstack/repos/gstack/setup --host codex --prefix --quiet
   ```
4. Installs this repo's routing skill:
   ```text
   ~/.codex/skills/sdd-control-plane
   ```

By default, gstack runs with `GSTACK_SKIP_COREUTILS=1` to avoid Homebrew side effects. Override that environment variable if you want gstack's optional coreutils setup.

## Status

```sh
scripts/sdd-control-plane.sh status
```

## Initialize A Project As A Personal Workflow

Inside any repository you personally work in:

```sh
/path/to/sdd-workflow-codex/scripts/init_project.sh .
```

This writes:

```text
AGENTS.md
.sdd-control/
  PROJECT.md
  STACKS.md
```

By default, project initialization is **personal**. It updates the target repo's local `.git/info/exclude`, not the shared `.gitignore`, so these workflow artifacts stay off team branches:

```text
AGENTS.md
.sdd-control/
.planning/
```

If official GSD has already created `.planning/config.json`, personal mode also sets:

```json
"commit_docs": false
```

Then in Codex, use:

```text
$sdd-control-plane
$gsd-new-project
```

For a team-visible workflow that should be committed to the repo:

```sh
/path/to/sdd-workflow-codex/scripts/init_project.sh --team .
```

## Sync Personal Artifacts Across Machines

Use the private artifacts repo to sync workflow state by stable project id, not repository name:

```sh
/path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts init . \
  --project-id compass-a2a \
  --display-name "Compass A2A Gateway" \
  --alias compass \
  --alias uhdc-compass
```

This writes a local pointer:

```text
.sdd-control/project.json
```

and stores artifacts in the central repo:

```text
projects/compass-a2a/
  manifest.json
  AGENTS.md
  sdd-control/
  planning/
registry/projects.json
```

Default artifacts repo:

```text
https://github.com/Jincy7/sdd-artifacts.git
```

Common commands:

```sh
# Push local AGENTS.md, .sdd-control/, and .planning/ to the artifacts repo
/path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts push .

# Restore on another machine or after a repo rename
/path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts pull . --project-id compass-a2a

# After a specific task, capture current repo shape and sync artifacts
/path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts checkpoint . \
  --note "finished PR-10 reducer stabilization"

# If your git credential helper picks the wrong GitHub account
/path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts checkpoint . \
  --note "finished PR-10 reducer stabilization" \
  --gh-user Jincy7

# Use a different local clone/cache path
SDD_ARTIFACTS_DIR=~/.cache/sdd-artifacts \
  /path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts status .
```

Aliases such as `compass` and `uhdc-compass` are metadata only. The stable `project_id` is the identity.

For semantic repo-shape sync after meaningful code changes, use this post-work route:

```text
$gsd-progress or $gsd-verify-work
-> if architecture/code layout changed: $gsd-map-codebase
-> if lessons changed: $gsd-extract-learnings
-> scripts/sdd-control-plane.sh artifacts checkpoint . --note "<task>"
```

`checkpoint` records the current git branch, HEAD, dirty status, and whether `.planning/codebase/` appears stale against HEAD. It does not rewrite GSD's semantic docs by itself; official GSD owns that.

## Control Plane Route

The default route is:

```text
gstack office-hours/CEO review
-> GSD spec/plan phase
-> gstack eng/design review
-> Superpowers TDD/execution discipline
-> GSD execute/verify
-> gstack review/QA/ship
```

Use prefixed gstack skills such as `$gstack-review` and `$gstack-qa` so they do not collide with GSD or Superpowers.

## Tests

Fast mocked test:

```sh
./scripts/test_install.sh
```

Real upstream smoke test in a temporary `HOME`:

```sh
./scripts/test_real_upstreams.sh
```

Full real upstream test including gstack's heavy Bun build and Playwright browser download:

```sh
./scripts/test_real_upstreams.sh --include-gstack
```

## Notes

- GSD currently declares Node.js `>=22`. The installer may still complete on older Node versions, but Node 22+ is recommended.
- gstack requires Bun and downloads Playwright Chromium during setup.
- Restart Codex after installing new skills so discovery refreshes.
