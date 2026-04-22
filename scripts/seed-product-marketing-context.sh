#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE_FILE="$REPO_ROOT/.agents/product-marketing-context.md"

usage() {
  cat <<'EOF'
Usage:
  seed-product-marketing-context.sh [--force] <workspace> [<workspace> ...]

Copies the seeded Tryambakam Noesis product-marketing context into one or more
OpenClaw or repo workspaces as .agents/product-marketing-context.md.
EOF
}

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Source context file not found: $SOURCE_FILE" >&2
  exit 1
fi

force=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

for target in "$@"; do
  target_dir="${target%/}"
  agents_dir="$target_dir/.agents"
  target_file="$agents_dir/product-marketing-context.md"

  mkdir -p "$agents_dir"

  if [[ -f "$target_file" && "$force" != true ]]; then
    echo "Skipping existing file: $target_file" >&2
    continue
  fi

  cp "$SOURCE_FILE" "$target_file"
  echo "Seeded: $target_file"
done
