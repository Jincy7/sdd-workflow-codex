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

## Planning Preview

After GSD or Superpowers finishes a spec/plan pass, generate a local visual tree of the planning artifacts:

```sh
scripts/sdd-control-plane.sh preview .
```

This writes:

```text
.sdd-control/previews/latest.html
```

The preview reads upstream-owned artifacts from `.planning/phases/` and `docs/superpowers/`; it does not create or mutate GSD, Superpowers, or gstack planning state. Use `--output FILE` to choose another HTML path, or `--open` to open it after generation.

When a plan or spec changes, regenerate the preview and checkpoint artifacts even if no source code changed:

```sh
scripts/sdd-control-plane.sh preview .
scripts/sdd-control-plane.sh artifacts checkpoint . --note "updated plan/spec preview"
```

This syncs `.planning/`, `docs/superpowers/`, and `.sdd-control/previews/` through the personal artifacts repo.

## Initialize A Project As A Personal Workflow

Inside any repository you personally work in:

```sh
/path/to/sdd-workflow-codex/scripts/init_project.sh .
```

This writes:

```text
AGENTS.md managed block
.sdd-control/
  AGENTS.md
  PROJECT.md
  STACKS.md
```

If `AGENTS.md` already exists, initialization preserves the rest of the file and only inserts or updates this block:

```md
<!-- BEGIN sdd-control-plane -->
When using `$sdd-control-plane`, read `.sdd-control/AGENTS.md`, `.sdd-control/PROJECT.md`, and `.sdd-control/STACKS.md`.
<!-- END sdd-control-plane -->
```

By default, project initialization is **personal**. It updates the target repo's local `.git/info/exclude`, not the shared `.gitignore`, so these workflow artifacts stay off team branches:

```text
.sdd-control/
.planning/
docs/superpowers/
```

`AGENTS.md` is not excluded. It stays visible to git as the thin Codex-readable layer, while SDD-specific routing details live under `.sdd-control/`.

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

First configure your personal artifacts repository on this machine:

```sh
/path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts configure \
  --repo https://github.com/<owner>/<repo>.git \
  --gh-user <github-user>
```

This writes `~/.sdd-control/config.json`. The artifacts repo URL and GitHub account stay in that local personal config. The GitHub token is read from `gh auth token` at runtime; it is not written to this repo or to the artifacts repo.

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
  sdd-control/
  planning/
  superpowers/
registry/projects.json
```

`sdd-control/` mirrors local `.sdd-control/`, including the SDD-specific agent routing file. The root `AGENTS.md` is not copied into artifacts; `pull` updates only the managed block so existing repo instructions are not overwritten. `superpowers/` mirrors local `docs/superpowers/`. Treat those files as personal design drafts by default; promote a reviewed spec into the team's normal docs path only when it should become shared project truth.

At the start of work on a machine or checkout that may be stale:

```sh
/path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts pull .
```

`pull` uses local `.sdd-control/project.json` when present. If this repo has not been bound locally yet, it resolves the project from artifact registry aliases and the current git remote. Pass `--project-id` when there is more than one match. Superpowers itself reads and writes the local `docs/superpowers/` directory; the control plane is what hydrates and syncs that directory.

Common commands:

```sh
# Push local .sdd-control/, .planning/, and docs/superpowers/ to the artifacts repo
/path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts push .

# Restore on another machine or after a repo rename
/path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts pull . --project-id compass-a2a

# After a specific task, capture current repo shape and sync artifacts
/path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts checkpoint . \
  --note "finished PR-10 reducer stabilization"

# If your git credential helper picks the wrong GitHub account
/path/to/sdd-workflow-codex/scripts/sdd-control-plane.sh artifacts checkpoint . \
  --note "finished PR-10 reducer stabilization" \
  --gh-user <github-user>

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

For plan/spec-only updates, use:

```text
$gsd-spec-phase/$gsd-plan-phase or Superpowers planning
-> scripts/sdd-control-plane.sh preview .
-> scripts/sdd-control-plane.sh artifacts checkpoint . --note "updated plan/spec preview"
```

## Control Plane Route

The default route is:

```text
gstack office-hours/CEO review
-> GSD spec/plan phase
-> scripts/sdd-control-plane.sh preview .
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
