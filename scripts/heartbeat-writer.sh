#!/usr/bin/env bash
# VelvetClaw Heartbeat Writer
# Appends structured entries to agent HEARTBEAT.md files and logs/cycles.jsonl.
#
# Usage:
#   ./scripts/heartbeat-writer.sh <agent_id> <step_id> <outcome> <duration_seconds> [tokens_used]
#
# Arguments:
#   agent_id        - Agent identifier (e.g., jarvis, atlas, clawd)
#   step_id         - Step identifier (e.g., step-3, cycle-1700000000, idle)
#   outcome         - One of: completed, blocked, failed, timeout, idle
#   duration_seconds - How long the cycle took in seconds
#   tokens_used     - (Optional) Token count for the cycle
#
# Outputs:
#   - Appends markdown entry to agents/{agent_id}/HEARTBEAT.md
#   - Appends JSON line to logs/cycles.jsonl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# ─── Logging (to stderr) ───

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [heartbeat-writer] [$level] $*" >&2
}

# ─── Validate args ───

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <agent_id> <step_id> <outcome> <duration_seconds> [tokens_used]" >&2
  exit 1
fi

AGENT_ID="$1"
STEP_ID="$2"
OUTCOME="$3"
DURATION="$4"
TOKENS="${5:-0}"

# Validate outcome
case "$OUTCOME" in
  completed|blocked|failed|timeout|idle)
    ;;
  *)
    log "warn" "Unknown outcome '$OUTCOME', defaulting to 'failed'"
    OUTCOME="failed"
    ;;
esac

AGENT_DIR="$REPO_ROOT/agents/$AGENT_ID"
HEARTBEAT_FILE="$AGENT_DIR/HEARTBEAT.md"
LOG_DIR="$REPO_ROOT/logs"
CYCLE_LOG="$LOG_DIR/cycles.jsonl"

# ─── Ensure directories exist ───

mkdir -p "$LOG_DIR"

# ─── Timestamp ───

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ─── Read model from agent manifest (if available) ───

MODEL="unknown"
AGENT_MANIFEST="$AGENT_DIR/MANIFEST.yaml"
if [[ -f "$AGENT_MANIFEST" ]]; then
  pm=$(grep -A3 "^models:" "$AGENT_MANIFEST" | grep "primary:" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs 2>/dev/null || true)
  if [[ -n "$pm" ]]; then
    MODEL="$pm"
  fi
fi

# ─── Append to HEARTBEAT.md ───

if [[ -f "$HEARTBEAT_FILE" ]]; then
  {
    echo ""
    echo "### $NOW Cycle Result"
    echo "- Step: $STEP_ID"
    echo "- Outcome: $OUTCOME"
    echo "- Duration: ${DURATION}s"
    echo "- Tokens: $TOKENS"
  } >> "$HEARTBEAT_FILE"
  log "info" "Appended heartbeat entry for $AGENT_ID: $STEP_ID=$OUTCOME (${DURATION}s, ${TOKENS} tokens)"
else
  log "warn" "HEARTBEAT.md not found for $AGENT_ID at $HEARTBEAT_FILE — creating"
  {
    echo "# ${AGENT_ID} -- Heartbeat"
    echo ""
    echo "### $NOW Cycle Result"
    echo "- Step: $STEP_ID"
    echo "- Outcome: $OUTCOME"
    echo "- Duration: ${DURATION}s"
    echo "- Tokens: $TOKENS"
  } > "$HEARTBEAT_FILE"
fi

# ─── Append JSON line to cycles.jsonl ───

# Use python3 for reliable JSON encoding
python3 -c "
import json, sys
entry = {
    'timestamp': '$NOW',
    'agent_id': '$AGENT_ID',
    'step_id': '$STEP_ID',
    'outcome': '$OUTCOME',
    'duration': int('$DURATION'),
    'tokens': int('$TOKENS'),
    'model': '$MODEL'
}
print(json.dumps(entry))
" >> "$CYCLE_LOG"

log "info" "Appended cycle log entry to $CYCLE_LOG"
