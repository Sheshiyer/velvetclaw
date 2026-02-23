#!/usr/bin/env bash
# VelvetClaw Task Registry — Global CRUD for .velvetclaw/task-registry.json
#
# Usage:
#   ./scripts/task-registry.sh init
#   ./scripts/task-registry.sh add "title" --tag TAG --priority PRIORITY --agent AGENT
#   ./scripts/task-registry.sh update TASK_ID --status STATUS
#   ./scripts/task-registry.sh list [--status STATUS] [--agent AGENT]
#   ./scripts/task-registry.sh get TASK_ID
#   ./scripts/task-registry.sh summary

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY_DIR="$REPO_ROOT/.velvetclaw"
REGISTRY_FILE="$REGISTRY_DIR/task-registry.json"

# ─── Dependency Check ───

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed. Install with: brew install jq" >&2
  exit 1
fi

# ─── Helpers ───

iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

random4() {
  # macOS-compatible 4-char random hex
  LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c 4
}

generate_task_id() {
  local ts
  ts="$(date +%s)"
  local rand
  rand="$(random4)"
  echo "task-${ts}-${rand}"
}

VALID_STATUSES="pending in_progress completed blocked failed"
VALID_PRIORITIES="critical high medium low"

validate_status() {
  local status="$1"
  if ! echo "$VALID_STATUSES" | grep -qw "$status"; then
    echo "ERROR: Invalid status '$status'. Must be one of: $VALID_STATUSES" >&2
    exit 1
  fi
}

validate_priority() {
  local priority="$1"
  if ! echo "$VALID_PRIORITIES" | grep -qw "$priority"; then
    echo "ERROR: Invalid priority '$priority'. Must be one of: $VALID_PRIORITIES" >&2
    exit 1
  fi
}

# ─── Ensure Registry Exists ───

ensure_registry() {
  mkdir -p "$REGISTRY_DIR"
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    init_registry
  fi
}

# ─── Update Metadata Counts ───

update_metadata() {
  local tmp_file="${REGISTRY_FILE}.tmp"
  local now
  now="$(iso_now)"

  jq --arg now "$now" '
    .metadata.total = (.tasks | length) |
    .metadata.pending = ([.tasks[] | select(.status == "pending")] | length) |
    .metadata.in_progress = ([.tasks[] | select(.status == "in_progress")] | length) |
    .metadata.completed = ([.tasks[] | select(.status == "completed")] | length) |
    .metadata.blocked = ([.tasks[] | select(.status == "blocked")] | length) |
    .metadata.failed = ([.tasks[] | select(.status == "failed")] | length) |
    .metadata.last_updated = $now
  ' "$REGISTRY_FILE" > "$tmp_file"

  mv "$tmp_file" "$REGISTRY_FILE"
}

# ─── Atomic Write Helper ───

atomic_write() {
  local content="$1"
  local target="$2"
  local tmp_file="${target}.tmp"
  echo "$content" > "$tmp_file"
  mv "$tmp_file" "$target"
}

# ─── Subcommands ───

init_registry() {
  mkdir -p "$REGISTRY_DIR"
  local now
  now="$(iso_now)"
  local content
  content=$(jq -n --arg now "$now" '{
    tasks: [],
    metadata: {
      total: 0,
      pending: 0,
      in_progress: 0,
      completed: 0,
      blocked: 0,
      failed: 0,
      last_updated: $now
    }
  }')
  atomic_write "$content" "$REGISTRY_FILE"
  echo "Task registry initialized at $REGISTRY_FILE" >&2
}

cmd_init() {
  init_registry
}

cmd_add() {
  ensure_registry

  local title=""
  local tag=""
  local priority="medium"
  local agent=""
  local department=""
  local source="manual"
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
      --agent)
        agent="$2"
        shift 2
        ;;
      --department)
        department="$2"
        shift 2
        ;;
      --source)
        source="$2"
        shift 2
        ;;
      --depends-on)
        depends_on="$2"
        shift 2
        ;;
      *)
        echo "ERROR: Unknown argument '$1'" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$title" ]]; then
    echo "ERROR: Title is required. Usage: task-registry.sh add \"title\" --tag TAG --priority PRIORITY" >&2
    exit 1
  fi

  validate_priority "$priority"

  local task_id
  task_id="$(generate_task_id)"
  local now
  now="$(iso_now)"

  # Build tags array from comma-separated or single tag
  local tags_json="[]"
  if [[ -n "$tag" ]]; then
    tags_json=$(echo "$tag" | tr ',' '\n' | jq -R . | jq -s .)
  fi

  local tmp_file="${REGISTRY_FILE}.tmp"

  jq --arg id "$task_id" \
     --arg title "$title" \
     --arg agent "$agent" \
     --arg department "$department" \
     --arg priority "$priority" \
     --argjson tags "$tags_json" \
     --arg now "$now" \
     --arg source "$source" \
     --arg depends_on "$depends_on" \
  '.tasks += [{
    id: $id,
    title: $title,
    assigned_agent: $agent,
    department: $department,
    status: "pending",
    priority: $priority,
    tags: $tags,
    created_at: $now,
    updated_at: $now,
    created_by: "dispatch",
    source: $source,
    depends_on: (if $depends_on == "" then null else $depends_on end)
  }]' "$REGISTRY_FILE" > "$tmp_file"

  mv "$tmp_file" "$REGISTRY_FILE"
  update_metadata

  # Output the task ID to stdout for piping
  echo "$task_id"
  echo "Task added: $task_id — $title" >&2
}

cmd_update() {
  ensure_registry

  local task_id=""
  local new_status=""

  # First positional arg is task_id
  if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
    task_id="$1"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status)
        new_status="$2"
        shift 2
        ;;
      *)
        echo "ERROR: Unknown argument '$1'" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$task_id" ]]; then
    echo "ERROR: Task ID is required. Usage: task-registry.sh update TASK_ID --status STATUS" >&2
    exit 1
  fi

  if [[ -z "$new_status" ]]; then
    echo "ERROR: --status is required." >&2
    exit 1
  fi

  validate_status "$new_status"

  # Check task exists
  local exists
  exists=$(jq --arg id "$task_id" '[.tasks[] | select(.id == $id)] | length' "$REGISTRY_FILE")
  if [[ "$exists" -eq 0 ]]; then
    echo "ERROR: Task '$task_id' not found." >&2
    exit 1
  fi

  local now
  now="$(iso_now)"
  local tmp_file="${REGISTRY_FILE}.tmp"

  jq --arg id "$task_id" \
     --arg status "$new_status" \
     --arg now "$now" \
  '(.tasks[] | select(.id == $id)) |= (.status = $status | .updated_at = $now)' \
  "$REGISTRY_FILE" > "$tmp_file"

  mv "$tmp_file" "$REGISTRY_FILE"
  update_metadata

  echo "Task $task_id updated to status: $new_status" >&2
}

cmd_list() {
  ensure_registry

  local filter_status=""
  local filter_agent=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status)
        filter_status="$2"
        shift 2
        ;;
      --agent)
        filter_agent="$2"
        shift 2
        ;;
      *)
        echo "ERROR: Unknown argument '$1'" >&2
        exit 1
        ;;
    esac
  done

  # Build jq filter
  local jq_filter='.tasks[]'
  if [[ -n "$filter_status" ]]; then
    validate_status "$filter_status"
    jq_filter="$jq_filter | select(.status == \"$filter_status\")"
  fi
  if [[ -n "$filter_agent" ]]; then
    jq_filter="$jq_filter | select(.assigned_agent == \"$filter_agent\")"
  fi

  # Formatted table output
  printf "%-28s %-35s %-12s %-10s %-10s %s\n" "ID" "TITLE" "AGENT" "STATUS" "PRIORITY" "TAGS"
  printf "%-28s %-35s %-12s %-10s %-10s %s\n" "---" "---" "---" "---" "---" "---"

  jq -r "[$jq_filter] | .[] | [.id, .title, .assigned_agent, .status, .priority, (.tags | join(\",\"))] | @tsv" \
    "$REGISTRY_FILE" 2>/dev/null | while IFS=$'\t' read -r id title agent status priority tags; do
    # Truncate title if too long
    if [[ ${#title} -gt 33 ]]; then
      title="${title:0:30}..."
    fi
    printf "%-28s %-35s %-12s %-10s %-10s %s\n" "$id" "$title" "$agent" "$status" "$priority" "$tags"
  done
}

cmd_get() {
  ensure_registry

  local task_id="${1:-}"
  if [[ -z "$task_id" ]]; then
    echo "ERROR: Task ID is required. Usage: task-registry.sh get TASK_ID" >&2
    exit 1
  fi

  local result
  result=$(jq --arg id "$task_id" '.tasks[] | select(.id == $id)' "$REGISTRY_FILE")

  if [[ -z "$result" ]]; then
    echo "ERROR: Task '$task_id' not found." >&2
    exit 1
  fi

  echo "$result" | jq .
}

cmd_summary() {
  ensure_registry

  local total pending in_progress completed blocked failed last_updated
  total=$(jq '.metadata.total' "$REGISTRY_FILE")
  pending=$(jq '.metadata.pending' "$REGISTRY_FILE")
  in_progress=$(jq '.metadata.in_progress' "$REGISTRY_FILE")
  completed=$(jq '.metadata.completed' "$REGISTRY_FILE")
  blocked=$(jq '.metadata.blocked // 0' "$REGISTRY_FILE")
  failed=$(jq '.metadata.failed // 0' "$REGISTRY_FILE")
  last_updated=$(jq -r '.metadata.last_updated' "$REGISTRY_FILE")

  echo "Task Registry Summary"
  echo "====================="
  echo "Total: $total | Pending: $pending | In Progress: $in_progress | Completed: $completed | Blocked: $blocked | Failed: $failed"
  echo "Last updated: $last_updated"
}

# ─── Entry Point ───

case "${1:-help}" in
  init)
    cmd_init
    ;;
  add)
    shift
    cmd_add "$@"
    ;;
  update)
    shift
    cmd_update "$@"
    ;;
  list)
    shift
    cmd_list "$@"
    ;;
  get)
    shift
    cmd_get "$@"
    ;;
  summary)
    cmd_summary
    ;;
  help|*)
    echo "VelvetClaw Task Registry"
    echo ""
    echo "Usage: $0 {init|add|update|list|get|summary}"
    echo ""
    echo "  init                                      Create empty registry"
    echo "  add \"title\" --tag TAG --priority PRI      Add a task"
    echo "  update TASK_ID --status STATUS             Update task status"
    echo "  list [--status STATUS] [--agent AGENT]     List tasks"
    echo "  get TASK_ID                                Show task details"
    echo "  summary                                    Show metadata counts"
    echo ""
    echo "Valid statuses: $VALID_STATUSES"
    echo "Valid priorities: $VALID_PRIORITIES"
    ;;
esac
