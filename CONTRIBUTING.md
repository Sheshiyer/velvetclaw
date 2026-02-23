# Contributing to VelvetClaw

Thanks for your interest in contributing! VelvetClaw is a local-first multi-agent swarm powered by `claude -p`. We welcome contributions of all kinds.

## Ways to Contribute

- **Add new agents** — Define new roles in `agents/` with all 12 state files
- **Create workflows** — Build new automation pipelines in `workflows/`
- **Improve scripts** — Enhance the operational scripts in `scripts/`
- **Write tests** — Add bats test coverage in `tests/`
- **Fix bugs** — Report issues or submit fixes
- **Improve documentation** — Better docs help everyone

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Test locally (see below)
6. Commit with a clear message
7. Push and open a pull request

## Prerequisites

- macOS with Bash 4+ (`brew install bash` if needed)
- `claude` CLI installed and in PATH
- `jq` installed (`brew install jq`)
- `bats-core` for tests (`brew install bats-core`)

## Project Structure

```
agents/          # Agent definitions (12 files each)
scripts/         # Operational scripts (17 total)
tests/           # Bats test suites
workflows/       # YAML automation pipelines
templates/       # ClawVault primitive schemas
departments/     # Department coordination rules
memory/          # Shared organizational memory
vault/           # Shared deliverables and handoffs
.velvetclaw/     # Runtime state (task registry)
logs/            # Runtime logs (gitignored)
```

## Agent Definition Format

Every agent needs 12 files in `agents/{name}/`:

| File | Purpose |
|:-----|:--------|
| `MANIFEST.yaml` | Role, model, loop config, skills, triggers |
| `IDENTITY.md` | Persona and communication style |
| `SOUL.md` | 5-7 core directives |
| `MEMORY.md` | Seed memory and context |
| `TASKS.md` | Active work queue |
| `INBOX.md` | Cross-agent task assignments |
| `HEARTBEAT.md` | Cycle log |
| `CONTEXT.md` | Known pitfalls and constraints |
| `TOOLS.md` | Available tool definitions |
| `USER.md` | User-facing configuration |
| `AGENTS.md` | Known peers and delegation targets |

## Testing Locally

### Run the full test suite

```bash
bats tests/
```

### Run individual test files

```bash
bats tests/loop-runner.bats
bats tests/prompt-assembler.bats
bats tests/write-back.bats
bats tests/integration-dispatch.bats
```

### Validate agent health

```bash
./scripts/health-check.sh         # Check all 11 agents
./scripts/health-check.sh --fix   # Auto-repair missing files
```

### Test dispatch routing

```bash
./scripts/dispatch-task.sh "Test task" --tag research --priority low
# Verify it appears in the correct agent's INBOX.md
```

### Syntax check all scripts

```bash
for f in scripts/*.sh; do bash -n "$f" && echo "OK: $f"; done
```

## Script Development

When adding or modifying scripts in `scripts/`:

- Use `#!/usr/bin/env bash` and `set -euo pipefail`
- Make scripts executable: `chmod +x scripts/your-script.sh`
- Use BSD-compatible commands (macOS-first — no GNU flags)
- Use `mkdir`-based locking, not `flock` (macOS compatibility)
- Add a corresponding bats test file in `tests/`
- Log to stderr for diagnostics, stdout for data output

## Pull Request Guidelines

- Keep PRs focused — one feature or fix per PR
- Update `manifest.yaml` if adding/removing agents or departments
- Run `bats tests/` and ensure all tests pass
- Run `./scripts/health-check.sh` and ensure 11/11 healthy
- Include a clear description of what changed and why

## Code Style

- **Bash**: `set -euo pipefail`, quote all variables, use `local` in functions
- **YAML**: 2-space indentation, quoted strings for values with special characters
- **Markdown**: ATX-style headers, blank lines between sections

## Reporting Issues

Open an issue with:
- Clear title describing the problem
- Steps to reproduce (if applicable)
- Expected vs actual behavior
- Your macOS version and `claude --version` output

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
