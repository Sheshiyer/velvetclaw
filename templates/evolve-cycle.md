---
primitive: evolve-cycle
description: "Weekly self-evolution schema for agents. Combines pressure prompts with interaction-derived questions for continuous refinement."
fields:
  week:
    type: string
    required: true
    description: "ISO week identifier (e.g., 2026-W09)"
  agent:
    type: string
    required: true
    description: "Agent ID running the evolution cycle"
  status:
    type: string
    required: true
    default: pending
    enum: [pending, in-progress, completed, skipped]
  pressure_prompts_selected:
    type: integer[]
    description: "Indices of the 5-8 pressure prompts selected from the bank of 25"
  interaction_questions:
    type: string[]
    description: "12-15 questions derived from that week's actual interactions, failures, and patterns"
  total_questions:
    type: integer
    required: true
    default: 20
    description: "Total questions answered this cycle (pressure + interaction-derived)"
  insights:
    type: string[]
    description: "Top 3 actionable insights from the evolution answers"
  tasks_generated:
    type: string[]
    description: "Task IDs created from evolution insights"
  cycle_data:
    type: object
    description: "Summary stats from the week's loop cycles"
    fields:
      total_cycles:
        type: integer
      steps_completed:
        type: integer
      steps_blocked:
        type: integer
      steps_failed:
        type: integer
      avg_step_duration:
        type: string
      most_common_blocker:
        type: string
  evolution_score:
    type: number
    description: "Self-assessed improvement score 1-10 compared to previous week"
---

# Evolve Cycle Primitive

Weekly proactive self-refinement. The agent doesn't wait to be told to improve — it initiates its own evolution every week.

## The 20-Question Structure

Each weekly evolution cycle consists of exactly 20 questions:

- **5-8 Pressure Prompts**: Selected from the bank of 25 strategic audit questions in `pressure-prompts.md`. Agent chooses the most relevant to their current challenges and domain.
- **12-15 Interaction Questions**: Generated from that week's actual work — failures encountered, patterns noticed, efficiency observations, capability gaps discovered during loop cycles.

## Weekly Cadence

| Day | Action |
|-----|--------|
| Sunday 00:00 | Evolve cycle triggers automatically |
| Sunday | Agent reviews week's HEARTBEAT.md logs, selects pressure prompts, generates interaction questions |
| Sunday | Agent answers all 20 questions with evidence from cycle logs |
| Sunday | Agent identifies top 3 insights and creates tasks for next week |
| Monday 00:00 | New week begins with evolution-informed task list |

## Output Format

The agent writes its evolution results to `EVOLVE.md` in its directory, replacing the previous week's content but appending a summary to the evolution history at the bottom.
