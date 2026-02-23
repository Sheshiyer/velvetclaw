#!/usr/bin/env bash
# VelvetClaw Agent Prompt Assembler
# Builds the structured prompt that gets piped to `claude -p` for a given agent.
#
# Reads the agent's identity, state files, manifest, and workflow definition
# to construct a prompt that makes the agent follow the agent-loop.yaml cycle.
#
# Usage:
#   ./scripts/agent-prompt-assembler.sh <agent_id>
#
# Output: prompt text on stdout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# ─── Logging (to stderr so stdout stays clean for the prompt) ───

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [prompt-assembler] [$level] $*" >&2
}

# ─── Validate args ───

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <agent_id>" >&2
  exit 1
fi

AGENT_ID="$1"
AGENT_DIR="$REPO_ROOT/agents/$AGENT_ID"

if [[ ! -d "$AGENT_DIR" ]]; then
  log "error" "Agent directory not found: $AGENT_DIR"
  exit 1
fi

# ─── Read file safely (returns empty string if missing) ───

read_file() {
  local filepath="$1"
  if [[ -f "$filepath" ]]; then
    cat "$filepath"
  else
    log "warn" "File not found: $filepath"
    echo "(file not found)"
  fi
}

# ─── Read agent manifest values ───

AGENT_MANIFEST="$AGENT_DIR/MANIFEST.yaml"

agent_role=""
agent_reports_to=""
agent_tier=""
agent_max_timeout="4m"
agent_on_blocked="log_and_skip"
agent_on_failure="log_skip_continue"
agent_retry_blocked_after="3"

if [[ -f "$AGENT_MANIFEST" ]]; then
  agent_role=$(grep "role:" "$AGENT_MANIFEST" | head -1 | sed 's/.*role: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs)
  agent_reports_to=$(grep "reports_to:" "$AGENT_MANIFEST" | head -1 | awk '{print $2}')
  agent_tier=$(grep "tier:" "$AGENT_MANIFEST" | head -1 | awk '{print $2}')

  # Loop config
  local_timeout=$(grep -A10 "^loop:" "$AGENT_MANIFEST" | grep "max_step_timeout:" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs)
  if [[ -n "$local_timeout" ]]; then
    agent_max_timeout="$local_timeout"
  fi

  local_on_blocked=$(grep -A10 "^loop:" "$AGENT_MANIFEST" | grep "on_blocked:" | head -1 | awk '{print $2}')
  if [[ -n "$local_on_blocked" ]]; then
    agent_on_blocked="$local_on_blocked"
  fi

  local_on_failure=$(grep -A10 "^loop:" "$AGENT_MANIFEST" | grep "on_failure:" | head -1 | awk '{print $2}')
  if [[ -n "$local_on_failure" ]]; then
    agent_on_failure="$local_on_failure"
  fi

  local_retry=$(grep -A10 "^loop:" "$AGENT_MANIFEST" | grep "retry_blocked_after:" | head -1 | awk '{print $2}')
  if [[ -n "$local_retry" ]]; then
    agent_retry_blocked_after="$local_retry"
  fi
fi

# ─── Read model config from org manifest ───

ORG_MANIFEST="$REPO_ROOT/manifest.yaml"
primary_model="claude-sonnet-4-20250514"
fallback_model=""

if [[ -f "$ORG_MANIFEST" ]]; then
  pm=$(grep -A3 "default:" "$ORG_MANIFEST" | grep "primary:" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs)
  if [[ -n "$pm" ]]; then
    primary_model="$pm"
  fi
  fm=$(grep -A3 "default:" "$ORG_MANIFEST" | grep "fallback:" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs)
  if [[ -n "$fm" ]]; then
    fallback_model="$fm"
  fi
fi

# Agent-level model override
if [[ -f "$AGENT_MANIFEST" ]]; then
  apm=$(grep -A3 "^models:" "$AGENT_MANIFEST" | grep "primary:" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs)
  if [[ -n "$apm" ]]; then
    primary_model="$apm"
  fi
fi

# ─── Read all agent state files ───

IDENTITY=$(read_file "$AGENT_DIR/IDENTITY.md")
SOUL=$(read_file "$AGENT_DIR/SOUL.md")
TASKS=$(read_file "$AGENT_DIR/TASKS.md")
INBOX=$(read_file "$AGENT_DIR/INBOX.md")
CONTEXT=$(read_file "$AGENT_DIR/CONTEXT.md")
HEARTBEAT=$(read_file "$AGENT_DIR/HEARTBEAT.md")
AGENTS=$(read_file "$AGENT_DIR/AGENTS.md")

# ─── Read workflow definition ───

WORKFLOW=$(read_file "$REPO_ROOT/workflows/agent-loop.yaml")

# ─── Current timestamp ───

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ─── Assemble the prompt ───

log "info" "Assembling prompt for agent: $AGENT_ID (role: $agent_role, tier: $agent_tier)"

cat <<PROMPT_EOF
You are ${AGENT_ID}, a VelvetClaw autonomous agent running a scheduled loop cycle.

Current time: ${NOW}
Model: ${primary_model}

=============================================
IDENTITY
=============================================
${IDENTITY}

=============================================
CORE DIRECTIVES (SOUL)
=============================================
${SOUL}

=============================================
AGENT HIERARCHY & AWARENESS
=============================================
${AGENTS}

=============================================
LOOP CYCLE CONFIGURATION
=============================================
- Agent ID: ${AGENT_ID}
- Role: ${agent_role}
- Tier: ${agent_tier}
- Reports to: ${agent_reports_to}
- Max step timeout: ${agent_max_timeout}
- On blocked: ${agent_on_blocked}
- On failure: ${agent_on_failure}
- Retry blocked after: ${agent_retry_blocked_after} cycles

=============================================
WORKFLOW DEFINITION
=============================================
${WORKFLOW}

=============================================
CURRENT STATE FILES
=============================================

--- INBOX.md (check FIRST) ---
${INBOX}

--- TASKS.md (work queue) ---
${TASKS}

--- CONTEXT.md (rules, constraints, pitfalls) ---
${CONTEXT}

--- HEARTBEAT.md (cycle history) ---
${HEARTBEAT}

=============================================
YOUR INSTRUCTIONS FOR THIS CYCLE
=============================================

You are running ONE autonomous loop cycle. Follow these steps EXACTLY:

PHASE 1 — INBOX PROCESSING
1. Read the INBOX.md content above.
2. Look under "## Pending" for any new items.
3. For each pending item:
   a. Create a new step in TASKS.md with the item's priority and tags.
   b. Mark the inbox item as processed (move to "## Processed" with timestamp ${NOW}).
4. If there are 10+ pending items, add a note to escalate to ${agent_reports_to} for triage.
5. Critical inbox items override current step selection.

PHASE 2 — STEP SELECTION
1. Look at TASKS.md under "## Active Tasks".
2. Find the first step with status "open" or "in-progress", ordered by priority: critical > high > medium > low.
3. Skip any step with status "blocked" whose retry_count < ${agent_retry_blocked_after}.
4. Retry any "blocked" step whose retry_count >= ${agent_retry_blocked_after}.
5. Respect depends_on: skip steps whose dependencies have not completed.
6. If no actionable steps exist, report idle.

PHASE 3 — EXECUTE ONE STEP
1. Work on ONLY the selected step. Do NOT attempt multiple steps.
2. Read CONTEXT.md constraints before acting — honor all rules and past pitfalls.
3. If the step requires delegating to a subordinate, create a task in their INBOX.md instead.
4. If the step is not your responsibility per the hierarchy, escalate upward.
5. Apply your identity and soul directives to HOW you approach the work.

PHASE 4 — WRITE RESULTS
Based on the outcome of your step execution:

ON SUCCESS:
- Update the step status in TASKS.md to "done" with a Result description.
- Record the cycle in HEARTBEAT.md.
- If the step produced deliverables, note the vault path.

ON BLOCKED:
- Update the step status to "blocked" with a specific blocked reason.
- Increment the step's retry_count.
- Log the blocker in CONTEXT.md under "## Known Pitfalls".

ON FAILURE:
- Update the step status to "failed" with error details.
- The error becomes context — add it to CONTEXT.md under "## Known Pitfalls".
- If the same step has failed 3+ times, add an escalation note for ${agent_reports_to}.

ON IDLE (no steps to work):
- Report idle status. Do not invent work.

=============================================
OUTPUT FORMAT — MANDATORY
=============================================

You MUST output your results in this EXACT structured format.
Everything between the START and END markers will be parsed programmatically.
Do NOT include any text outside these markers except a brief summary before them.

Brief cycle summary: [1-2 sentences about what you did this cycle]

===VELVETCLAW_OUTPUT_START===
---FILE_UPDATE: TASKS.md---
[Write the COMPLETE updated TASKS.md content here.
Include ALL sections: Active Tasks, Task Format, Completed Tasks.
Update the step you worked on. Keep all other steps as-is.]
---END_FILE_UPDATE---
---FILE_UPDATE: HEARTBEAT.md---
### ${NOW} Cycle Result
- Step: [step_id or "idle"]
- Outcome: [completed|blocked|failed|idle]
- Duration: [estimated seconds]
- Summary: [1 sentence of what happened]
---END_FILE_UPDATE---
---FILE_UPDATE: INBOX.md---
[Write the COMPLETE updated INBOX.md content here.
Move any processed items from Pending to Processed with timestamps.
If no changes needed, reproduce the current content exactly.]
---END_FILE_UPDATE---
---FILE_UPDATE: CONTEXT.md---
[ONLY if you have new pitfalls or learnings to add.
Write ONLY the new entries to append, prefixed with "- [${NOW}]".
If nothing to add, write: NO_CHANGES]
---END_FILE_UPDATE---
===VELVETCLAW_OUTPUT_END===

CRITICAL RULES:
- Output MUST contain the ===VELVETCLAW_OUTPUT_START=== and ===VELVETCLAW_OUTPUT_END=== markers.
- Each file update MUST be between ---FILE_UPDATE: {filename}--- and ---END_FILE_UPDATE--- markers.
- TASKS.md update must contain the FULL file content (not just changes).
- HEARTBEAT.md update should contain ONLY the new entry to append.
- INBOX.md update must contain the FULL file content (not just changes).
- CONTEXT.md update contains ONLY new lines to append, or "NO_CHANGES".
- Do NOT wrap the output in markdown code fences.
- Do NOT add commentary inside the structured output section.
PROMPT_EOF

log "info" "Prompt assembled for $AGENT_ID"
