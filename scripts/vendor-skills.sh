#!/usr/bin/env bash
#
# vendor-skills.sh — flatten claude-arsenal's plugin skills into a consuming
# project's .claude/skills/ so they work on Claude Code on the web (which has
# no plugin/marketplace support and only reads committed .claude/skills/).
#
# One source of truth stays in plugins/<plugin>/skills/<skill>/; the vendored
# copies are generated build output. Each vendored skill dir is tagged with a
# .arsenal-vendored marker so a re-run can clean up renamed/removed skills
# without touching skills the consumer authored themselves.
#
# Usage (from a consuming repo, against a clone of claude-arsenal):
#   bash <arsenal>/scripts/vendor-skills.sh --src <arsenal> --dest .claude/skills
#
# Options:
#   --src DIR       claude-arsenal checkout (default: this script's repo root)
#   --dest DIR      output dir (default: .claude/skills)
#   --plugins LIST  comma-separated plugins to vendor, or "all" (default: core)
#   --list          print the skills that would be vendored, then exit
#   -h, --help      this help
#
# Excludes skill-creator by default (you author skills in the marketplace, not
# in a consuming project) — pass --plugins all to include it.

set -euo pipefail

MARKER=".arsenal-vendored"

# --- resolve script's own repo root (works when run from a clone) -----------
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$(cd "$script_dir/.." && pwd)"
dest=".claude/skills"
plugins="core"
list_only=0

usage() { sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --src)     src="$2"; shift 2 ;;
    --dest)    dest="$2"; shift 2 ;;
    --plugins) plugins="$2"; shift 2 ;;
    --list)    list_only=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "vendor-skills: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -d "$src/plugins" ] || { echo "vendor-skills: no plugins/ under --src '$src'" >&2; exit 2; }

# --- select plugins ---------------------------------------------------------
if [ "$plugins" = "all" ]; then
  mapfile -t plugin_dirs < <(find "$src/plugins" -maxdepth 1 -mindepth 1 -type d | sort)
else
  plugin_dirs=()
  IFS=',' read -ra names <<< "$plugins"
  for n in "${names[@]}"; do
    n="$(echo "$n" | tr -d '[:space:]')"
    [ -n "$n" ] || continue
    if [ -d "$src/plugins/$n" ]; then
      plugin_dirs+=("$src/plugins/$n")
    else
      echo "vendor-skills: plugin '$n' not found under $src/plugins" >&2; exit 2
    fi
  done
fi

# --- collect skills, detect cross-plugin name collisions --------------------
declare -A skill_src=()   # skill name -> source dir
for pd in "${plugin_dirs[@]}"; do
  [ -d "$pd/skills" ] || continue
  for sd in "$pd/skills"/*/; do
    [ -f "$sd/SKILL.md" ] || continue
    name="$(basename "$sd")"
    if [ -n "${skill_src[$name]:-}" ]; then
      echo "vendor-skills: skill name collision '$name' (in two plugins) — refusing" >&2
      exit 2
    fi
    skill_src[$name]="${sd%/}"
  done
done

[ "${#skill_src[@]}" -gt 0 ] || { echo "vendor-skills: no skills matched" >&2; exit 2; }

if [ "$list_only" -eq 1 ]; then
  printf '%s\n' "${!skill_src[@]}" | sort
  exit 0
fi

# --- safety: refuse to clobber a consumer-authored skill of the same name ---
for name in "${!skill_src[@]}"; do
  if [ -d "$dest/$name" ] && [ ! -f "$dest/$name/$MARKER" ]; then
    echo "vendor-skills: $dest/$name exists and is not arsenal-vendored — refusing to overwrite a skill you authored" >&2
    exit 2
  fi
done

# --- clean previously-vendored skills (handles renames/removals) ------------
mkdir -p "$dest"
while IFS= read -r marker; do
  rm -rf "$(dirname "$marker")"
done < <(find "$dest" -mindepth 2 -maxdepth 2 -name "$MARKER" 2>/dev/null)

# --- copy selected skills flat, tag each with a marker ----------------------
count=0
for name in "${!skill_src[@]}"; do
  cp -R "${skill_src[$name]}" "$dest/$name"
  # drop any author-local findings logs that may ride along
  rm -f "$dest/$name/findings.md"
  printf 'vendored from claude-arsenal by scripts/vendor-skills.sh\nskill: %s\n' "$name" > "$dest/$name/$MARKER"
  count=$((count + 1))
done

echo "vendor-skills: vendored $count skill(s) into $dest/ (plugins: $plugins)"
echo "Commit $dest/ so Claude Code on the web picks the skills up."
