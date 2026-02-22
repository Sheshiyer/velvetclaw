# Dashboard Pivot: OpenClaw-Native Monitoring

**Date:** 2026-02-23
**Status:** Planned (Stage 3)
**Inspired by:** TenacitOS by Carlos Azaustre (@carlosazaustre)

## Problem

VelvetClaw's current dashboard approach uses Convex (cloud database) as a separate data layer. This creates a fundamental disconnect:

- Agent state lives in OpenClaw (HEARTBEAT.md, TASKS.md, etc.)
- Dashboard reads from Convex
- Two sources of truth that can drift apart
- Requires syncing infrastructure between OpenClaw and Convex
- Adds a cloud dependency to what should be a local-first system

## Proposed Pivot

Replace the Convex-based dashboard with an OpenClaw-native dashboard that reads directly from agent state files. No extra database — OpenClaw IS the backend.

### Architecture

```
Browser Dashboard
       |
       v
  Local HTTP Server (reads OpenClaw state)
       |
       v
  OpenClaw Agent Files (HEARTBEAT.md, TASKS.md, CONTEXT.md, etc.)
```

### Core Features (from TenacitOS)

1. **Real-Time Agent Monitoring**
   - Read each agent's HEARTBEAT.md for cycle status
   - Show active/idle/blocked/failed states per agent
   - Display last cycle timestamp and outcome

2. **Visual Cron Manager**
   - Read loop-runner state for cron schedules
   - Show tier 1/2 agent timing
   - Toggle agents on/off

3. **Cost/Token Tracking**
   - Read model usage data from OpenClaw
   - Display per-agent token consumption
   - Budget alerts when approaching limits

4. **Memory Explorer**
   - Browse agent files visually (IDENTITY.md, SOUL.md, SELF.md, etc.)
   - View TASKS.md progress per agent
   - Read CONTEXT.md known pitfalls

5. **Department Vault Browser**
   - Navigate vault/ directory structure
   - View cross-department handoffs
   - Track deliverable status

6. **Inbox Activity Feed**
   - Read all agents' INBOX.md files
   - Show pending/processed cross-agent tasks
   - Highlight escalations

### Data Sources (All Local Files)

| Feature | Source File(s) |
|---------|---------------|
| Agent status | `agents/*/HEARTBEAT.md` |
| Task progress | `agents/*/TASKS.md` |
| Agent identity | `agents/*/IDENTITY.md`, `agents/*/SELF.md` |
| Cron schedules | `scripts/loop-runner.conf`, `manifest.yaml` |
| Department output | `vault/*/` |
| Cross-agent routing | `agents/*/INBOX.md` |
| Org hierarchy | `manifest.yaml` |

### Technology Options

| Option | Pros | Cons |
|--------|------|------|
| **Next.js + file reads** | Rich UI, SSR, familiar | Heavier than needed |
| **Astro + Islands** | Lightweight, fast, partial hydration | Less interactivity |
| **Plain HTML + htmx** | Minimal deps, instant reload | Less sophisticated UI |
| **TenacitOS fork** | Already built for OpenClaw | May not match VelvetClaw's specific needs |

### Implementation Notes

- Dashboard server must be read-only — never modify agent files
- File watching (chokidar/fsnotify) for real-time updates
- Markdown parsing for HEARTBEAT/TASKS/INBOX rendering
- YAML parsing for manifest.yaml hierarchy visualization
- Consider SSE (Server-Sent Events) for live updates to browser

## Dependencies Removed

- Convex (cloud database) — no longer needed
- Convex SDK — removed from package.json
- Sync infrastructure — eliminated entirely

## Timeline

This is a Stage 3 task. Prerequisites:
1. Stage 2 loop infrastructure running and generating real HEARTBEAT data
2. At least one full evolution cycle completed
3. Enough agent activity to make monitoring meaningful

## References

- TenacitOS: Open-source OpenClaw dashboard by Carlos Azaustre
- VelvetClaw Gap Analysis: `docs/plans/2026-02-23-stage2-gap-analysis-design.md` (Gap 7)
