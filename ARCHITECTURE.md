# Architecture Overview

This document explains what this workspace is, how it is built, and how the components work together. It is intended for anyone who wants to understand the solution before using it.

---

## What This Is

A pre-configured AI observability workspace that connects GitHub Copilot to Dynatrace — enabling natural language investigation of production systems directly from VS Code.

Instead of logging into Dynatrace, navigating dashboards, and writing queries manually, you type a slash command in Copilot Chat and receive structured, accurate, production-aware answers in seconds.

---

## The Problem It Solves

GitHub Copilot is a general-purpose AI assistant. Without domain-specific knowledge it will:
- Guess DQL syntax — and get it wrong
- Use field names that don't exist (`log.level` instead of `loglevel`)
- Write queries that hit scan limits and return zero results
- Have no access to your live Dynatrace data

This workspace solves all four problems by combining three things: domain knowledge, live data access, and pre-built workflows.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    VS Code                              │
│                                                         │
│  ┌─────────────────┐      ┌──────────────────────────┐  │
│  │  Copilot Chat   │      │   Integrated Terminal    │  │
│  │                 │      │                          │  │
│  │  /health-check  │      │  dtctl get workflows     │  │
│  │  /troubleshoot  │      │  dtctl query "..."       │  │
│  │  /standup       │      │  dtctl describe notebook │  │
│  └────────┬────────┘      └────────────┬─────────────┘  │
│           │                            │                │
│  ┌────────▼────────┐                   │                │
│  │  Agent Skills   │                   │                │
│  │  (13 skills)    │                   │                │
│  │  .agents/skills/│                   │                │
│  └────────┬────────┘                   │                │
└───────────┼────────────────────────────┼────────────────┘
            │ MCP (stdio)                │ HTTPS + OAuth
            ▼                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Dynatrace Platform                         │
│                                                                 │
│   guu84124.apps.dynatrace.com  (production, public baseline)    │
│   <TENANTID>.<class>.dynatrace[labs].com  (any other)           │
│                                                                 │
│   Grail data lakehouse — logs, spans, metrics, events           │
│   Davis AI — problem detection, root cause analysis             │
│   Notebooks, Dashboards, Workflows                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Four Components

### 1. Agent Skills
**Source:** [github.com/Dynatrace/dynatrace-for-ai](https://github.com/Dynatrace/dynatrace-for-ai) + [github.com/dynatrace-oss/dtctl](https://github.com/dynatrace-oss/dtctl)
**Location:** `.agents/skills/`

Skills are markdown files containing domain-specific knowledge. They teach Copilot how Dynatrace works — correct DQL syntax, field names, query patterns, and investigation workflows. Copilot loads them automatically when relevant, using a three-tier progressive disclosure model:

```
Tier 1 — Catalog     Always loaded    ~100 tokens per skill
Tier 2 — SKILL.md    On demand        ~5,000 tokens
Tier 3 — references/ On demand        Deep reference detail
```

This means all 13 skills can be installed without performance penalty — Copilot only loads what it needs for each specific query.

| Skill | Domain |
|---|---|
| `dt-dql-essentials` | DQL syntax, pitfalls, query patterns — required before any DQL |
| `dt-obs-problems` | Davis Problems, root cause analysis, impact assessment |
| `dt-obs-logs` | Log queries, filtering, error classification |
| `dt-obs-tracing` | Distributed traces, spans, failure detection |
| `dt-obs-services` | RED metrics, SLA tracking, runtime monitoring |
| `dt-obs-hosts` | Host and process metrics |
| `dt-obs-kubernetes` | Pods, workloads, nodes, cluster health |
| `dt-obs-aws` | EC2, RDS, Lambda, ECS/EKS, cost optimization |
| `dt-obs-frontends` | RUM, Web Vitals, user sessions, mobile crashes |
| `dt-app-dashboards` | Dashboard JSON creation and modification |
| `dt-app-notebooks` | Notebook creation and analytics workflows |
| `dt-migration` | Classic entity DQL → Smartscape migration |
| `dtctl` | CLI commands for managing Dynatrace resources |

---

### 2. MCP Server
**Source:** [github.com/dynatrace-oss/dynatrace-mcp](https://github.com/dynatrace-oss/dynatrace-mcp)
**Location:** `.vscode/mcp.json`

The Model Context Protocol (MCP) server is the live data bridge between Copilot and Dynatrace. When Copilot needs to answer a question about your environment, it calls the MCP server, which executes real API calls and DQL queries against your Dynatrace tenant and returns live results.

This workspace runs **one** local MCP server (launched via `.mcp.json`). Each named entry in `.mcp.json` is just a **tenant routing** — a different `DT_ENVIRONMENT` for that same server, so Copilot can talk to multiple tenants by name without launching multiple servers:

```json
demo.live   →  https://guu84124.apps.dynatrace.com               (production, public baseline, committed)
<NICKNAME>  →  https://<TENANTID>.<class>.dynatrace[labs].com    (added per machine, not committed)
```

Only the public baseline routing (`guu84124`) is committed to the repo.

- Additional tenant routings (private tenant IDs/URLs) must be configured **locally per machine** in your working copy of `.vscode/mcp.json` and `.mcp.json`.
- **Never commit** those private routings to Git.
- The canonical place to record tenant metadata (nickname, id, url, class, safety) is the local-only registry at `temp_dtctl_files/tenant-memory/tenants.json`.

If you edit `.vscode/mcp.json` / `.mcp.json` locally, consider protecting yourself from accidental staging with:

```bash
git update-index --skip-worktree .vscode/mcp.json .mcp.json
```

Authentication uses OAuth browser SSO — no API tokens or credentials are stored in the workspace. To target a specific environment in a Copilot session:

```
"Use the demo.live server for all queries"
```

---

### 3. Prompt Templates
**Source:** [github.com/Dynatrace/dynatrace-for-ai/prompts](https://github.com/Dynatrace/dynatrace-for-ai/tree/main/prompts) + built in this session
**Location:** `.github/prompts/`

Prompts are pre-built investigation workflows saved as slash commands. They combine skills with structured instructions — telling Copilot what to do, in what order, and with what guardrails. Type `/` in Copilot Chat to see all available prompts.

| Prompt | Purpose | When to Use |
|---|---|---|
| `/health-check` | Service health snapshot | Routine morning check or before a deployment |
| `/daily-standup` | Multi-service report with today vs yesterday comparison | Team standup preparation |
| `/daily-standup-notebook` | Standup report + Dynatrace notebook + dtctl verification | Full documented standup workflow |
| `/investigate-error` | Error-focused investigation from a service name | "Something is wrong with this service" |
| `/troubleshoot-problem` | Structured 7-step deep dive into a specific problem | Known problem needing root cause |
| `/incident-response` | Full triage of all active problems by business impact | Active production incident |
| `/performance-regression` | Before vs after deployment comparison | Post-deployment validation |

#### The Investigation Workflow

Prompts are designed to chain together as an investigation deepens:

```
/health-check              Flag concerns across a service
       ↓
/troubleshoot-problem      Investigate a specific problem deeply
       ↓
/investigate-error         Drill into error patterns and traces
       ↓
/incident-response         Full triage if situation escalates
```

#### Key Guardrails Built Into Prompts

The `troubleshoot-problem` and `daily-standup-notebook` prompts encode operational rules learned from real usage:

- **Always start with problems** — never run broad log searches without problem context (hits 500GB scan limit)
- **No `#` or `--` comments in DQL** — invalid syntax that causes parse errors
- **`timeseries` uses `=` not `as`** for aliasing
- **`timeseries` filters use `==` with `by:` dimension** — not `contains()`
- **Array notation required** for computed fields after `timeseries`

---

### 4. Session Briefing Files
**Locations:** `.github/copilot-instructions.md` (GitHub Copilot) · `CLAUDE.md` (Claude Code)

Both files are automatically loaded at the start of every AI session in this workspace. They act as a standing briefing — the AI already knows the default MCP environment, the investigation rule, and the available prompts before a single word is typed.

Each file contains:
- Default and fallback MCP server
- Global rule: always start with problems, never broad log searches
- Prompt directory — all 7 slash commands and when to use them
- Note that 13 skills are installed and load automatically

The two files are identical in content but kept separate because each tool requires a specific path:
- GitHub Copilot reads only `.github/copilot-instructions.md`
- Claude Code reads only `CLAUDE.md` at the repo root

They now reference the committed `CONVENTIONS.md` (single source of truth for workspace/temp rules, Live State Reconciliation & Conflict Protection, Sync Checklist). `dt-dql-essentials/SKILL.md` and `dt-app-notebooks/SKILL.md` are the canonical references for their domains. The memory file holds only lightweight AI-side notes.

---

### 5. dtctl CLI
**Source:** [github.com/dynatrace-oss/dtctl](https://github.com/dynatrace-oss/dtctl)
**Installation:** `/usr/local/bin/dtctl`

`dtctl` is a kubectl-style command-line tool for Dynatrace. It complements the Copilot + MCP workflow by providing direct terminal access to Dynatrace resources — running DQL queries, managing workflows, verifying notebooks, and more.

In this workspace, `dtctl` is used primarily for **verification** — confirming that notebooks and other artifacts created by Copilot via MCP actually exist and are correctly structured in Dynatrace.

```bash
dtctl get notebooks                    # List all notebooks
dtctl describe notebook "name"         # Inspect notebook structure
dtctl query 'fetch dt.davis.problems   # Run DQL directly
  | filter event.status == "ACTIVE"
  | limit 5'
dtctl get workflows                    # List all workflows
dtctl doctor                           # Verify authentication and connectivity
```

Three authenticated contexts are configured:

```
demo.live    →  production  (public baseline, committed)
<NICKNAME>   →  any class   (added locally per machine)
<TENANTID>   →  any class   (added locally per machine)
```

Switch between them with either the nickname or the raw tenant ID:
```bash
dtctl config use-context demo.live
dtctl config use-context <NICKNAME>      # e.g. "lab", resolved via tenant-memory/tenants.json
dtctl config use-context <TENANTID>      # raw 8-char tenant ID, always works
```

**Nickname resolution.** When you say *"switch to <NICKNAME>"* in chat, the agent resolves the short name via the local-only registry at `temp_dtctl_files/tenant-memory/tenants.json` (auto-created on first use, gitignored). It looks up the matching `id` / `url` / `class` / `safety`, echoes a one-line confirmation (`Switching context → <NICKNAME> · <TENANTID> · <class> · <safety>`), then runs `dtctl config use-context <TENANTID>`. Ambiguous or fuzzy names are never auto-resolved — the agent asks first. See `CONVENTIONS.md` → *Connecting to a New Tenant* and *Local Tenant Nickname Registry* for the full procedure (URL options, safety levels, save/update rules).

---

## How It All Works Together

Here is the complete flow for a typical `/daily-standup-notebook` session:

```
1. You type /daily-standup-notebook in Copilot Chat

2. Copilot loads copilot-instructions.md
   → Knows to use demo.live by default
   → Knows the investigation rules and DQL guardrails

3. Copilot loads relevant skills
   → dt-obs-services  (RED metrics)
   → dt-obs-problems  (active problems)
   → dt-app-notebooks (notebook structure)
   → dtctl            (verification commands)

4. Copilot calls demo.live
   → Executes live DQL queries against production
   → Retrieves metrics, problems, and deployment data

5. Copilot generates the standup report
   → Today vs yesterday metric comparison
   → Active problems and incidents
   → Action items per service

6. Copilot creates a Dynatrace notebook via MCP
   → Executive summary
   → Per-service findings
   → Embedded live DQL queries
   → Prioritised remediation steps

7. dtctl verifies the notebook
   → dtctl get notebooks confirms it exists
   → dtctl describe notebook confirms structure
   → Shareable URL returned
```

---

## Keeping the Workspace Up to Date

Skills are versioned via `skills-lock.json`. Update to the latest skills before important demos or after Dynatrace releases new features:

```bash
npx skills add dynatrace/dynatrace-for-ai
npx skills add dynatrace-oss/dtctl
git add .
git commit -m "Update skills to latest — $(date +%Y-%m-%d)"
git push
```

Update `dtctl` by following the upgrade instructions in the dtctl repo: **[github.com/dynatrace-oss/dtctl](https://github.com/dynatrace-oss/dtctl)** (Homebrew, install script, or `go install` — whichever method you used originally).

---

## Source References

### Reference Extraction Pattern
- Use `reference/official/` to hold copies of key files from the official MCP server (`davis-analyzers.ts`, `execute-dql.ts`, `notebooks.ts`, `send-event.ts`, etc.).
- Extract patterns (interfaces, execution logic, metadata handling, error patterns) into dedicated skills (`dt-davis-analyzers`, `dt-obs-events`, updates to `dt-dql-essentials` and `dt-app-notebooks`).
- This keeps the workspace scalable for future official MCP enhancements while preserving our skill-based architecture and guardrails.

## Source References

| Component | Source |
|---|---|
| 13 Dynatrace skills | [github.com/Dynatrace/dynatrace-for-ai](https://github.com/Dynatrace/dynatrace-for-ai) |
| 6 investigation prompts | [github.com/Dynatrace/dynatrace-for-ai/prompts](https://github.com/Dynatrace/dynatrace-for-ai/tree/main/prompts) |
| MCP server package | [github.com/dynatrace-oss/dynatrace-mcp](https://github.com/dynatrace-oss/dynatrace-mcp) |
| dtctl CLI + skill | [github.com/dynatrace-oss/dtctl](https://github.com/dynatrace-oss/dtctl) |
| copilot-instructions.md | Lean session briefing auto-loaded by GitHub Copilot |
| CLAUDE.md | Lean session briefing auto-loaded by Claude Code |
| ELI5.md | Beginner-friendly 15-minute install guide |
| daily-standup-notebook prompt | Built in this session with DQL guardrails from live testing |
