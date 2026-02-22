---
primitive: decision
fields:
  status:
    type: string
    required: true
    default: proposed
    enum: [proposed, accepted, rejected, superseded]
  decided_by:
    type: string
    description: "Agent or human who made the decision"
  department:
    type: string
    enum: [research, content, development, design, user-success, product, org-wide]
  context:
    type: string
    description: "What prompted this decision"
  alternatives:
    type: string[]
    description: "Other options that were considered"
  rationale:
    type: string
    description: "Why this option was chosen"
  consequences:
    type: string[]
    description: "Expected outcomes and tradeoffs"
  supersedes:
    type: string
    description: "ID of the decision this replaces"
  review_date:
    type: date
    description: "When to re-evaluate this decision"
---
