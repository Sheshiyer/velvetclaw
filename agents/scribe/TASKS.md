# SCRIBE — Tasks

Step-by-step work queue. The loop reads this file each cycle to pick the next incomplete step.

## Active Tasks

_No tasks yet. Tasks are created by the agent's lead, by JARVIS, or by the weekly evolution cycle._

## Task Format

Each task follows this structure:
- **Step N**: [description]
  - Status: open | in-progress | blocked | done | failed
  - Priority: critical | high | medium | low
  - Blocked reason: (if blocked — WHY specifically)
  - Retry count: 0
  - Depends on: (step IDs if any)
  - Result: (written after completion or failure)

## Completed Tasks

_History of completed tasks moves here._
