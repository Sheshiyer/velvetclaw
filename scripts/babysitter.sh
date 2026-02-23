#!/usr/bin/env bash
# VelvetClaw — Babysitter Daemon
#
# Monitors loop-runner health and auto-restarts on crash.
# Also monitors daily cost budget.
#
# Usage:
#   ./scripts/babysitter.sh start     # Start babysitter daemon
#   ./scripts/babysitter.sh stop      # Stop babysitter
#   ./scripts/babysitter.sh status    # Show babysitter and loop-runner status

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="$REPO_ROOT/.babysitter.pid"
LOOP_PID_FILE="$REPO_ROOT/.loop-runner.pid"
LOG_DIR="$REPO_ROOT/logs"
LOG_FILE="$LOG_DIR/babysitter.log"
RESPAWN_COUNT_FILE="/tmp/velvetclaw-respawn-count"
LAST_CHECK_FILE="/tmp/velvetclaw-babysitter-lastcheck"
CHECK_INTERVAL=30

# ── Load config ──

load_config() {
  if [[ -f "$REPO_ROOT/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$REPO_ROOT/.env"
    set +a
  fi
}

MAX_RESPAWNS="${MAX_RESPAWNS:-3}"
COST_ALERT_THRESHOLD="${COST_ALERT_THRESHOLD:-10.00}"

# ── Ensure directories ──

mkdir -p "$LOG_DIR"

# ── Helpers ──

log() {
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "[$timestamp] $*" >> "$LOG_FILE"
  echo "[$timestamp] $*" >&2
}

notify() {
  local message="$1"
  local level="${2:-info}"
  "$REPO_ROOT/scripts/notify.sh" "$message" "$level" 2>/dev/null || true
}

get_respawn_count() {
  if [[ -f "$RESPAWN_COUNT_FILE" ]]; then
    cat "$RESPAWN_COUNT_FILE"
  else
    echo "0"
  fi
}

set_respawn_count() {
  echo "$1" > "$RESPAWN_COUNT_FILE"
}

is_process_alive() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null
}

loop_runner_pid() {
  if [[ -f "$LOOP_PID_FILE" ]]; then
    cat "$LOOP_PID_FILE"
  else
    echo ""
  fi
}

is_loop_runner_alive() {
  local pid
  pid="$(loop_runner_pid)"
  if [[ -n "$pid" ]] && is_process_alive "$pid"; then
    return 0
  fi
  return 1
}

# ── Commands ──

start_babysitter() {
  load_config
  MAX_RESPAWNS="${MAX_RESPAWNS:-3}"

  # Check if already running
  if [[ -f "$PID_FILE" ]]; then
    local existing_pid
    existing_pid=$(cat "$PID_FILE")
    if is_process_alive "$existing_pid"; then
      echo "Babysitter already running (PID $existing_pid)"
      exit 1
    else
      log "Stale PID file found, cleaning up"
      rm -f "$PID_FILE"
    fi
  fi

  echo "Starting babysitter daemon..."
  log "Babysitter starting (max_respawns=$MAX_RESPAWNS, check_interval=${CHECK_INTERVAL}s)"

  # Reset respawn counter on fresh start
  set_respawn_count 0

  # Fork to background
  nohup bash "$0" _run >> "$LOG_FILE" 2>&1 &
  local daemon_pid=$!
  echo "$daemon_pid" > "$PID_FILE"
  echo "Babysitter started (PID $daemon_pid). Logs: $LOG_FILE"
}

stop_babysitter() {
  if [[ ! -f "$PID_FILE" ]]; then
    echo "No PID file found. Babysitter not running."
    exit 0
  fi

  local pid
  pid=$(cat "$PID_FILE")
  if is_process_alive "$pid"; then
    echo "Stopping babysitter (PID $pid)..."
    kill "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "Stopped."
  else
    echo "PID $pid not running. Cleaning up stale PID file."
    rm -f "$PID_FILE"
  fi
}

show_status() {
  load_config
  MAX_RESPAWNS="${MAX_RESPAWNS:-3}"

  local babysitter_status="STOPPED"
  local babysitter_pid="--"
  local loop_status="STOPPED"
  local loop_pid="--"
  local respawn_count
  respawn_count="$(get_respawn_count)"
  local daily_cost="unknown"
  local budget="$COST_ALERT_THRESHOLD"
  local last_check="unknown"

  # Babysitter status
  if [[ -f "$PID_FILE" ]]; then
    babysitter_pid=$(cat "$PID_FILE")
    if is_process_alive "$babysitter_pid"; then
      babysitter_status="RUNNING"
    else
      babysitter_status="DEAD (stale PID)"
    fi
  fi

  # Loop runner status
  if [[ -f "$LOOP_PID_FILE" ]]; then
    loop_pid=$(cat "$LOOP_PID_FILE")
    if is_process_alive "$loop_pid"; then
      loop_status="RUNNING"
    else
      loop_status="DEAD (stale PID)"
    fi
  fi

  # Daily cost
  local cost_output
  cost_output=$("$REPO_ROOT/scripts/cost-tracker.sh" check-budget 2>/dev/null || echo "")
  if [[ -n "$cost_output" ]]; then
    # Extract dollar amounts from "Budget OK: $X.XX / $Y.YY ($Z.ZZ remaining)"
    daily_cost=$(echo "$cost_output" | grep -oE '\$[0-9]+\.[0-9]+' | head -1 || echo "unknown")
  fi

  # Last check time
  if [[ -f "$LAST_CHECK_FILE" ]]; then
    local last_ts
    last_ts=$(cat "$LAST_CHECK_FILE")
    local now_ts
    now_ts=$(date +%s)
    local diff=$(( now_ts - last_ts ))
    last_check="${diff}s ago"
  fi

  echo ""
  echo "Babysitter: $babysitter_status (PID $babysitter_pid)"
  echo "Loop Runner: $loop_status (PID $loop_pid)"
  echo "Respawn Count: $respawn_count/$MAX_RESPAWNS"
  echo "Daily Cost: $daily_cost / \$$budget budget"
  echo "Last Check: $last_check"
  echo ""
}

# ── Main daemon loop ──

run_daemon() {
  load_config
  MAX_RESPAWNS="${MAX_RESPAWNS:-3}"

  log "Babysitter daemon loop started"

  while true; do
    # Record check time
    date +%s > "$LAST_CHECK_FILE"

    # 1. Check loop-runner health
    if ! is_loop_runner_alive; then
      local respawn_count
      respawn_count="$(get_respawn_count)"
      respawn_count=$(( respawn_count + 1 ))
      set_respawn_count "$respawn_count"

      if [[ "$respawn_count" -ge "$MAX_RESPAWNS" ]]; then
        log "Max respawns reached ($respawn_count/$MAX_RESPAWNS), giving up"
        notify "Loop-runner crashed $respawn_count times. Max respawns reached -- babysitter giving up." "critical"
        # Clean up and exit
        rm -f "$PID_FILE"
        exit 1
      else
        log "Loop-runner crashed, respawning (attempt $respawn_count/$MAX_RESPAWNS)"
        notify "Loop-runner crashed. Respawning (attempt $respawn_count/$MAX_RESPAWNS)." "warning"
        "$REPO_ROOT/scripts/loop-runner.sh" start 2>/dev/null || {
          log "Failed to restart loop-runner"
          notify "Failed to restart loop-runner on attempt $respawn_count" "critical"
        }
      fi
    else
      # Loop runner is alive, reset respawn counter
      # (only reset if we see it alive for a full cycle)
      local current_count
      current_count="$(get_respawn_count)"
      if [[ "$current_count" -gt 0 ]]; then
        log "Loop-runner stable, resetting respawn counter from $current_count to 0"
        set_respawn_count 0
      fi
    fi

    # 2. Check daily cost budget
    if ! "$REPO_ROOT/scripts/cost-tracker.sh" check-budget >/dev/null 2>&1; then
      log "OVER BUDGET -- stopping loop-runner"
      notify "Daily cost budget exceeded (\$$COST_ALERT_THRESHOLD). Stopping loop-runner." "critical"

      # Stop loop-runner
      "$REPO_ROOT/scripts/loop-runner.sh" stop 2>/dev/null || true
      log "Loop-runner stopped due to budget overage"

      # Don't exit babysitter -- keep monitoring in case budget resets at midnight
      # But stop checking loop-runner until budget clears
      sleep "$CHECK_INTERVAL"
      continue
    fi

    sleep "$CHECK_INTERVAL"
  done
}

# ── Entry Point ──

case "${1:-help}" in
  start)
    start_babysitter
    ;;
  stop)
    stop_babysitter
    ;;
  status)
    show_status
    ;;
  _run)
    # Internal: called by nohup in start_babysitter
    run_daemon
    ;;
  help|*)
    echo "VelvetClaw Babysitter"
    echo ""
    echo "Usage: $0 {start|stop|status}"
    echo ""
    echo "  start   Start babysitter daemon (monitors loop-runner)"
    echo "  stop    Stop the babysitter"
    echo "  status  Show babysitter and loop-runner status"
    ;;
esac
