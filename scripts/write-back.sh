#!/usr/bin/env bash
# VelvetClaw Write-Back
# Takes parser JSON output and applies file updates to the agent's directory.
#
# Usage:
#   ./scripts/write-back.sh <agent_id> /path/to/parsed-output.json
#   cat parsed-output.json | ./scripts/write-back.sh <agent_id>
#
# Behavior:
#   - TASKS.md:    Full overwrite (parser provides complete file)
#   - HEARTBEAT.md: APPEND only (new entry appended to existing file)
#   - INBOX.md:    Full overwrite (parser provides complete file)
#   - CONTEXT.md:  APPEND new pitfalls (unless content is "NO_CHANGES")

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# ─── Logging (to stderr) ───

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [write-back] [$level] $*" >&2
}

# ─── Validate args ───

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <agent_id> [parsed-output.json]" >&2
  exit 1
fi

AGENT_ID="$1"
AGENT_DIR="$REPO_ROOT/agents/$AGENT_ID"

if [[ ! -d "$AGENT_DIR" ]]; then
  log "error" "Agent directory not found: $AGENT_DIR"
  exit 1
fi

# ─── Read JSON input ───

JSON_INPUT=""

if [[ $# -ge 2 ]] && [[ -f "$2" ]]; then
  JSON_INPUT=$(cat "$2")
  log "info" "Reading parsed output from file: $2"
elif [[ ! -t 0 ]]; then
  JSON_INPUT=$(cat)
  log "info" "Reading parsed output from stdin"
else
  log "error" "No input provided. Pass a file path or pipe stdin."
  exit 1
fi

# ─── Check for error in parser output ───

HAS_ERROR=$(echo "$JSON_INPUT" | python3 -c '
import sys, json
data = json.load(sys.stdin)
print("yes" if "error" in data else "no")
' 2>/dev/null || echo "parse_fail")

if [[ "$HAS_ERROR" == "yes" ]]; then
  ERROR_MSG=$(echo "$JSON_INPUT" | python3 -c '
import sys, json
data = json.load(sys.stdin)
print(data.get("error", "unknown"))
')
  log "warn" "Parser returned error: $ERROR_MSG — writing error context"

  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Write error to CONTEXT.md under Known Pitfalls
  if [[ -f "$AGENT_DIR/CONTEXT.md" ]]; then
    echo "" >> "$AGENT_DIR/CONTEXT.md"
    echo "- [$NOW] Loop cycle error: $ERROR_MSG — agent output was not parseable. Check logs for raw output." >> "$AGENT_DIR/CONTEXT.md"
    log "info" "Appended error to CONTEXT.md"
  fi

  # Write failure entry to HEARTBEAT.md
  if [[ -f "$AGENT_DIR/HEARTBEAT.md" ]]; then
    {
      echo ""
      echo "### $NOW Cycle Result"
      echo "- Step: parse-error"
      echo "- Outcome: failed"
      echo "- Duration: 0s"
      echo "- Summary: Agent output could not be parsed ($ERROR_MSG)"
    } >> "$AGENT_DIR/HEARTBEAT.md"
    log "info" "Appended failure entry to HEARTBEAT.md"
  fi

  exit 0
fi

# ─── Process each file update ───

UPDATE_COUNT=$(echo "$JSON_INPUT" | python3 -c '
import sys, json
data = json.load(sys.stdin)
print(len(data.get("updates", [])))
')

log "info" "Processing $UPDATE_COUNT file updates for agent $AGENT_ID"

echo "$JSON_INPUT" | python3 -c '
import sys, json, os

data = json.load(sys.stdin)
agent_dir = os.environ.get("AGENT_DIR", "")

for update in data.get("updates", []):
    filename = update["file"]
    content = update["content"]
    # Output tab-separated: filename\tcontent
    # Use a unique separator since content is multi-line
    print(f"===UPDATE_ENTRY===")
    print(f"FILE:{filename}")
    print(content)
    print(f"===END_UPDATE_ENTRY===")
' | {
  current_file=""
  current_content=""
  in_entry=false

  while IFS= read -r line; do
    if [[ "$line" == "===UPDATE_ENTRY===" ]]; then
      in_entry=true
      current_file=""
      current_content=""
      continue
    fi

    if [[ "$line" == "===END_UPDATE_ENTRY===" ]]; then
      in_entry=false

      if [[ -z "$current_file" ]]; then
        log "warn" "Skipping update with empty filename"
        continue
      fi

      TARGET_FILE="$AGENT_DIR/$current_file"

      case "$current_file" in
        TASKS.md)
          # Full overwrite
          echo "$current_content" > "$TARGET_FILE"
          log "info" "Wrote TASKS.md (overwrite) — $(echo "$current_content" | wc -l | xargs) lines"
          ;;

        HEARTBEAT.md)
          # Append only
          if [[ -f "$TARGET_FILE" ]]; then
            {
              echo ""
              echo "$current_content"
            } >> "$TARGET_FILE"
          else
            echo "$current_content" > "$TARGET_FILE"
          fi
          log "info" "Appended to HEARTBEAT.md — $(echo "$current_content" | wc -l | xargs) lines"
          ;;

        INBOX.md)
          # Full overwrite
          echo "$current_content" > "$TARGET_FILE"
          log "info" "Wrote INBOX.md (overwrite) — $(echo "$current_content" | wc -l | xargs) lines"
          ;;

        CONTEXT.md)
          # Append new pitfalls (unless NO_CHANGES)
          if [[ "$current_content" == "NO_CHANGES" ]]; then
            log "info" "CONTEXT.md — no changes"
          else
            if [[ -f "$TARGET_FILE" ]]; then
              {
                echo ""
                echo "$current_content"
              } >> "$TARGET_FILE"
            else
              echo "$current_content" > "$TARGET_FILE"
            fi
            log "info" "Appended to CONTEXT.md — $(echo "$current_content" | wc -l | xargs) lines"
          fi
          ;;

        *)
          log "warn" "Unknown file update target: $current_file — skipping"
          ;;
      esac

      continue
    fi

    if [[ "$in_entry" == "true" ]]; then
      if [[ "$line" == FILE:* ]] && [[ -z "$current_file" ]]; then
        current_file="${line#FILE:}"
      else
        if [[ -z "$current_content" ]]; then
          current_content="$line"
        else
          current_content="$current_content
$line"
        fi
      fi
    fi
  done
}

log "info" "Write-back complete for agent $AGENT_ID"
