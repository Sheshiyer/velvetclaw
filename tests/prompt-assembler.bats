#!/usr/bin/env bats
# VelvetClaw Prompt Assembler Tests
# Tests the agent-prompt-assembler.sh script that reads agent state files
# and constructs the structured prompt for `claude -p`.
#
# Run: bats tests/prompt-assembler.bats

setup() {
  export TEST_DIR="$(mktemp -d)"
  export REPO_ROOT="$TEST_DIR"

  # Create directory structure
  mkdir -p "$TEST_DIR/agents/testbot"
  mkdir -p "$TEST_DIR/scripts"
  mkdir -p "$TEST_DIR/workflows"
  mkdir -p "$TEST_DIR/logs"

  # Create agent IDENTITY.md
  cat > "$TEST_DIR/agents/testbot/IDENTITY.md" << 'EOF'
# TESTBOT - Identity

I am TESTBOT, the test agent for VelvetClaw.
I process data efficiently and report results.
EOF

  # Create agent SOUL.md
  cat > "$TEST_DIR/agents/testbot/SOUL.md" << 'EOF'
# TESTBOT - Core Directives

1. Always verify before acting
2. Report findings accurately
3. Escalate when uncertain
EOF

  # Create agent TASKS.md
  cat > "$TEST_DIR/agents/testbot/TASKS.md" << 'EOF'
# TESTBOT -- Tasks

## Active Tasks

### task-001
- title: "Run integration tests"
- status: open
- priority: high
- depends_on: null

### task-002
- title: "Review pull requests"
- status: blocked
- priority: medium
- retry_count: 1
EOF

  # Create agent INBOX.md
  cat > "$TEST_DIR/agents/testbot/INBOX.md" << 'EOF'
# TESTBOT -- Inbox

## Pending

### [2026-02-24T10:00:00Z] From: jarvis | Priority: high
Research competitor pricing for Q2 report

## Processed
EOF

  # Create agent CONTEXT.md
  cat > "$TEST_DIR/agents/testbot/CONTEXT.md" << 'EOF'
# TESTBOT -- Context

## Rules
- Never access production databases directly
- Always use staging environment for tests

## Known Pitfalls
- [2026-02-23] API rate limiting occurs after 100 requests/minute
EOF

  # Create agent HEARTBEAT.md
  cat > "$TEST_DIR/agents/testbot/HEARTBEAT.md" << 'EOF'
# TESTBOT -- Heartbeat

### 2026-02-24T09:00:00Z Cycle Result
- Step: task-001
- Outcome: completed
- Duration: 120s
- Summary: Ran unit tests successfully
EOF

  # Create agent AGENTS.md
  cat > "$TEST_DIR/agents/testbot/AGENTS.md" << 'EOF'
# Agent Hierarchy

- JARVIS (Chief) -> delegates to all departments
- TESTBOT (Research Lead) -> reports to JARVIS
EOF

  # Create agent MANIFEST.yaml
  cat > "$TEST_DIR/agents/testbot/MANIFEST.yaml" << 'YAML'
agent:
  id: "testbot"
  tier: 2
  role: "Test Research Agent"
  reports_to: jarvis
models:
  primary: "custom-test-model-v2"
loop:
  interval: "10m"
  max_step_timeout: "4m"
  on_blocked: log_and_skip
  on_failure: log_skip_continue
  retry_blocked_after: 3
YAML

  # Create org manifest.yaml
  cat > "$TEST_DIR/manifest.yaml" << 'YAML'
org:
  hierarchy:
    chief:
      agent: jarvis
  models:
    default:
      primary: "org-default-model"
      fallback: "org-fallback-model"
YAML

  # Create workflow definition
  cat > "$TEST_DIR/workflows/agent-loop.yaml" << 'YAML'
name: agent-loop
description: Standard agent cycle workflow
steps:
  - read_inbox
  - select_step
  - execute_step
  - write_results
YAML

  # Copy the prompt assembler script
  cp "$BATS_TEST_DIRNAME/../scripts/agent-prompt-assembler.sh" "$TEST_DIR/scripts/" 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Helper: Run the prompt assembler with the test agent
run_assembler() {
  # Override REPO_ROOT by modifying the script temporarily
  # We create a wrapper that sets REPO_ROOT before running
  cat > "$TEST_DIR/scripts/run-assembler.sh" << WRAPPER
#!/usr/bin/env bash
export REPO_ROOT="$TEST_DIR"
# Redirect the assembler's SCRIPT_DIR calculation
exec bash -c '
  SCRIPT_DIR="$TEST_DIR/scripts"
  REPO_ROOT="$TEST_DIR"
  source /dev/stdin
' < <(
  # Replace the SCRIPT_DIR/REPO_ROOT calculation in the assembler
  sed \
    -e "s|SCRIPT_DIR=.*|SCRIPT_DIR=\"$TEST_DIR/scripts\"|" \
    -e "s|REPO_ROOT=.*dirname.*|REPO_ROOT=\"$TEST_DIR\"|" \
    "$TEST_DIR/scripts/agent-prompt-assembler.sh"
) "\$@"
WRAPPER
  chmod +x "$TEST_DIR/scripts/run-assembler.sh"

  # Simpler approach: create a modified copy of the assembler
  sed \
    -e "s|^SCRIPT_DIR=.*|SCRIPT_DIR=\"$TEST_DIR/scripts\"|" \
    -e "s|^REPO_ROOT=.*|REPO_ROOT=\"$TEST_DIR\"|" \
    "$TEST_DIR/scripts/agent-prompt-assembler.sh" > "$TEST_DIR/scripts/test-assembler.sh"
  chmod +x "$TEST_DIR/scripts/test-assembler.sh"

  bash "$TEST_DIR/scripts/test-assembler.sh" "$@" 2>/dev/null
}

# ===========================================================================
# Test 1: Assembles prompt with agent identity
# ===========================================================================
@test "assembles prompt with agent identity" {
  output=$(run_assembler testbot)
  [[ "$output" == *"I am TESTBOT, the test agent for VelvetClaw"* ]]
  [[ "$output" == *"IDENTITY"* ]]
}

# ===========================================================================
# Test 2: Includes TASKS.md in prompt
# ===========================================================================
@test "includes TASKS.md in prompt" {
  output=$(run_assembler testbot)
  [[ "$output" == *"Run integration tests"* ]]
  [[ "$output" == *"Review pull requests"* ]]
  [[ "$output" == *"TASKS.md"* ]]
}

# ===========================================================================
# Test 3: Includes INBOX.md pending items
# ===========================================================================
@test "includes INBOX.md pending items" {
  output=$(run_assembler testbot)
  [[ "$output" == *"Research competitor pricing for Q2 report"* ]]
  [[ "$output" == *"Pending"* ]]
  [[ "$output" == *"INBOX.md"* ]]
}

# ===========================================================================
# Test 4: Includes CONTEXT.md constraints
# ===========================================================================
@test "includes CONTEXT.md constraints" {
  output=$(run_assembler testbot)
  [[ "$output" == *"Never access production databases directly"* ]]
  [[ "$output" == *"API rate limiting"* ]]
  [[ "$output" == *"Known Pitfalls"* ]]
}

# ===========================================================================
# Test 5: Includes workflow instructions
# ===========================================================================
@test "includes workflow instructions" {
  output=$(run_assembler testbot)
  # Should include the workflow definition content
  [[ "$output" == *"agent-loop"* ]]
  [[ "$output" == *"WORKFLOW"* ]]
  # Should include the behavioral instructions
  [[ "$output" == *"PHASE 1"* ]]
  [[ "$output" == *"PHASE 2"* ]]
  [[ "$output" == *"INBOX PROCESSING"* ]]
}

# ===========================================================================
# Test 6: Includes structured output format instructions
# ===========================================================================
@test "includes structured output format instructions" {
  output=$(run_assembler testbot)
  [[ "$output" == *"VELVETCLAW_OUTPUT_START"* ]]
  [[ "$output" == *"VELVETCLAW_OUTPUT_END"* ]]
  [[ "$output" == *"FILE_UPDATE"* ]]
  [[ "$output" == *"END_FILE_UPDATE"* ]]
  [[ "$output" == *"OUTPUT FORMAT"* ]]
}

# ===========================================================================
# Test 7: Handles missing optional files gracefully
# ===========================================================================
@test "handles missing optional files gracefully" {
  # Remove MEMORY.md (which does not exist anyway) and ensure no crash
  rm -f "$TEST_DIR/agents/testbot/MEMORY.md"

  # Also remove AGENTS.md to test that missing files are handled
  rm -f "$TEST_DIR/agents/testbot/AGENTS.md"

  # The assembler should still succeed
  output=$(run_assembler testbot)
  status=$?
  [ "$status" -eq 0 ]
  # Should still contain the identity and other present files
  [[ "$output" == *"I am TESTBOT"* ]]
  [[ "$output" == *"Run integration tests"* ]]
}

# ===========================================================================
# Test 8: Reads model config from agent and org manifest
# ===========================================================================
@test "reads model config" {
  output=$(run_assembler testbot)
  # Agent-level override model should appear (custom-test-model-v2)
  [[ "$output" == *"custom-test-model-v2"* ]]
}
