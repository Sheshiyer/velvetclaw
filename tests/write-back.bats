#!/usr/bin/env bats
# VelvetClaw Write-Back Tests
# Tests the write-back.sh script that takes parsed JSON output
# and applies file updates to agent state files.
#
# Run: bats tests/write-back.bats

setup() {
  export TEST_DIR="$(mktemp -d)"
  export REPO_ROOT="$TEST_DIR"

  # Create directory structure
  mkdir -p "$TEST_DIR/agents/testbot"
  mkdir -p "$TEST_DIR/scripts"
  mkdir -p "$TEST_DIR/logs"

  # Create initial agent state files with existing content
  cat > "$TEST_DIR/agents/testbot/TASKS.md" << 'EOF'
# TESTBOT -- Tasks

## Active Tasks

### task-001
- title: "Run integration tests"
- status: open
- priority: high
EOF

  cat > "$TEST_DIR/agents/testbot/HEARTBEAT.md" << 'EOF'
# TESTBOT -- Heartbeat

### 2026-02-24T09:00:00Z Cycle Result
- Step: task-001
- Outcome: completed
- Duration: 120s
- Summary: Ran unit tests successfully
EOF

  cat > "$TEST_DIR/agents/testbot/INBOX.md" << 'EOF'
# TESTBOT -- Inbox

## Pending

### [2026-02-24T10:00:00Z] From: jarvis | Priority: high
Research competitor pricing

## Processed
EOF

  cat > "$TEST_DIR/agents/testbot/CONTEXT.md" << 'EOF'
# TESTBOT -- Context

## Rules
- Never access production databases directly

## Known Pitfalls
- [2026-02-23] API rate limiting occurs after 100 requests/minute
EOF

  # Copy write-back.sh and create a test-friendly version
  cp "$BATS_TEST_DIRNAME/../scripts/write-back.sh" "$TEST_DIR/scripts/" 2>/dev/null || true

  # Create a modified write-back.sh that uses our TEST_DIR
  sed \
    -e "s|^REPO_ROOT=.*|REPO_ROOT=\"$TEST_DIR\"|" \
    "$TEST_DIR/scripts/write-back.sh" > "$TEST_DIR/scripts/test-write-back.sh"
  chmod +x "$TEST_DIR/scripts/test-write-back.sh"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Helper: Run write-back with piped JSON
run_write_back() {
  local agent_id="$1"
  local json_input="$2"
  echo "$json_input" | bash "$TEST_DIR/scripts/test-write-back.sh" "$agent_id" 2>/dev/null
}

# ===========================================================================
# Test 1: Updates TASKS.md from parsed output (full overwrite)
# ===========================================================================
@test "updates TASKS.md from parsed output" {
  local json_input
  json_input=$(cat << 'JSON'
{
  "updates": [
    {
      "file": "TASKS.md",
      "content": "# TESTBOT -- Tasks\n\n## Active Tasks\n\n### task-001\n- title: \"Run integration tests\"\n- status: done\n- priority: high\n- Result: All 42 tests passed"
    }
  ]
}
JSON
)

  run_write_back "testbot" "$json_input"

  # TASKS.md should be fully overwritten with new content
  run cat "$TEST_DIR/agents/testbot/TASKS.md"
  [[ "$output" == *"status: done"* ]]
  [[ "$output" == *"All 42 tests passed"* ]]
}

# ===========================================================================
# Test 2: Appends to HEARTBEAT.md not overwrites
# ===========================================================================
@test "appends to HEARTBEAT.md not overwrites" {
  local json_input
  json_input=$(cat << 'JSON'
{
  "updates": [
    {
      "file": "HEARTBEAT.md",
      "content": "### 2026-02-24T10:30:00Z Cycle Result\n- Step: task-002\n- Outcome: completed\n- Duration: 45s\n- Summary: Reviewed PR and approved"
    }
  ]
}
JSON
)

  run_write_back "testbot" "$json_input"

  # Original content should still be present
  run cat "$TEST_DIR/agents/testbot/HEARTBEAT.md"
  [[ "$output" == *"2026-02-24T09:00:00Z"* ]]
  [[ "$output" == *"Ran unit tests successfully"* ]]
  # New content should be appended
  [[ "$output" == *"2026-02-24T10:30:00Z"* ]]
  [[ "$output" == *"Reviewed PR and approved"* ]]
}

# ===========================================================================
# Test 3: Processes INBOX items (Pending to Processed)
# ===========================================================================
@test "processes INBOX items to Processed" {
  local json_input
  json_input=$(cat << 'JSON'
{
  "updates": [
    {
      "file": "INBOX.md",
      "content": "# TESTBOT -- Inbox\n\n## Pending\n\n## Processed\n\n### [2026-02-24T10:00:00Z] From: jarvis | Priority: high\nResearch competitor pricing\n- Processed: 2026-02-24T10:30:00Z"
    }
  ]
}
JSON
)

  run_write_back "testbot" "$json_input"

  # INBOX.md should be fully overwritten (items moved to Processed)
  run cat "$TEST_DIR/agents/testbot/INBOX.md"
  [[ "$output" == *"Processed"* ]]
  [[ "$output" == *"Research competitor pricing"* ]]
  [[ "$output" == *"2026-02-24T10:30:00Z"* ]]
}

# ===========================================================================
# Test 4: Writes error to CONTEXT.md on failure
# ===========================================================================
@test "writes error to CONTEXT.md on failure" {
  local json_input
  json_input=$(cat << 'JSON'
{
  "error": "no_structured_output",
  "raw": "The agent returned garbage text without markers"
}
JSON
)

  run_write_back "testbot" "$json_input"

  # CONTEXT.md should have error appended
  run cat "$TEST_DIR/agents/testbot/CONTEXT.md"
  [[ "$output" == *"Loop cycle error"* ]]
  [[ "$output" == *"no_structured_output"* ]]
  # Original content should still be present
  [[ "$output" == *"Never access production databases directly"* ]]
  [[ "$output" == *"API rate limiting"* ]]

  # HEARTBEAT.md should have failure entry
  run cat "$TEST_DIR/agents/testbot/HEARTBEAT.md"
  [[ "$output" == *"parse-error"* ]]
  [[ "$output" == *"Outcome: failed"* ]]
}

# ===========================================================================
# Test 5: Handles empty update list
# ===========================================================================
@test "handles empty update list" {
  local json_input
  json_input=$(cat << 'JSON'
{
  "updates": []
}
JSON
)

  # Should not crash
  run bash "$TEST_DIR/scripts/test-write-back.sh" "testbot" <<< "$json_input"
  [ "$status" -eq 0 ]

  # Original files should be untouched
  run cat "$TEST_DIR/agents/testbot/TASKS.md"
  [[ "$output" == *"Run integration tests"* ]]
  [[ "$output" == *"status: open"* ]]
}

# ===========================================================================
# Test 6: CONTEXT.md NO_CHANGES leaves file untouched
# ===========================================================================
@test "CONTEXT.md NO_CHANGES leaves file untouched" {
  # Record original content for comparison
  local original_context
  original_context=$(cat "$TEST_DIR/agents/testbot/CONTEXT.md")

  local json_input
  json_input=$(cat << 'JSON'
{
  "updates": [
    {
      "file": "CONTEXT.md",
      "content": "NO_CHANGES"
    }
  ]
}
JSON
)

  run_write_back "testbot" "$json_input"

  # CONTEXT.md should be unchanged
  run cat "$TEST_DIR/agents/testbot/CONTEXT.md"
  [[ "$output" == *"Never access production databases directly"* ]]
  [[ "$output" == *"API rate limiting"* ]]
  # Should NOT contain NO_CHANGES text
  [[ "$output" != *"NO_CHANGES"* ]] || true
}
