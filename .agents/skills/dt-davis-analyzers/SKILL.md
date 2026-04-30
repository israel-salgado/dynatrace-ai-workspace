---
name: dt-davis-analyzers
description: Work with Davis Analyzers for forecasting, anomaly detection, correlation, and advanced analysis. Provides analyzer metadata, execution patterns, input parameters, polling, result interpretation, and integration with notebooks and investigation workflows. Always load dt-dql-essentials/SKILL.md first.
---

# Davis Analyzers Skill

## Overview

Davis Analyzers provide advanced AI-driven analysis including time series forecasting, anomaly detection, baseline calculation, and correlation.

**When to use this skill:**
- List available analyzers and their capabilities
- Execute analyzers with proper parameters and timeframes
- Interpret analyzer results in investigations and notebooks
- Combine analyzer output with Davis Problems and DQL

**MANDATORY:** Always load `.agents/skills/dt-dql-essentials/SKILL.md` FIRST before any DQL or analyzer work.

## Core Rules (from dt-dql-essentials)

- Start all investigations with **problems** (`dt.davis.problems` or `list_problems`).
- Use unique `event.type` + `event.provider` for workflow isolation.
- Validate EVERY query in exact target context (standalone + notebook tile).
- Prefer `fields`/`bin()`/`sort`/`limit` over `summarize by` in dashboard tiles.
- Follow notebook Live State Reconciliation & Conflict Protection before any modification.

## Common Analyzers

| Analyzer | Use Case | Key Input Parameters |
|----------|----------|----------------------|
| `dt.statistics.GenericForecastAnalyzer` | Time series forecasting | `metric`, `forecastHorizon` |
| Adaptive anomaly detection | Dynamic threshold detection | entity, metric, sensitivity |
| Seasonal baseline | Seasonal pattern analysis | metric, seasonality |
| Static threshold | Fixed threshold analysis | metric, threshold |
| Correlation | Entity correlation analysis | entities, timeframe |

(See `list_davis_analyzers` tool for full current list and metadata: name, displayName, description, category, labels.)

## Execution Patterns

**Basic execution (use via MCP `execute_davis_analyzer`):**
```json
{
  "analyzerName": "dt.statistics.GenericForecastAnalyzer",
  "input": {
    "generalParameters": {
      "timeframe": {
        "startTime": "now-7d",
        "endTime": "now"
      }
    },
    "metric": "builtin:host.cpu.usage",
    "forecastHorizon": 24
  }
}
```

**Polling note:** Long-running analyzers return a `requestToken`. Poll until `executionStatus: "COMPLETED"`. Use timeout and cancel logic on failure.

**Result handling:**
- Check `result.executionStatus`
- Extract metrics, confidence intervals, anomalies
- Feed results into notebooks using explicit DQL section metadata
- Always include `state.input.timeframe`, `state.querySettings`, and `visualizationSettings`

## Integration with Notebooks

When adding analyzer results to notebooks:
- Use JSON payload with full section metadata (`type: dql`, `showTitle`, `state.input.value`, `visualization`)
- Re-export live notebook state first (`dtctl get notebook <id>`)
- Verify `state.input.value` is non-empty after apply
- Follow per-tenant reconciliation contract (write per-resource files under `temp_dtctl_files/tenant-memory/<TENANTID>/<type>/<id>.json`)

## Best Practices

- Start with Davis Problems to scope analyzers to relevant entities/timeframes.
- Use tight timeframes to reduce Grail cost.
- Combine with `dt-obs-problems` and `dt-app-notebooks` skills.
- Record generic lessons only in `/memories/repo/`.

## References

- `dt-dql-essentials/SKILL.md` (mandatory)
- `dt-app-notebooks/SKILL.md`
- `dt-obs-problems/SKILL.md`
- MCP tools: `execute_davis_analyzer` + `list_davis_analyzers`

Load this skill when user mentions forecasting, anomaly detection, Davis analyzers, or advanced Davis AI analysis.