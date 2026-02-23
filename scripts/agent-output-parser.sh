#!/usr/bin/env bash
# VelvetClaw Agent Output Parser
# Parses raw claude output to extract structured file updates.
#
# Looks for ===VELVETCLAW_OUTPUT_START=== / ===VELVETCLAW_OUTPUT_END=== markers
# and extracts each ---FILE_UPDATE: {filename}--- block.
#
# Usage:
#   ./scripts/agent-output-parser.sh /path/to/raw-output.txt
#   cat raw-output.txt | ./scripts/agent-output-parser.sh
#
# Output: JSON on stdout
#   Success: {"updates": [{"file": "TASKS.md", "content": "..."}, ...]}
#   Error:   {"error": "no_structured_output", "raw": "first 500 chars..."}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Logging (to stderr) ───

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [output-parser] [$level] $*" >&2
}

# ─── Read input from file arg or stdin ───

RAW_OUTPUT=""

if [[ $# -ge 1 ]] && [[ -f "$1" ]]; then
  RAW_OUTPUT=$(cat "$1")
  log "info" "Reading from file: $1"
elif [[ ! -t 0 ]]; then
  RAW_OUTPUT=$(cat)
  log "info" "Reading from stdin"
else
  log "error" "No input provided. Pass a file path or pipe stdin."
  echo '{"error": "no_input", "raw": ""}'
  exit 0
fi

# ─── Check for structured output markers ───

if ! echo "$RAW_OUTPUT" | grep -q "===VELVETCLAW_OUTPUT_START===" || \
   ! echo "$RAW_OUTPUT" | grep -q "===VELVETCLAW_OUTPUT_END==="; then
  log "warn" "No structured output markers found in agent response"
  # Extract first 500 chars for diagnostics, JSON-escape them
  FIRST_500=$(echo "$RAW_OUTPUT" | head -c 500)
  # JSON-escape the raw preview
  ESCAPED_RAW=$(printf '%s' "$FIRST_500" | python3 -c '
import sys, json
raw = sys.stdin.read()
print(json.dumps(raw))
' 2>/dev/null || printf '"%s"' "$(echo "$FIRST_500" | tr '\n' ' ' | tr '"' "'" | head -c 500)")
  echo "{\"error\": \"no_structured_output\", \"raw\": ${ESCAPED_RAW}}"
  exit 0
fi

# ─── Extract content between markers ───

STRUCTURED=$(echo "$RAW_OUTPUT" | sed -n '/===VELVETCLAW_OUTPUT_START===/,/===VELVETCLAW_OUTPUT_END===/p' | sed '1d;$d')

if [[ -z "$STRUCTURED" ]]; then
  log "warn" "Markers found but no content between them"
  echo '{"error": "empty_structured_output", "raw": ""}'
  exit 0
fi

# ─── Parse each FILE_UPDATE block using python3 for reliable JSON escaping ───

PARSE_RESULT=""
PARSE_RESULT=$(echo "$STRUCTURED" | python3 -c '
import sys
import json
import re

content = sys.stdin.read()

# Find all FILE_UPDATE blocks
pattern = r"---FILE_UPDATE:\s*([^-\n]+?)\s*---\n(.*?)---END_FILE_UPDATE---"
matches = re.findall(pattern, content, re.DOTALL)

if not matches:
    print(json.dumps({"error": "no_file_updates_found", "raw": content[:500]}))
    sys.exit(0)

updates = []
for filename, file_content in matches:
    filename = filename.strip()
    file_content = file_content.strip()
    updates.append({
        "file": filename,
        "content": file_content
    })

result = {"updates": updates}
print(json.dumps(result))
' 2>/dev/null) || {
  log "error" "Python parser failed"
  echo '{"error": "parser_failure", "raw": ""}'
  exit 0
}

echo "$PARSE_RESULT"
log "info" "Successfully parsed agent output"
