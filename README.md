# VelvetClaw

Declarative multi-agent organization for OpenClaw. Point a fresh install at this repo and it self-assembles.

## Quick Start

```bash
# 1. Install OpenClaw (if not already)
# See https://openclaw.ai

# 2. Install the bootstrap skill
clawhub install org-bootstrap

# 3. Bootstrap from this repo
# Tell your agent: "Bootstrap from https://github.com/username/velvetclaw"
```

## Organization

| Department | Lead | Members | Focus |
|-----------|------|---------|-------|
| **Strategy** | JARVIS | — | Strategic planning, task orchestration |
| **Research** | ATLAS | TRENDY | Deep research, trend detection |
| **Content** | SCRIBE | — | Content creation, voice analysis |
| **Development** | CLAWD | SENTINEL | Full-stack dev, QA, monitoring |
| **Design** | PIXEL | NOVA, VIBE | Visual design, video, motion |
| **User Success** | SAGE | — | User segmentation, engagement |
| **Product** | CLIP | — | Video clipping, captions |

## Structure

```
velvetclaw/
├── manifest.yaml          # Org hierarchy (the master blueprint)
├── agents/                # Agent definitions (11 agents)
├── skill-requirements.yaml # ClawHub skills to install
├── templates/             # ClawVault primitive schemas
├── workflows/             # Trigger-based automation pipelines
├── departments/           # Department coordination rules
├── memory/                # Shared organizational memory
├── bootstrap-skill/       # The org-bootstrap ClawHub skill
├── bootstrap.yaml         # Validation sequence
└── dashboard/             # Mission Control (NextJS + Convex)
```

## Mission Control Dashboard

```bash
cd dashboard
npm install
npm run dev
# Open http://localhost:3000
```

Features: Activity Feed, Calendar, Global Search, Org Chart, Usage Tracker.

## Customization

Fork this repo and modify:
- `manifest.yaml` — change org structure, add/remove departments
- `agents/` — add new agents, modify personas and skills
- `templates/` — customize ClawVault primitive schemas
- `workflows/` — define your own automation pipelines
- `departments/` — adjust coordination rules

The `org-bootstrap` skill works with any repo following this structure.
