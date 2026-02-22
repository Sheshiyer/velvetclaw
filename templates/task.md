---
primitive: task
fields:
  status:
    type: string
    required: true
    default: open
    enum: [open, in-progress, blocked, done, cancelled]
  priority:
    type: string
    required: true
    default: medium
    enum: [critical, high, medium, low]
  owner:
    type: string
    description: "Agent ID responsible for this task"
  department:
    type: string
    enum: [research, content, development, design, user-success, product]
  project:
    type: string
  due:
    type: date
  tags:
    type: string[]
  estimate:
    type: string
    description: "Time estimate (e.g., 30m, 2h, 1d)"
  parent:
    type: string
    description: "Parent task ID for subtask trees"
  depends_on:
    type: string[]
    description: "Task IDs that must complete before this task"
  assigned_by:
    type: string
    description: "Agent or human who created/assigned the task"
  transition_ledger:
    type: object[]
    description: "Status change history with timestamps and reasons"
---
