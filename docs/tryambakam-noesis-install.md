# Tryambakam Noesis Install Notes

This repo is now wired as a Noesis-flavored VelvetClaw organization.

## What Was Added

- The official `coreyhaines31/marketingskills` pack was vendored into `skills/`.
- Marketing skills were mapped to the right VelvetClaw agents through each agent's `skills.custom` list.
- Shared Noesis brand, offering, audience, and workflow context was added under `memory/`.
- A seeded `.agents/product-marketing-context.md` was added at repo root.
- A helper script was added to copy that context into OpenClaw workspaces after bootstrap.

## Bootstrap Model

Keep the repo split exactly like this:

- `skill-requirements.yaml` = ClawHub-installable skills only
- `skills/` = repo-local custom skills copied into workspaces
- `agents/*/MANIFEST.yaml` = the source of truth for which agent owns which custom marketing skills

That matches the existing `org-bootstrap` contract in this repo.

## Install Paths

### Path 1: Standard bootstrap

If `clawhub` is available on the target machine:

```bash
clawhub install org-bootstrap
# Then tell your bootstrap-capable agent to bootstrap from this repo.
```

### Path 2: Local workspace seeding

If the agents already exist in OpenClaw and you mainly need the Noesis marketing context copied in, run:

```bash
bash /Volumes/madara/2026/twc-vault/01-Projects/velvetclaw/scripts/seed-product-marketing-context.sh \
  ~/.openclaw/workspace-jarvis \
  ~/.openclaw/workspace-atlas \
  ~/.openclaw/workspace-trendy \
  ~/.openclaw/workspace-scribe \
  ~/.openclaw/workspace-sage \
  ~/.openclaw/workspace-clawd \
  ~/.openclaw/workspace-sentinel \
  ~/.openclaw/workspace-clip
```

This writes `.agents/product-marketing-context.md` into each workspace so the marketing skills can pick it up automatically.

## Important Note

This integration fixes the Noesis-specific marketing layer, but VelvetClaw still has some pre-existing shared-memory references outside this scope, especially for `pixel`, `nova`, and `vibe`, that are unrelated to the `marketingskills` mapping.
