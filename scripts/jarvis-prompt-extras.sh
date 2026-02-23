#!/usr/bin/env bash
# VelvetClaw JARVIS Prompt Extras — Organizational context for JARVIS chief agent
#
# Sourced by agent-prompt-assembler.sh when building JARVIS's prompt.
# Outputs additional context sections to stdout for inclusion in the prompt.
#
# Usage:
#   ./scripts/jarvis-prompt-extras.sh
#   source scripts/jarvis-prompt-extras.sh  # can also be sourced

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/manifest.yaml"
AGENTS_DIR="$REPO_ROOT/agents"
TASK_REGISTRY="$REPO_ROOT/scripts/task-registry.sh"
VAULT_HANDOFFS="$REPO_ROOT/vault/handoffs"

# ─── Helpers ───

iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

now_epoch() {
  date +%s
}

iso_to_epoch() {
  local ts="$1"
  if date -jf "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null; then
    return
  fi
  if date -d "$ts" +%s 2>/dev/null; then
    return
  fi
  echo "0"
}

time_ago() {
  local diff="$1"
  if [[ "$diff" -lt 60 ]]; then
    echo "${diff}s ago"
  elif [[ "$diff" -lt 3600 ]]; then
    echo "$(( diff / 60 ))m ago"
  elif [[ "$diff" -lt 86400 ]]; then
    echo "$(( diff / 3600 ))h ago"
  else
    echo "$(( diff / 86400 ))d ago"
  fi
}

# ─── Department Lead Map ───
# department_name -> lead_agent_id
declare -A DEPT_LEADS
DEPT_LEADS=(
  ["research"]="atlas"
  ["content"]="scribe"
  ["development"]="clawd"
  ["design"]="pixel"
  ["user-success"]="sage"
  ["product"]="clip"
)

# ─── 1. Department Lead Summaries ───

generate_department_status() {
  echo "## Department Status"

  for dept in research content development design user-success product; do
    local lead="${DEPT_LEADS[$dept]}"
    local heartbeat="$AGENTS_DIR/$lead/HEARTBEAT.md"
    local display_name
    display_name="$(echo "$dept" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')"

    if [[ ! -f "$heartbeat" ]]; then
      echo "- $display_name ($lead): No heartbeat data"
      continue
    fi

    # Read last cycle and state
    local last_cycle state
    last_cycle=$(grep -E '^\- \*\*Last Cycle\*\*:' "$heartbeat" 2>/dev/null | head -1 | sed 's/.*: *//' || echo "never")
    state=$(grep -E '^\- \*\*State\*\*:' "$heartbeat" 2>/dev/null | head -1 | sed 's/.*: *//' || echo "unknown")

    # Check cycle log for last real entry
    local last_log_line
    last_log_line=$(grep -E '^\|[[:space:]]*[0-9]{4}-' "$heartbeat" 2>/dev/null | tail -1 || true)

    local ago_str="never"
    local step_info=""
    local outcome_str="$state"

    if [[ -n "$last_log_line" ]]; then
      local log_ts log_step log_outcome
      log_ts=$(echo "$last_log_line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
      log_step=$(echo "$last_log_line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')
      log_outcome=$(echo "$last_log_line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4}')

      if [[ -n "$log_ts" ]]; then
        local epoch
        epoch=$(iso_to_epoch "$log_ts")
        if [[ "$epoch" != "0" ]]; then
          local now
          now=$(now_epoch)
          local diff=$(( now - epoch ))
          ago_str=$(time_ago "$diff")
        fi
      fi

      step_info="$log_step"
      outcome_str="${log_outcome:-$state}"
    fi

    if [[ -n "$step_info" && "$step_info" != "-" && "$step_info" != "" ]]; then
      echo "- $display_name ($lead): Last cycle ${ago_str} -- ${outcome_str} step \"${step_info}\""
    else
      echo "- $display_name ($lead): Last cycle ${ago_str} -- ${outcome_str}"
    fi
  done
}

# ─── 2. Task Registry State ───

generate_task_summary() {
  echo "## Task Registry"

  if [[ -x "$TASK_REGISTRY" ]]; then
    local summary
    summary=$("$TASK_REGISTRY" summary 2>/dev/null || echo "Registry not initialized")
    # Extract the counts line
    echo "$summary" | grep -E "^Total:" || echo "Total: 0 | Pending: 0 | In Progress: 0 | Completed: 0"
  else
    echo "Task registry not available"
  fi
}

# ─── 3. Pending Escalations ───

generate_escalations() {
  echo "## Pending Escalations"

  local found_any=false

  for agent_dir in "$AGENTS_DIR"/*/; do
    local agent_id
    agent_id="$(basename "$agent_dir")"
    local tasks_file="$agent_dir/TASKS.md"

    if [[ ! -f "$tasks_file" ]]; then
      continue
    fi

    # Look for blocked steps with retry counts >= 3
    # Format: - Status: blocked
    #         - Retry count: N
    # We parse step names and their blocked/failed status
    local current_step=""
    local current_status=""
    local retry_count=0
    local current_reason=""

    while IFS= read -r line; do
      # Detect step header
      if echo "$line" | grep -qE '^\- \*\*Step [0-9]+\*\*:'; then
        # Emit previous step if blocked
        if [[ "$current_status" == "blocked" || "$current_status" == "failed" ]]; then
          if [[ $retry_count -ge 3 || "$current_status" == "failed" ]]; then
            if [[ -n "$current_reason" ]]; then
              echo "- ${agent_id}: step \"${current_step}\" ${current_status} ${retry_count} times -- ${current_reason}"
            else
              echo "- ${agent_id}: step \"${current_step}\" ${current_status} ${retry_count} times -- needs attention"
            fi
            found_any=true
          fi
        fi
        current_step=$(echo "$line" | sed 's/.*\*\*Step [0-9]*\*\*:[[:space:]]*//')
        current_status=""
        retry_count=0
        current_reason=""
        continue
      fi

      # Read status
      if echo "$line" | grep -qE '^\s*-\s*Status:'; then
        current_status=$(echo "$line" | sed 's/.*Status:[[:space:]]*//')
        continue
      fi

      # Read retry count
      if echo "$line" | grep -qE '^\s*-\s*Retry count:'; then
        retry_count=$(echo "$line" | sed 's/.*Retry count:[[:space:]]*//' | tr -dc '0-9')
        retry_count="${retry_count:-0}"
        continue
      fi

      # Read blocked reason
      if echo "$line" | grep -qE '^\s*-\s*Blocked reason:'; then
        current_reason=$(echo "$line" | sed 's/.*Blocked reason:[[:space:]]*//')
        continue
      fi
    done < "$tasks_file"

    # Don't forget the last step
    if [[ "$current_status" == "blocked" || "$current_status" == "failed" ]]; then
      if [[ $retry_count -ge 3 || "$current_status" == "failed" ]]; then
        if [[ -n "$current_reason" ]]; then
          echo "- ${agent_id}: step \"${current_step}\" ${current_status} ${retry_count} times -- ${current_reason}"
        else
          echo "- ${agent_id}: step \"${current_step}\" ${current_status} ${retry_count} times -- needs attention"
        fi
        found_any=true
      fi
    fi
  done

  if [[ "$found_any" == "false" ]]; then
    echo "- No pending escalations"
  fi
}

# ─── 4. Active Handoffs ───

generate_handoffs() {
  echo "## Active Handoffs"

  local found_any=false

  if [[ -d "$VAULT_HANDOFFS" ]]; then
    for handoff_file in "$VAULT_HANDOFFS"/*; do
      # Skip if no files match (glob returns the pattern itself)
      [[ -e "$handoff_file" ]] || continue
      local basename_file
      basename_file="$(basename "$handoff_file")"

      # Skip .gitkeep and hidden files
      [[ "$basename_file" == .* ]] && continue

      # Check for requires_action: true in frontmatter
      if grep -q "requires_action: true" "$handoff_file" 2>/dev/null; then
        local from_dept to_dept
        from_dept=$(grep "handoff_from:" "$handoff_file" 2>/dev/null | head -1 | sed 's/.*handoff_from:[[:space:]]*//')
        to_dept=$(grep "handoff_to:" "$handoff_file" 2>/dev/null | head -1 | sed 's/.*handoff_to:[[:space:]]*//')

        echo "- vault/handoffs/${basename_file} (${from_dept:-unknown} -> ${to_dept:-unknown}, requires action)"
        found_any=true
      fi
    done
  fi

  if [[ "$found_any" == "false" ]]; then
    echo "- No active handoffs"
  fi
}

# ─── Main Output ───

main() {
  echo ""
  echo "=== ORGANIZATIONAL CONTEXT (for JARVIS only) ==="
  echo ""

  generate_department_status
  echo ""

  generate_task_summary
  echo ""

  generate_escalations
  echo ""

  generate_handoffs
  echo ""
}

main "$@"
