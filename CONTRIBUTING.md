# Contributing to VelvetClaw

Thanks for your interest in contributing! VelvetClaw is a declarative blueprint for multi-agent OpenClaw organizations, and we welcome contributions of all kinds.

## Ways to Contribute

- **Add new agents** — Define new roles in `agents/` with MANIFEST.yaml, IDENTITY.md, SOUL.md, MEMORY.md
- **Create workflows** — Build new automation pipelines in `workflows/`
- **Improve templates** — Enhance ClawVault primitives in `templates/`
- **Extend the dashboard** — Add features to Mission Control in `dashboard/`
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

## Project Structure

```
agents/          # Agent definitions (4 files each)
workflows/       # YAML automation pipelines
templates/       # ClawVault primitive schemas
departments/     # Department coordination rules
memory/          # Shared organizational memory
bootstrap-skill/ # The org-bootstrap ClawHub skill
dashboard/       # Mission Control (Next.js + Convex)
```

## Agent Definition Format

Every agent needs 4 files in `agents/{name}/`:

| File | Purpose |
|:-----|:--------|
| `MANIFEST.yaml` | Role, model, skills, triggers, channels |
| `IDENTITY.md` | Persona and communication style |
| `SOUL.md` | 5-7 core directives |
| `MEMORY.md` | Seed memory and context |

## Testing Locally

### Dashboard
```bash
cd dashboard
npm install
npm run dev
```

### Bootstrap Validation
Point an OpenClaw agent at your local fork and run the bootstrap skill to verify your changes parse correctly.

## Pull Request Guidelines

- Keep PRs focused — one feature or fix per PR
- Update `manifest.yaml` if adding/removing agents or departments
- Update `skill-requirements.yaml` if adding new skill dependencies
- Follow existing YAML formatting conventions
- Include a clear description of what changed and why

## Code Style

- **YAML**: 2-space indentation, quoted strings for values with special characters
- **Markdown**: ATX-style headers, blank lines between sections
- **TypeScript** (dashboard): Follow existing patterns, use TypeScript strict mode

## Reporting Issues

Open an issue with:
- Clear title describing the problem
- Steps to reproduce (if applicable)
- Expected vs actual behavior
- Your OpenClaw version and model

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
