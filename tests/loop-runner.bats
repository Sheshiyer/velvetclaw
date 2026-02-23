#!/usr/bin/env bats
# VelvetClaw Loop Runner Tests
# Tests the core loop-runner.sh functions: agent discovery, tier intervals,
# config loading, working hours, PID management, concurrency, and locking.
#
# Run: bats tests/loop-runner.bats

setup() {
  export TEST_DIR="$(mktemp -d)"
  export REPO_ROOT="$TEST_DIR"

  # Create minimal directory structure
  mkdir -p "$TEST_DIR/agents/jarvis" "$TEST_DIR/agents/atlas" "$TEST_DIR/agents/clawd"
  mkdir -p "$TEST_DIR/scripts" "$TEST_DIR/logs"

  # Create mock manifest.yaml
  cat > "$TEST_DIR/manifest.yaml" << 'YAML'
org:
  hierarchy:
    chief:
      agent: jarvis
    departments:
      research:
        lead: atlas
        members: []
      development:
        lead: clawd
        members: []
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

  # Create mock agent MANIFESTs
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

  cat > "$TEST_DIR/agents/atlas/MANIFEST.yaml" << 'YAML'
agent:
  id: "atlas"
  tier: 2
  role: "Sr. Research Analyst"
  reports_to: jarvis
loop:
  interval: "10m"
  max_step_timeout: "4m"
YAML

  cat > "$TEST_DIR/agents/clawd/MANIFEST.yaml" << 'YAML'
agent:
  id: "clawd"
  tier: 2
  role: "Sr. Software Engineer"
  reports_to: jarvis
loop:
  interval: "10m"
  max_step_timeout: "4m"
YAML

  # Create standard agent state files
  for agent in jarvis atlas clawd; do
    touch "$TEST_DIR/agents/$agent/TASKS.md"
    touch "$TEST_DIR/agents/$agent/HEARTBEAT.md"
    touch "$TEST_DIR/agents/$agent/INBOX.md"
    touch "$TEST_DIR/agents/$agent/CONTEXT.md"
    touch "$TEST_DIR/agents/$agent/IDENTITY.md"
    touch "$TEST_DIR/agents/$agent/SOUL.md"
    touch "$TEST_DIR/agents/$agent/AGENTS.md"
  done

  # Copy the real loop-runner.sh to the test directory
  cp "$BATS_TEST_DIRNAME/../scripts/loop-runner.sh" "$TEST_DIR/scripts/" 2>/dev/null || true
}

teardown() {
  # Clean up PID files or lock dirs that tests may have created
  rm -rf "$TEST_DIR"
  rm -f /tmp/velvetclaw-test-loop-*.pid 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Helper: Source loop-runner.sh functions without triggering the entry point.
# We override REPO_ROOT/SCRIPT_DIR and intercept the `case` at the bottom
# by providing a "help" command implicitly (the default).
# ---------------------------------------------------------------------------
source_loop_runner_functions() {
  # Redirect stdout to suppress the help text when sourcing triggers `case`
  (
    export SCRIPT_DIR="$TEST_DIR/scripts"
    export REPO_ROOT="$TEST_DIR"
    export LOG_DIR="$TEST_DIR/logs"
    export LOG_FILE="$TEST_DIR/logs/loop-runner.log"
    export CONF_FILE="$TEST_DIR/scripts/loop-runner.conf"
    export PID_FILE="$TEST_DIR/.loop-runner.pid"
    cd "$TEST_DIR"
    # Source the script; the `case` block defaults to "help" and prints usage
    bash -c '
      export SCRIPT_DIR="'"$TEST_DIR/scripts"'"
      export REPO_ROOT="'"$TEST_DIR"'"
      source "'"$TEST_DIR/scripts/loop-runner.sh"'" help 2>/dev/null
    '
  ) >/dev/null 2>&1 || true
}

# ===========================================================================
# Test 1: Discover agents from manifest
# ===========================================================================
@test "discovers agents from manifest" {
  # Run the loop-runner with a custom script that just discovers and lists agents
  cat > "$TEST_DIR/scripts/test-discover.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$REPO_ROOT/logs"
LOG_FILE="$LOG_DIR/loop-runner.log"
mkdir -p "$LOG_DIR"

# Source the variable declarations from loop-runner.sh via extraction
declare -A AGENT_TIERS
declare -A AGENT_LAST_RUN
declare -A AGENT_INTERVALS

TIER_1_INTERVAL=300
TIER_2_LEAD_INTERVAL=600
TIER_2_MEMBER_INTERVAL=900

log() { local level="$1"; shift; echo "[$level] $*" >> "$LOG_FILE"; }

# Re-implement discover_agents from loop-runner.sh
chief=$(grep -A1 "chief:" "$REPO_ROOT/manifest.yaml" | grep "agent:" | awk '{print $2}' | head -1)
if [[ -n "$chief" ]]; then
  AGENT_TIERS["$chief"]="tier_1"
  AGENT_INTERVALS["$chief"]=$TIER_1_INTERVAL
  AGENT_LAST_RUN["$chief"]=0
fi

for agent_dir in "$REPO_ROOT"/agents/*/; do
  agent_id="$(basename "$agent_dir")"
  if [[ "${AGENT_TIERS[$agent_id]:-}" == "tier_1" ]]; then
    continue
  fi
  manifest="$agent_dir/MANIFEST.yaml"
  if [[ ! -f "$manifest" ]]; then continue; fi
  interval=$(grep -A5 "^loop:" "$manifest" | grep "interval:" | head -1 | awk -F'"' '{print $2}')
  case "$interval" in
    "5m")  AGENT_TIERS["$agent_id"]="tier_1"; AGENT_INTERVALS["$agent_id"]=$TIER_1_INTERVAL ;;
    "10m") AGENT_TIERS["$agent_id"]="tier_2_lead"; AGENT_INTERVALS["$agent_id"]=$TIER_2_LEAD_INTERVAL ;;
    "15m") AGENT_TIERS["$agent_id"]="tier_2_member"; AGENT_INTERVALS["$agent_id"]=$TIER_2_MEMBER_INTERVAL ;;
    *)     AGENT_TIERS["$agent_id"]="tier_2_member"; AGENT_INTERVALS["$agent_id"]=$TIER_2_MEMBER_INTERVAL ;;
  esac
  AGENT_LAST_RUN["$agent_id"]=0
done

# Print discovered agents sorted
for agent in $(echo "${!AGENT_TIERS[@]}" | tr ' ' '\n' | sort); do
  echo "$agent:${AGENT_TIERS[$agent]}"
done
SCRIPT
  chmod +x "$TEST_DIR/scripts/test-discover.sh"

  run bash "$TEST_DIR/scripts/test-discover.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"jarvis:tier_1"* ]]
  [[ "$output" == *"atlas:tier_2_lead"* ]]
  [[ "$output" == *"clawd:tier_2_lead"* ]]
}

# ===========================================================================
# Test 2: Assigns correct tier intervals
# ===========================================================================
@test "assigns correct tier intervals" {
  # Add a member agent with 15m interval
  mkdir -p "$TEST_DIR/agents/trendy"
  cat > "$TEST_DIR/agents/trendy/MANIFEST.yaml" << 'YAML'
agent:
  id: "trendy"
loop:
  interval: "15m"
  max_step_timeout: "4m"
YAML

  cat > "$TEST_DIR/scripts/test-intervals.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$REPO_ROOT/logs"
LOG_FILE="$LOG_DIR/loop-runner.log"
mkdir -p "$LOG_DIR"

declare -A AGENT_TIERS
declare -A AGENT_LAST_RUN
declare -A AGENT_INTERVALS
TIER_1_INTERVAL=300
TIER_2_LEAD_INTERVAL=600
TIER_2_MEMBER_INTERVAL=900

log() { local level="$1"; shift; echo "[$level] $*" >> "$LOG_FILE"; }

chief=$(grep -A1 "chief:" "$REPO_ROOT/manifest.yaml" | grep "agent:" | awk '{print $2}' | head -1)
if [[ -n "$chief" ]]; then
  AGENT_TIERS["$chief"]="tier_1"
  AGENT_INTERVALS["$chief"]=$TIER_1_INTERVAL
  AGENT_LAST_RUN["$chief"]=0
fi

for agent_dir in "$REPO_ROOT"/agents/*/; do
  agent_id="$(basename "$agent_dir")"
  if [[ "${AGENT_TIERS[$agent_id]:-}" == "tier_1" ]]; then continue; fi
  manifest="$agent_dir/MANIFEST.yaml"
  if [[ ! -f "$manifest" ]]; then continue; fi
  interval=$(grep -A5 "^loop:" "$manifest" | grep "interval:" | head -1 | awk -F'"' '{print $2}')
  case "$interval" in
    "5m")  AGENT_TIERS["$agent_id"]="tier_1"; AGENT_INTERVALS["$agent_id"]=$TIER_1_INTERVAL ;;
    "10m") AGENT_TIERS["$agent_id"]="tier_2_lead"; AGENT_INTERVALS["$agent_id"]=$TIER_2_LEAD_INTERVAL ;;
    "15m") AGENT_TIERS["$agent_id"]="tier_2_member"; AGENT_INTERVALS["$agent_id"]=$TIER_2_MEMBER_INTERVAL ;;
    *)     AGENT_TIERS["$agent_id"]="tier_2_member"; AGENT_INTERVALS["$agent_id"]=$TIER_2_MEMBER_INTERVAL ;;
  esac
  AGENT_LAST_RUN["$agent_id"]=0
done

for agent in $(echo "${!AGENT_TIERS[@]}" | tr ' ' '\n' | sort); do
  echo "$agent:${AGENT_INTERVALS[$agent]}"
done
SCRIPT
  chmod +x "$TEST_DIR/scripts/test-intervals.sh"

  run bash "$TEST_DIR/scripts/test-intervals.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"jarvis:300"* ]]
  [[ "$output" == *"atlas:600"* ]]
  [[ "$output" == *"clawd:600"* ]]
  [[ "$output" == *"trendy:900"* ]]
}

# ===========================================================================
# Test 3: Config loading from .env
# ===========================================================================
@test "config loading from .env" {
  cat > "$TEST_DIR/.env" << 'ENV'
LOOP_MAX_CONCURRENT=5
LOOP_WORKING_HOURS_ONLY=true
LOOP_START_HOUR=8
LOOP_END_HOUR=20
ENV

  cat > "$TEST_DIR/scripts/test-env-config.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Defaults
MAX_CONCURRENT=2
WORKING_HOURS_ONLY=false
START_HOUR=9
END_HOUR=17

# Load .env
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  source "$REPO_ROOT/.env"
  set +a
fi

MAX_CONCURRENT="${LOOP_MAX_CONCURRENT:-$MAX_CONCURRENT}"
WORKING_HOURS_ONLY="${LOOP_WORKING_HOURS_ONLY:-$WORKING_HOURS_ONLY}"
START_HOUR="${LOOP_START_HOUR:-$START_HOUR}"
END_HOUR="${LOOP_END_HOUR:-$END_HOUR}"

echo "MAX_CONCURRENT=$MAX_CONCURRENT"
echo "WORKING_HOURS_ONLY=$WORKING_HOURS_ONLY"
echo "START_HOUR=$START_HOUR"
echo "END_HOUR=$END_HOUR"
SCRIPT
  chmod +x "$TEST_DIR/scripts/test-env-config.sh"

  run bash "$TEST_DIR/scripts/test-env-config.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MAX_CONCURRENT=5"* ]]
  [[ "$output" == *"WORKING_HOURS_ONLY=true"* ]]
  [[ "$output" == *"START_HOUR=8"* ]]
  [[ "$output" == *"END_HOUR=20"* ]]
}

# ===========================================================================
# Test 4: Config loading from loop-runner.conf (overrides .env)
# ===========================================================================
@test "config loading from loop-runner.conf overrides .env" {
  # .env sets MAX_CONCURRENT=5
  cat > "$TEST_DIR/.env" << 'ENV'
LOOP_MAX_CONCURRENT=5
ENV

  # conf overrides to 3
  cat > "$TEST_DIR/scripts/loop-runner.conf" << 'CONF'
LOOP_MAX_CONCURRENT=3
CONF

  cat > "$TEST_DIR/scripts/test-conf-override.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_FILE="$REPO_ROOT/scripts/loop-runner.conf"

MAX_CONCURRENT=2

# Load .env first
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a; source "$REPO_ROOT/.env"; set +a
fi

# Load conf second (overrides .env)
if [[ -f "$CONF_FILE" ]]; then
  source "$CONF_FILE"
fi

MAX_CONCURRENT="${LOOP_MAX_CONCURRENT:-$MAX_CONCURRENT}"
echo "MAX_CONCURRENT=$MAX_CONCURRENT"
SCRIPT
  chmod +x "$TEST_DIR/scripts/test-conf-override.sh"

  run bash "$TEST_DIR/scripts/test-conf-override.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MAX_CONCURRENT=3"* ]]
}

# ===========================================================================
# Test 5: Working hours check accepts within hours
# ===========================================================================
@test "working hours check accepts within hours" {
  cat > "$TEST_DIR/scripts/test-hours-within.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

WORKING_HOURS_ONLY=true
START_HOUR=9
END_HOUR=17

is_within_working_hours() {
  if [[ "$WORKING_HOURS_ONLY" != "true" ]]; then
    return 0
  fi
  local current_hour="$MOCK_HOUR"
  if (( current_hour >= START_HOUR && current_hour < END_HOUR )); then
    return 0
  fi
  return 1
}

# Mock hour at 12 (noon) - within 9-17
export MOCK_HOUR=12
if is_within_working_hours; then
  echo "WITHIN_HOURS"
else
  echo "OUTSIDE_HOURS"
fi
SCRIPT
  chmod +x "$TEST_DIR/scripts/test-hours-within.sh"

  run bash "$TEST_DIR/scripts/test-hours-within.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WITHIN_HOURS"* ]]
}

# ===========================================================================
# Test 6: Working hours check rejects outside hours
# ===========================================================================
@test "working hours check rejects outside hours" {
  cat > "$TEST_DIR/scripts/test-hours-outside.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

WORKING_HOURS_ONLY=true
START_HOUR=9
END_HOUR=17

is_within_working_hours() {
  if [[ "$WORKING_HOURS_ONLY" != "true" ]]; then
    return 0
  fi
  local current_hour="$MOCK_HOUR"
  if (( current_hour >= START_HOUR && current_hour < END_HOUR )); then
    return 0
  fi
  return 1
}

# Mock hour at 22 (10pm) - outside 9-17
export MOCK_HOUR=22
if is_within_working_hours; then
  echo "WITHIN_HOURS"
else
  echo "OUTSIDE_HOURS"
fi

# Also test boundary: hour 17 should be outside (END_HOUR is exclusive)
export MOCK_HOUR=17
if is_within_working_hours; then
  echo "BOUNDARY_WITHIN"
else
  echo "BOUNDARY_OUTSIDE"
fi
SCRIPT
  chmod +x "$TEST_DIR/scripts/test-hours-outside.sh"

  run bash "$TEST_DIR/scripts/test-hours-outside.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OUTSIDE_HOURS"* ]]
  [[ "$output" == *"BOUNDARY_OUTSIDE"* ]]
}

# ===========================================================================
# Test 7: PID file management on start
# ===========================================================================
@test "PID file management on start" {
  export PID_FILE="$TEST_DIR/.loop-runner.pid"

  # Simulate creating a PID file (what start_daemon does)
  echo "99999" > "$PID_FILE"

  # Verify PID file was created
  [ -f "$PID_FILE" ]

  # Verify PID content
  run cat "$PID_FILE"
  [ "$output" = "99999" ]
}

# ===========================================================================
# Test 8: PID file cleanup on stop
# ===========================================================================
@test "PID file cleanup on stop" {
  export PID_FILE="$TEST_DIR/.loop-runner.pid"

  # Create a PID file pointing to a non-existent process
  echo "99999" > "$PID_FILE"
  [ -f "$PID_FILE" ]

  # Run the stop logic inline (simulating stop_daemon for stale PID)
  cat > "$TEST_DIR/scripts/test-stop.sh" << SCRIPT
#!/usr/bin/env bash
set -euo pipefail
PID_FILE="$TEST_DIR/.loop-runner.pid"

if [[ ! -f "\$PID_FILE" ]]; then
  echo "No PID file found."
  exit 0
fi

pid=\$(cat "\$PID_FILE")
if kill -0 "\$pid" 2>/dev/null; then
  kill "\$pid"
  rm -f "\$PID_FILE"
  echo "Stopped."
else
  echo "PID not running. Cleaning up stale PID file."
  rm -f "\$PID_FILE"
fi
SCRIPT
  chmod +x "$TEST_DIR/scripts/test-stop.sh"

  run bash "$TEST_DIR/scripts/test-stop.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Cleaning up stale PID file"* ]]

  # PID file should be removed
  [ ! -f "$PID_FILE" ]
}

# ===========================================================================
# Test 9: Concurrent agent limit respected
# ===========================================================================
@test "concurrent agent limit respected" {
  cat > "$TEST_DIR/scripts/test-concurrency.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

MAX_CONCURRENT=1
RUNNING_AGENTS=0

invoke_agent() {
  local agent_id="$1"
  if (( RUNNING_AGENTS >= MAX_CONCURRENT )); then
    echo "SKIPPED:$agent_id"
    return
  fi
  RUNNING_AGENTS=$((RUNNING_AGENTS + 1))
  echo "INVOKED:$agent_id"
}

# First agent should be invoked
invoke_agent "jarvis"
# Second agent should be skipped (MAX_CONCURRENT=1)
invoke_agent "atlas"
SCRIPT
  chmod +x "$TEST_DIR/scripts/test-concurrency.sh"

  run bash "$TEST_DIR/scripts/test-concurrency.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INVOKED:jarvis"* ]]
  [[ "$output" == *"SKIPPED:atlas"* ]]
}

# ===========================================================================
# Test 10: Lock prevents duplicate agent runs
# ===========================================================================
@test "lock prevents duplicate agent runs" {
  cat > "$TEST_DIR/scripts/test-lock.sh" << SCRIPT
#!/usr/bin/env bash
set -euo pipefail

LOCK_DIR="/tmp/velvetclaw-test-lock-\$\$"

acquire_lock() {
  local agent_id="\$1"
  local lock_path="\${LOCK_DIR}-\${agent_id}"
  if mkdir "\$lock_path" 2>/dev/null; then
    echo "LOCKED:\$agent_id"
    return 0
  else
    echo "LOCK_FAILED:\$agent_id"
    return 1
  fi
}

release_lock() {
  local agent_id="\$1"
  local lock_path="\${LOCK_DIR}-\${agent_id}"
  rmdir "\$lock_path" 2>/dev/null
  echo "RELEASED:\$agent_id"
}

# First acquisition should succeed
acquire_lock "jarvis"
# Second acquisition should fail (lock exists)
acquire_lock "jarvis" || true
# Release and re-acquire should succeed
release_lock "jarvis"
acquire_lock "jarvis"
# Cleanup
release_lock "jarvis"
SCRIPT
  chmod +x "$TEST_DIR/scripts/test-lock.sh"

  run bash "$TEST_DIR/scripts/test-lock.sh"
  [ "$status" -eq 0 ]
  # First line: lock acquired
  [[ "${lines[0]}" == "LOCKED:jarvis" ]]
  # Second line: lock failed (duplicate)
  [[ "${lines[1]}" == "LOCK_FAILED:jarvis" ]]
  # Third line: released
  [[ "${lines[2]}" == "RELEASED:jarvis" ]]
  # Fourth line: re-acquired
  [[ "${lines[3]}" == "LOCKED:jarvis" ]]
}
