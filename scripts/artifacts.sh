#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home_dir="${HOME:?HOME is required}"
default_artifacts_repo="https://github.com/Jincy7/sdd-artifacts.git"
artifacts_repo="${SDD_ARTIFACTS_REPO:-$default_artifacts_repo}"
artifacts_dir="${SDD_ARTIFACTS_DIR:-$home_dir/.sdd-control/artifacts/sdd-artifacts}"

usage() {
  cat <<'EOF'
usage:
  scripts/artifacts.sh init [path] [options]
  scripts/artifacts.sh push [path] [options]
  scripts/artifacts.sh pull [path] [options]
  scripts/artifacts.sh status [path] [options]

Options:
  --repo URL              artifacts repository URL
  --dir PATH              local clone/cache directory for the artifacts repo
  --project-id ID         stable project id; repo-name agnostic
  --display-name NAME     human-readable project name
  --alias NAME            add an alias such as compass or uhdc-compass
  --no-push               commit locally but do not push artifacts repo
  --force                 allow rebinding a local project to a different project id

Environment:
  SDD_ARTIFACTS_REPO      default artifacts repo URL
  SDD_ARTIFACTS_DIR       default artifacts repo local clone/cache path

Artifact layout:
  projects/<project-id>/manifest.json
  projects/<project-id>/AGENTS.md
  projects/<project-id>/sdd-control/
  projects/<project-id>/planning/
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
}

git_remote_url() {
  git -C "$target_dir" remote get-url origin 2>/dev/null || true
}

git_head() {
  git -C "$target_dir" rev-parse HEAD 2>/dev/null || true
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

  node - "$config" "$project_id" "$display" "$aliases_json" "$artifacts_repo" "$remote" <<'NODE'
const fs = require("fs");
const [path, projectId, displayName, aliasesJson, artifactsRepo, remoteUrl] = process.argv.slice(2);
let data = {};
if (fs.existsSync(path)) data = JSON.parse(fs.readFileSync(path, "utf8"));
const aliases = JSON.parse(aliasesJson);
data.schema_version = 1;
data.project_id = projectId;
data.display_name = data.display_name || displayName;
data.aliases = [...new Set([...(data.aliases || []), ...aliases])];
data.artifacts_repo = artifactsRepo;
data.updated_at = new Date().toISOString();
data.repo_remotes = [...new Set([...(data.repo_remotes || []), remoteUrl].filter(Boolean))];
fs.writeFileSync(path, `${JSON.stringify(data, null, 2)}\n`);
NODE
}

load_project_id() {
  local config="$target_dir/.sdd-control/project.json"
  if [ "$project_id" != "" ]; then
    sanitize_project_id "$project_id"
    return
  fi
  [ -f "$config" ] || die "missing $config; run artifacts init first or pass --project-id"
  node -e 'const fs=require("fs"); const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); if (!d.project_id) process.exit(1); process.stdout.write(d.project_id)' "$config"
}

ensure_artifacts_repo() {
  need_cmd git

  if [ -d "$artifacts_dir/.git" ]; then
    log "Updating artifacts repo at $artifacts_dir"
    if git -C "$artifacts_dir" rev-parse --verify HEAD >/dev/null 2>&1 &&
      git -C "$artifacts_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
      git -C "$artifacts_dir" pull --ff-only || warn "could not fast-forward artifacts repo; continuing with local state"
    else
      log "Artifacts repo has no upstream branch yet; skipping pull"
    fi
  else
    mkdir -p "$(dirname "$artifacts_dir")"
    if git clone --quiet "$artifacts_repo" "$artifacts_dir"; then
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
const [configPath, manifestPath, registryPath, now, sourcePath, remoteUrl, gitHead] = process.argv.slice(2);
const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
const manifest = {
  schema_version: 1,
  project_id: config.project_id,
  display_name: config.display_name,
  aliases: config.aliases || [],
  artifacts_repo: config.artifacts_repo,
  updated_at: now,
  source: {
    path: sourcePath,
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

  "$repo_root/scripts/init_project.sh" "$target_dir" >/dev/null
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
  init) cmd_init "$@" ;;
  push|sync) cmd_push "$@" ;;
  pull) cmd_pull "$@" ;;
  status) cmd_status "$@" ;;
  -h|--help|help) usage ;;
  *) die "unknown artifacts command: $cmd" ;;
esac
