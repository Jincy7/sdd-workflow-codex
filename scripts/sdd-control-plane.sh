#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home_dir="${HOME:?HOME is required}"
codex_home="${home_dir}/.codex"
agents_home="${home_dir}/.agents"
control_skill_source="${repo_root}/skills/sdd-control-plane"

usage() {
  cat <<'EOF'
usage:
  scripts/sdd-control-plane.sh install [options]
  scripts/sdd-control-plane.sh update [options]
  scripts/sdd-control-plane.sh status
  scripts/sdd-control-plane.sh init-project [path] [--force]
  scripts/sdd-control-plane.sh preview [path] [--output FILE] [--open]
  scripts/sdd-control-plane.sh artifacts <init|push|pull|status> [path] [options]

install/update options:
  --skip-gsd
  --skip-superpowers
  --skip-gstack
  --skip-control-plane
  --no-backup

Environment:
  HOME                    controls the target ~/.codex, ~/.agents, ~/.gstack roots
  SDD_CP_MOCK=1           create fake install markers for fast tests
  GSTACK_SKIP_COREUTILS=1 skip gstack's optional Homebrew coreutils install
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

backup_path() {
  local path="$1"
  [ -e "$path" ] || [ -L "$path" ] || return 0
  local backup="${path}.backup.$(date +%Y%m%d%H%M%S)"
  cp -R "$path" "$backup"
  log "Backed up $path to $backup"
}

move_aside() {
  local path="$1"
  [ -e "$path" ] || [ -L "$path" ] || return 0
  local base
  local backup
  base="$(basename "$path")"
  case "$path" in
    "$codex_home/skills/"*)
      mkdir -p "$codex_home/skill-backups"
      backup="$codex_home/skill-backups/${base}.backup.$(date +%Y%m%d%H%M%S)"
      ;;
    "$agents_home/skills/"*)
      mkdir -p "$agents_home/skill-backups"
      backup="$agents_home/skill-backups/${base}.backup.$(date +%Y%m%d%H%M%S)"
      ;;
    *)
      backup="${path}.backup.$(date +%Y%m%d%H%M%S)"
      ;;
  esac
  mv "$path" "$backup"
  log "Moved existing $path to $backup"
}

quarantine_discovery_backups() {
  local skills_dir
  local backup_dir
  local item
  local base

  for skills_dir in "$codex_home/skills" "$agents_home/skills"; do
    [ -d "$skills_dir" ] || continue
    case "$skills_dir" in
      "$codex_home/skills") backup_dir="$codex_home/skill-backups" ;;
      "$agents_home/skills") backup_dir="$agents_home/skill-backups" ;;
      *) continue ;;
    esac
    mkdir -p "$backup_dir"
    while IFS= read -r item; do
      base="$(basename "$item")"
      mv "$item" "$backup_dir/$base"
      log "Moved discovery backup $item to $backup_dir/$base"
    done < <(find "$skills_dir" -maxdepth 1 \( -type d -o -type l \) -name '*.backup.*' -print 2>/dev/null)
  done
}

clone_or_update() {
  local url="$1"
  local dir="$2"
  if [ -d "$dir/.git" ]; then
    log "Updating $dir"
    git -C "$dir" pull --ff-only
  else
    mkdir -p "$(dirname "$dir")"
    log "Cloning $url to $dir"
    git clone --single-branch --depth 1 "$url" "$dir"
  fi
}

node_major() {
  node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0
}

install_gsd() {
  log "==> Installing official GSD for Codex"
  if [ "${SDD_CP_MOCK:-0}" = "1" ]; then
    mkdir -p "$codex_home/get-shit-done" "$codex_home/skills/gsd-help" "$codex_home/agents"
    printf 'mock\n' > "$codex_home/get-shit-done/VERSION"
    printf '%s\n' '---' 'name: gsd-help' 'description: mock' '---' > "$codex_home/skills/gsd-help/SKILL.md"
    return
  fi

  need_cmd node
  need_cmd npm
  need_cmd npx
  local major
  major="$(node_major)"
  if [ "$major" -lt 22 ]; then
    warn "get-shit-done-cc currently declares Node >=22; current Node major is $major. npm may warn even if install succeeds."
  fi

  backup_path "$codex_home/config.toml"
  npx --yes get-shit-done-cc@latest --codex --global
}

install_superpowers() {
  log "==> Installing official Superpowers for Codex"
  if [ "${SDD_CP_MOCK:-0}" = "1" ]; then
    mkdir -p "$codex_home/superpowers/skills/using-superpowers" "$agents_home/skills"
    printf '%s\n' '---' 'name: using-superpowers' 'description: mock' '---' > "$codex_home/superpowers/skills/using-superpowers/SKILL.md"
    ln -sfn "$codex_home/superpowers/skills" "$agents_home/skills/superpowers"
    return
  fi

  need_cmd git
  clone_or_update "https://github.com/obra/superpowers.git" "$codex_home/superpowers"
  mkdir -p "$agents_home/skills"
  if [ -e "$agents_home/skills/superpowers" ] && [ ! -L "$agents_home/skills/superpowers" ]; then
    move_aside "$agents_home/skills/superpowers"
  fi
  ln -sfn "$codex_home/superpowers/skills" "$agents_home/skills/superpowers"
  log "Linked $agents_home/skills/superpowers -> $codex_home/superpowers/skills"
}

install_gstack() {
  log "==> Installing official gstack for Codex"
  if [ "${SDD_CP_MOCK:-0}" = "1" ]; then
    mkdir -p "$home_dir/.gstack/repos/gstack" "$codex_home/skills/gstack-review" "$codex_home/skills/gstack-office-hours" "$codex_home/skills/gstack"
    printf '%s\n' '---' 'name: gstack-review' 'description: mock' '---' > "$codex_home/skills/gstack-review/SKILL.md"
    printf '%s\n' '---' 'name: gstack-office-hours' 'description: mock' '---' > "$codex_home/skills/gstack-office-hours/SKILL.md"
    printf '%s\n' '---' 'name: gstack' 'description: mock' '---' > "$codex_home/skills/gstack/SKILL.md"
    return
  fi

  need_cmd git
  need_cmd bun
  local gstack_repo="$home_dir/.gstack/repos/gstack"
  clone_or_update "https://github.com/garrytan/gstack.git" "$gstack_repo"
  GSTACK_SKIP_COREUTILS="${GSTACK_SKIP_COREUTILS:-1}" "$gstack_repo/setup" --host codex --prefix --quiet
}

install_control_plane() {
  log "==> Installing SDD control plane skill"
  [ -f "$control_skill_source/SKILL.md" ] || die "missing $control_skill_source/SKILL.md"
  mkdir -p "$codex_home/skills"
  quarantine_discovery_backups

  local legacy="$codex_home/skills/sdd-workflow"
  if [ -e "$legacy" ] || [ -L "$legacy" ]; then
    move_aside "$legacy"
  fi

  local target="$codex_home/skills/sdd-control-plane"
  move_aside "$target"
  cp -R "$control_skill_source" "$target"
  log "Installed control plane to $target"
}

write_manifest() {
  mkdir -p "$codex_home"
  cat > "$codex_home/sdd-control-plane-install.txt" <<EOF
installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
repo=${repo_root}
gsd=$1
superpowers=$2
gstack=$3
control_plane=$4
EOF
}

run_install() {
  local do_gsd=1
  local do_superpowers=1
  local do_gstack=1
  local do_control=1
  local do_backup=1

  while [ $# -gt 0 ]; do
    case "$1" in
      --skip-gsd) do_gsd=0 ;;
      --skip-superpowers) do_superpowers=0 ;;
      --skip-gstack) do_gstack=0 ;;
      --skip-control-plane) do_control=0 ;;
      --no-backup) do_backup=0 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown option for install: $1" ;;
    esac
    shift
  done

  if [ "$do_backup" -eq 0 ]; then
    backup_path() { return 0; }
  fi

  [ "$do_gsd" -eq 1 ] && install_gsd
  [ "$do_superpowers" -eq 1 ] && install_superpowers
  [ "$do_gstack" -eq 1 ] && install_gstack
  [ "$do_control" -eq 1 ] && install_control_plane
  write_manifest "$do_gsd" "$do_superpowers" "$do_gstack" "$do_control"
  status
}

count_dirs() {
  local path="$1"
  local pattern="$2"
  find "$path" -maxdepth 1 \( -type d -o -type l \) -name "$pattern" 2>/dev/null | wc -l | tr -d ' '
}

status_line() {
  local name="$1"
  local ok="$2"
  local detail="$3"
  if [ "$ok" = "1" ]; then
    printf 'ok   %-18s %s\n' "$name" "$detail"
  else
    printf 'miss %-18s %s\n' "$name" "$detail"
  fi
}

status() {
  local gsd_ok=0
  local super_ok=0
  local gstack_ok=0
  local control_ok=0

  [ -f "$codex_home/get-shit-done/VERSION" ] && [ -d "$codex_home/skills/gsd-help" ] && gsd_ok=1
  [ -d "$codex_home/superpowers/.git" ] || [ -d "$codex_home/superpowers/skills" ] && [ -L "$agents_home/skills/superpowers" ] && super_ok=1
  [ -d "$home_dir/.gstack/repos/gstack/.git" ] || [ -d "$codex_home/skills/gstack" ] && [ -d "$codex_home/skills/gstack-review" ] && gstack_ok=1
  [ -f "$codex_home/skills/sdd-control-plane/SKILL.md" ] && control_ok=1

  log "==> SDD control plane status for HOME=$home_dir"
  status_line "GSD" "$gsd_ok" "$codex_home/get-shit-done ($(count_dirs "$codex_home/skills" 'gsd-*') skills)"
  status_line "Superpowers" "$super_ok" "$codex_home/superpowers -> $agents_home/skills/superpowers"
  status_line "gstack" "$gstack_ok" "$home_dir/.gstack/repos/gstack ($(count_dirs "$codex_home/skills" 'gstack-*') skills)"
  status_line "Control plane" "$control_ok" "$codex_home/skills/sdd-control-plane"
}

cmd="${1:-install}"
shift || true

case "$cmd" in
  install|update)
    run_install "$@"
    ;;
  status|doctor)
    status
    ;;
  init-project)
    "${repo_root}/scripts/init_project.sh" "$@"
    ;;
  preview)
    need_cmd node
    node "${repo_root}/scripts/preview.js" "$@"
    ;;
  artifacts)
    "${repo_root}/scripts/artifacts.sh" "$@"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    die "unknown command: $cmd"
    ;;
esac
