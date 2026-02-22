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
