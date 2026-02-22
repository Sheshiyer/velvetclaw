---
primitive: loop-config
description: "Defines the autonomous loop cycle for an agent. The agent runs in short cron-triggered cycles rather than single long sessions."
fields:
  enabled:
    type: boolean
    required: true
    default: true
    description: "Whether the loop is active for this agent"
  interval:
    type: string
    required: true
    description: "Cron cycle interval (e.g., 5m, 10m, 15m). Tier 1 = 5m, Tier 2 leads = 10m, Tier 2 members = 15m"
  max_step_timeout:
    type: string
    default: "10m"
    description: "Maximum time per step before the agent must write result and yield"
  on_blocked:
    type: string
    required: true
    default: "log_and_skip"
    enum: [log_and_skip, escalate, retry_next_cycle, halt]
    description: "What happens when a step is blocked"
  on_failure:
    type: string
    required: true
    default: "log_skip_continue"
    enum: [log_skip_continue, escalate_and_skip, retry_once, halt]
    description: "What happens when a step fails with an error"
  retry_blocked_after:
    type: integer
    default: 3
    description: "Number of cycles to wait before retrying a blocked step"
  reads:
    type: string[]
    required: true
    default:
      - TASKS.md
      - CONTEXT.md
      - HEARTBEAT.md
    description: "Files the agent reads at the start of each cycle"
  writes:
    type: string[]
    required: true
    default:
      - TASKS.md
      - HEARTBEAT.md
    description: "Files the agent writes results to after each cycle"
  escalation:
    type: string
    description: "Agent ID to escalate to when blocked beyond retry threshold"
  cycle_log:
    type: boolean
    default: true
    description: "Whether to append cycle results to HEARTBEAT.md"
---

# Loop Config Primitive

Each agent runs in autonomous short cycles triggered by cron. This is NOT a single long-running session — it is a series of short, focused runs where the agent:

1. Reads `TASKS.md` → picks the next incomplete step
2. Reads `CONTEXT.md` → knows the rules, constraints, and past mistakes
3. Reads `HEARTBEAT.md` → knows its own cycle history and health
4. Works on exactly ONE step
5. Writes the result back to `TASKS.md` ("step N done" or "step N blocked: reason")
6. Updates `HEARTBEAT.md` with cycle timestamp and outcome
7. If blocked → logs WHY, skips to next step, retries after `retry_blocked_after` cycles
8. If error → logs error as context for next run, moves on

The failure becomes context for the next run. Single prompt = fragile. Loop agent = resilient.

## Hierarchy-Aware Intervals

| Tier | Role | Default Interval | Rationale |
|------|------|-----------------|-----------|
| 1 | Chief (JARVIS) | 5m | Fastest cycle — orchestration and delegation |
| 2 | Department Leads | 10m | Medium cycle — coordination and execution |
| 2 | Department Members | 15m | Standard cycle — focused task execution |

## Cycle Math

- 15-minute cycles over 8 hours = 32 runs
- 10-minute cycles over 8 hours = 48 runs
- 5-minute cycles over 8 hours = 96 runs

Each run reads what the last one did, learns from its failures, and pushes forward.
