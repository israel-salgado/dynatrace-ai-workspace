# dynatrace-ai-workspace

An AI-powered observability workspace for Dynatrace — combining GitHub Copilot, the Dynatrace MCP server, and the [dynatrace-for-ai](https://github.com/Dynatrace/dynatrace-for-ai) skills framework to accelerate incident triage, root cause analysis, and day-to-day observability workflows.

> **What this gives you:** Ask Copilot natural language questions about your Dynatrace environment and get accurate, production-aware answers — powered by verified domain knowledge, live API access, and pre-built investigation workflows.

---

## What's Inside

```
dynatrace-ai-workspace/
├── ARCHITECTURE.md               # How the workspace is built and how components connect
├── README.md                     # Setup guide and quick reference
├── skills-lock.json              # Locked skill versions
├── .gitignore
├── .github/
│   ├── copilot-instructions.md   # Auto-loaded workspace rules every Copilot session
│   └── prompts/                  # 7 slash command investigation workflows
│       ├── health-check.prompt.md
│       ├── daily-standup.prompt.md
│       ├── daily-standup-notebook.prompt.md
│       ├── investigate-error.prompt.md
│       ├── troubleshoot-problem.prompt.md
│       ├── incident-response.prompt.md
│       └── performance-regression.prompt.md
├── .agents/skills/               # 13 Dynatrace domain knowledge files
├── .claude/skills/               # Symlinks for Claude Code compatibility
├── .vscode/
│   └── mcp.json                  # Dynatrace MCP server configuration (2 environments)
└── demos/
    └── ai-observability-demo.md  # 15-minute demo script for mixed audiences
```

---

## Prerequisites

| Tool | Purpose |
|---|---|
| [VS Code](https://code.visualstudio.com/) | Editor with Copilot Chat |
| [GitHub Copilot](https://github.com/features/copilot) | AI assistant (subscription required) |
| [Node.js](https://nodejs.org/) v18+ | Required for skills installer and MCP server |
| [dtctl](https://github.com/dynatrace-oss/dtctl) | Dynatrace CLI for notebook verification and resource management |
| A Dynatrace environment | `https://<env>.apps.dynatrace.com` |

---

## Setup

> **Dynatrace employees:** This workspace is pre-configured for the standard
> Dynatrace demo environment (`guu84124.apps.dynatrace.com`). No changes are
> required to run demos against the production demo tenant. Clone the repo,
> reload VS Code, and authenticate via your Dynatrace SSO when prompted.

### 1. Clone the workspace

```bash
git clone git@github.com:virtualrussel/dynatrace-ai-workspace.git
cd dynatrace-ai-workspace
```

Then open the folder in VS Code via **File → Open Folder**.

### 2. Update skills to latest

```bash
npx skills add dynatrace/dynatrace-for-ai
npx skills add dynatrace-oss/dtctl
```

> Run this command any time Dynatrace releases new skills.

### 3. Configure your sprint environment (optional)

The workspace is pre-configured with two MCP servers — the shared demo tenant
(`guu84124`) and a personal sprint tenant. The sprint entry is specific to the
original author and **must be updated** if you want to use your own sprint environment.

Complete all four steps below to fully configure your sprint tenant. Skipping
any step will result in Copilot referencing a server that doesn't exist or
authenticating against the wrong environment.

#### Sprint Tenant Checklist

**Step A — Update `.vscode/mcp.json`**

Replace `<your-tenant-id>` with your personal sprint tenant ID (e.g. `abc12345`):

```json
{
  "servers": {
    "guu84124-mcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@dynatrace-oss/dynatrace-mcp-server@latest", "--stdio"],
      "env": {
        "DT_ENVIRONMENT": "https://guu84124.apps.dynatrace.com"
      }
    },
    "<your-tenant-id>-mcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@dynatrace-oss/dynatrace-mcp-server@latest", "--stdio"],
      "env": {
        "DT_ENVIRONMENT": "https://<your-tenant-id>.sprint.apps.dynatracelabs.com"
      }
    }
  }
}
```

**Step B — Update `.github/copilot-instructions.md`**

Find the MCP server section and update the fallback server name to match
your tenant ID:

```
- **Default MCP Server:** guu84124-mcp
- **Fallback MCP Server:** <your-tenant-id>-mcp
```

Without this update, Copilot's auto-briefing will reference the original
author's sprint server — which won't exist in your workspace.

**Step C — Authenticate dtctl**

```bash
dtctl auth login --context <your-tenant-id> \
  --environment "https://<your-tenant-id>.sprint.apps.dynatracelabs.com"
```

**Step D — Reload VS Code**

Press `Cmd+Shift+P` → `Developer: Reload Window` to register the new MCP server.

> If you only need the shared demo tenant (`guu84124`), skip this section entirely —
> no sprint configuration is required for demos.

### 4. Configure dtctl for the shared demo tenant (optional)

`dtctl` is used for terminal-level verification and resource management. It is
required for the `/daily-standup-notebook` prompt but optional for all other prompts.

```bash
# macOS — direct install (no Homebrew required)
curl -fsSL https://raw.githubusercontent.com/dynatrace-oss/dtctl/main/install.sh | bash

# Authenticate against the shared demo tenant
dtctl auth login --context guu84124 \
  --environment "https://guu84124.apps.dynatrace.com"

# Verify
dtctl doctor
```

### 5. Reload VS Code

Press `Cmd+Shift+P` → `Developer: Reload Window`

When you first use a prompt in Copilot Chat, a browser window will open for
Dynatrace SSO authentication. This is expected — complete the login and return
to VS Code. Subsequent sessions authenticate automatically.

### 6. Verify the connection

In Copilot Chat, type:

```
Using the guu84124-mcp server, list the top 5 services by request volume in the last hour
```

If you see a table of services with request counts — you are live and ready to demo.

---

## Skills

Skills are domain knowledge files that teach Copilot how Dynatrace works — correct DQL syntax, field names, query patterns, and investigation workflows. They load automatically when relevant.

| Skill | What It Covers |
|---|---|
| `dt-dql-essentials` | DQL syntax, common pitfalls, query patterns — **load before any DQL** |
| `dt-obs-problems` | Davis Problems, root cause analysis, impact assessment |
| `dt-obs-logs` | Log queries, filtering, pattern analysis, error classification |
| `dt-obs-tracing` | Distributed traces, spans, failure detection, log correlation |
| `dt-obs-services` | RED metrics, SLA tracking, runtime-specific monitoring (Java, .NET, Node.js, Python, PHP, Go) |
| `dt-obs-hosts` | Host and process metrics, CPU, memory, disk, containers |
| `dt-obs-kubernetes` | Pods, workloads, nodes, labels, ingress, PVCs |
| `dt-obs-aws` | EC2, RDS, Lambda, ECS/EKS, VPC, cost optimization |
| `dt-obs-frontends` | RUM, Web Vitals, user sessions, mobile crashes |
| `dt-app-dashboards` | Dashboard JSON creation and modification |
| `dt-app-notebooks` | Notebook creation and analytics workflows |
| `dt-migration` | Classic entity DQL → Smartscape migration |
| `dtctl` | CLI commands for managing Dynatrace resources from the terminal |

---

## Prompts

Prompts are pre-built investigation workflows available as Copilot slash commands. Type `/` in Copilot Chat to see them.

| Prompt | When to Use |
|---|---|
| `/health-check` | Routine service health — performance, problems, deployments, vulnerabilities |
| `/daily-standup` | Morning team report across multiple services with today vs yesterday comparison |
| `/daily-standup-notebook` | Standup report + Dynatrace notebook creation + dtctl verification |
| `/investigate-error` | "Something is wrong with this service" — error-focused investigation |
| `/troubleshoot-problem` | Deep 7-step investigation into a specific Dynatrace problem |
| `/incident-response` | Full production incident triage — all active problems, prioritized by business impact |
| `/performance-regression` | Did my deployment cause a slowdown? Before vs after comparison with trace analysis |

### Investigation Workflow

The prompts follow a structured drill-down pattern:

```
/health-check          →  flag concerns
/troubleshoot-problem  →  investigate a specific problem
/investigate-error     →  drill into error patterns
/incident-response     →  full triage when things are on fire
```

---

## Key Concepts

### Why Skills Matter

Copilot without skills will guess DQL syntax — and get it wrong. For example, it might use `event.status == "OPEN"` (doesn't exist) instead of `event.status == "ACTIVE"`, or `log.level` instead of `loglevel`. The skills encode the corrections for known failure modes before Copilot writes a single query.

### How MCP Works

The Dynatrace MCP server gives Copilot live API access to your environment. When you run `/health-check`, Copilot calls the MCP server to execute real DQL queries and return live data — not cached or synthetic results.

### The Investigation Rule

**Always start with problems, never with broad log searches.** Broad log queries without a problem context will hit Dynatrace's 500GB scan limit and return zero results. The prompts enforce this automatically.

---

## Optional: dtctl CLI

[dtctl](https://github.com/dynatrace-oss/dtctl) is a kubectl-style CLI for Dynatrace that complements this workspace — giving you terminal-level access to run DQL queries, manage workflows, verify notebooks, and more.

```bash
# macOS (direct install — no Homebrew required)
curl -fsSL https://raw.githubusercontent.com/dynatrace-oss/dtctl/main/install.sh | bash

# Authenticate against the shared demo tenant
dtctl auth login --context guu84124 \
  --environment "https://guu84124.apps.dynatrace.com"

# Verify
dtctl doctor

# Example commands
dtctl get workflows
dtctl get notebooks
dtctl query 'fetch dt.davis.problems | filter event.status == "ACTIVE" | limit 5'
```

---

## Keeping Up to Date

```bash
# Update all skills to latest
npx skills add dynatrace/dynatrace-for-ai
npx skills add dynatrace-oss/dtctl

# Commit the updates
git add .
git commit -m "Update skills to latest"
git push
```

---

## Related Resources

- [ARCHITECTURE.md](./ARCHITECTURE.md) — How the workspace components connect
- [dynatrace-for-ai](https://github.com/Dynatrace/dynatrace-for-ai) — Skills and prompts source repo
- [dtctl](https://github.com/dynatrace-oss/dtctl) — Dynatrace CLI for humans and AI agents
- [Dynatrace MCP Server](https://docs.dynatrace.com/docs/shortlink/dynatrace-mcp-server) — Official MCP server docs
- [Agent Skills spec](https://agentskills.io) — The open standard this workspace follows

---

## License

Skills and prompts sourced from [dynatrace-for-ai](https://github.com/Dynatrace/dynatrace-for-ai) and [dtctl](https://github.com/dynatrace-oss/dtctl) are Apache-2.0 licensed.
