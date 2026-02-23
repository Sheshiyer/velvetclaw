#!/usr/bin/env bash
# VelvetClaw Idle Detector — Tracks idle agents and notifies JARVIS after threshold
#
# Called after each agent cycle to track whether agents have work.
#
# Usage:
#   ./scripts/idle-detector.sh <agent_id> <had_work>
#
#   agent_id   The agent being tracked
#   had_work   "true" if the agent had tasks this cycle, "false" if idle
#
# Behavior:
#   - Maintains counter at /tmp/velvetclaw-idle-{agent_id}.count
#   - had_work=false: increment counter
#   - had_work=true: reset counter to 0
#   - counter reaches 5: notify JARVIS INBOX, reset counter

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="$REPO_ROOT/agents"
IDLE_THRESHOLD=5

# ─── Helpers ───

iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

usage() {
  echo "VelvetClaw Idle Detector"
  echo ""
  echo "Usage: idle-detector.sh <agent_id> <had_work>"
  echo ""
  echo "  agent_id   Agent identifier (e.g., atlas, scribe)"
  echo "  had_work   'true' if agent had tasks, 'false' if idle"
}

# Write entry to an agent's INBOX.md
write_to_inbox() {
  local target_agent="$1"
  local entry="$2"
  local inbox="$AGENTS_DIR/$target_agent/INBOX.md"

  # Create INBOX if missing
  if [[ ! -f "$inbox" ]]; then
    mkdir -p "$AGENTS_DIR/$target_agent"
    cat > "$inbox" <<'EOF'
# INBOX

> Cross-agent task assignments and messages.

## Pending

## Processed
EOF
  fi

  # Ensure ## Pending exists
  if ! grep -q "^## Pending" "$inbox"; then
    if grep -q "^## Processed" "$inbox"; then
      local tmp="${inbox}.tmp"
      awk '/^## Processed/ { print "## Pending\n"; } { print }' "$inbox" > "$tmp"
      mv "$tmp" "$inbox"
    else
      echo "" >> "$inbox"
      echo "## Pending" >> "$inbox"
      echo "" >> "$inbox"
      echo "## Processed" >> "$inbox"
    fi
  fi

  # Insert after ## Pending
  local tmp="${inbox}.tmp"
  awk -v entry="$entry" '
    /^## Pending/ {
      print $0
      print ""
      print entry
      next
    }
    { print }
  ' "$inbox" > "$tmp"
  mv "$tmp" "$inbox"
}

# ─── Main ───

main() {
  if [[ $# -lt 2 ]]; then
    echo "ERROR: Missing arguments." >&2
    usage >&2
    exit 1
  fi

  local agent_id="$1"
  local had_work="$2"

  # Validate had_work
  if [[ "$had_work" != "true" && "$had_work" != "false" ]]; then
    echo "ERROR: had_work must be 'true' or 'false', got '$had_work'" >&2
    exit 1
  fi

  # Validate agent exists
  if [[ ! -d "$AGENTS_DIR/$agent_id" ]]; then
    echo "ERROR: Agent directory not found: $AGENTS_DIR/$agent_id" >&2
    exit 1
  fi

  local counter_file="/tmp/velvetclaw-idle-${agent_id}.count"

  # Read current counter
  local count=0
  if [[ -f "$counter_file" ]]; then
    count=$(cat "$counter_file" 2>/dev/null || echo "0")
    # Ensure it's a number
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
      count=0
    fi
  fi

  if [[ "$had_work" == "true" ]]; then
    # Reset counter
    echo "0" > "$counter_file"
    echo "Agent $agent_id had work. Idle counter reset to 0." >&2
    return
  fi

  # had_work == false: increment counter
  count=$(( count + 1 ))
  echo "$count" > "$counter_file"
  echo "Agent $agent_id idle. Counter: $count/$IDLE_THRESHOLD" >&2

  # Check threshold
  if [[ "$count" -ge "$IDLE_THRESHOLD" ]]; then
    local timestamp
    timestamp="$(iso_now)"

    local entry=""
    entry+="### [$timestamp] From: idle-detector | Priority: low"
    entry+=$'\n'"IDLE ALERT: Agent $agent_id has had no tasks for $IDLE_THRESHOLD consecutive cycles."
    entry+=$'\n'"Consider assigning work or reviewing task distribution."
    entry+=$'\n'"Tags: idle, monitoring"

    # Write to JARVIS INBOX
    write_to_inbox "jarvis" "$entry"
    echo "IDLE ALERT sent to JARVIS for agent $agent_id ($IDLE_THRESHOLD cycles idle)" >&2

    # Reset counter after notification
    echo "0" > "$counter_file"
    echo "Idle counter reset after notification." >&2
  fi
}

main "$@"
