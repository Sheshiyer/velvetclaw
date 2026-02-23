#!/usr/bin/env bash
# VelvetClaw — macOS Notification Center Alerts
#
# Usage:
#   ./scripts/notify.sh "Message text" [level]
#   level: info (default), warning, critical
#
# Sends macOS notifications via osascript and logs all notifications.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$REPO_ROOT/logs"
LOG_FILE="$LOG_DIR/notifications.log"

# ── Ensure log directory ──

mkdir -p "$LOG_DIR"

# ── Arguments ──

MESSAGE="${1:-}"
LEVEL="${2:-info}"

if [[ -z "$MESSAGE" ]]; then
  echo "Usage: $0 \"message\" [info|warning|critical]" >&2
  exit 1
fi

# Normalize level
case "$LEVEL" in
  info|warning|critical) ;;
  *)
    echo "Unknown level '$LEVEL', defaulting to info" >&2
    LEVEL="info"
    ;;
esac

# ── Timestamp ──

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# ── Log the notification ──

echo "[$TIMESTAMP] [$LEVEL] $MESSAGE" >> "$LOG_FILE"

# ── Send macOS notification ──

send_notification() {
  local title="VelvetClaw"
  local subtitle
  subtitle="$(echo "$LEVEL" | tr '[:lower:]' '[:upper:]')"

  if [[ "$LEVEL" == "critical" ]]; then
    title="VelvetClaw CRITICAL"
    osascript -e "display notification \"$MESSAGE\" with title \"$title\" subtitle \"$subtitle\" sound name \"Basso\"" 2>/dev/null || {
      echo "[$TIMESTAMP] [warn] osascript failed (headless?), notification logged only" >> "$LOG_FILE"
      return 0
    }
  else
    osascript -e "display notification \"$MESSAGE\" with title \"$title\" subtitle \"$subtitle\"" 2>/dev/null || {
      echo "[$TIMESTAMP] [warn] osascript failed (headless?), notification logged only" >> "$LOG_FILE"
      return 0
    }
  fi
}

send_notification

echo "[$LEVEL] $MESSAGE" >&2
