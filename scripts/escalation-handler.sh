#!/usr/bin/env bash
# VelvetClaw Escalation Handler — Routes blocked/failed step escalations to supervisors
#
# Called by write-back.sh when a step has been blocked >= 3 times.
#
# Usage:
#   ./scripts/escalation-handler.sh <agent_id> <step_id> <block_reason>
#
# Behavior:
#   1. Read the agent's MANIFEST.yaml reports_to field
#   2. Write escalation to supervisor's INBOX.md
#   3. Also notify JARVIS if supervisor is not JARVIS (double-notify)
#   4. Log to logs/escalations.log

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="$REPO_ROOT/agents"
LOGS_DIR="$REPO_ROOT/logs"
ESCALATION_LOG="$LOGS_DIR/escalations.log"

# ─── Helpers ───

iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

usage() {
  echo "VelvetClaw Escalation Handler"
  echo ""
  echo "Usage: escalation-handler.sh <agent_id> <step_id> <block_reason>"
  echo ""
  echo "  agent_id     The agent whose step is blocked/failed"
  echo "  step_id      The step identifier (e.g. 'market-analysis-3')"
  echo "  block_reason Why the step is blocked"
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
    echo "Created INBOX.md for $target_agent" >&2
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
  if [[ $# -lt 3 ]]; then
    echo "ERROR: Missing arguments." >&2
    usage >&2
    exit 1
  fi

  local agent_id="$1"
  local step_id="$2"
  local block_reason="$3"

  # Validate agent exists
  local agent_manifest="$AGENTS_DIR/$agent_id/MANIFEST.yaml"
  if [[ ! -f "$agent_manifest" ]]; then
    echo "ERROR: Agent '$agent_id' MANIFEST.yaml not found at $agent_manifest" >&2
    exit 1
  fi

  # Read reports_to from agent's MANIFEST.yaml
  local reports_to
  reports_to=$(grep -E "^\s*reports_to:" "$agent_manifest" | head -1 | sed 's/.*reports_to:[[:space:]]*//')

  if [[ -z "$reports_to" ]]; then
    echo "WARNING: No reports_to field found for $agent_id. Defaulting to jarvis." >&2
    reports_to="jarvis"
  fi

  # Read department from agent's MANIFEST.yaml
  local department
  department=$(grep -E "^\s*department:" "$agent_manifest" | head -1 | sed 's/.*department:[[:space:]]*//')
  department="${department:-unknown}"

  # Count how many times this has been blocked (from TASKS.md)
  local tasks_file="$AGENTS_DIR/$agent_id/TASKS.md"
  local block_count=0
  if [[ -f "$tasks_file" ]]; then
    # Look for the step and its retry count
    block_count=$(awk '
      /'"$step_id"'/ { found=1 }
      found && /Retry count:/ {
        gsub(/.*Retry count:[[:space:]]*/, "")
        gsub(/[^0-9]/, "")
        print
        exit
      }
    ' "$tasks_file" 2>/dev/null || echo "0")
    block_count="${block_count:-0}"
    # Ensure it's a number
    if ! [[ "$block_count" =~ ^[0-9]+$ ]]; then
      block_count=0
    fi
  fi

  # If block_count is 0, default to 3 (the threshold that triggered this)
  if [[ "$block_count" -eq 0 ]]; then
    block_count=3
  fi

  local timestamp
  timestamp="$(iso_now)"

  # Build escalation entry
  local entry=""
  entry+="### [$timestamp] From: escalation-handler | Priority: high"
  entry+=$'\n'"ESCALATION: Agent $agent_id step \"$step_id\" blocked $block_count times."
  entry+=$'\n'"Last reason: $block_reason"
  entry+=$'\n'"Agent's department: $department"
  entry+=$'\n'"Tags: escalation, $department"

  # 1. Write to supervisor's INBOX
  if [[ "$reports_to" != "owner" ]]; then
    write_to_inbox "$reports_to" "$entry"
    echo "Escalation sent to supervisor: $reports_to" >&2
  fi

  # 2. Double-notify JARVIS if supervisor is not JARVIS
  if [[ "$reports_to" != "jarvis" && "$reports_to" != "owner" ]]; then
    write_to_inbox "jarvis" "$entry"
    echo "Escalation also sent to JARVIS (double-notify)" >&2
  fi

  # If reports_to is "owner", still notify JARVIS
  if [[ "$reports_to" == "owner" ]]; then
    write_to_inbox "jarvis" "$entry"
    echo "Escalation sent to JARVIS (agent reports to owner)" >&2
  fi

  # 3. Log to escalations.log
  mkdir -p "$LOGS_DIR"
  echo "[$timestamp] ESCALATION agent=$agent_id step=$step_id blocked=$block_count reason=\"$block_reason\" supervisor=$reports_to department=$department" >> "$ESCALATION_LOG"
  echo "Logged to $ESCALATION_LOG" >&2

  # Output summary
  echo "Escalation processed: $agent_id/$step_id -> $reports_to (blocked $block_count times)"
}

main "$@"
