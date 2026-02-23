#!/usr/bin/env bash
# VelvetClaw Agent Status — Formatted dashboard of all agent heartbeats
#
# Usage:
#   ./scripts/agent-status.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/manifest.yaml"
AGENTS_DIR="$REPO_ROOT/agents"
TASK_REGISTRY="$REPO_ROOT/scripts/task-registry.sh"

# ─── Dependency Check ───

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed." >&2
  exit 1
fi

# ─── Helpers ───

# Get current epoch time (macOS compatible)
now_epoch() {
  date +%s
}

# Parse ISO timestamp to epoch (macOS compatible)
# Handles format: 2026-02-24T10:30:00Z
iso_to_epoch() {
  local ts="$1"
  # macOS BSD date: use -jf for parsing
  if date -jf "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null; then
    return
  fi
  # Fallback: try GNU date
  if date -d "$ts" +%s 2>/dev/null; then
    return
  fi
  echo "0"
}

# Calculate human-readable "X ago" from epoch seconds difference
time_ago() {
  local diff="$1"

  if [[ "$diff" -lt 0 ]]; then
    echo "future"
    return
  fi

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

# ─── Read Agent Info from Manifest ───

# Build agent metadata: id, tier, department
# Returns lines of: agent_id|tier|department
get_all_agents() {
  # Use awk to parse the hierarchy section of the manifest precisely
  # This avoids false matches from vault.departments or other sections
  awk '
    # Track the chief agent
    /^[[:space:]]*chief:/ { in_chief=1; next }
    in_chief && /agent:/ {
      gsub(/[[:space:]]*agent:[[:space:]]*/, "")
      chief = $0
      printf "%s|tier_1|chief\n", $0
      in_chief = 0
      next
    }

    # Enter the hierarchy.departments block
    /^[[:space:]]{4}departments:/ { in_depts=1; next }

    # Exit hierarchy.departments when indentation drops to 4 or less
    in_depts && /^[[:space:]]{0,4}[a-z]/ { in_depts=0; dept="" }

    # Detect department name (6-space indent, line ends with just colon)
    in_depts && /^[[:space:]]{6}[a-z][-a-z]*:[[:space:]]*$/ {
      dept = $0
      gsub(/[[:space:]]/, "", dept)
      gsub(/:/, "", dept)
      in_members = 0
      next
    }

    # Detect lead within department
    in_depts && dept != "" && /^[[:space:]]+lead:/ {
      lead = $0
      gsub(/.*lead:[[:space:]]*/, "", lead)
      if (lead != chief) {
        printf "%s|lead|%s\n", lead, dept
      }
      next
    }

    # Detect members array
    in_depts && dept != "" && /^[[:space:]]+members:/ {
      if ($0 ~ /\[\]/) { in_members = 0 }
      else { in_members = 1 }
      next
    }

    # Read member entries
    in_depts && in_members && /^[[:space:]]*-[[:space:]]/ {
      member = $0
      gsub(/.*-[[:space:]]*/, "", member)
      printf "%s|member|%s\n", member, dept
      next
    }

    # End of members array (line without dash)
    in_depts && in_members && !/^[[:space:]]*-/ && !/^[[:space:]]*$/ {
      in_members = 0
    }
  ' "$MANIFEST"
}

# ─── Parse Last Heartbeat ───

get_last_heartbeat() {
  local agent_id="$1"
  local heartbeat_file="$AGENTS_DIR/$agent_id/HEARTBEAT.md"

  if [[ ! -f "$heartbeat_file" ]]; then
    echo "never|-"
    return
  fi

  # Try to read Last Cycle from the Current Status section
  local last_cycle
  last_cycle=$(grep -E '^\- \*\*Last Cycle\*\*:' "$heartbeat_file" 2>/dev/null | head -1 | sed 's/.*: *//')

  if [[ -z "$last_cycle" || "$last_cycle" == "never" ]]; then
    echo "never|-"
    return
  fi

  # Try to read State
  local state
  state=$(grep -E '^\- \*\*State\*\*:' "$heartbeat_file" 2>/dev/null | head -1 | sed 's/.*: *//')

  # Also check the Cycle Log table for the last real entry
  # Format: | Timestamp | Step | Outcome | Duration | Notes |
  local last_log_line
  last_log_line=$(grep -E '^\|[[:space:]]*[0-9]{4}-' "$heartbeat_file" 2>/dev/null | tail -1)

  if [[ -n "$last_log_line" ]]; then
    local log_ts log_outcome
    log_ts=$(echo "$last_log_line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
    log_outcome=$(echo "$last_log_line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4}')

    if [[ -n "$log_ts" ]]; then
      local epoch
      epoch=$(iso_to_epoch "$log_ts")
      if [[ "$epoch" != "0" ]]; then
        local now
        now=$(now_epoch)
        local diff=$(( now - epoch ))
        local ago
        ago=$(time_ago "$diff")
        echo "${ago}|${log_outcome:-${state:-unknown}}"
        return
      fi
    fi
  fi

  # Fallback: if Last Cycle is a timestamp
  local epoch
  epoch=$(iso_to_epoch "$last_cycle" 2>/dev/null || echo "0")
  if [[ "$epoch" != "0" ]]; then
    local now
    now=$(now_epoch)
    local diff=$(( now - epoch ))
    local ago
    ago=$(time_ago "$diff")
    echo "${ago}|${state:-unknown}"
    return
  fi

  echo "never|${state:--}"
}

# ─── Main Output ───

main() {
  local now_ts
  now_ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Table header
  echo ""
  printf "%s\n" "+============+==========+===============+=================+============+"
  printf "%s\n" "|                    VelvetClaw Agent Status                           |"
  printf "%s\n" "+============+==========+===============+=================+============+"
  printf "| %-10s | %-8s | %-13s | %-15s | %-10s |\n" "Agent" "Tier" "Dept" "Last Cycle" "Outcome"
  printf "%s\n" "+============+==========+===============+=================+============+"

  # Read all agents and display
  while IFS='|' read -r agent_id tier dept; do
    # Skip empty lines
    [[ -z "$agent_id" ]] && continue

    local heartbeat_info last_cycle outcome
    heartbeat_info=$(get_last_heartbeat "$agent_id")
    last_cycle=$(echo "$heartbeat_info" | cut -d'|' -f1)
    outcome=$(echo "$heartbeat_info" | cut -d'|' -f2)

    printf "| %-10s | %-8s | %-13s | %-15s | %-10s |\n" \
      "$agent_id" "$tier" "$dept" "$last_cycle" "$outcome"
  done < <(get_all_agents)

  printf "%s\n" "+============+==========+===============+=================+============+"

  # Task registry summary
  echo ""
  if [[ -x "$TASK_REGISTRY" ]]; then
    "$TASK_REGISTRY" summary 2>/dev/null || echo "Tasks: (registry not initialized)"
  else
    echo "Tasks: (task-registry.sh not found)"
  fi

  echo ""
  echo "Status as of: $now_ts"
}

main "$@"
