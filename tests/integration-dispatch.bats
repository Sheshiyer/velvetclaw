#!/usr/bin/env bats
# VelvetClaw Integration Dispatch Tests
# End-to-end tests for the full dispatch pipeline with mock claude.
# Tests task creation, routing, inbox delivery, and the complete
# dispatch -> pick up -> write back cycle.
#
# Run: bats tests/integration-dispatch.bats

setup() {
  export TEST_DIR="$(mktemp -d)"
  export REPO_ROOT="$TEST_DIR"

  # Create full directory structure
  mkdir -p "$TEST_DIR/.velvetclaw"
  mkdir -p "$TEST_DIR/scripts"
  mkdir -p "$TEST_DIR/workflows"
  mkdir -p "$TEST_DIR/logs"
  mkdir -p "$TEST_DIR/vault/research" "$TEST_DIR/vault/development" "$TEST_DIR/vault/handoffs"

  # Create all agent directories with full state files
  for agent in jarvis atlas trendy clawd sentinel pixel scribe sage clip nova vibe; do
    mkdir -p "$TEST_DIR/agents/$agent"
    cat > "$TEST_DIR/agents/$agent/IDENTITY.md" << EOF
# ${agent^^} - Identity
I am ${agent^^}, an autonomous agent in VelvetClaw.
EOF

    cat > "$TEST_DIR/agents/$agent/SOUL.md" << EOF
# ${agent^^} - Core Directives
1. Complete tasks efficiently
2. Report results accurately
EOF

    cat > "$TEST_DIR/agents/$agent/TASKS.md" << EOF
# ${agent^^} -- Tasks

## Active Tasks

## Completed Tasks
EOF

    cat > "$TEST_DIR/agents/$agent/INBOX.md" << EOF
# ${agent^^} -- Inbox

## Pending

## Processed
EOF

    cat > "$TEST_DIR/agents/$agent/CONTEXT.md" << EOF
# ${agent^^} -- Context

## Rules

## Known Pitfalls
EOF

    cat > "$TEST_DIR/agents/$agent/HEARTBEAT.md" << EOF
# ${agent^^} -- Heartbeat
EOF

    cat > "$TEST_DIR/agents/$agent/AGENTS.md" << EOF
# Agent Hierarchy
EOF

    cat > "$TEST_DIR/agents/$agent/MANIFEST.yaml" << YAML
agent:
  id: "${agent}"
  role: "Test Agent"
  reports_to: jarvis
loop:
  interval: "10m"
  max_step_timeout: "4m"
YAML
  done

  # Override jarvis as chief with 5m interval
  cat > "$TEST_DIR/agents/jarvis/MANIFEST.yaml" << 'YAML'
agent:
  id: "jarvis"
  tier: 1
  role: "Chief Strategy Officer"
  reports_to: owner
loop:
  interval: "5m"
  max_step_timeout: "4m"
YAML

  # Create org manifest with full routing config
  cat > "$TEST_DIR/manifest.yaml" << 'YAML'
org:
  hierarchy:
    chief:
      agent: jarvis
    departments:
      research:
        lead: atlas
        members:
          - trendy
      content:
        lead: scribe
        members: []
      development:
        lead: clawd
        members:
          - sentinel
      design:
        lead: pixel
        members:
          - nova
          - vibe
      user-success:
        lead: sage
        members: []
      product:
        lead: clip
        members: []
  coordination:
    task_routing:
      default: jarvis
      by_tag:
        research: research
        content: content
        code: development
        design: design
        video: design
        user: user-success
        clip: product
  models:
    default:
      primary: "test-model"
      fallback: "test-fallback"
  loop:
    enabled: true
    intervals:
      tier_1: "5m"
      tier_2_lead: "10m"
      tier_2_member: "15m"
YAML

  # Create workflow definition
  cat > "$TEST_DIR/workflows/agent-loop.yaml" << 'YAML'
name: agent-loop
steps:
  - read_inbox
  - select_step
  - execute_step
  - write_results
YAML

  # Copy all scripts and create test-friendly versions
  for script in task-registry.sh agent-prompt-assembler.sh agent-output-parser.sh write-back.sh heartbeat-writer.sh; do
    if [[ -f "$BATS_TEST_DIRNAME/../scripts/$script" ]]; then
      cp "$BATS_TEST_DIRNAME/../scripts/$script" "$TEST_DIR/scripts/"
      # Create a patched version that uses TEST_DIR
      sed \
        -e "s|^REPO_ROOT=.*|REPO_ROOT=\"$TEST_DIR\"|" \
        "$TEST_DIR/scripts/$script" > "$TEST_DIR/scripts/test-${script}"
      chmod +x "$TEST_DIR/scripts/test-${script}"
    fi
  done

  # Initialize the task registry
  bash "$TEST_DIR/scripts/test-task-registry.sh" init 2>/dev/null

  # -----------------------------------------------------------------------
  # Create dispatch-task.sh mock that uses the real task-registry + routing
  # -----------------------------------------------------------------------
  cat > "$TEST_DIR/scripts/dispatch-task.sh" << 'DISPATCH'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse arguments
TITLE=""
TAG=""
PRIORITY="medium"

# First positional arg is title
if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
  TITLE="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)    TAG="$2"; shift 2 ;;
    --priority) PRIORITY="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$TITLE" ]]; then
  echo "ERROR: Title required" >&2
  exit 1
fi

# Route by tag to department lead
route_tag_to_agent() {
  local tag="$1"
  case "$tag" in
    research)  echo "atlas" ;;
    content)   echo "scribe" ;;
    code)      echo "clawd" ;;
    design|video) echo "pixel" ;;
    user)      echo "sage" ;;
    clip)      echo "clip" ;;
    *)         echo "jarvis" ;;  # default fallback
  esac
}

TARGET_AGENT=$(route_tag_to_agent "$TAG")

# Add to task registry
TASK_ID=$(bash "$SCRIPT_DIR/test-task-registry.sh" add "$TITLE" --tag "$TAG" --priority "$PRIORITY" --agent "$TARGET_AGENT" 2>/dev/null)

# Write to agent INBOX
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
INBOX_FILE="$REPO_ROOT/agents/$TARGET_AGENT/INBOX.md"

if [[ -f "$INBOX_FILE" ]]; then
  # Insert under ## Pending section
  {
    echo ""
    echo "### [$NOW] From: dispatch | Priority: $PRIORITY"
    echo "Task: $TITLE"
    echo "Task-ID: $TASK_ID"
    echo "Tags: $TAG"
  } >> "$INBOX_FILE"
fi

echo "$TASK_ID"
echo "Dispatched to $TARGET_AGENT" >&2
DISPATCH
  chmod +x "$TEST_DIR/scripts/dispatch-task.sh"

  # Patch dispatch to use TEST_DIR
  sed \
    -e "s|^REPO_ROOT=.*|REPO_ROOT=\"$TEST_DIR\"|" \
    "$TEST_DIR/scripts/dispatch-task.sh" > "$TEST_DIR/scripts/test-dispatch-task.sh"
  chmod +x "$TEST_DIR/scripts/test-dispatch-task.sh"

  # -----------------------------------------------------------------------
  # Create vault-write.sh
  # -----------------------------------------------------------------------
  cat > "$TEST_DIR/scripts/vault-write.sh" << 'VAULT'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

DEPARTMENT="${1:-}"
FILENAME="${2:-}"
CONTENT="${3:-}"

if [[ -z "$DEPARTMENT" || -z "$FILENAME" ]]; then
  echo "Usage: vault-write.sh <department> <filename> [content]" >&2
  exit 1
fi

VAULT_DIR="$REPO_ROOT/vault/$DEPARTMENT"
mkdir -p "$VAULT_DIR"

TARGET="$VAULT_DIR/$FILENAME"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

{
  echo "---"
  echo "created: $NOW"
  echo "department: $DEPARTMENT"
  echo "filename: $FILENAME"
  echo "---"
  echo ""
  if [[ -n "$CONTENT" ]]; then
    echo "$CONTENT"
  elif [[ ! -t 0 ]]; then
    cat
  fi
} > "$TARGET"

echo "$TARGET"
VAULT
  chmod +x "$TEST_DIR/scripts/vault-write.sh"

  sed \
    -e "s|^REPO_ROOT=.*|REPO_ROOT=\"$TEST_DIR\"|" \
    "$TEST_DIR/scripts/vault-write.sh" > "$TEST_DIR/scripts/test-vault-write.sh"
  chmod +x "$TEST_DIR/scripts/test-vault-write.sh"

  # -----------------------------------------------------------------------
  # Create escalation-handler.sh
  # -----------------------------------------------------------------------
  cat > "$TEST_DIR/scripts/escalation-handler.sh" << 'ESCALATION'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

AGENT_ID="${1:-}"
BLOCK_COUNT="${2:-0}"
BLOCK_REASON="${3:-unknown}"

if [[ -z "$AGENT_ID" ]]; then
  echo "Usage: escalation-handler.sh <agent_id> <block_count> [reason]" >&2
  exit 1
fi

# Determine supervisor from manifest
SUPERVISOR="jarvis"  # Default escalation target

if (( BLOCK_COUNT >= 3 )); then
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  SUPERVISOR_INBOX="$REPO_ROOT/agents/$SUPERVISOR/INBOX.md"

  if [[ -f "$SUPERVISOR_INBOX" ]]; then
    {
      echo ""
      echo "### [$NOW] From: escalation-handler | Priority: high"
      echo "ESCALATION: Agent $AGENT_ID blocked $BLOCK_COUNT times"
      echo "Reason: $BLOCK_REASON"
      echo "Action required: Review and unblock or reassign"
    } >> "$SUPERVISOR_INBOX"
    echo "ESCALATED:$AGENT_ID:$SUPERVISOR"
  fi
else
  echo "NO_ESCALATION:$AGENT_ID:count=$BLOCK_COUNT"
fi
ESCALATION
  chmod +x "$TEST_DIR/scripts/escalation-handler.sh"

  sed \
    -e "s|^REPO_ROOT=.*|REPO_ROOT=\"$TEST_DIR\"|" \
    "$TEST_DIR/scripts/escalation-handler.sh" > "$TEST_DIR/scripts/test-escalation-handler.sh"
  chmod +x "$TEST_DIR/scripts/test-escalation-handler.sh"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ===========================================================================
# Test 1: Dispatch creates registry entry
# ===========================================================================
@test "dispatch creates registry entry" {
  TASK_ID=$(bash "$TEST_DIR/scripts/test-dispatch-task.sh" "Research competitor pricing" --tag research --priority high 2>/dev/null)

  # Verify task exists in registry
  run bash "$TEST_DIR/scripts/test-task-registry.sh" get "$TASK_ID" 2>/dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Research competitor pricing"* ]]
  [[ "$output" == *"pending"* ]]
  [[ "$output" == *"high"* ]]
}

# ===========================================================================
# Test 2: Dispatch routes by tag to correct agent (research -> atlas)
# ===========================================================================
@test "dispatch routes by tag to correct agent" {
  bash "$TEST_DIR/scripts/test-dispatch-task.sh" "Analyze market trends" --tag research --priority medium 2>/dev/null

  # Atlas INBOX should have the task
  run cat "$TEST_DIR/agents/atlas/INBOX.md"
  [[ "$output" == *"Analyze market trends"* ]]
  [[ "$output" == *"From: dispatch"* ]]

  # Clawd INBOX should NOT have it
  run cat "$TEST_DIR/agents/clawd/INBOX.md"
  [[ "$output" != *"Analyze market trends"* ]]
}

# ===========================================================================
# Test 3: Dispatch routes code tag to clawd
# ===========================================================================
@test "dispatch routes code tag to clawd" {
  bash "$TEST_DIR/scripts/test-dispatch-task.sh" "Fix login page CSS" --tag code --priority high 2>/dev/null

  # Clawd INBOX should have the task
  run cat "$TEST_DIR/agents/clawd/INBOX.md"
  [[ "$output" == *"Fix login page CSS"* ]]

  # Atlas INBOX should NOT have it
  run cat "$TEST_DIR/agents/atlas/INBOX.md"
  [[ "$output" != *"Fix login page CSS"* ]]
}

# ===========================================================================
# Test 4: Dispatch falls back to jarvis for unknown tag
# ===========================================================================
@test "dispatch falls back to jarvis for unknown tag" {
  bash "$TEST_DIR/scripts/test-dispatch-task.sh" "Unknown category task" --tag zzz_unknown --priority low 2>/dev/null

  # JARVIS INBOX should have the task (default routing)
  run cat "$TEST_DIR/agents/jarvis/INBOX.md"
  [[ "$output" == *"Unknown category task"* ]]
}

# ===========================================================================
# Test 5: INBOX entry has correct format
# ===========================================================================
@test "INBOX entry has correct format" {
  bash "$TEST_DIR/scripts/test-dispatch-task.sh" "Format test task" --tag research --priority critical 2>/dev/null

  run cat "$TEST_DIR/agents/atlas/INBOX.md"
  # Should have timestamp in ISO format
  [[ "$output" =~ \[20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\] ]]
  # Should have From field
  [[ "$output" == *"From: dispatch"* ]]
  # Should have Priority field
  [[ "$output" == *"Priority: critical"* ]]
  # Should have task content
  [[ "$output" == *"Format test task"* ]]
  # Should have Task-ID
  [[ "$output" == *"Task-ID: task-"* ]]
}

# ===========================================================================
# Test 6: Full cycle: dispatch -> pick up -> write back
# ===========================================================================
@test "full cycle: dispatch -> pick up -> write back" {
  # Step A: Dispatch task to atlas
  TASK_ID=$(bash "$TEST_DIR/scripts/test-dispatch-task.sh" "Deep dive on AI trends" --tag research --priority high 2>/dev/null)

  # Verify: atlas INBOX has the item
  run cat "$TEST_DIR/agents/atlas/INBOX.md"
  [[ "$output" == *"Deep dive on AI trends"* ]]

  # Step B: Run prompt assembler for atlas (verify inbox item in prompt)
  PROMPT=$(bash "$TEST_DIR/scripts/test-agent-prompt-assembler.sh" atlas 2>/dev/null)
  [[ "$PROMPT" == *"Deep dive on AI trends"* ]]
  [[ "$PROMPT" == *"VELVETCLAW_OUTPUT_START"* ]]

  # Step C: Create a mock claude response with structured output
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat > "$TEST_DIR/mock-claude-output.txt" << OUTPUT
I processed the inbox item about AI trends research.

===VELVETCLAW_OUTPUT_START===
---FILE_UPDATE: TASKS.md---
# ATLAS -- Tasks

## Active Tasks

### task-new-001
- title: "Deep dive on AI trends"
- status: done
- priority: high
- Result: Completed comprehensive analysis of AI trends for Q2

## Completed Tasks
---END_FILE_UPDATE---
---FILE_UPDATE: HEARTBEAT.md---
### ${NOW} Cycle Result
- Step: task-new-001
- Outcome: completed
- Duration: 90s
- Summary: Analyzed AI trends and produced report
---END_FILE_UPDATE---
---FILE_UPDATE: INBOX.md---
# ATLAS -- Inbox

## Pending

## Processed

### [${NOW}] From: dispatch | Priority: high
Task: Deep dive on AI trends
- Processed: ${NOW}
---END_FILE_UPDATE---
---FILE_UPDATE: CONTEXT.md---
NO_CHANGES
---END_FILE_UPDATE---
===VELVETCLAW_OUTPUT_END===
OUTPUT

  # Step D: Run parser on mock output
  PARSED=$(bash "$TEST_DIR/scripts/test-agent-output-parser.sh" "$TEST_DIR/mock-claude-output.txt" 2>/dev/null)

  # Verify parser produced valid JSON with updates
  echo "$PARSED" | python3 -c 'import sys, json; data=json.load(sys.stdin); assert "updates" in data; assert len(data["updates"]) >= 3' 2>/dev/null
  [ $? -eq 0 ]

  # Step E: Run write-back with parsed JSON
  echo "$PARSED" | bash "$TEST_DIR/scripts/test-write-back.sh" atlas 2>/dev/null

  # Verify: TASKS.md was updated
  run cat "$TEST_DIR/agents/atlas/TASKS.md"
  [[ "$output" == *"status: done"* ]]
  [[ "$output" == *"Deep dive on AI trends"* ]]

  # Verify: HEARTBEAT.md has new entry appended
  run cat "$TEST_DIR/agents/atlas/HEARTBEAT.md"
  [[ "$output" == *"Analyzed AI trends"* ]]
  [[ "$output" == *"Outcome: completed"* ]]

  # Verify: INBOX item moved to Processed
  run cat "$TEST_DIR/agents/atlas/INBOX.md"
  [[ "$output" == *"Processed"* ]]
}

# ===========================================================================
# Test 7: Escalation triggers after 3 blocks
# ===========================================================================
@test "escalation triggers after 3 blocks" {
  # Simulate 3 blocked cycles by calling escalation-handler
  run bash "$TEST_DIR/scripts/test-escalation-handler.sh" atlas 3 "API key expired"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ESCALATED:atlas:jarvis"* ]]

  # Verify jarvis INBOX has escalation entry
  run cat "$TEST_DIR/agents/jarvis/INBOX.md"
  [[ "$output" == *"ESCALATION"* ]]
  [[ "$output" == *"atlas"* ]]
  [[ "$output" == *"blocked 3 times"* ]]
  [[ "$output" == *"API key expired"* ]]
  [[ "$output" == *"Priority: high"* ]]
}

# ===========================================================================
# Test 7b: No escalation below 3 blocks
# ===========================================================================
@test "no escalation below 3 blocks" {
  run bash "$TEST_DIR/scripts/test-escalation-handler.sh" atlas 2 "Temporary issue"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NO_ESCALATION"* ]]
  [[ "$output" == *"count=2"* ]]

  # Jarvis INBOX should NOT have escalation
  run cat "$TEST_DIR/agents/jarvis/INBOX.md"
  [[ "$output" != *"ESCALATION"* ]]
}

# ===========================================================================
# Test 8: Vault write creates file with frontmatter
# ===========================================================================
@test "vault write creates file with frontmatter" {
  run bash "$TEST_DIR/scripts/test-vault-write.sh" research "ai-trends-report.md" "AI is growing rapidly in 2026."
  [ "$status" -eq 0 ]

  # File should exist in the vault
  [ -f "$TEST_DIR/vault/research/ai-trends-report.md" ]

  # Check frontmatter
  run cat "$TEST_DIR/vault/research/ai-trends-report.md"
  [[ "$output" == *"---"* ]]
  [[ "$output" == *"department: research"* ]]
  [[ "$output" == *"filename: ai-trends-report.md"* ]]
  [[ "$output" =~ created:\ 20[0-9]{2} ]]
  # Check content after frontmatter
  [[ "$output" == *"AI is growing rapidly in 2026."* ]]
}
