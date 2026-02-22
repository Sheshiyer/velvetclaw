---
primitive: project
fields:
  status:
    type: string
    required: true
    default: active
    enum: [planning, active, paused, completed, archived]
  department:
    type: string
    required: true
    enum: [research, content, development, design, user-success, product, cross-functional]
  lead:
    type: string
    description: "Agent ID leading the project"
  members:
    type: string[]
    description: "Agent IDs involved in the project"
  priority:
    type: string
    default: medium
    enum: [critical, high, medium, low]
  started:
    type: date
  deadline:
    type: date
  tags:
    type: string[]
  objectives:
    type: string[]
    description: "Key objectives for this project"
  metrics:
    type: object
    description: "Success metrics and KPIs"
---
