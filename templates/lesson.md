---
primitive: lesson
fields:
  category:
    type: string
    required: true
    enum: [mistake, optimization, pattern, insight, warning]
  learned_by:
    type: string
    description: "Agent ID that learned this lesson"
  department:
    type: string
    enum: [research, content, development, design, user-success, product, org-wide]
  context:
    type: string
    description: "Situation where this lesson was learned"
  lesson:
    type: string
    required: true
    description: "The key takeaway"
  action:
    type: string
    description: "What to do differently next time"
  confidence:
    type: string
    default: medium
    enum: [low, medium, high]
    description: "How confident we are in this lesson"
  related_tasks:
    type: string[]
    description: "Task IDs related to this lesson"
  tags:
    type: string[]
---
