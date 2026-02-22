# Stage 2 Gap Analysis & Local Execution Design

**Date:** 2026-02-23
**Status:** Implemented and pushed

## Context

VelvetClaw Stage 2 added autonomous loop infrastructure (cron-triggered cycles, skip-on-block resilience, weekly evolution) for 11 agents. A gap analysis identified 10 architectural gaps, 4 of which were critical for local-only execution.

## 10 Gaps Identified

| # | Gap | Severity | Status |
|---|-----|----------|--------|
| 1 | No actual loop runner / daemon to trigger agent cycles | Critical | Implemented |
| 2 | Mac sleep/lid-close kills all crons | Medium | Documented (future) |
| 3 | No shared vault path defined for cross-agent deliverables | Critical | Implemented |
| 4 | No inter-agent task routing mechanism | Critical | Implemented |
| 5 | No token/cost budget per agent | Medium | Scaffolded (.env) |
| 6 | No concurrency limiter for parallel agent execution | Medium | Implemented (MAX_CONCURRENT) |
| 7 | Dashboard has no local data source | Low | Future |
| 8 | Notification delivery undefined locally | Low | Future |
| 9 | Log rotation / file growth unbounded | Low | Future |
| 10 | API key / environment setup not addressed | Critical | Implemented |

## Decisions

### Gap 1: Loop Runner
- **Chosen:** Single orchestrator bash script (`scripts/loop-runner.sh`)
- **Rejected:** macOS launchd plists (11 files to manage), OpenClaw native scheduler (may not exist yet)
- **Rationale:** One process, easy to start/stop, reads manifest for agent discovery

### Gaps 3+4: Shared Vault + Inter-Agent Routing
- **Chosen:** Inbox pattern (INBOX.md per agent) + vault/ directory with department subdirs
- **Rejected:** Central dispatch queue (bottleneck), direct TASKS.md writes (concurrent write risk)
- **Rationale:** Inbox is auditable, file-based, and each agent owns its own inbox

### Gap 10: Credentials
- **Chosen:** `.env.example` template with documentation
- **Rejected:** macOS Keychain integration (complex), OpenClaw-only (uncertain)
- **Rationale:** Standard, portable, works with any model provider

## Files Created

- `scripts/loop-runner.sh` — Orchestrator daemon with start/stop/status
- `scripts/loop-runner.conf` — Configuration overrides
- `agents/*/INBOX.md` — 11 inbox files for cross-agent routing
- `templates/inbox.md` — Inbox entry schema
- `vault/{research,content,development,design,user-success,product,handoffs}/` — Shared vault
- `.env.example` — Environment template

## Files Modified

- `workflows/agent-loop.yaml` — Added INBOX.md to pre_read, added inbox_processing step
- `manifest.yaml` — Added vault configuration section
- `.gitignore` — Added logs/ and .loop-runner.pid

## Remaining Gaps (Future Work)

- **Gap 2 (Sleep/Wake):** Add launchd-level keepalive or wake-on-schedule
- **Gap 7 (Dashboard):** Replace Convex with local SQLite or filesystem reads
- **Gap 8 (Notifications):** Add macOS notification center integration via osascript
- **Gap 9 (Log Rotation):** Add monthly HEARTBEAT.md archival to `logs/archive/`
