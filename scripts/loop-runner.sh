#!/usr/bin/env bash
# VelvetClaw Loop Runner — Local Orchestrator Daemon
# Triggers agent cycles on schedule based on MANIFEST.yaml tier intervals.
#
# Usage:
#   ./scripts/loop-runner.sh start    # Start the loop daemon in background
#   ./scripts/loop-runner.sh stop     # Stop the running daemon
#   ./scripts/loop-runner.sh status   # Check if daemon is running
#   ./scripts/loop-runner.sh run      # Run in foreground (for debugging)
#
# Configuration: scripts/loop-runner.conf or .env at repo root

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PID_FILE="$REPO_ROOT/.loop-runner.pid"
LOG_DIR="$REPO_ROOT/logs"
LOG_FILE="$LOG_DIR/loop-runner.log"
CONF_FILE="$SCRIPT_DIR/loop-runner.conf"

# ─── Defaults (overridden by .env or loop-runner.conf) ───

MAX_CONCURRENT=2
WORKING_HOURS_ONLY=false
START_HOUR=9
END_HOUR=17
CHECK_INTERVAL=60  # seconds between scheduler checks
LOG_LEVEL="info"   # debug, info, warn, error

# ─── Tier intervals in seconds ───

TIER_1_INTERVAL=300    # 5 minutes  — Chief (JARVIS)
TIER_2_LEAD_INTERVAL=600   # 10 minutes — Department leads
TIER_2_MEMBER_INTERVAL=900 # 15 minutes — Members

# ─── Load configuration ───

load_config() {
  # Load .env if it exists
  if [[ -f "$REPO_ROOT/.env" ]]; then
    # shellcheck disable=SC1091
    set -a
    source "$REPO_ROOT/.env"
    set +a
  fi

  # Load loop-runner.conf if it exists (overrides .env)
  if [[ -f "$CONF_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONF_FILE"
  fi

  # Apply env overrides
  MAX_CONCURRENT="${LOOP_MAX_CONCURRENT:-$MAX_CONCURRENT}"
  WORKING_HOURS_ONLY="${LOOP_WORKING_HOURS_ONLY:-$WORKING_HOURS_ONLY}"
  START_HOUR="${LOOP_START_HOUR:-$START_HOUR}"
  END_HOUR="${LOOP_END_HOUR:-$END_HOUR}"
}

# ─── Logging ───

log() {
  local level="$1"
  shift
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "[$timestamp] [$level] $*" >> "$LOG_FILE"
  if [[ "$level" != "debug" ]] || [[ "$LOG_LEVEL" == "debug" ]]; then
    echo "[$timestamp] [$level] $*"
  fi
}

# ─── Agent Discovery ───

declare -A AGENT_TIERS
declare -A AGENT_LAST_RUN
declare -A AGENT_INTERVALS

discover_agents() {
  log "info" "Discovering agents from manifest..."

  # Read manifest.yaml to find chief
  local chief
  chief=$(grep -A1 "chief:" "$REPO_ROOT/manifest.yaml" | grep "agent:" | awk '{print $2}' | head -1)

  if [[ -n "$chief" ]]; then
    AGENT_TIERS["$chief"]="tier_1"
    AGENT_INTERVALS["$chief"]=$TIER_1_INTERVAL
    AGENT_LAST_RUN["$chief"]=0
    log "info" "  Chief: $chief (${TIER_1_INTERVAL}s interval)"
  fi

  # Read each agent's MANIFEST.yaml for tier and interval
  for agent_dir in "$REPO_ROOT"/agents/*/; do
    local agent_id
    agent_id="$(basename "$agent_dir")"

    # Skip if already registered as chief
    if [[ "${AGENT_TIERS[$agent_id]:-}" == "tier_1" ]]; then
      continue
    fi

    local manifest="$agent_dir/MANIFEST.yaml"
    if [[ ! -f "$manifest" ]]; then
      log "warn" "  No MANIFEST.yaml for $agent_id, skipping"
      continue
    fi

    # Read the loop interval from MANIFEST.yaml
    local interval
    interval=$(grep -A5 "^loop:" "$manifest" | grep "interval:" | head -1 | awk -F'"' '{print $2}')

    case "$interval" in
      "5m")
        AGENT_TIERS["$agent_id"]="tier_1"
        AGENT_INTERVALS["$agent_id"]=$TIER_1_INTERVAL
        ;;
      "10m")
        AGENT_TIERS["$agent_id"]="tier_2_lead"
        AGENT_INTERVALS["$agent_id"]=$TIER_2_LEAD_INTERVAL
        ;;
      "15m")
        AGENT_TIERS["$agent_id"]="tier_2_member"
        AGENT_INTERVALS["$agent_id"]=$TIER_2_MEMBER_INTERVAL
        ;;
      *)
        AGENT_TIERS["$agent_id"]="tier_2_member"
        AGENT_INTERVALS["$agent_id"]=$TIER_2_MEMBER_INTERVAL
        log "warn" "  Unknown interval '$interval' for $agent_id, defaulting to 15m"
        ;;
    esac

    AGENT_LAST_RUN["$agent_id"]=0
    log "info" "  Agent: $agent_id (${AGENT_INTERVALS[$agent_id]}s interval, ${AGENT_TIERS[$agent_id]})"
  done

  log "info" "Discovered ${#AGENT_TIERS[@]} agents"
}

# ─── Working Hours Check ───

is_within_working_hours() {
  if [[ "$WORKING_HOURS_ONLY" != "true" ]]; then
    return 0  # Always running
  fi

  local current_hour
  current_hour=$(date +"%H")
  if (( current_hour >= START_HOUR && current_hour < END_HOUR )); then
    return 0
  fi
  return 1
}

# ─── Agent Invocation ───

RUNNING_AGENTS=0

invoke_agent() {
  local agent_id="$1"
  local workspace="$HOME/.openclaw/workspace-$agent_id"
  local agent_dir="$REPO_ROOT/agents/$agent_id"

  if (( RUNNING_AGENTS >= MAX_CONCURRENT )); then
    log "debug" "Skipping $agent_id — max concurrent ($MAX_CONCURRENT) reached"
    return
  fi

  log "info" ">>> Triggering cycle for $agent_id (${AGENT_TIERS[$agent_id]})"

  # ──────────────────────────────────────────────────────
  # INVOKE AGENT HERE
  # Replace this section with your OpenClaw CLI invocation.
  # The agent should:
  #   1. Read: INBOX.md, TASKS.md, CONTEXT.md, HEARTBEAT.md, AGENTS.md
  #   2. Pick next incomplete step from TASKS.md
  #   3. Execute one step
  #   4. Write results back
  #
  # Example (customize for your OpenClaw installation):
  #
  #   openclaw run --agent "$agent_id" \
  #     --workspace "$workspace" \
  #     --workflow agent-loop \
  #     --timeout "${AGENT_INTERVALS[$agent_id]}s" &
  #
  # For now, this logs the invocation point:
  log "info" "    [PLACEHOLDER] Would invoke: openclaw run --agent $agent_id --workspace $workspace"
  # ──────────────────────────────────────────────────────

  AGENT_LAST_RUN["$agent_id"]=$(date +%s)
  log "info" "<<< Cycle triggered for $agent_id"
}

# ─── Main Loop ───

run_loop() {
  log "info" "=== VelvetClaw Loop Runner started ==="
  log "info" "Config: max_concurrent=$MAX_CONCURRENT, working_hours=$WORKING_HOURS_ONLY ($START_HOUR-$END_HOUR)"
  log "info" "Check interval: ${CHECK_INTERVAL}s"

  while true; do
    if ! is_within_working_hours; then
      log "debug" "Outside working hours, sleeping..."
      sleep "$CHECK_INTERVAL"
      continue
    fi

    local now
    now=$(date +%s)

    # Check each agent
    for agent_id in "${!AGENT_TIERS[@]}"; do
      local last_run=${AGENT_LAST_RUN[$agent_id]}
      local interval=${AGENT_INTERVALS[$agent_id]}
      local elapsed=$(( now - last_run ))

      if (( elapsed >= interval )); then
        invoke_agent "$agent_id"
      fi
    done

    sleep "$CHECK_INTERVAL"
  done
}

# ─── Daemon Control ───

start_daemon() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Loop runner already running (PID $(cat "$PID_FILE"))"
    exit 1
  fi

  mkdir -p "$LOG_DIR"
  load_config
  discover_agents

  echo "Starting loop runner daemon..."
  nohup bash "$0" _run >> "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  echo "Loop runner started (PID $!). Logs: $LOG_FILE"
}

stop_daemon() {
  if [[ ! -f "$PID_FILE" ]]; then
    echo "No PID file found. Loop runner not running."
    exit 0
  fi

  local pid
  pid=$(cat "$PID_FILE")
  if kill -0 "$pid" 2>/dev/null; then
    echo "Stopping loop runner (PID $pid)..."
    kill "$pid"
    rm -f "$PID_FILE"
    echo "Stopped."
  else
    echo "PID $pid not running. Cleaning up stale PID file."
    rm -f "$PID_FILE"
  fi
}

show_status() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Loop runner: RUNNING (PID $(cat "$PID_FILE"))"
    echo "Log file: $LOG_FILE"
    if [[ -f "$LOG_FILE" ]]; then
      echo ""
      echo "Last 5 log entries:"
      tail -5 "$LOG_FILE"
    fi
  else
    echo "Loop runner: STOPPED"
  fi
}

# ─── Entry Point ───

case "${1:-help}" in
  start)
    load_config
    discover_agents
    start_daemon
    ;;
  stop)
    stop_daemon
    ;;
  status)
    show_status
    ;;
  run)
    mkdir -p "$LOG_DIR"
    load_config
    discover_agents
    run_loop
    ;;
  _run)
    # Internal: called by nohup in start_daemon
    load_config
    discover_agents
    run_loop
    ;;
  help|*)
    echo "VelvetClaw Loop Runner"
    echo ""
    echo "Usage: $0 {start|stop|status|run}"
    echo ""
    echo "  start   Start the loop daemon in background"
    echo "  stop    Stop the running daemon"
    echo "  status  Check if daemon is running"
    echo "  run     Run in foreground (for debugging)"
    ;;
esac
