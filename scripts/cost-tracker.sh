#!/usr/bin/env bash
# VelvetClaw — Cost Tracker
#
# Tracks per-agent token costs from claude -p invocations.
#
# Usage:
#   ./scripts/cost-tracker.sh <agent_id> <stderr_file>     # Log cost from a cycle
#   ./scripts/cost-tracker.sh report                         # Show cost summary
#   ./scripts/cost-tracker.sh report --agent jarvis          # Per-agent report
#   ./scripts/cost-tracker.sh check-budget                   # Check against daily budget

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$REPO_ROOT/logs"

# ── Load config ──

if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$REPO_ROOT/.env"
  set +a
fi

COST_ALERT_THRESHOLD="${COST_ALERT_THRESHOLD:-10.00}"

# ── Ensure log directory ──

mkdir -p "$LOG_DIR"

# ── Helpers ──

log() {
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "[$timestamp] $*" >&2
}

today_date() {
  date -u +"%Y-%m-%d"
}

# ── Pricing (per 1M tokens) ──

price_input() {
  local model="${1:-default}"
  case "$model" in
    *opus*)   echo "15.00" ;;
    *sonnet*) echo "3.00"  ;;
    *)        echo "3.00"  ;;
  esac
}

price_output() {
  local model="${1:-default}"
  case "$model" in
    *opus*)   echo "75.00" ;;
    *sonnet*) echo "15.00" ;;
    *)        echo "15.00" ;;
  esac
}

# ── CSV header ──

csv_header() {
  echo "date,agent_id,model,input_tokens,output_tokens,estimated_cost_usd"
}

ensure_csv() {
  local csv_file="$1"
  if [[ ! -f "$csv_file" ]]; then
    csv_header > "$csv_file"
  fi
}

# ── Command: log cost from a cycle ──

log_cost() {
  local agent_id="$1"
  local stderr_file="$2"

  if [[ ! -f "$stderr_file" ]]; then
    log "WARN: stderr file '$stderr_file' not found"
    exit 1
  fi

  local csv_file="$LOG_DIR/cost-${agent_id}.csv"
  ensure_csv "$csv_file"

  # Parse token counts from stderr
  # Common patterns: "input_tokens": 1234, "output_tokens": 5678
  # Also: input_tokens=1234, output_tokens=5678
  local input_tokens=0
  local output_tokens=0

  # Try JSON-style patterns first
  local found_input
  found_input=$(grep -oE '"?input_tokens"?\s*[=:]\s*[0-9]+' "$stderr_file" | grep -oE '[0-9]+' | tail -1 || echo "")
  local found_output
  found_output=$(grep -oE '"?output_tokens"?\s*[=:]\s*[0-9]+' "$stderr_file" | grep -oE '[0-9]+' | tail -1 || echo "")

  # Also try total_tokens if individual counts not found
  local found_total=""
  if [[ -z "$found_input" ]] && [[ -z "$found_output" ]]; then
    found_total=$(grep -oE '"?total_tokens"?\s*[=:]\s*[0-9]+' "$stderr_file" | grep -oE '[0-9]+' | tail -1 || echo "")
  fi

  if [[ -n "$found_input" ]]; then
    input_tokens="$found_input"
  fi
  if [[ -n "$found_output" ]]; then
    output_tokens="$found_output"
  fi

  # If only total found, split estimate 30/70 (rough input/output ratio)
  if [[ -n "$found_total" ]] && [[ "$input_tokens" -eq 0 ]] && [[ "$output_tokens" -eq 0 ]]; then
    input_tokens=$(( found_total * 30 / 100 ))
    output_tokens=$(( found_total - input_tokens ))
  fi

  if [[ "$input_tokens" -eq 0 ]] && [[ "$output_tokens" -eq 0 ]]; then
    log "WARN: no token counts found in $stderr_file"
    return 0
  fi

  # Detect model from stderr
  local model="default"
  if grep -q "opus" "$stderr_file" 2>/dev/null; then
    model="claude-opus-4"
  elif grep -q "sonnet" "$stderr_file" 2>/dev/null; then
    model="claude-sonnet-4"
  fi

  # Calculate cost
  local ip
  ip=$(price_input "$model")
  local op
  op=$(price_output "$model")

  # Cost = (input_tokens / 1000000 * input_price) + (output_tokens / 1000000 * output_price)
  # Use awk for floating point
  local cost
  cost=$(awk "BEGIN { printf \"%.6f\", ($input_tokens / 1000000.0 * $ip) + ($output_tokens / 1000000.0 * $op) }")

  local date_str
  date_str="$(today_date)"

  echo "$date_str,$agent_id,$model,$input_tokens,$output_tokens,$cost" >> "$csv_file"
  log "LOGGED $agent_id: ${input_tokens}in/${output_tokens}out tokens, model=$model, cost=\$$cost"
}

# ── Command: report ──

show_report() {
  local filter_agent=""

  # Parse --agent flag
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent)
        filter_agent="${2:-}"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  echo ""
  echo "=== VelvetClaw Cost Report ==="
  echo ""

  local grand_total=0
  local today
  today="$(today_date)"
  local today_total=0

  # Collect all CSV files
  local csv_files
  if [[ -n "$filter_agent" ]]; then
    csv_files="$LOG_DIR/cost-${filter_agent}.csv"
    if [[ ! -f "$csv_files" ]]; then
      echo "No cost data for agent '$filter_agent'"
      return 0
    fi
  else
    csv_files=""
    for f in "$LOG_DIR"/cost-*.csv; do
      if [[ -f "$f" ]]; then
        csv_files="$csv_files $f"
      fi
    done
    if [[ -z "$csv_files" ]]; then
      echo "No cost data found."
      return 0
    fi
  fi

  printf "%-12s  %-18s  %12s  %12s  %12s\n" "Agent" "Model" "Input Tok" "Output Tok" "Cost (USD)"
  printf "%-12s  %-18s  %12s  %12s  %12s\n" "------------" "------------------" "------------" "------------" "------------"

  for csv_file in $csv_files; do
    if [[ ! -f "$csv_file" ]]; then
      continue
    fi

    local agent_id
    agent_id=$(basename "$csv_file" .csv | sed 's/^cost-//')

    # Sum per agent (skip header line)
    local result
    result=$(awk -F',' 'NR>1 {
      input += $4
      output += $5
      cost += $6
      model = $3
    }
    END {
      if (NR > 1) printf "%s|%d|%d|%.4f", model, input, output, cost
    }' "$csv_file")

    if [[ -n "$result" ]]; then
      local model input output cost
      model=$(echo "$result" | cut -d'|' -f1)
      input=$(echo "$result" | cut -d'|' -f2)
      output=$(echo "$result" | cut -d'|' -f3)
      cost=$(echo "$result" | cut -d'|' -f4)

      printf "%-12s  %-18s  %12s  %12s  \$%11s\n" "$agent_id" "$model" "$input" "$output" "$cost"
      grand_total=$(awk "BEGIN { printf \"%.4f\", $grand_total + $cost }")
    fi

    # Today's cost
    local today_cost
    today_cost=$(awk -F',' -v d="$today" 'NR>1 && $1==d { sum += $6 } END { printf "%.4f", sum }' "$csv_file")
    today_total=$(awk "BEGIN { printf \"%.4f\", $today_total + $today_cost }")
  done

  echo ""
  printf "%-12s  %-18s  %12s  %12s  \$%11s\n" "TOTAL" "" "" "" "$grand_total"
  echo ""
  echo "Today ($today): \$$today_total"
  echo ""
}

# ── Command: check-budget ──

check_budget() {
  local today
  today="$(today_date)"
  local today_total=0

  for csv_file in "$LOG_DIR"/cost-*.csv; do
    if [[ ! -f "$csv_file" ]]; then
      continue
    fi

    local day_cost
    day_cost=$(awk -F',' -v d="$today" 'NR>1 && $1==d { sum += $6 } END { printf "%.4f", sum }' "$csv_file")
    today_total=$(awk "BEGIN { printf \"%.4f\", $today_total + $day_cost }")
  done

  local remaining
  remaining=$(awk "BEGIN { printf \"%.2f\", $COST_ALERT_THRESHOLD - $today_total }")

  local over
  over=$(awk "BEGIN { print ($today_total >= $COST_ALERT_THRESHOLD) ? 1 : 0 }")

  if [[ "$over" -eq 1 ]]; then
    echo "OVER BUDGET: \$$today_total spent today (threshold: \$$COST_ALERT_THRESHOLD)" >&2
    echo "Overage: \$$(awk "BEGIN { printf \"%.2f\", $today_total - $COST_ALERT_THRESHOLD }")" >&2
    exit 1
  else
    echo "Budget OK: \$$today_total / \$$COST_ALERT_THRESHOLD (\$$remaining remaining)"
    exit 0
  fi
}

# ── Entry Point ──

case "${1:-help}" in
  report)
    shift
    show_report "$@"
    ;;
  check-budget)
    check_budget
    ;;
  help|--help|-h)
    echo "VelvetClaw Cost Tracker"
    echo ""
    echo "Usage:"
    echo "  $0 <agent_id> <stderr_file>   Log cost from a cycle"
    echo "  $0 report                      Show cost summary"
    echo "  $0 report --agent <id>         Per-agent report"
    echo "  $0 check-budget                Check against daily budget"
    ;;
  *)
    # Assume: cost-tracker.sh <agent_id> <stderr_file>
    AGENT_ID="$1"
    STDERR_FILE="${2:-}"
    if [[ -z "$STDERR_FILE" ]]; then
      echo "Usage: $0 <agent_id> <stderr_file>" >&2
      exit 1
    fi
    log_cost "$AGENT_ID" "$STDERR_FILE"
    ;;
esac
