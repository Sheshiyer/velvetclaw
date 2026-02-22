---
primitive: inbox-entry
version: "2.0.0"
description: "Cross-agent task assignment delivered to another agent's INBOX.md"
---

# Inbox Entry Schema

## Entry Format

```yaml
### [{ISO-timestamp}] From: {SENDER_AGENT} | Priority: {priority}
{task description}
Tags: {comma-separated tags}
Depends-on: {optional — reference to vault file or prior task}
```

## Fields

| Field | Required | Values | Description |
|-------|----------|--------|-------------|
| timestamp | yes | ISO 8601 | When the entry was created |
| from | yes | agent name | Which agent is assigning this work |
| priority | yes | critical, high, medium, low | Urgency level |
| description | yes | free text | What needs to be done |
| tags | no | comma-separated | For routing and categorization |
| depends-on | no | file path or task ref | Prerequisite work |

## Lifecycle

1. Sender appends entry to recipient's `INBOX.md` under `## Pending`
2. Recipient's loop cycle reads INBOX.md during pre_read
3. Recipient converts pending items to steps in their own TASKS.md
4. Recipient moves the inbox entry to `## Processed` with a timestamp
5. If recipient cannot handle it, they re-route to their `reports_to` agent's inbox

## Rules

- Never delete inbox entries — move to Processed
- Critical priority items trigger an immediate cycle (outside cron schedule)
- If INBOX has 10+ pending items, escalate to reports_to for triage
