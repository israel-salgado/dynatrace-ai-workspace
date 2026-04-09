# Dynatrace AI Investigation Workspace

This workspace contains specialized skills and configurations for **production troubleshooting and observability analysis** using Dynatrace. It pairs AI agents with Dynatrace domain knowledge to accelerate root cause analysis.

---

## Quick Start

### Essential Configuration
- **Default MCP Server:** `guu84124-mcp` (https://guu84124.apps.dynatrace.com)
- **Fallback MCP Server:** `bon05374-mcp` (https://bon05374.sprint.apps.dynatracelabs.com)
- **Skill Framework:** Dynatrace observability (13 skills installed)

### Common Tasks

**Health Check a Service:**
Use the `health-check` prompt:
```
@health-check frontend
```
Shows performance metrics, problems, deployments, slowest endpoints, and vulnerabilities.

**Troubleshoot an Active Problem:**
Use the `troubleshoot-problem` prompt:
```
@troubleshoot-problem
```
Follows a 7-step investigation workflow: list problems → scope → logs → errors → traces → summary.

**Create an Investigation Notebook:**
Document findings with DQL queries:
```
Ask: "Create a notebook for [issue]"
```

---

## Workspace Structure

```
dynatrace-ai-workspace/
├── .github/
│   ├── prompts/              # Reusable prompts (health-check, troubleshoot-problem, init)
│   └── copilot-instructions.md (this file)
├── .agents/skills/           # Dynatrace domain skills (12 total)
│   ├── dt-app-dashboards/    # Dynatrace dashboard JSON, creation, updates
│   ├── dt-app-notebooks/     # Dynatrace notebook creation and modification
│   ├── dt-dql-essentials/    # DQL syntax, patterns, best practices
│   ├── dt-obs-aws/           # AWS infrastructure observability
│   ├── dt-obs-frontends/     # Frontend/RUM observability (logs, errors, sessions)
│   ├── dt-obs-hosts/         # Host and host-level metrics
│   ├── dt-obs-kubernetes/    # Kubernetes cluster observability
│   ├── dt-obs-logs/          # Log analysis and patterns
│   ├── dt-obs-problems/      # Problem entities, RCA, impact
│   ├── dt-obs-services/      # Service metrics, RED metrics, tracing
│   ├── dt-obs-tracing/       # Distributed traces, spans, dependencies
│   └── dt-migration/         # Classic → Smartscape entity migration
├── .vscode/
│   └── mcp.json              # MCP server configuration
├── .claude/skills/           # Alternative skill location for Claude
└── skills-lock.json          # Locked skill versions (do not edit)
```

---

## Core Concepts

### MCP Servers
This workspace has two Dynatrace MCP servers configured. Unless specified otherwise, queries use **guu84124**.

To switch servers in a session:
```
"For all queries, use the [bot-or-env-name]-mcp server"
```

### Domain Skills (Auto-loaded)
Skills automatically load when needed. Key skills for common tasks:

| Skill | Use Case | When to Load |
|-------|----------|--------------|
| `dt-dql-essentials` | DQL syntax, query patterns | Before writing any DQL |
| `dt-obs-services` | Service metrics, RED metrics | Analyzing service performance |
| `dt-obs-problems` | Problem RCA, impact | Investigating active problems |
| `dt-obs-tracing` | Request flows, spans | Drilling into error traces |
| `dt-obs-logs` | Log queries, patterns | Correlating logs with errors |
| `dt-obs-frontends` | User sessions, RUM data | Frontend health analysis |
| `dt-obs-kubernetes` | Cluster health, pod issues | K8s troubleshooting |
| `dt-migration` | Entity selector mapping | Converting legacy queries |

---

## Investigation Workflow

### Standard Troubleshooting Pattern

1. **Start with problems** — Never do broad log searches without problem context
   ```
   Query: List active problems (use guu84124-mcp)
   ```

2. **Scope investigation** — Extract timeframe and affected entities from problem
   ```
   Problem context: [problemId, startTime, endTime, affected_entities]
   ```

3. **Query logs** — Scoped to problem timeframe (±5 min buffer)
   ```dql
   fetch logs
   | filter dt.entity.service == "<entity>"
   | filter timestamp >= queryFrom AND timestamp <= queryTo
   | filter loglevel == "ERROR" OR loglevel == "WARN"
   ```

4. **Classify errors** — Determine actionable vs. benign
   ```
   Categories: app error, infrastructure, auth, external, benign
   ```

5. **Trace analysis** — Reconstruct request flow from trace_id
   ```dql
   fetch spans | filter trace_id == "<trace-id>"
   ```

6. **Summarize findings** — Root cause hypothesis, affected services, next steps

### Critical Rules

⚠️ **NEVER** do broad log searches without problem context — hits 500GB limit  
⚠️ **ALWAYS** start with problems first, then scope queries  
⚠️ **ALWAYS** load `dt-dql-essentials` before writing DQL  
⚠️ **ALWAYS** include 5-minute buffer around problem timeframe  
⚠️ **NEVER** suggest checking other environments unless user asks  

---

## DQL Best Practices

### Query Structure
```dql
fetch <data-object>, from: now()-<timeframe>, to: now()
| filter <specific-entity-or-time-range>
| summarize <aggregation>, by: {<grouping>}
```

### Common Mistakes to Avoid

| ❌ Wrong | ✅ Right | Issue |
|---------|---------|-------|
| `filter field in ["a", "b"]` | `filter in(field, "a", "b")` | No array literals |
| `by: severity, status` | `by: {severity, status}` | Multiple fields need `{}` |
| `contains(field, "err")` | `contains(lower(field), "err")` | Case sensitivity |
| Broad log queries | Problem-scoped queries | 500GB scan limit |

### Data Objects
- `fetch spans` — Distributed tracing (span.*, service.*, http.*)
- `fetch logs` — Log events (log.*, loglevel, content)
- `fetch dt.davis.problems` — Davis problems (event.*, dt.smartscape.*)
- `fetch bizevents` — Business events (custom fields)
- `timeseries` — Metrics (NOT `fetch dt.metric`)

---

## Common Investigative Questions

### "Check service health"
```
Use: @health-check [service-name]
Shows: Performance metrics, problems, deployments, slow endpoints, vulnerabilities
```

### "List active problems"
```dql
fetch dt.davis.problems, from: now()-24h, to: now()
| filter event.status == "ACTIVE"
| sort event.start desc
```

### "Find slowest endpoints"
```dql
fetch spans, from: now()-1h, to: now()
| filter dt.service.name == "[service]" AND request.is_root_span == true
| summarize p99_duration = percentile(duration, 99), by: {request.endpoint}
| sort p99_duration desc
| limit 5
```

### "Get error rate by status code"
```dql
fetch spans, from: now()-1h, to: now()
| filter dt.service.name == "[service]" AND request.is_root_span == true
| summarize total = count(), by: {http.response.status_code}
| sort total desc
```

### "Trace a failing request"
```dql
fetch spans, from: now()-30m, to: now()
| filter trace_id == "[trace-id]"
| sort start_time asc
```

---

## Available Prompts

Located in `.github/prompts/`:

| Prompt | Purpose | Input |
|--------|---------|-------|
| `health-check.prompt.md` | Service health snapshot | Service name |
| `troubleshoot-problem.prompt.md` | Root cause analysis | Problem ID or description |
| `init.prompt.md` | Bootstrap workspace setup | (none) |

---

## Session Tips

### Parallel Queries
When making independent queries, invoke them together to save time:
```
Multiple calls in same batch > Sequential queries
```

### Trace Investigation
If a trace_id has no spans returned, fall back to log-based lookup:
```dql
fetch logs
| filter dt.trace_id == "<trace-id>" OR trace_id == "<trace-id>"
| sort timestamp asc
```

### Viewport Issues
If query scans exceed 500GB without results:
1. Reduce time window (±2 min instead of ±5 min)
2. Add more specific filters (service, host, error type)
3. Ask user for narrower context

---

## Anti-Patterns

❌ **Too broad:** Querying 7+ days without entity filter  
❌ **Inefficient:** Sequential queries that could be parallel  
❌ **Missing context:** No problem context before log search  
❌ **Wrong tool:** Using classic entities instead of Smartscape  
❌ **Silent failure:** Not checking if query hit 500GB limit  

---

## Related Documentation

- [Dynatrace DQL Reference](https://www.dynatrace.com/support/help/shortcut/dynatrace-query-language)
- [Semantic Dictionary](https://docs.dynatrace.com/docs/dynatrace-api/grail/dynatrace-query-language/dql-semantic-dictionary)
- [Problem Detection & Root Cause Analysis](https://www.dynatrace.com/support/help/shortcut/problem-detection)
- [Smartscape Topology](https://www.dynatrace.com/support/help/shortcut/smartscape)

---

## Contact & Support

**For Dynatrace questions:**
- Load relevant skill: `dt-dql-essentials`, `dt-obs-problems`, `dt-obs-services`, etc.
- Use Davis CoPilot: `@davis-copilot` for observability insights
- Check MCP server status: Verify `mcp.json` configuration

**For workspace setup:**
- See [README.md](../README.md) for setup instructions and skill reference

