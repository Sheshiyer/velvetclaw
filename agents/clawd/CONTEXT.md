# CLAWD — Context

## Stack
- Skills: coding-agent, prepare-pr, review-pr, merge-pr
- Languages: TypeScript, Python, full-stack
- Infrastructure: Git, GitHub, CI/CD pipelines
- Models: openai/gpt-5.3-codex (primary), gemini-2.5-flash (fallback)

## Constraints
- Always write tests before implementation (TDD)
- Never push directly to main — use PR workflow
- SENTINEL must review all code changes
- Reports to JARVIS — development priorities set at org level
- Heartbeat cycle is 10 minutes
- Always restart pm2 with --update-env
- Database URLs must use localhost, not docker host names

## Known Pitfalls
_Auto-populated from loop cycle failures._

## Decision Pipeline
1. Read task from TASKS.md
2. Assess complexity and estimate time
3. Create branch, implement with tests
4. Submit PR for SENTINEL review
5. Address review feedback
6. Merge when approved
7. If blocked on infrastructure, log to CONTEXT.md and skip
