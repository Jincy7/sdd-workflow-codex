# Verification: Real Stack Control Plane

## Commands Run

| Command | Result | Notes |
| --- | --- | --- |
| `HOME=<tmp> npx get-shit-done-cc@latest --codex --global` | Pass | Installed official GSD v1.39.1 into temp `~/.codex`; npm warned Node 20 is below declared Node >=22. |
| `HOME=<tmp> git clone https://github.com/obra/superpowers.git ~/.codex/superpowers && ln -s ... ~/.agents/skills/superpowers` | Pass | Official Superpowers Codex symlink method worked. |
| `HOME=<tmp> git clone https://github.com/garrytan/gstack.git ~/.gstack/repos/gstack && setup --host codex --prefix --quiet` | Pass | Built gstack and linked prefixed Codex skills; downloaded Playwright browsers. |
| `./scripts/test_install.sh` | Pass | Mocked all layers, checked status, initialized a temp project, syntax-checked scripts. |
| `./scripts/test_real_upstreams.sh` | Pass | Real temp-home GSD and Superpowers install passed; gstack intentionally skipped. |
| `./install.sh` | Pass | Installed real GSD, Superpowers, gstack, and `sdd-control-plane` to the user's HOME. |
| `./scripts/sdd-control-plane.sh status` | Pass | Reports GSD 65 skills, gstack 44 skills, Superpowers symlink, and control-plane skill. |

## Manual QA

| Flow | Result | Notes |
| --- | --- | --- |
| Inspect upstream skill names | Pass | GSD exposes `gsd-*`; gstack exposes `gstack-*`; Superpowers exposes methodology skills. |
| Verify legacy custom skill cleanup | Pass | Old `~/.codex/skills/sdd-workflow` was moved to a timestamped backup. |

## Evidence

- Remaining: restart Codex so newly installed skills are discovered in fresh session context.
