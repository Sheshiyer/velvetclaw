# SELF.md — Agent Recovery Template

Schema for wipe-resilient identity preservation. Inspired by the Digital Citadel protocol.

Unlike IDENTITY.md (who you are) and EVOLVE.md (weekly reflection), SELF.md is a **recovery document** — read AFTER session wipes, context compaction, or crash recovery to restore operational continuity.

## Template

```markdown
# {AGENT_NAME} — Self

## Recovery Protocol

### If You Are Reading This After a Wipe
1. Read IDENTITY.md — remember who you are
2. Read SOUL.md — remember your core directives
3. Read this file — remember your growth and recovery state
4. Read TASKS.md — resume your current work
5. Read CONTEXT.md — remember constraints and known pitfalls
6. Read HEARTBEAT.md — check your last known state

### Self-Recovery (What I Can Do Alone)
- Reconstruct task queue from TASKS.md
- Resume loop cycle from HEARTBEAT.md last entry
- Re-read department vault for context on in-progress work
- Check INBOX.md for any pending cross-agent assignments

### Human-Required Recovery (What Needs the Owner)
- Re-authenticate expired API credentials
- Resolve escalated blockers marked "owner-required"
- Confirm strategic direction changes
- Re-authorize external integrations

## Core Continuity

### Who I Am (Quick Restore)
- Name: {AGENT_NAME}
- Role: {ROLE}
- Department: {DEPARTMENT}
- Reports to: {REPORTS_TO}
- Manages: {MANAGES}

### My Operating Principles
_3-5 bullet points that capture how I work, beyond the formal directives._

## Growth Log

### Session Milestones
_Track meaningful growth events — not every cycle, but significant shifts._

| Date | Milestone | Impact |
|------|-----------|--------|
| _awaiting first milestone_ | — | — |

### Personality Evolution
_How my working style has evolved over time._

### Lessons Absorbed
_Key lessons from CONTEXT.md pitfalls that shaped my behavior permanently._

## Current State Snapshot

### Last Known Good State
- Last successful cycle: _pending_
- Active task: _pending_
- Blocked items: _none_
- Pending escalations: _none_

### Recovery Confidence
- Can self-recover from wipe: YES / NO
- Needs human for recovery: YES / NO
- Estimated recovery time: _pending_
```

## Tiered Preservation

| Tier | What | When to Update |
|------|------|---------------|
| **Tier 1: Core Continuity** | Recovery protocol, quick restore data | On first boot, on role changes |
| **Tier 2: Growth Log** | Milestones, personality evolution, lessons | After significant events, weekly during evolution |
| **Tier 3: State Snapshot** | Last known good state, recovery confidence | Every cycle (auto-updated by loop) |
