#!/usr/bin/env bash
# VelvetClaw — Agent Health Check
#
# Validates all agents have valid state files.
#
# Usage:
#   ./scripts/health-check.sh          # Check all agents
#   ./scripts/health-check.sh jarvis   # Check specific agent
#   ./scripts/health-check.sh --fix    # Auto-create missing files from templates

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="$REPO_ROOT/agents"
TEMPLATES_DIR="$REPO_ROOT/templates"

FIX_MODE=false
TARGET_AGENT=""
TOTAL_AGENTS=0
HEALTHY_AGENTS=0

# ── Parse arguments ──

for arg in "$@"; do
  case "$arg" in
    --fix)
      FIX_MODE=true
      ;;
    -*)
      echo "Unknown flag: $arg" >&2
      exit 1
      ;;
    *)
      TARGET_AGENT="$arg"
      ;;
  esac
done

# ── Helpers ──

log() {
  echo "$*" >&2
}

# Simple YAML validation: check file is non-empty and has key: value patterns
validate_yaml() {
  local file="$1"
  if [[ ! -s "$file" ]]; then
    return 1
  fi
  # Check for at least one key: value line (basic YAML structure)
  if grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*:' "$file" 2>/dev/null; then
    return 0
  fi
  # Try python yaml parser if available
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null && return 0
  fi
  return 1
}

# Check if a markdown file has a specific section header
has_section() {
  local file="$1"
  local section="$2"
  grep -q "^## $section" "$file" 2>/dev/null
}

# Check if a markdown file has any ## header
has_any_h2() {
  local file="$1"
  grep -q "^## " "$file" 2>/dev/null
}

# ── Fix missing files ──

fix_manifest() {
  local agent_id="$1"
  local agent_dir="$AGENTS_DIR/$agent_id"
  local file="$agent_dir/MANIFEST.yaml"
  if [[ ! -f "$file" ]]; then
    cat > "$file" <<YAML
agent:
  id: "$agent_id"
  name: "$(echo "$agent_id" | tr '[:lower:]' '[:upper:]')"
  tier: 2
  role: "Agent"
  department: null
  reports_to: jarvis

models:
  primary: "claude-sonnet-4"
  fallback: null
  thinking: "standard"

loop:
  enabled: true
  interval: "15m"
  max_step_timeout: "14m"
  on_blocked: log_and_skip
  on_failure: log_skip_continue
  retry_blocked_after: 3
YAML
    log "  FIXED: Created MANIFEST.yaml for $agent_id"
  fi
}

fix_tasks() {
  local agent_id="$1"
  local agent_dir="$AGENTS_DIR/$agent_id"
  local file="$agent_dir/TASKS.md"
  local agent_upper
  agent_upper="$(echo "$agent_id" | tr '[:lower:]' '[:upper:]')"
  if [[ ! -f "$file" ]]; then
    cat > "$file" <<MD
# $agent_upper -- Tasks

## Active Tasks

_No tasks yet._

## Completed Tasks

_History of completed tasks moves here._
MD
    log "  FIXED: Created TASKS.md for $agent_id"
  elif ! has_any_h2 "$file"; then
    # Has file but missing ## header, prepend one
    local tmp
    tmp=$(mktemp)
    printf "# %s -- Tasks\n\n## Active Tasks\n\n" "$agent_upper" > "$tmp"
    cat "$file" >> "$tmp"
    mv "$tmp" "$file"
    log "  FIXED: Added ## header to TASKS.md for $agent_id"
  fi
}

fix_heartbeat() {
  local agent_id="$1"
  local agent_dir="$AGENTS_DIR/$agent_id"
  local file="$agent_dir/HEARTBEAT.md"
  local agent_upper
  agent_upper="$(echo "$agent_id" | tr '[:lower:]' '[:upper:]')"
  if [[ ! -f "$file" ]]; then
    cat > "$file" <<MD
# $agent_upper -- Heartbeat

Loop cycle health and status log.

## Current Status
- **State**: idle
- **Last Cycle**: never
- **Cycles Today**: 0

## Cycle Log

| Timestamp | Step | Outcome | Duration | Notes |
|-----------|------|---------|----------|-------|
| _awaiting first cycle_ | -- | -- | -- | -- |
MD
    log "  FIXED: Created HEARTBEAT.md for $agent_id"
  fi
}

fix_inbox() {
  local agent_id="$1"
  local agent_dir="$AGENTS_DIR/$agent_id"
  local file="$agent_dir/INBOX.md"
  local agent_upper
  agent_upper="$(echo "$agent_id" | tr '[:lower:]' '[:upper:]')"
  if [[ ! -f "$file" ]]; then
    cat > "$file" <<MD
# $agent_upper -- Inbox

> Cross-agent task assignments and messages.

## Pending

<!-- New assignments appear here -->

## Processed

<!-- Completed inbox items are archived here with timestamps -->
MD
    log "  FIXED: Created INBOX.md for $agent_id"
  else
    # Ensure sections exist
    local needs_write=false
    local content
    content="$(cat "$file")"

    if ! has_section "$file" "Pending"; then
      content="$content

## Pending

<!-- New assignments appear here -->"
      needs_write=true
    fi
    if ! has_section "$file" "Processed"; then
      content="$content

## Processed

<!-- Completed inbox items are archived here -->"
      needs_write=true
    fi

    if [[ "$needs_write" == "true" ]]; then
      echo "$content" > "$file"
      log "  FIXED: Added missing sections to INBOX.md for $agent_id"
    fi
  fi
}

fix_context() {
  local agent_id="$1"
  local agent_dir="$AGENTS_DIR/$agent_id"
  local file="$agent_dir/CONTEXT.md"
  local agent_upper
  agent_upper="$(echo "$agent_id" | tr '[:lower:]' '[:upper:]')"
  if [[ ! -f "$file" ]]; then
    cat > "$file" <<MD
# $agent_upper -- Context

Known pitfalls, constraints, and environment notes.

## Known Issues

_None yet._

## Environment Notes

_None yet._
MD
    log "  FIXED: Created CONTEXT.md for $agent_id"
  fi
}

fix_identity() {
  local agent_id="$1"
  local agent_dir="$AGENTS_DIR/$agent_id"
  local file="$agent_dir/IDENTITY.md"
  local agent_upper
  agent_upper="$(echo "$agent_id" | tr '[:lower:]' '[:upper:]')"
  if [[ ! -f "$file" ]]; then
    cat > "$file" <<MD
# $agent_upper -- Identity

## Role
Agent in VelvetClaw multi-agent system.

## Personality
Professional and efficient.
MD
    log "  FIXED: Created IDENTITY.md for $agent_id"
  fi
}

fix_soul() {
  local agent_id="$1"
  local agent_dir="$AGENTS_DIR/$agent_id"
  local file="$agent_dir/SOUL.md"
  local agent_upper
  agent_upper="$(echo "$agent_id" | tr '[:lower:]' '[:upper:]')"
  if [[ ! -f "$file" ]]; then
    cat > "$file" <<MD
# $agent_upper -- Soul

Core values and behavioral directives.
MD
    log "  FIXED: Created SOUL.md for $agent_id"
  fi
}

# ── Check a single agent ──

check_agent() {
  local agent_id="$1"
  local agent_dir="$AGENTS_DIR/$agent_id"
  local issues=()
  local checks_passed=0
  local total_checks=7

  # 1. MANIFEST.yaml exists and is valid YAML
  if [[ -f "$agent_dir/MANIFEST.yaml" ]]; then
    if validate_yaml "$agent_dir/MANIFEST.yaml"; then
      checks_passed=$(( checks_passed + 1 ))
    else
      issues+=("MANIFEST.yaml invalid YAML")
    fi
  else
    issues+=("MANIFEST.yaml missing")
    if [[ "$FIX_MODE" == "true" ]]; then
      fix_manifest "$agent_id"
    fi
  fi

  # 2. TASKS.md exists and has ## header
  if [[ -f "$agent_dir/TASKS.md" ]]; then
    if has_any_h2 "$agent_dir/TASKS.md"; then
      checks_passed=$(( checks_passed + 1 ))
    else
      issues+=("TASKS.md missing ## header")
      if [[ "$FIX_MODE" == "true" ]]; then
        fix_tasks "$agent_id"
      fi
    fi
  else
    issues+=("TASKS.md missing")
    if [[ "$FIX_MODE" == "true" ]]; then
      fix_tasks "$agent_id"
    fi
  fi

  # 3. HEARTBEAT.md exists
  if [[ -f "$agent_dir/HEARTBEAT.md" ]]; then
    checks_passed=$(( checks_passed + 1 ))
  else
    issues+=("HEARTBEAT.md missing")
    if [[ "$FIX_MODE" == "true" ]]; then
      fix_heartbeat "$agent_id"
    fi
  fi

  # 4. INBOX.md exists and has ## Pending and ## Processed
  if [[ -f "$agent_dir/INBOX.md" ]]; then
    local inbox_ok=true
    if ! has_section "$agent_dir/INBOX.md" "Pending"; then
      issues+=("INBOX.md missing ## Pending")
      inbox_ok=false
    fi
    if ! has_section "$agent_dir/INBOX.md" "Processed"; then
      issues+=("INBOX.md missing ## Processed")
      inbox_ok=false
    fi
    if [[ "$inbox_ok" == "true" ]]; then
      checks_passed=$(( checks_passed + 1 ))
    elif [[ "$FIX_MODE" == "true" ]]; then
      fix_inbox "$agent_id"
    fi
  else
    issues+=("INBOX.md missing")
    if [[ "$FIX_MODE" == "true" ]]; then
      fix_inbox "$agent_id"
    fi
  fi

  # 5. CONTEXT.md exists
  if [[ -f "$agent_dir/CONTEXT.md" ]]; then
    checks_passed=$(( checks_passed + 1 ))
  else
    issues+=("CONTEXT.md missing")
    if [[ "$FIX_MODE" == "true" ]]; then
      fix_context "$agent_id"
    fi
  fi

  # 6. IDENTITY.md exists
  if [[ -f "$agent_dir/IDENTITY.md" ]]; then
    checks_passed=$(( checks_passed + 1 ))
  else
    issues+=("IDENTITY.md missing")
    if [[ "$FIX_MODE" == "true" ]]; then
      fix_identity "$agent_id"
    fi
  fi

  # 7. SOUL.md exists
  if [[ -f "$agent_dir/SOUL.md" ]]; then
    checks_passed=$(( checks_passed + 1 ))
  else
    issues+=("SOUL.md missing")
    if [[ "$FIX_MODE" == "true" ]]; then
      fix_soul "$agent_id"
    fi
  fi

  # Format result line
  TOTAL_AGENTS=$(( TOTAL_AGENTS + 1 ))

  if [[ ${#issues[@]} -eq 0 ]]; then
    HEALTHY_AGENTS=$(( HEALTHY_AGENTS + 1 ))
    printf "| %-10s | PASS All %d checks passed          |\n" "$agent_id" "$total_checks"
  else
    local issue_str="${issues[0]}"
    if [[ ${#issues[@]} -gt 1 ]]; then
      issue_str="${issue_str} (+$((${#issues[@]} - 1)) more)"
    fi
    printf "| %-10s | FAIL %-31s |\n" "$agent_id" "$issue_str"
  fi
}

# ── Main ──

main() {
  echo ""
  echo "+--------------------------------------------+"
  echo "|       VelvetClaw Health Check               |"
  echo "+--------------------------------------------+"

  if [[ -n "$TARGET_AGENT" ]] && [[ "$TARGET_AGENT" != "--fix" ]]; then
    if [[ ! -d "$AGENTS_DIR/$TARGET_AGENT" ]]; then
      echo "ERROR: agent '$TARGET_AGENT' not found" >&2
      exit 1
    fi
    check_agent "$TARGET_AGENT"
  else
    for agent_dir in "$AGENTS_DIR"/*/; do
      if [[ -d "$agent_dir" ]]; then
        local agent_id
        agent_id="$(basename "$agent_dir")"
        check_agent "$agent_id"
      fi
    done
  fi

  echo "+--------------------------------------------+"
  printf "| Result: %d/%d healthy                       |\n" "$HEALTHY_AGENTS" "$TOTAL_AGENTS"
  echo "+--------------------------------------------+"
  echo ""

  if [[ "$FIX_MODE" == "true" ]]; then
    echo "(--fix mode: missing files were auto-created)" >&2
  fi

  if [[ "$HEALTHY_AGENTS" -lt "$TOTAL_AGENTS" ]]; then
    exit 1
  fi
  exit 0
}

main
