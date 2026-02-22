---
name: org-bootstrap
slug: org-bootstrap
version: "1.0.0"
description: "Bootstrap a multi-agent OpenClaw organization from a GitHub repo manifest"
author: "VelvetClaw"
license: "MIT"
tags: [bootstrap, organization, multi-agent, manifest, setup, automation]
requirements:
  - name: git
    install:
      darwin: "xcode-select --install"
      linux: "sudo apt install git"
  - name: clawhub
    install:
      all: "clawhub is included with OpenClaw"
---

# org-bootstrap

Bootstrap a complete multi-agent OpenClaw organization from a single GitHub repository.

## What This Skill Does

When you tell your agent to "bootstrap from [repo URL]", it will:

1. **Clone the repository** containing the organization manifest
2. **Parse `manifest.yaml`** to understand the org hierarchy
3. **Create agent workspaces** for every agent defined in the manifest
4. **Install skills** from `skill-requirements.yaml` via ClawHub
5. **Copy custom skills** from the repo's `skills/` directory
6. **Initialize ClawVault templates** for task/project/decision/lesson primitives
7. **Seed agent memory** from the repo's `memory/` directory and per-agent files
8. **Wire workflows** from the repo's `workflows/` directory
9. **Apply department rules** from the repo's `departments/` directory
10. **Validate** the entire deployment

## Usage

Tell your agent:
```
Bootstrap my organization from https://github.com/username/my-org-config
```

Or with a specific model:
```
Bootstrap from https://github.com/username/my-org-config using openai/gpt-5.3-codex as the default model
```

## Repository Structure

Your config repo must follow this structure:

```
my-org-config/
├── manifest.yaml              # REQUIRED: Org hierarchy and coordination rules
├── agents/                    # REQUIRED: One directory per agent
│   └── {agent-name}/
│       ├── MANIFEST.yaml      # REQUIRED: Agent role, model, skills, triggers
│       ├── IDENTITY.md        # REQUIRED: Agent persona and voice
│       ├── SOUL.md            # REQUIRED: Core directives
│       └── MEMORY.md          # OPTIONAL: Seed memory
├── skill-requirements.yaml    # OPTIONAL: ClawHub skills to auto-install
├── skills/                    # OPTIONAL: Custom repo-local skills
│   └── {skill-name}/
│       └── SKILL.md
├── workflows/                 # OPTIONAL: Trigger-based automation definitions
│   └── {workflow-name}.yaml
├── templates/                 # OPTIONAL: ClawVault primitive schemas
│   ├── task.md
│   ├── project.md
│   ├── decision.md
│   └── lesson.md
├── departments/               # OPTIONAL: Department coordination rules
│   └── {department-name}.yaml
├── memory/                    # OPTIONAL: Shared organizational memory
│   └── {topic}.md
└── bootstrap.yaml             # OPTIONAL: Custom validation checks
```

## Bootstrap Procedure

When bootstrapping, follow this exact sequence:

### Step 1: Clone the Repository

```bash
# Clone to a temporary location
git clone {repo_url} /tmp/org-bootstrap-{timestamp}
cd /tmp/org-bootstrap-{timestamp}
```

### Step 2: Validate the Manifest

Read `manifest.yaml` and verify:
- All agents referenced in the hierarchy have corresponding directories in `agents/`
- All department leads are defined agents
- No circular delegation references
- The coordination section has valid values

If validation fails, report the specific errors and stop.

### Step 3: Create Agent Workspaces

For each agent defined in `manifest.yaml`:

```bash
# Create workspace directory
mkdir -p ~/.openclaw/workspace-{agent-id}

# Copy agent files
cp agents/{agent-id}/MANIFEST.yaml ~/.openclaw/workspace-{agent-id}/
cp agents/{agent-id}/IDENTITY.md ~/.openclaw/workspace-{agent-id}/
cp agents/{agent-id}/SOUL.md ~/.openclaw/workspace-{agent-id}/

# Copy seed memory if it exists
if [ -f agents/{agent-id}/MEMORY.md ]; then
  cp agents/{agent-id}/MEMORY.md ~/.openclaw/workspace-{agent-id}/
fi
```

Register the agent in OpenClaw's configuration:
- Add to the agents list in `~/.openclaw/openclaw.json`
- Set the model from the agent's MANIFEST.yaml (or use the manifest default)
- Configure channels from the agent's MANIFEST.yaml

### Step 4: Install Global Skills

If `skill-requirements.yaml` exists, install global skills:

```bash
# For each skill in the global list
clawhub install {skill-name}
```

### Step 5: Install Per-Agent Skills

For each agent in `skill-requirements.yaml`'s `per_agent` section:

```bash
# Install skills into the agent's workspace
cd ~/.openclaw/workspace-{agent-id}
clawhub install {skill-name}
```

### Step 6: Copy Custom Skills

If `skills/` directory exists in the repo:

```bash
# Copy each custom skill to relevant agent workspaces
cp -r skills/{skill-name} ~/.openclaw/workspace-{agent-id}/skills/
```

### Step 7: Initialize Templates

If `templates/` directory exists:

```bash
# Copy to each workspace
for workspace in ~/.openclaw/workspace-*/; do
  mkdir -p "$workspace/templates"
  cp templates/*.md "$workspace/templates/"
done
```

### Step 8: Seed Memory

Copy shared memory files to each workspace:

```bash
for workspace in ~/.openclaw/workspace-*/; do
  mkdir -p "$workspace/memory"
  cp memory/*.md "$workspace/memory/"
done
```

### Step 9: Wire Workflows

If `workflows/` directory exists, copy workflow definitions:

```bash
for workspace in ~/.openclaw/workspace-*/; do
  mkdir -p "$workspace/workflows"
  cp workflows/*.yaml "$workspace/workflows/"
done
```

### Step 10: Apply Department Rules

If `departments/` directory exists:

```bash
for workspace in ~/.openclaw/workspace-*/; do
  mkdir -p "$workspace/departments"
  cp departments/*.yaml "$workspace/departments/"
done
```

### Step 11: Validate

Run validation checks:
- Each agent workspace exists and has required files
- All referenced skills are installed
- Heartbeat is responding for each agent
- At least one workflow can be triggered

Report the results as a structured summary.

### Step 12: Cleanup

```bash
rm -rf /tmp/org-bootstrap-{timestamp}
```

## Sync (Re-Bootstrap)

To sync changes from the repo without recreating everything:

```
Sync my organization from https://github.com/username/my-org-config
```

This will:
1. Pull latest changes from the repo
2. Diff against current workspace state
3. Apply only the changes (new agents, updated configs, new skills)
4. Report what changed

## Troubleshooting

- **"Agent workspace already exists"**: The bootstrap will skip existing workspaces by default. Use "force bootstrap" to overwrite.
- **"Skill not found on ClawHub"**: Check the skill name in `skill-requirements.yaml`. Use `clawhub search {name}` to find the correct slug.
- **"Manifest validation failed"**: Check that all agent names in the hierarchy match directory names in `agents/`.

---

## Stage 2: Loop Infrastructure

Stage 2 adds autonomous loop infrastructure to each agent. When bootstrapping a repo with Stage 2 files, the bootstrap process extends with these additional steps.

### Stage 2 Agent Files

Each agent directory may contain these additional files (all optional — Stage 2 features activate when present):

```
agents/{agent-name}/
├── MANIFEST.yaml      # Stage 1 (existing)
├── IDENTITY.md        # Stage 1 (existing)
├── SOUL.md            # Stage 1 (existing)
├── MEMORY.md          # Stage 1 (existing)
├── TASKS.md           # Stage 2: Step-by-step work queue for loop cycles
├── CONTEXT.md         # Stage 2: Stack, constraints, and known pitfalls
├── TOOLS.md           # Stage 2: Available skills and capabilities
├── USER.md            # Stage 2: Owner context and preferences
├── HEARTBEAT.md       # Stage 2: Loop cycle health and status log
├── AGENTS.md          # Stage 2: Hierarchy awareness — subordinates and peers
├── EVOLVE.md          # Stage 2: Weekly self-evolution with 20 questions
└── SELF.md            # Stage 2.1: Wipe-recovery identity preservation document
```

### Stage 2 Templates

```
templates/
├── task.md             # Stage 1 (existing)
├── project.md          # Stage 1 (existing)
├── decision.md         # Stage 1 (existing)
├── lesson.md           # Stage 1 (existing)
├── loop-config.md      # Stage 2: Loop cycle configuration primitive
├── pressure-prompts.md # Stage 2: 25 strategic audit questions
├── evolve-cycle.md     # Stage 2: Weekly evolution cycle schema
└── self-recovery.md    # Stage 2.1: SELF.md agent recovery template
```

### Stage 2 Workflows

```
workflows/
├── content-pipeline.yaml  # Stage 1 (existing)
├── research-loop.yaml     # Stage 1 (existing)
├── qa-monitoring.yaml     # Stage 1 (existing)
├── agent-loop.yaml        # Stage 2: Autonomous cron-triggered loop cycle
└── weekly-evolve.yaml     # Stage 2: Weekly self-evolution trigger
```

### Stage 2 Bootstrap Steps

After Step 10 (Apply Department Rules), add:

#### Step 10a: Copy Stage 2 Agent Files

```bash
for agent_dir in agents/*/; do
  agent_id=$(basename "$agent_dir")
  workspace="$HOME/.openclaw/workspace-$agent_id"

  # Copy Stage 2 files if they exist (do NOT overwrite Stage 1 files)
  for stage2_file in TASKS.md CONTEXT.md TOOLS.md USER.md HEARTBEAT.md AGENTS.md EVOLVE.md SELF.md; do
    if [ -f "$agent_dir/$stage2_file" ]; then
      cp "$agent_dir/$stage2_file" "$workspace/"
    fi
  done
done
```

#### Step 10b: Configure Loop Crons

Read each agent's MANIFEST.yaml `loop:` section and configure the cron schedule:
- Tier 1 agents (chiefs): every 5 minutes
- Tier 2 leads: every 10 minutes
- Tier 2 members: every 15 minutes

Register the cron trigger in OpenClaw's scheduler for each agent.

#### Step 10c: Register Weekly Evolution

Set up the weekly evolution cron (Sunday midnight) for all agents:

```bash
# Register weekly-evolve workflow for each agent
for workspace in ~/.openclaw/workspace-*/; do
  agent_id=$(basename "$workspace" | sed 's/workspace-//')
  openclaw schedule add --agent "$agent_id" --cron "0 0 * * 0" --workflow weekly-evolve
done
```

### Stage 2 Validation

Add these checks to Step 11:

- Each agent workspace has TASKS.md, CONTEXT.md, HEARTBEAT.md (minimum viable loop)
- Loop cron is registered and active for each agent
- Weekly evolution cron is registered
- Agent HEARTBEAT.md is writable
- AGENTS.md hierarchy matches manifest.yaml hierarchy
