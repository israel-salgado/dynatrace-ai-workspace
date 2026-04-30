# Dynatrace AI Workspace — Session Briefing

## Governing Reference for Tenant Interaction (Agent-Agnostic)

**The single governing reference file for GitHub Copilot is `.github/copilot-instructions.md` (auto-loaded at session start). For Claude it is `CLAUDE.md`. Both are kept in sync.**

This file (and its counterpart) defines **exactly** how any agent interacts with a Dynatrace tenant:
- Default/fallback MCP servers (the live bridge to the tenant via the Model Context Protocol).
- How to switch tenants/contexts when changing agents.
- Global rule, available prompts, skills, notebook guardrails, and agent-agnostic DQL rules.

**Baseline tenant.** `guu84124` (production, public URL `demo.live.dynatrace.com`) is the only tenant ID referenced in this repo's source files — it is publicly reachable and safe to demo. The local nickname registry may seed it as `demo.live` (matching the public URL), but this is purely a convenience; the user may rename it or skip it entirely.

**Session start.** The agent reports the active tenant context in one line, using whichever path(s) are configured (resolving via the local nickname registry where possible). Neither path is required — use whichever is present:
- **dtctl configured** → run `dtctl config current-context` and emit `Active dtctl context: <NICKNAME> · <TENANTID> · <class> · <safety>`. dtctl's active context is **persistent on disk** (carries over between VS Code sessions), so the agent does **not** auto-switch.
- **MCP configured** → list the configured MCP server(s) from `.vscode/mcp.json` / `.mcp.json` and emit `Active MCP server: <NICKNAME> · <TENANTID>` (one line per server if multiple).
- **Both configured** → emit one line for each. There is no "default tenant."

**Switch context** (preferred → nickname; fallback → raw tenant ID). The same nickname resolves both paths — single identity, two routes:
```
"switch to <NICKNAME>"             # dtctl: dtctl config use-context <id>
"use the <NICKNAME> server, …"      # MCP: select that server entry in chat
"switch to <TENANTID>"             # raw 8-char ID always works for dtctl
```
For dtctl switches the agent always echoes a one-line confirmation (`Switching context → <NICKNAME> · <TENANTID> · <class> · <safety>`) before running `dtctl config use-context`. For MCP-only sessions no `use-context` exists — the user picks the server by name in chat. Ambiguous or fuzzy names are never auto-resolved on either path.

**Connecting to a brand-new tenant.** Two independent procedures — dtctl (Path A) and MCP server entry (Path B). The user may want one, the other, or both. See `CONVENTIONS.md` → *Connecting to a New Tenant* for the full dual procedure (Path A: prompt for URL + safety level, run `dtctl auth login`, verify; Path B: add a parallel server entry to both `.vscode/mcp.json` and `.mcp.json`, reload MCP, verify with `get_environment_info`). Quick reference also in `CHEATSHEET.md` → *Session Management*.

**Local tenant nickname registry**: when the user says *"switch to <NICKNAME>"* using a short name, resolve it via `temp_dtctl_files/tenant-memory/tenants.json` per `CONVENTIONS.md` → *Local Tenant Nickname Registry*. Never auto-resolve ambiguous or fuzzy matches — always ask. The registry is local-only and never committed.

**Clickable options for short choices.** Use `vscode_askQuestions` for any short fork-in-the-road (2–6 options); leave freeform input on. Use plain text for explanations and multi-paragraph recommendations. (See `CONVENTIONS.md` → *Agent Behavior*.)

**Mandatory agent initialization sequence** (review files first, then run/validate):
1. Read this file + `copilot-instructions.md` + `CONVENTIONS.md` + `ARCHITECTURE.md`.
2. **ALWAYS load `.agents/skills/dt-dql-essentials/SKILL.md` FIRST** (before any DQL).
3. Review **all** relevant workspace files (the active tenant's folder under `temp_dtctl_files/tenant-memory/<TENANTID>/` and any per-type subfolder relevant to the task, skills).
4. For tenant context, use whichever path(s) the user has configured — do not assume dtctl is present:
   - **dtctl path**: `dtctl config current-context` + `dtctl auth whoami --plain`.
   - **MCP path**: list configured MCP servers from `.vscode/mcp.json` / `.mcp.json`, and call `get_environment_info` / `find_entity_by_name` against the active one.
5. Apply the *Tool Selection* rubric below when picking between MCP and dtctl for a given task. Follow the Global Rule and rules in `CONVENTIONS.md` strictly. No tenant-specific names/IDs in root source files.

See `CONVENTIONS.md` for full Workspace & Temp File Conventions, Live State Reconciliation & Conflict Protection, DQL rules, and Sync Checklist.

This ensures identical, predictable behavior across agent switches.

See `CONVENTIONS.md` for full details on Workspace & Temp File Conventions, Live State Reconciliation & Conflict Protection, DQL rules, Sync Checklist, and agent behavior.

## Environment

| | |
|---|---|
| **Baseline tenant routing** | `demo.live` → https://guu84124.apps.dynatrace.com (public, only tenant ID in repo source) |

This workspace is an MCP repo at heart — it configures and ships skills/prompts/conventions on top of the Dynatrace MCP server (one local server launched from `.mcp.json` and `.vscode/mcp.json`; entries there are tenant routings of that one server). It is also configured **assuming the user has `dtctl` installed alongside MCP** so the agent can use the best of both. `dtctl` is a separate project in a separate repo (`github.com/dynatrace-oss/dtctl`) — nothing in this repo builds or vendors it. Add more tenants per machine via either path (or both): MCP server entry in `mcp.json` files, and/or `dtctl auth login`. See `CONVENTIONS.md` → *Connecting to a New Tenant* (Path A and Path B) and *Local Tenant Nickname Registry*.

## Tool Selection (MCP vs dtctl)

Both paths can do most read/query/edit work. The full capability matrix lives in [README.md](README.md#two-paths-to-dynatrace) → *Two paths to Dynatrace*; the canonical rubric lives in `CONVENTIONS.md` → *Tool Selection*. Quick decision guide:

- **Prefer MCP** for: Davis CoPilot chat, Davis Analyzers, ad-hoc Slack/email from chat, ingesting custom events (`send_event`), resetting Grail budget, NL→DQL helpers, structured-JSON-direct-to-the-AI tasks.
- **Prefer `dtctl`** for: declarative `apply`/`diff`/`history`/`restore`, `share`/`unshare`, persistent multi-context with safety levels, custom output formats (yaml/csv/toon/wide), `dtctl skills install`, anything the user wants to **see** in the terminal.
- **Either works** for: DQL queries, reading entities (services/hosts/problems/vulnerabilities/Kubernetes/RUM), creating/editing notebooks, dashboards, workflows, settings.

When in doubt: continuity (use what the user just used) → configured-only path → ask once if both are configured.

## Always-On Behaviors

These rules apply every turn, regardless of topic. Topic-specific rules (DQL syntax, notebook structure, etc.) live in their respective sections below.

- **Echo every tenant context switch.** For dtctl switches: one-line confirmation (`Switching context → <NICKNAME> · <TENANTID> · <class> · <safety>`) before running `dtctl config use-context`. For MCP server selection in chat: echo `Using MCP server → <NICKNAME> · <TENANTID>` once before the first call. Never auto-resolve ambiguous or fuzzy nicknames — always ask.
- **Clickable options for short choices.** Use `vscode_askQuestions` for any 2–6-option fork-in-the-road; leave freeform input on. Use plain text for explanations and multi-paragraph recommendations.
- **File-system boundaries.** Default scope is the workspace folder. Reads outside the workspace require a stated plain-language reason first; writes outside the workspace require explicit user permission. Subagents inherit this rule. Full details in `CONVENTIONS.md` → *File-System Boundaries*.
- **Live-state reconciliation before any modification.** Before any `dtctl apply`, MCP update, or write to a Dynatrace resource (notebook, dashboard, workflow, settings), re-export that resource's live state by ID first. Smart-merge unrelated user UI edits; stop and ask only on conflicting overwrites (options: stop / let AI overwrite / do something else). Keep a timestamped before-user-edit snapshot for revert.
- **Always start with problems — never broad log searches.** See `## Global Rule` below for full text.
- **Load `.agents/skills/dt-dql-essentials/SKILL.md` before any DQL.** Including dashboards and notebooks. Non-negotiable.
- **Run `scripts/validate-tenant-write.ps1` before any tenant write.** Targeted at the single resource being modified.
- **Keep root source files generic.** No tenant-specific names or IDs in root source files. Tenant artifacts live only in `temp_dtctl_files/tenant-memory/<TENANTID>/` (one folder per tenant, gitignored).
- **Any file whose contents come from a tenant lives in that tenant's folder.** Rule applies to every output derived from a `dtctl`/MCP call — schema dumps, query results, Davis transcripts, entity lists, scratch grep output, anything. Landing zones: structured resources with an ID → `tenant-memory/<TENANTID>/<type>/<id>.json`; loose/scratch tenant data → `tenant-memory/<TENANTID>/scratch/` (auto-create); tenant notes → `tenant-memory/<TENANTID>/notes.md`; tenant-agnostic followups → `temp_dtctl_files/followup-items/`. Same rule governs terminal redirects (`> filename`). Never write tenant-derived data to repo root, `scripts/`, `.agents/`, `docs/`, or any other source folder. If unsure which zone fits, ask before writing.
- **Tenant isolation is absolute (cross-tenant data movement is forbidden).** Each Dynatrace tenant is a sealed island. Never read data, IDs, names, queries, entity references, dashboards, notebooks, settings, or any artifact from one tenant and embed, transform, copy, apply, or even *reference* it in another tenant's context. The agent treats each tenant as if it knows nothing about any other tenant. If the user asks for cross-tenant comparison, refuse and explain — only the user can manually carry findings across. Per-tenant artifacts live exclusively under `temp_dtctl_files/tenant-memory/<TENANTID>/` and never leave that folder.
- **Mandatory dual-context echo before any tenant write.** Before any `dtctl apply`, MCP `update_*`/`create_*`/`send_*`, or write to a Dynatrace resource, emit one block on its own line and verify all three agree:
  ```
  Target tenant write → dtctl: <NICKNAME> · <TENANTID> · <class> · <safety>
                         MCP : <SERVER-NICKNAME> · <TENANTID>   (or "none selected this turn")
                         File: temp_dtctl_files/tenant-memory/<TENANTID>/<path>
                         Status: OK ✓   (or STOP ✗ on any disagreement)
  ```
  If `dtctl` context, selected MCP server, and file folder do not all point to the same `<TENANTID>` (or one path is unused), **stop and ask** before writing. Files outside `temp_dtctl_files/tenant-memory/<TENANTID>/` may not be applied to a tenant.
- **Session reset on tenant switch.** When the user switches dtctl context or selects a different MCP server, immediately declare: *"Tenant changed → discarding in-memory references to entities, IDs, queries, and findings from the previous tenant."* Do not carry forward any tenant-specific facts, names, IDs, or analysis from the prior tenant into the new one.
- **Repo memory stays generic.** `/memories/repo/` may only contain workspace-wide patterns and lessons that are true for all tenants. Tenant-specific facts (entity names, IDs, known issues, owners) go only in `temp_dtctl_files/tenant-memory/<TENANTID>/notes.md` (gitignored).

## Global Rule

**Always start with problems — never run broad log searches.**
Broad queries without problem context hit Dynatrace's 500GB scan limit and return zero results.
All investigation workflows enforce this automatically.

## Prompts

Type `/` in Copilot Chat to access these slash commands:

| Prompt | When to use |
|---|---|
| `/health-check` | Routine service health — metrics, problems, deployments, vulnerabilities |
| `/daily-standup` | Morning report across services — today vs yesterday comparison |
| `/daily-standup-notebook` | Standup report + Dynatrace notebook creation + dtctl verification |
| `/investigate-error` | Error-focused investigation from a service name |
| `/troubleshoot-problem` | Deep 7-step investigation into a specific Dynatrace problem |
| `/incident-response` | Full triage of all active problems during a live incident |
| `/performance-regression` | Before vs after deployment comparison with rollback/hotfix recommendation |

## Skills

17 domain knowledge skills are installed in `.agents/skills/`. They load automatically when relevant — no manual loading required.

## Notebook (and App) Update Contract

This workspace follows a per-tenant per-resource smart reconciliation contract (full details in `CONVENTIONS.md`):

- One file per resource at `temp_dtctl_files/tenant-memory/<TENANTID>/<type>/<id>.json` with a top-level `_tenant` marker. Per-type subfolders (`notebooks/`, `dashboards/`, `workflows/`, `settings/`, …) and `snapshots/` are auto-created on first use. The retired `temp_<type>_files/` + `current-<type>.json` pattern is no longer used.
- Target **only the specific resource** being modified. Refresh that single resource from the tenant before edit (`dtctl get <type> <id> -o json` written to its file).
- On user UI edits: give 1-2 sentence summary. Smart-merge unrelated changes into the local JSON. Stop and ask (stop / let AI overwrite / do something else) only on conflicting overwrites.
- Keep a timestamped before-user-edit snapshot at `tenant-memory/<TENANTID>/snapshots/<type>-<id>-<timestamp>.json` for revert.
- Prefer JSON payloads, ID-based operations, explicit DQL metadata, re-export + verify after apply.

**File-System Boundaries**: Default scope for all file operations is the **workspace folder** (wherever the user installed it). Reads outside the workspace are allowed when there is a clear, legitimate reason — but the agent must state the reason in plain language first so the user can approve or deny. Writes outside the workspace always require explicit user permission and a stated reason. When in doubt, copy needed material into the active tenant's folder under `temp_dtctl_files/tenant-memory/<TENANTID>/` and work locally. Subagents inherit this rule. Full details in `CONVENTIONS.md` → *File-System Boundaries*.

**`temp_dtctl_files/` scope (agent-neutral).** Despite the name, this folder is the agent's tenant workspace for **all** tenant-bound artifacts regardless of which tool fetched them — `dtctl get`, MCP `execute_dql` results saved to disk, MCP-driven notebook/dashboard exports, etc. The folder name is historical; the rule is universal.

**Agent-Agnostic DQL Rules** (apply to ALL agents — see also copilot-instructions.md):
- **ALWAYS load dt-dql-essentials/SKILL.md FIRST**. Review the active tenant's folder under `temp_dtctl_files/tenant-memory/<TENANTID>/` and the relevant per-type subfolder first.
- Unique `event.type` + provider for isolation. Validate in exact context (dashboard tiles require `fields`/`bin()`/`sort`/`limit` fallback).
- Prefer JSON, start with problems, record generic lessons only. Ensures identical safe behavior. Root remains standardized; per-tenant folders hold context.

Failure mode reminders:
- Duplicate names can point to different ownership.
- Mixed encoding and non-ASCII punctuation can create parser issues.
- Missing `type: dql` can produce empty or non-functional query sections.