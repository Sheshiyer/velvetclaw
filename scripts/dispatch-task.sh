#!/usr/bin/env bash
# VelvetClaw Task Dispatcher — Creates tasks and routes them to correct agent INBOX
#
# Usage:
#   ./scripts/dispatch-task.sh "Research competitor pricing" --tag research --priority high
#   ./scripts/dispatch-task.sh "Fix authentication bug" --tag code
#   ./scripts/dispatch-task.sh "Create logo variants" --tag design --priority critical
#   ./scripts/dispatch-task.sh "Fix auth and research" --tag code,research --priority high
#   ./scripts/dispatch-task.sh "General task" (routes to jarvis by default)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/manifest.yaml"
TASK_REGISTRY="$REPO_ROOT/scripts/task-registry.sh"

# ─── Dependency Check ───

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed. Install with: brew install jq" >&2
  exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: manifest.yaml not found at $MANIFEST" >&2
  exit 1
fi

if [[ ! -x "$TASK_REGISTRY" ]]; then
  echo "ERROR: task-registry.sh not found or not executable at $TASK_REGISTRY" >&2
  exit 1
fi

# ─── Helpers ───

iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

VALID_PRIORITIES="critical high medium low"

validate_priority() {
  local priority="$1"
  if ! echo "$VALID_PRIORITIES" | grep -qw "$priority"; then
    echo "ERROR: Invalid priority '$priority'. Must be one of: $VALID_PRIORITIES" >&2
    exit 1
  fi
}

# ─── Resolve Tag to Department and Lead ───
# Reads manifest.yaml task_routing.by_tag to find department, then department lead

resolve_routing() {
  local tag="$1"

  # Parse task_routing.by_tag from manifest.yaml
  # The by_tag section format (8-space indent):
  #       by_tag:
  #         research: research
  #         code: development
  local department=""

  # Handle comma-separated tags — use first matching tag
  local IFS=','
  for t in $tag; do
    t="$(echo "$t" | xargs)"  # trim whitespace
    if [[ -z "$t" ]]; then continue; fi

    # Extract the by_tag block and search for our tag
    local match
    match=$(awk -v target="$t" '
      /by_tag:/ { intag=1; next }
      intag && /^[[:space:]]+[a-z]/ {
        line = $0
        gsub(/^[[:space:]]+/, "", line)
        n = split(line, kv, ":")
        if (n >= 2) {
          key = kv[1]
          val = kv[2]
          gsub(/[[:space:]]/, "", key)
          gsub(/[[:space:]]/, "", val)
          if (key == target) { print val; exit }
        }
      }
      intag && /^[[:space:]]*$/ { intag=0 }
      intag && /^[[:space:]]*[a-z].*:/ && !/^[[:space:]]+[a-z]/ { intag=0 }
    ' "$MANIFEST")

    if [[ -n "$match" ]]; then
      department="$match"
      break
    fi
  done

  if [[ -z "$department" ]]; then
    # Default route: jarvis
    echo "jarvis|chief|jarvis"
    return
  fi

  # Look up the department lead from hierarchy.departments section
  # The departments block has structure like:
  #     departments:
  #       research:
  #         name: "Research"
  #         lead: atlas
  # Note: must only match hierarchy.departments (4-space indent), not vault.departments
  local lead
  lead=$(awk -v dept="$department" '
    /^[[:space:]]{4}departments:/ { indepts=1; next }
    # Exit departments block if indentation drops
    indepts && /^[[:space:]]{0,4}[a-z]/ { indepts=0 }
    # Match the specific department (6-space indent, e.g. "      research:")
    indepts && $0 ~ "^[[:space:]]+"dept":" { indept=1; next }
    # Match lead line within department (8-space indent)
    indept && /^[[:space:]]+lead:/ {
      line = $0
      gsub(/.*lead:[[:space:]]*/, "", line)
      gsub(/[[:space:]]*$/, "", line)
      print line
      exit
    }
    # Exit department block if we hit another department at 6-space indent
    indept && /^[[:space:]]{6}[a-z]/ { indept=0 }
  ' "$MANIFEST")

  if [[ -z "$lead" ]]; then
    echo "jarvis|chief|jarvis"
    return
  fi

  echo "${lead}|${department}|${lead}"
}

# ─── Write to Agent INBOX ───

write_to_inbox() {
  local agent_id="$1"
  local title="$2"
  local priority="$3"
  local tags="$4"
  local task_id="$5"
  local depends_on="${6:-}"

  local inbox="$REPO_ROOT/agents/$agent_id/INBOX.md"

  # Create agent dir and INBOX if missing
  mkdir -p "$REPO_ROOT/agents/$agent_id"

  if [[ ! -f "$inbox" ]]; then
    cat > "$inbox" <<'INBOX_TEMPLATE'
# INBOX

> Cross-agent task assignments and messages.

## Pending

## Processed
INBOX_TEMPLATE
    echo "Created INBOX.md for $agent_id" >&2
  fi

  # Ensure ## Pending section exists
  if ! grep -q "^## Pending" "$inbox"; then
    # Insert ## Pending before ## Processed, or at end
    if grep -q "^## Processed" "$inbox"; then
      local tmp_inbox="${inbox}.tmp"
      awk '/^## Processed/ { print "## Pending"; print ""; } { print }' "$inbox" > "$tmp_inbox"
      mv "$tmp_inbox" "$inbox"
    else
      echo "" >> "$inbox"
      echo "## Pending" >> "$inbox"
      echo "" >> "$inbox"
      echo "## Processed" >> "$inbox"
    fi
  fi

  local timestamp
  timestamp="$(iso_now)"

  # Build the inbox entry
  local entry=""
  entry+="### [$timestamp] From: dispatch | Priority: $priority"
  entry+=$'\n'"$title"
  entry+=$'\n'"Task-ID: $task_id"
  entry+=$'\n'"Tags: $tags"
  if [[ -n "$depends_on" ]]; then
    entry+=$'\n'"Depends-on: $depends_on"
  fi
  entry+=$'\n'

  # Insert after ## Pending line using a temp file
  local tmp_inbox="${inbox}.tmp"
  local entry_file
  entry_file="$(mktemp)"
  printf '%s\n' "$entry" > "$entry_file"

  # Use sed to insert the entry file content after ## Pending
  {
    local found=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      echo "$line"
      if [[ "$line" == "## Pending"* && $found -eq 0 ]]; then
        found=1
        echo ""
        cat "$entry_file"
      fi
    done < "$inbox"
  } > "$tmp_inbox"
  mv "$tmp_inbox" "$inbox"
  rm -f "$entry_file"
}

# ─── Main ───

main() {
  local title=""
  local tag=""
  local priority="medium"
  local depends_on=""

  # First positional arg is title
  if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
    title="$1"
    shift
  fi

  # Parse named args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag)
        tag="$2"
        shift 2
        ;;
      --priority)
        priority="$2"
        shift 2
        ;;
      --depends-on)
        depends_on="$2"
        shift 2
        ;;
      *)
        echo "ERROR: Unknown argument '$1'" >&2
        echo "Usage: dispatch-task.sh \"title\" --tag TAG --priority PRIORITY [--depends-on DEP]" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$title" ]]; then
    echo "ERROR: Title is required." >&2
    echo "Usage: dispatch-task.sh \"title\" --tag TAG --priority PRIORITY [--depends-on DEP]" >&2
    exit 1
  fi

  validate_priority "$priority"

  # Resolve routing: tag -> department -> lead
  local routing
  routing="$(resolve_routing "$tag")"
  local target_agent target_department target_lead
  target_agent="$(echo "$routing" | cut -d'|' -f1)"
  target_department="$(echo "$routing" | cut -d'|' -f2)"
  target_lead="$(echo "$routing" | cut -d'|' -f3)"

  echo "Routing: tag='${tag:-none}' -> department='$target_department' -> agent='$target_agent'" >&2

  # Create entry in task registry
  local registry_args=("$title" --priority "$priority" --agent "$target_agent" --department "$target_department" --source "manual")
  if [[ -n "$tag" ]]; then
    registry_args+=(--tag "$tag")
  fi
  if [[ -n "$depends_on" ]]; then
    registry_args+=(--depends-on "$depends_on")
  fi

  local task_id
  task_id=$("$TASK_REGISTRY" add "${registry_args[@]}" 2>/dev/null)

  echo "Registry: task $task_id created" >&2

  # Write to target agent's INBOX
  write_to_inbox "$target_agent" "$title" "$priority" "${tag:-untagged}" "$task_id" "$depends_on"

  echo "INBOX: Written to agents/$target_agent/INBOX.md" >&2
  echo ""
  echo "Dispatched: $task_id -> $target_agent ($target_department)"
}

main "$@"
