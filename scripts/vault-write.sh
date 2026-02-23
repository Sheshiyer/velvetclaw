#!/usr/bin/env bash
# VelvetClaw Vault Writer — Writes deliverables to shared vault with YAML frontmatter
#
# Usage (normal write):
#   ./scripts/vault-write.sh research market-analysis.md --author atlas --task task-123 --content "Content..."
#   cat analysis.md | ./scripts/vault-write.sh research market-analysis.md --author atlas --task task-123
#
# Usage (cross-department handoff):
#   ./scripts/vault-write.sh --handoff research content brief.md --author atlas --task task-123 --content "Brief..."
#   cat brief.md | ./scripts/vault-write.sh --handoff research content brief.md --author atlas --task task-123

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_BASE="$REPO_ROOT/vault"

# ─── Helpers ───

iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

usage() {
  echo "VelvetClaw Vault Writer"
  echo ""
  echo "Usage:"
  echo "  vault-write.sh DEPARTMENT FILENAME --author AGENT --task TASK_ID [--content \"...\"] [--tags t1,t2]"
  echo "  vault-write.sh --handoff FROM_DEPT TO_DEPT FILENAME --author AGENT --task TASK_ID [--content \"...\"]"
  echo "  cat file.md | vault-write.sh DEPARTMENT FILENAME --author AGENT --task TASK_ID"
  echo ""
  echo "Options:"
  echo "  --author   Agent ID who authored the content (required)"
  echo "  --task     Task ID this deliverable is for (required)"
  echo "  --content  Content string (if not piped via stdin)"
  echo "  --tags     Comma-separated tags"
  echo "  --handoff  Cross-department handoff mode (FROM_DEPT TO_DEPT)"
}

# ─── Main ───

main() {
  local handoff_mode=false
  local handoff_from=""
  local handoff_to=""
  local department=""
  local filename=""
  local author=""
  local task_id=""
  local content=""
  local tags=""

  # Detect handoff mode
  if [[ "${1:-}" == "--handoff" ]]; then
    handoff_mode=true
    shift
    if [[ $# -lt 3 ]]; then
      echo "ERROR: --handoff requires FROM_DEPT TO_DEPT FILENAME" >&2
      usage >&2
      exit 1
    fi
    handoff_from="$1"
    handoff_to="$2"
    filename="$3"
    department="handoffs"
    shift 3
  else
    # Normal mode: positional args are department filename
    if [[ $# -lt 2 ]]; then
      echo "ERROR: DEPARTMENT and FILENAME are required." >&2
      usage >&2
      exit 1
    fi
    department="$1"
    filename="$2"
    shift 2
  fi

  # Parse named args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --author)
        author="$2"
        shift 2
        ;;
      --task)
        task_id="$2"
        shift 2
        ;;
      --content)
        content="$2"
        shift 2
        ;;
      --tags)
        tags="$2"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "ERROR: Unknown argument '$1'" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  # Validate required fields
  if [[ -z "$author" ]]; then
    echo "ERROR: --author is required." >&2
    exit 1
  fi
  if [[ -z "$task_id" ]]; then
    echo "ERROR: --task is required." >&2
    exit 1
  fi

  # Read content from stdin if not provided via --content
  if [[ -z "$content" ]]; then
    if [[ -t 0 ]]; then
      echo "ERROR: No --content provided and no stdin pipe detected." >&2
      exit 1
    fi
    content="$(cat)"
  fi

  if [[ -z "$content" ]]; then
    echo "ERROR: Content is empty." >&2
    exit 1
  fi

  # Determine target path
  local target_dir
  if [[ "$handoff_mode" == "true" ]]; then
    target_dir="$VAULT_BASE/handoffs"
  else
    target_dir="$VAULT_BASE/$department"
  fi

  mkdir -p "$target_dir"
  local target_file="$target_dir/$filename"

  # Build tags array for frontmatter
  local tags_yaml="[]"
  if [[ -n "$tags" ]]; then
    tags_yaml="[$(echo "$tags" | sed 's/,/, /g')]"
  fi

  local now
  now="$(iso_now)"

  # Build YAML frontmatter
  local frontmatter=""
  frontmatter+="---"
  frontmatter+=$'\n'"author: $author"
  if [[ "$handoff_mode" == "true" ]]; then
    frontmatter+=$'\n'"department: $handoff_from"
  else
    frontmatter+=$'\n'"department: $department"
  fi
  frontmatter+=$'\n'"task_id: $task_id"
  frontmatter+=$'\n'"created: $now"
  frontmatter+=$'\n'"tags: $tags_yaml"

  if [[ "$handoff_mode" == "true" ]]; then
    frontmatter+=$'\n'"handoff_from: $handoff_from"
    frontmatter+=$'\n'"handoff_to: $handoff_to"
    frontmatter+=$'\n'"requires_action: true"
  fi

  frontmatter+=$'\n'"---"

  # Write with atomic temp file
  local tmp_file="${target_file}.tmp"
  {
    echo "$frontmatter"
    echo ""
    echo "$content"
  } > "$tmp_file"
  mv "$tmp_file" "$target_file"

  # Output results
  echo "$target_file"

  if [[ "$handoff_mode" == "true" ]]; then
    echo "Vault handoff: $handoff_from -> $handoff_to via $target_file" >&2
  else
    echo "Vault write: $target_file (author: $author, task: $task_id)" >&2
  fi
}

main "$@"
