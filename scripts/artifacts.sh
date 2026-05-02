#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home_dir="${HOME:?HOME is required}"
artifacts_repo="${SDD_ARTIFACTS_REPO:-}"
artifacts_dir="${SDD_ARTIFACTS_DIR:-$home_dir/.sdd-control/artifacts/sdd-artifacts}"
artifacts_dir_explicit=0
global_config="$home_dir/.sdd-control/config.json"

usage() {
  cat <<'EOF'
usage:
  scripts/artifacts.sh init [path] [options]
  scripts/artifacts.sh push [path] [options]
  scripts/artifacts.sh pull [path] [options]
  scripts/artifacts.sh checkpoint [path] [options]
  scripts/artifacts.sh status [path] [options]
  scripts/artifacts.sh configure [options]

Options:
  --repo URL              artifacts repository URL
  --dir PATH              local clone/cache directory for the artifacts repo
  --project-id ID         stable project id; repo-name agnostic
  --display-name NAME     human-readable project name
  --alias NAME            add an alias such as compass or uhdc-compass
  --note TEXT             checkpoint note, such as the completed task name
  --gh-user USER          use a GitHub CLI token for this user when pushing
  --no-push               commit locally but do not push artifacts repo
  --force                 allow rebinding a local project to a different project id

Environment:
  SDD_ARTIFACTS_REPO      default artifacts repo URL
  SDD_ARTIFACTS_DIR       default artifacts repo local clone/cache path
  SDD_ARTIFACTS_GH_USER   GitHub CLI account to use for artifact pushes
  ~/.sdd-control/config.json can also provide artifacts_repo, artifacts_dir, and gh_user.

Artifact layout:
  projects/<project-id>/manifest.json
  projects/<project-id>/AGENTS.md
  projects/<project-id>/sdd-control/
  projects/<project-id>/planning/
  projects/<project-id>/superpowers/
  registry/projects.json
EOF
}

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

github_auth_header() {
  [ "$gh_user" != "" ] || return 1
  need_cmd gh
  local token
  token="$(gh auth token -h github.com -u "$gh_user")"
  printf 'AUTHORIZATION: basic %s\n' "$(printf 'x-access-token:%s' "$token" | base64 | tr -d '\n')"
}

git_clone() {
  local url="$1"
  local dir="$2"
  local header
  if header="$(github_auth_header 2>/dev/null)"; then
    git -c credential.helper= -c "http.https://github.com/.extraheader=$header" clone --quiet "$url" "$dir"
  else
    git clone --quiet "$url" "$dir"
  fi
}

git_artifacts() {
  local header
  if header="$(github_auth_header 2>/dev/null)"; then
    git -C "$artifacts_dir" -c credential.helper= -c "http.https://github.com/.extraheader=$header" "$@"
  else
    git -C "$artifacts_dir" "$@"
  fi
}

json_escape() {
  node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$1"
}

utc_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

generate_project_id() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    printf 'proj-%s-%s\n' "$(date +%Y%m%d%H%M%S)" "$$"
  fi
}

sanitize_project_id() {
  local value="$1"
  if ! printf '%s' "$value" | grep -Eq '^[A-Za-z0-9._-]+$'; then
    die "project id must contain only letters, numbers, dot, underscore, or dash: $value"
  fi
  printf '%s\n' "$value"
}

parse_common_args() {
  target="."
  project_id=""
  display_name=""
  sync_note=""
  gh_user="${SDD_ARTIFACTS_GH_USER:-}"
  aliases=()
  no_push=0
  force=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --repo)
        artifacts_repo="${2:?missing value for --repo}"
        shift
        ;;
      --dir)
        artifacts_dir="${2:?missing value for --dir}"
        artifacts_dir_explicit=1
        shift
        ;;
      --project-id)
        project_id="$(sanitize_project_id "${2:?missing value for --project-id}")"
        shift
        ;;
      --display-name)
        display_name="${2:?missing value for --display-name}"
        shift
        ;;
      --alias)
        aliases+=("${2:?missing value for --alias}")
        shift
        ;;
      --note)
        sync_note="${2:?missing value for --note}"
        shift
        ;;
      --gh-user)
        gh_user="${2:?missing value for --gh-user}"
        shift
        ;;
      --no-push)
        no_push=1
        ;;
      --force)
        force=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        target="$1"
        ;;
    esac
    shift
  done

  target_dir="$(cd "$target" && pwd)"
  load_config_defaults
  load_project_config_defaults
}

load_config_defaults() {
  [ -f "$global_config" ] || return 0
  need_cmd node
  eval "$(
    node - "$global_config" <<'NODE'
const fs = require("fs");
const data = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
function sh(name, value) {
  if (value === undefined || value === null || value === "") return;
  console.log(`${name}=${JSON.stringify(String(value))}`);
}
sh("CONFIG_ARTIFACTS_REPO", data.artifacts_repo);
sh("CONFIG_ARTIFACTS_DIR", data.artifacts_dir);
sh("CONFIG_GH_USER", data.gh_user);
NODE
  )"
  [ "$artifacts_repo" != "" ] || artifacts_repo="${CONFIG_ARTIFACTS_REPO:-}"
  [ "${SDD_ARTIFACTS_DIR:-}" != "" ] || [ "$artifacts_dir_explicit" -eq 1 ] || artifacts_dir="${CONFIG_ARTIFACTS_DIR:-$artifacts_dir}"
  [ "$gh_user" != "" ] || gh_user="${CONFIG_GH_USER:-}"
}

load_project_config_defaults() {
  local config="$target_dir/.sdd-control/project.json"
  [ -f "$config" ] || return 0
  need_cmd node
  local repo
  repo="$(node -e 'const fs=require("fs"); const p=process.argv[1]; const d=JSON.parse(fs.readFileSync(p,"utf8")); process.stdout.write(d.artifacts_repo || "")' "$config")"
  [ "$artifacts_repo" != "" ] || artifacts_repo="$repo"
}

require_artifacts_repo() {
  [ "$artifacts_repo" != "" ] || die "artifacts repo is not configured; pass --repo URL, set SDD_ARTIFACTS_REPO, or run artifacts configure --repo URL"
}

git_remote_url() {
  git -C "$target_dir" remote get-url origin 2>/dev/null || true
}

git_head() {
  git -C "$target_dir" rev-parse HEAD 2>/dev/null || true
}

git_branch() {
  git -C "$target_dir" branch --show-current 2>/dev/null || true
}

default_aliases_json() {
  local remote
  local remote_base
  local entries=()

  entries+=("$(basename "$target_dir")")
  remote="$(git_remote_url)"
  if [ "$remote" != "" ]; then
    remote_base="$(basename "$remote")"
    remote_base="${remote_base%.git}"
    [ "$remote_base" != "" ] && entries+=("$remote_base")
  fi
  if [ "${#aliases[@]}" -gt 0 ]; then
    entries+=("${aliases[@]}")
  fi

  node - "${entries[@]}" <<'NODE'
const values = process.argv.slice(2).map((v) => v.trim()).filter(Boolean);
process.stdout.write(JSON.stringify([...new Set(values)]));
NODE
}

resolve_project_id_from_artifacts() {
  local registry="$artifacts_dir/registry/projects.json"
  local aliases_json
  local remote

  [ -f "$registry" ] || return 1
  aliases_json="$(default_aliases_json)"
  remote="$(git_remote_url)"

  node - "$registry" "$aliases_json" "$remote" <<'NODE'
const fs = require("fs");
const path = require("path");
const [registryPath, aliasesJson, remoteUrl] = process.argv.slice(2);
const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
const root = path.dirname(path.dirname(registryPath));
const aliases = new Set(JSON.parse(aliasesJson).map((value) => value.toLowerCase()));

function remoteName(url) {
  if (!url) return "";
  const raw = url.split(/[/:]/).pop() || "";
  return raw.replace(/\.git$/, "").toLowerCase();
}

function readManifest(project) {
  if (!project.artifact_path) return {};
  const manifestPath = path.join(root, project.artifact_path, "manifest.json");
  if (!fs.existsSync(manifestPath)) return {};
  try {
    return JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  } catch {
    return {};
  }
}

const remote = remoteUrl || "";
const remoteBase = remoteName(remote);
if (remoteBase) aliases.add(remoteBase);

const matches = [];
for (const project of registry.projects || []) {
  const projectAliases = new Set([
    project.project_id,
    ...(project.aliases || []),
  ].filter(Boolean).map((value) => String(value).toLowerCase()));
  const manifest = readManifest(project);
  const reasons = [];
  let score = 0;

  if (remote && manifest.source?.git_remote === remote) {
    reasons.push("git remote");
    score += 10;
  }

  if (aliases.has(String(project.project_id).toLowerCase())) {
    reasons.push("project id");
    score += 5;
  }

  for (const alias of aliases) {
    if (projectAliases.has(alias)) {
      reasons.push(`alias:${alias}`);
      score += 3;
      break;
    }
  }

  if (score > 0) {
    matches.push({ project_id: project.project_id, score, reasons });
  }
}

matches.sort((a, b) => b.score - a.score || a.project_id.localeCompare(b.project_id));
const bestScore = matches[0]?.score || 0;
const best = matches.filter((match) => match.score === bestScore);

if (best.length === 1) {
  process.stdout.write(best[0].project_id);
  process.exit(0);
}

if (matches.length > 1) {
  console.error("multiple artifact projects match this repository; pass --project-id explicitly:");
  for (const match of matches) {
    console.error(`- ${match.project_id} (${match.reasons.join(", ")})`);
  }
  process.exit(2);
}

process.exit(1);
NODE
}

ensure_control_context() {
  if [ ! -d "$target_dir/.sdd-control" ] || [ ! -f "$target_dir/AGENTS.md" ]; then
    "$repo_root/scripts/init_project.sh" "$target_dir" >/dev/null
  fi
}

ensure_local_project_config() {
  local config="$target_dir/.sdd-control/project.json"
  local aliases_json
  local id
  local display
  local remote

  mkdir -p "$target_dir/.sdd-control"
  require_artifacts_repo
  aliases_json="$(default_aliases_json)"
  remote="$(git_remote_url)"

  if [ -f "$config" ]; then
    id="$(node -e 'const fs=require("fs"); const p=process.argv[1]; const d=JSON.parse(fs.readFileSync(p,"utf8")); process.stdout.write(d.project_id || "")' "$config")"
    if [ "$project_id" != "" ] && [ "$id" != "$project_id" ] && [ "$force" -ne 1 ]; then
      die "$config is already bound to project_id=$id; pass --force to rebind"
    fi
    [ "$project_id" = "" ] && project_id="$id"
  fi

  [ "$project_id" != "" ] || project_id="$(generate_project_id)"
  project_id="$(sanitize_project_id "$project_id")"
  display="${display_name:-$(basename "$target_dir")}"

  node - "$config" "$project_id" "$display" "$aliases_json" "$remote" <<'NODE'
const fs = require("fs");
const [path, projectId, displayName, aliasesJson, remoteUrl] = process.argv.slice(2);
let data = {};
if (fs.existsSync(path)) data = JSON.parse(fs.readFileSync(path, "utf8"));
const aliases = JSON.parse(aliasesJson);
data.schema_version = 1;
data.project_id = projectId;
data.display_name = data.display_name || displayName;
data.aliases = [...new Set([...(data.aliases || []), ...aliases])];
delete data.artifacts_repo;
data.updated_at = new Date().toISOString();
data.repo_remotes = [...new Set([...(data.repo_remotes || []), remoteUrl].filter(Boolean))];
fs.writeFileSync(path, `${JSON.stringify(data, null, 2)}\n`);
NODE
}

load_project_id() {
  local config="$target_dir/.sdd-control/project.json"
  local resolved
  if [ "$project_id" != "" ]; then
    sanitize_project_id "$project_id"
    return
  fi
  if [ ! -f "$config" ]; then
    if resolved="$(resolve_project_id_from_artifacts)"; then
      project_id="$(sanitize_project_id "$resolved")"
      printf 'Resolved artifact project_id=%s from registry aliases\n' "$project_id" >&2
      printf '%s' "$project_id"
      return
    fi
    die "missing $config and could not resolve this repository from artifact aliases; run artifacts init first or pass --project-id"
  fi
  node -e 'const fs=require("fs"); const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); if (!d.project_id) process.exit(1); process.stdout.write(d.project_id)' "$config"
}

ensure_artifacts_repo() {
  need_cmd git
  require_artifacts_repo

  if [ -d "$artifacts_dir/.git" ]; then
    log "Updating artifacts repo at $artifacts_dir"
    if git -C "$artifacts_dir" rev-parse --verify HEAD >/dev/null 2>&1 &&
      git -C "$artifacts_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
      git_artifacts pull --ff-only || warn "could not fast-forward artifacts repo; continuing with local state"
    else
      log "Artifacts repo has no upstream branch yet; skipping pull"
    fi
  else
    mkdir -p "$(dirname "$artifacts_dir")"
    if git_clone "$artifacts_repo" "$artifacts_dir"; then
      :
    else
      warn "could not clone $artifacts_repo; initializing local artifacts repo at $artifacts_dir"
      mkdir -p "$artifacts_dir"
      git -C "$artifacts_dir" init -q
      git -C "$artifacts_dir" remote add origin "$artifacts_repo" || true
    fi
  fi

  if ! git -C "$artifacts_dir" rev-parse --verify HEAD >/dev/null 2>&1; then
    git -C "$artifacts_dir" checkout -B main >/dev/null 2>&1 || true
  fi

  mkdir -p "$artifacts_dir/projects" "$artifacts_dir/registry"
  if [ ! -f "$artifacts_dir/README.md" ]; then
    cat > "$artifacts_dir/README.md" <<'EOF'
# SDD Artifacts

Personal SDD/GSD/control-plane artifacts keyed by stable project ids, not repository names.

This repo is intended for private workflow state and cross-machine synchronization.
EOF
  fi
  if [ ! -f "$artifacts_dir/.gitignore" ]; then
    printf '%s\n' '.DS_Store' > "$artifacts_dir/.gitignore"
  fi
}

artifact_project_dir() {
  printf '%s/projects/%s\n' "$artifacts_dir" "$1"
}

write_manifest_and_registry() {
  local id="$1"
  local project_dir
  local config="$target_dir/.sdd-control/project.json"
  local now
  local remote
  local head

  project_dir="$(artifact_project_dir "$id")"
  now="$(utc_now)"
  remote="$(git_remote_url)"
  head="$(git_head)"

  node - "$config" "$project_dir/manifest.json" "$artifacts_dir/registry/projects.json" "$now" "$target_dir" "$remote" "$head" <<'NODE'
const fs = require("fs");
const path = require("path");
const [configPath, manifestPath, registryPath, now, sourcePath, remoteUrl, gitHead] = process.argv.slice(2);
const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
const manifest = {
  schema_version: 1,
  project_id: config.project_id,
  display_name: config.display_name,
  aliases: config.aliases || [],
  updated_at: now,
  source: {
    local_name: path.basename(sourcePath),
    git_remote: remoteUrl || null,
    git_head: gitHead || null,
  },
};
fs.mkdirSync(require("path").dirname(manifestPath), { recursive: true });
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

let registry = { schema_version: 1, projects: [] };
if (fs.existsSync(registryPath)) registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
const projects = (registry.projects || []).filter((p) => p.project_id !== config.project_id);
projects.push({
  project_id: config.project_id,
  display_name: config.display_name,
  aliases: config.aliases || [],
  artifact_path: `projects/${config.project_id}`,
  updated_at: now,
});
projects.sort((a, b) => a.project_id.localeCompare(b.project_id));
registry.schema_version = 1;
registry.projects = projects;
fs.mkdirSync(require("path").dirname(registryPath), { recursive: true });
fs.writeFileSync(registryPath, `${JSON.stringify(registry, null, 2)}\n`);
NODE
}

write_repo_snapshot() {
  local snapshot_json="$target_dir/.sdd-control/repo-snapshot.json"
  local snapshot_md="$target_dir/.sdd-control/REPO-SNAPSHOT.md"
  local status_file
  local head
  local branch
  local remote
  local now

  mkdir -p "$target_dir/.sdd-control"
  status_file="$(mktemp)"
  git -C "$target_dir" status --short > "$status_file" 2>/dev/null || true
  head="$(git_head)"
  branch="$(git_branch)"
  remote="$(git_remote_url)"
  now="$(utc_now)"

  node - "$target_dir" "$snapshot_json" "$snapshot_md" "$status_file" "$now" "$head" "$branch" "$remote" "$sync_note" <<'NODE'
const fs = require("fs");
const path = require("path");
const [targetDir, snapshotJson, snapshotMd, statusFile, now, head, branch, remote, note] = process.argv.slice(2);

const statusLines = fs.existsSync(statusFile)
  ? fs.readFileSync(statusFile, "utf8").split(/\r?\n/).filter(Boolean)
  : [];

const codebaseDir = path.join(targetDir, ".planning", "codebase");
const mappedCommits = new Set();
if (fs.existsSync(codebaseDir)) {
  const stack = [codebaseDir];
  while (stack.length) {
    const dir = stack.pop();
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        stack.push(full);
      } else if (entry.isFile() && entry.name.endsWith(".md")) {
        const text = fs.readFileSync(full, "utf8");
        for (const match of text.matchAll(/Mapped Commit:\*\*\s*`?([0-9a-f]{7,40})`?/gi)) {
          mappedCommits.add(match[1]);
        }
      }
    }
  }
}

const mapped = [...mappedCommits].sort();
const stale = Boolean(head && mapped.length && !mapped.some((commit) => head.startsWith(commit) || commit.startsWith(head)));
const snapshot = {
  schema_version: 1,
  updated_at: now,
  note: note || null,
  repo: {
    local_name: path.basename(targetDir),
    branch: branch || null,
    head: head || null,
    remote: remote || null,
    dirty: statusLines.length > 0,
    status: statusLines,
  },
  planning: {
    exists: fs.existsSync(path.join(targetDir, ".planning")),
    codebase_map: {
      exists: fs.existsSync(codebaseDir),
      mapped_commits: mapped,
      stale_against_head: stale,
    },
  },
};

fs.writeFileSync(snapshotJson, `${JSON.stringify(snapshot, null, 2)}\n`);

const statusPreview = statusLines.length
  ? statusLines.map((line) => `- \`${line.replace(/`/g, "\\`")}\``).join("\n")
  : "- Clean";
const mappedText = mapped.length ? mapped.map((commit) => `- \`${commit}\``).join("\n") : "- None found";
const guidance = stale
  ? "- Codebase map appears stale against current HEAD. In Codex, run `$gsd-map-codebase`, then run `artifacts checkpoint` again."
  : "- Codebase map is either current against HEAD or no mapped commit was found.";

fs.writeFileSync(snapshotMd, `# Repo Snapshot

Updated: ${now}

${note ? `Note: ${note}\n\n` : ""}## Git

- Branch: ${branch || "unknown"}
- HEAD: ${head || "unknown"}
- Remote: ${remote || "none"}
- Dirty: ${statusLines.length ? "yes" : "no"}

## Git Status

${statusPreview}

## GSD Codebase Map

- Exists: ${fs.existsSync(codebaseDir) ? "yes" : "no"}
- Stale against HEAD: ${stale ? "yes" : "no"}

Mapped commits:

${mappedText}

## Sync Guidance

${guidance}
- For phase/progress state, run the relevant GSD workflow such as \`$gsd-progress\`, \`$gsd-verify-work\`, or \`$gsd-extract-learnings\` before checkpointing.
`);
NODE

  rm -f "$status_file"

  if grep -q '"stale_against_head": true' "$snapshot_json"; then
    warn "GSD codebase map appears stale against current HEAD. Run \$gsd-map-codebase, then checkpoint again for semantic repo-shape sync."
  fi
}

commit_artifacts() {
  local id="$1"
  local message="${2:-sync SDD artifacts for $id}"

  git -C "$artifacts_dir" add README.md .gitignore registry "projects/$id"
  if git -C "$artifacts_dir" diff --cached --quiet; then
    log "No artifact changes to commit"
  else
    git -C "$artifacts_dir" commit -m "$message"
  fi

  if [ "$no_push" -eq 1 ]; then
    log "Skipped artifacts push (--no-push)"
  elif [ "$gh_user" != "" ]; then
    git_artifacts push -u origin HEAD:main
  else
    git -C "$artifacts_dir" push -u origin HEAD:main
  fi
}

copy_up() {
  local id="$1"
  local project_dir
  project_dir="$(artifact_project_dir "$id")"
  mkdir -p "$project_dir"

  if [ -f "$target_dir/AGENTS.md" ]; then
    cp "$target_dir/AGENTS.md" "$project_dir/AGENTS.md"
  fi
  if [ -d "$target_dir/.sdd-control" ]; then
    mkdir -p "$project_dir/sdd-control"
    rsync -a --delete "$target_dir/.sdd-control/" "$project_dir/sdd-control/"
  fi
  if [ -d "$target_dir/.planning" ]; then
    mkdir -p "$project_dir/planning"
    rsync -a --delete "$target_dir/.planning/" "$project_dir/planning/"
  fi
  if [ -d "$target_dir/docs/superpowers" ]; then
    mkdir -p "$project_dir/superpowers"
    rsync -a --delete "$target_dir/docs/superpowers/" "$project_dir/superpowers/"
  fi

  write_manifest_and_registry "$id"
}

copy_down() {
  local id="$1"
  local project_dir
  project_dir="$(artifact_project_dir "$id")"
  [ -d "$project_dir" ] || die "missing artifact project directory: $project_dir"

  mkdir -p "$target_dir"
  if [ -f "$project_dir/AGENTS.md" ]; then
    cp "$project_dir/AGENTS.md" "$target_dir/AGENTS.md"
  fi
  if [ -d "$project_dir/sdd-control" ]; then
    mkdir -p "$target_dir/.sdd-control"
    rsync -a --delete "$project_dir/sdd-control/" "$target_dir/.sdd-control/"
  fi
  if [ -d "$project_dir/planning" ]; then
    mkdir -p "$target_dir/.planning"
    rsync -a --delete "$project_dir/planning/" "$target_dir/.planning/"
  fi
  if [ -d "$project_dir/superpowers" ]; then
    mkdir -p "$target_dir/docs/superpowers"
    rsync -a --delete "$project_dir/superpowers/" "$target_dir/docs/superpowers/"
  fi

  "$repo_root/scripts/init_project.sh" "$target_dir" >/dev/null
}

cmd_configure() {
  target="."
  project_id=""
  display_name=""
  sync_note=""
  gh_user="${SDD_ARTIFACTS_GH_USER:-}"
  aliases=()
  no_push=0
  force=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --repo)
        artifacts_repo="${2:?missing value for --repo}"
        shift
        ;;
      --dir)
        artifacts_dir="${2:?missing value for --dir}"
        artifacts_dir_explicit=1
        shift
        ;;
      --gh-user)
        gh_user="${2:?missing value for --gh-user}"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown configure option: $1"
        ;;
    esac
    shift
  done
  [ "$artifacts_repo" != "" ] || die "configure requires --repo URL"
  mkdir -p "$(dirname "$global_config")"
  node - "$global_config" "$artifacts_repo" "$artifacts_dir" "$gh_user" <<'NODE'
const fs = require("fs");
const [path, repo, dir, ghUser] = process.argv.slice(2);
let data = {};
if (fs.existsSync(path)) data = JSON.parse(fs.readFileSync(path, "utf8"));
data.schema_version = 1;
data.artifacts_repo = repo;
data.artifacts_dir = dir;
if (ghUser) data.gh_user = ghUser;
fs.writeFileSync(path, `${JSON.stringify(data, null, 2)}\n`);
NODE
  log "Wrote artifact sync config to $global_config"
}

cmd_init() {
  parse_common_args "$@"
  need_cmd node
  need_cmd rsync
  ensure_control_context
  ensure_local_project_config
  ensure_artifacts_repo
  local id
  id="$(load_project_id)"
  copy_up "$id"
  commit_artifacts "$id" "sync SDD artifacts for $id"
  log "Initialized artifact sync for project_id=$id"
}

cmd_push() {
  parse_common_args "$@"
  need_cmd node
  need_cmd rsync
  ensure_control_context
  ensure_local_project_config
  ensure_artifacts_repo
  local id
  id="$(load_project_id)"
  copy_up "$id"
  commit_artifacts "$id" "sync SDD artifacts for $id"
}

cmd_checkpoint() {
  parse_common_args "$@"
  need_cmd node
  need_cmd rsync
  ensure_control_context
  ensure_local_project_config
  ensure_artifacts_repo
  local id
  id="$(load_project_id)"
  write_repo_snapshot
  copy_up "$id"
  commit_artifacts "$id" "checkpoint SDD artifacts for $id"
}

cmd_pull() {
  parse_common_args "$@"
  need_cmd node
  need_cmd rsync
  ensure_artifacts_repo
  local id
  id="$(load_project_id)"
  copy_down "$id"
  log "Pulled artifact sync for project_id=$id"
}

cmd_status() {
  parse_common_args "$@"
  local id=""
  if [ -f "$target_dir/.sdd-control/project.json" ] || [ "$project_id" != "" ]; then
    id="$(load_project_id)"
  fi
  printf 'target: %s\n' "$target_dir"
  printf 'artifacts_repo: %s\n' "$artifacts_repo"
  printf 'artifacts_dir: %s\n' "$artifacts_dir"
  if [ "$id" != "" ]; then
    printf 'project_id: %s\n' "$id"
    [ -d "$(artifact_project_dir "$id")" ] && printf 'artifact_path: %s\n' "$(artifact_project_dir "$id")"
  else
    printf 'project_id: not initialized\n'
  fi
}

cmd="${1:-status}"
shift || true

case "$cmd" in
  configure) cmd_configure "$@" ;;
  init) cmd_init "$@" ;;
  push|sync) cmd_push "$@" ;;
  checkpoint|refresh) cmd_checkpoint "$@" ;;
  pull) cmd_pull "$@" ;;
  status) cmd_status "$@" ;;
  -h|--help|help) usage ;;
  *) die "unknown artifacts command: $cmd" ;;
esac
