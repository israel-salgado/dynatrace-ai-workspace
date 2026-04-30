# Dynatrace AI Workspace Conventions

This is the committed, single source of truth for agent behavior, workspace rules, and conventions. It is referenced by the governing briefing files, skills, ARCHITECTURE.md, and CHEATSHEET.md.

## Governing Reference
- **Primary files**: `.github/copilot-instructions.md` (for GitHub Copilot) and `CLAUDE.md` (for Claude). Both are auto-loaded at session start and kept in sync.
- They define tenant interaction via MCP/dtctl, context switching, Global Rule, prompts, skills, notebook guardrails, and agent initialization.
- **Capability matrix** (which path does what): see [README.md](README.md#two-paths-to-dynatrace) → *Two paths to Dynatrace*. That table is the single source of truth for MCP-vs-dtctl coverage; the rubric in *Tool Selection* (below) tells the agent which to prefer when both can do the job.

## Mandatory Agent Initialization Sequence
When starting a session or switching agents/tenants:
1. Read the governing briefing file + this `CONVENTIONS.md` + `ARCHITECTURE.md`.
2. **ALWAYS load `.agents/skills/dt-dql-essentials/SKILL.md` FIRST** (before any DQL).
3. Review the active tenant's folder under `temp_dtctl_files/tenant-memory/<TENANTID>/` first (`list_dir` it), then any per-type subfolder relevant to the task (`notebooks/`, `dashboards/`, `workflows/`, `settings/`).
4. Establish tenant context using whichever path(s) the user has configured:
   - **dtctl path**: `dtctl config current-context` + `dtctl auth whoami --plain`.
   - **MCP path**: list configured MCP servers from `.vscode/mcp.json` / `.mcp.json`, and call `get_environment_info` / `find_entity_by_name` against the active one.
   - At least one of the two will be available; report whichever is. Do not assume dtctl is present.
5. Follow the Global Rule, the *Tool Selection* rubric, and all conventions below strictly. No tenant-specific names/IDs in root source files.

This ensures identical behavior across agents.

## Tool Selection (MCP vs dtctl)

Both paths can do most read/query/edit work against a Dynatrace tenant. The full capability matrix lives in [README.md](README.md#two-paths-to-dynatrace) → *Two paths to Dynatrace*; this rubric is the agent's quick decision guide.

- **Prefer MCP** for: Davis CoPilot chat, Davis Analyzers, sending an ad-hoc Slack message or email from chat, ingesting a custom event (`send_event`), resetting Grail query budget, natural-language → DQL helpers, and any task where structured-JSON-direct-to-the-AI is faster than parsing terminal output.
- **Prefer `dtctl`** for: declarative `apply` / `diff` / `history` / `restore`, document `share` / `unshare`, persistent multi-context switching with explicit safety levels, custom output formats (`yaml` / `csv` / `toon` / `wide`), `dtctl skills install`, and any operation the user wants to **see** scroll past in the integrated terminal.
- **Either works** for: DQL queries, reading entities (services / hosts / problems / vulnerabilities / Kubernetes / RUM), creating or editing notebooks, dashboards, workflows, and settings.

When in doubt:
1. Use the path the user just used (continuity beats consistency).
2. If neither has been used yet, use whichever the user has configured — check `dtctl config current-context` and the MCP server list in `.vscode/mcp.json` / `.mcp.json`.
3. If both are configured and the task is in the *either-works* bucket, ask the user once which they prefer for this session, then stick with it.

## Workspace & Temp File Conventions
- `temp_dtctl_files/` is **only** for tenant-specific experiments (ignored by `.gitignore`; **never** commit tenant names, IDs, or specific artifacts to root).
- **Per-tenant folder layout (mandatory).** Inside `temp_dtctl_files/`, the `tenant-memory/` directory holds **both** the cross-tenant nickname registry **and** every per-tenant artifact folder (one folder per tenant ID):
  ```
  temp_dtctl_files/
  ├── followup-items/                       # generic notes, no tenant data
  └── tenant-memory/
      ├── tenants.json                      # local nickname registry (cross-tenant; just IDs/URLs)
      └── <TENANTID>/                       # one folder per tenant; everything tenant-scoped lives here
          ├── notebooks/  dashboards/  workflows/  settings/
          ├── snapshots/                    # before-user-edit snapshots
          └── notes.md                      # tenant-specific notes
  ```
  Per-type subfolders (`notebooks/`, `dashboards/`, `workflows/`, `settings/`) inside each tenant folder replace the old flat `temp_<type>_files/` pattern. The agent must `list_dir` the active tenant's folder first and never touch another tenant's folder during the same operation. **Auto-create per-type subfolders on first use.** When the agent first creates or edits a resource of a type that doesn't yet have a subfolder for the active tenant (e.g. first workflow in `tenant-memory/guu84124/`), it creates `tenant-memory/<TENANTID>/<type>/` automatically. Same rule for `snapshots/` and `notes.md` — created on first need, never preemptively.

- **File naming inside per-type subfolders.** One file per resource, named by its stable Dynatrace ID with a `.json` extension: `tenant-memory/<TENANTID>/notebooks/<NOTEBOOK-ID>.json`, `tenant-memory/<TENANTID>/dashboards/<DASHBOARD-ID>.json`, etc. For brand-new resources that don't have a tenant ID yet, use a slug (lowercase, hyphenated): `tenant-memory/<TENANTID>/notebooks/draft-<slug>.json`, then rename to the real ID after first apply. Snapshot files use `snapshots/<RESOURCE-TYPE>-<ID>-<timestamp>.json`. The legacy single-file `current-<type>.json` pattern is **no longer used** — every resource has its own file.
- **Any file whose contents come from a tenant must live inside that tenant's folder.** This rule is broader than the per-resource contract above and covers everything else: schema dumps, query result CSVs, Davis CoPilot transcripts, entity ID lists, exported settings, raw API responses, scratch grep dumps, before/after diffs, anything else derived from a `dtctl` or MCP call. The mandatory landing zones are:
  - **Structured resources with a Dynatrace ID** → `tenant-memory/<TENANTID>/<type>/<id>.json` (the per-resource contract).
  - **Loose / unstructured / scratch tenant data** (text, csv, json without an ID, ad-hoc notes) → `tenant-memory/<TENANTID>/scratch/` (auto-create on first use). Use descriptive filenames like `settings-schemas-2026-04-30.txt`, `host-tags-export.csv`, `davis-conversation-host-rename.md`.
  - **Tenant-specific narrative notes the agent wants to keep across turns** → `tenant-memory/<TENANTID>/notes.md`.
  - **Tenant-agnostic followups** → `temp_dtctl_files/followup-items/`.
  Before creating any file derived from tenant data, the agent picks one of the four landing zones above. If none fits, the agent asks the user before writing. **Never** create a tenant-derived file at the workspace root, in `scripts/`, in `.agents/`, in `docs/`, or anywhere else outside `temp_dtctl_files/`. This applies equally to terminal-redirected output (`> filename`) — the same rule that governs `create_file` governs shell redirection.
- Every JSON artifact under `tenant-memory/<TENANTID>/` carries a top-level `_tenant: "<TENANTID>"` marker. `scripts/validate-tenant-write.ps1` rejects any apply where the active dtctl context, the parent tenant folder name, and the file's `_tenant` tag do not all match.
- `reference/official/` holds extracted patterns from the official MCP server for analysis (do not commit tenant-specific code; use for skill enhancement only).
- After experiments, clean up or archive. Root source must remain fully generic/standardized for any user/GitHub.

## Tenant Isolation (Absolute)
- **Cross-tenant data movement is forbidden.** Each Dynatrace tenant is a sealed island. Never read data, IDs, names, queries, entity references, dashboards, notebooks, settings, or any artifact from one tenant and embed, transform, copy, apply, or even *reference* it in another tenant's context.
- **Mandatory dual-context echo before any tenant write.** Before any `dtctl apply`, MCP `update_*`/`create_*`/`send_*`, or write to a Dynatrace resource, the agent must emit one block on its own line:
  ```
  Target tenant write → dtctl: <NICKNAME> · <TENANTID> · <class> · <safety>
                         MCP : <SERVER-NICKNAME> · <TENANTID>   (or "none selected this turn")
                         File: temp_dtctl_files/tenant-memory/<TENANTID>/<path>
                         Status: OK ✓   (or STOP ✗ on any disagreement)
  ```
  If the dtctl context, the selected MCP server (when used), and the file's parent folder do not all point to the same `<TENANTID>`, **stop and ask** before writing.
- **Session reset on tenant switch.** When the user switches dtctl context or selects a different MCP server in chat, the agent declares: *"Tenant changed → discarding in-memory references to entities, IDs, queries, and findings from the previous tenant."* No tenant-specific facts, names, IDs, or analyses carry forward into the new tenant context.
- **Memory scoping.**
  - `/memories/` (user) — workspace-agnostic preferences only. No tenant data.
  - `/memories/repo/` — generic workspace patterns and lessons that hold true for **all** tenants. No tenant names, no tenant IDs, no tenant-specific entity references, no tenant-specific findings.
  - `/memories/session/` — current conversation only; cleared at end of session. May reference the active tenant by name during the session, but must not be promoted to repo memory.
  - Tenant-specific facts (entity names, IDs, known issues, owners, query patterns particular to one environment) live **only** in `temp_dtctl_files/tenant-memory/<TENANTID>/notes.md` (gitignored).
- **Cross-tenant comparison requests.** If a user asks the agent to compare findings, copy a notebook, or transfer settings between tenants, the agent refuses and explains. Only the user can manually carry findings across; the agent does not.

## Live State Reconciliation & Conflict Protection (Mandatory)
- Refresh per-resource state from the tenant when starting work (using stable ID): `dtctl get <type> <id> -o json` writes/overwrites `tenant-memory/<TENANTID>/<type>/<id>.json` (with `_tenant` tag added at the top). One file per resource; no shared `current-<type>.json`.
- Before any modification, `dtctl apply`, or MCP update on a **specific resource**: re-export **only that resource's** live state (`dtctl get <type> <id> -o json`, using ID not name) and overwrite its per-resource file.
- Run `scripts/validate-tenant-write.ps1` targeted at that single per-resource file. The validator enforces tenant isolation (active dtctl context = parent tenant folder = `_tenant` tag).
- On detected user edits in the UI:
  - Provide a brief 1-2 sentence summary of what the user changed.
  - If edits are unrelated to the AI's pending changes → smart-merge user's edits into the local JSON, update the outgoing payload, and proceed.
  - Only stop and ask for explicit permission if the AI's changes would overwrite user edits. Offer options: stop, let AI overwrite, or do something else.
- Always keep a timestamped "before-user-edit" snapshot at `tenant-memory/<TENANTID>/snapshots/<type>-<id>-<timestamp>.json` for easy revert.
- Never silently overwrite user work. Report ownership/access constraints.

## File-System Boundaries (All Agents)

Agents (and any subagents they spawn) should treat the **workspace folder** (wherever the user has cloned/installed this repo) as the default and primary scope for all file operations.

- **Default scope**: stay within the workspace root and its subfolders. This applies regardless of where the user installed it (e.g. `~/code/dt-mcp-server`, `C:\github\dt-mcp-server`, `/workspaces/dt-mcp-server`).
- **Reads outside the workspace**: allowed when there is a clear, legitimate reason (e.g. inspecting a tool's own config, verifying credential storage, reading a referenced doc). Before doing so, **state the reason in plain language** so the user can decide whether to approve. The user has final discretion.
- **Writes outside the workspace**: never silent. Always ask for explicit permission first and explain why. Default answer is no.
- **Large or transient outputs**: prefer saving them inside the workspace under `temp_dtctl_files/tenant-memory/<TENANTID>/` (or `temp_dtctl_files/followup-items/` for tenant-agnostic notes). If something useful exists outside the workspace and you need it locally, copy it in rather than reading it in place repeatedly.
- **Subagent prompts**: inherit this same rule. When delegating execution work, include a short note that file operations should stay inside the workspace unless the subagent has a clear reason to step outside, in which case it should report the reason back rather than act silently.

The spirit of the rule: flexibility for reads when justified, strict guardrails on writes, and transparency about *why* whenever the agent needs to step outside the workspace.

## Connecting to a New Tenant

When the user asks to connect to / switch to a new Dynatrace tenant ID (e.g. `abc12345`, `xyz98765`), the agent first asks **which path(s) the user wants the new tenant reachable from** — `dtctl`, MCP, or both. Most users want both; some only use one. Then walk the matching procedure(s) below.

### Path A — dtctl context

1. Run `dtctl config get-contexts` to see if the context already exists. If it does, just `dtctl config use-context <id>` and verify.
2. If it is new, ask the user (e.g. via `vscode_askQuestions`) for two inputs:
   - **Environment URL** — offer three options based on the tenant ID:
     - `https://<id>.apps.dynatrace.com` — production (default for customers)
     - `https://<id>.sprint.apps.dynatracelabs.com` — sprint/lab (Dynatrace internal only)
     - `https://<id>.live.dynatrace.com` — classic Gen2
   - **Safety level** — `readonly` / `readwrite-mine` (recommended) / `readwrite-all` / `dangerously-unrestricted`. dtctl's own default is `readwrite-all` if `--safety-level` is omitted; this repo recommends `readwrite-mine` for routine work and `readonly` when you only need to query. See [README.md](README.md) → *Safety Levels* for what each level allows.
   Auth method defaults to OAuth interactive; only ask if the user has indicated otherwise.
3. Run:
   ```
   dtctl auth login --environment <URL> --context <id> --safety-level <level>
   ```
   Use async terminal mode (~15s timeout). The command opens a browser for SSO and on success prints `Context '<id>' configured and activated`. Tokens are stored in the OS credential store (Windows Credential Manager on Windows, Keychain on macOS, libsecret on Linux) under `<id>-oauth`.
4. Verify with `dtctl config current-context; dtctl auth whoami --plain`.

**Notes (Path A)**
- `dtctl auth login` auto-detects the environment class (prod/sprint/hard) from the URL and selects the matching OAuth client + SSO host (`sso.dynatrace.com` for prod/classic, `sso-sprint.dynatracelabs.com` for sprint).
- Login also activates the new context — no separate `use-context` step needed.
- **Who can do this**: anyone with valid Dynatrace credentials for the target tenant. Sprint/lab tenants are restricted to Dynatrace internal accounts because their SSO host doesn't accept external identities; production and classic tenants are open to any authorised user of that tenant.

### Path B — MCP server entry

MCP reaches a tenant via a named server entry in **both** `.vscode/mcp.json` and `.mcp.json` (kept in sync). This path is independent of dtctl — you can configure MCP without ever installing dtctl.

1. Ask the user for a **nickname** (free text, lowercased; the chat invocation will be *"use the `<nickname>` server, …"*) and the **environment URL** (same three URL options as Path A).
2. Add a parallel server entry under the top-level `"servers"` key in `.vscode/mcp.json`:
   ```jsonc
   "<nickname>": {
     "type": "stdio",
     "command": "npx",
     "args": ["-y", "@dynatrace-oss/dynatrace-mcp-server@latest", "--stdio"],
     "env": { "DT_ENVIRONMENT": "https://<id>.<class-suffix>" }
   }
   ```
3. Mirror the **same entry** into `.mcp.json` under the top-level `"mcpServers"` key (the only structural difference between the two files). Both files must stay in sync.
4. Reload the MCP servers (VS Code: *MCP: Reload Servers*) and verify with `get_environment_info` against the new server.

**Notes (Path B)**
- MCP authentication uses the OAuth flow built into `@dynatrace-oss/dynatrace-mcp-server`; first call to a new server triggers a browser sign-in.
- One server entry = one tenant. Multiple tenants = multiple entries (no `use-context` equivalent — the user picks the server by name in chat).
- Safety levels are not a built-in MCP concept; access is governed by the OAuth scopes the user grants at sign-in.

### Both paths

- Do **not** add tenant-specific IDs to root source files **other than** the two `mcp.json` files. Per-tenant artifacts go in `temp_dtctl_files/tenant-memory/<TENANTID>/`.
- After a successful connect via either path, **offer to record a nickname** for the tenant in the Local Tenant Nickname Registry (next section). The same nickname works for both `"switch to <nickname>"` (dtctl) and *"use the `<nickname>` server"* (MCP) — that's the intended single-identity pattern.

## Local Tenant Nickname Registry

To keep the repo generic (the only tenant ID referenced in committed source is the public baseline `guu84124`, reachable at `demo.live.dynatrace.com`) while still letting users say *"switch to **<NICKNAME>**"* instead of *"switch to **<TENANTID>**"*, agents maintain a **local-only** nickname registry.

**Location** (always — never anywhere else):
```
temp_dtctl_files/tenant-memory/tenants.json
```
This path lives under `temp_dtctl_files/`, which is `.gitignore`d, so the registry **never** gets pushed to GitHub. The `tenant-memory/` subfolder is reserved for this purpose; agents must auto-create it (with an empty `tenants.json`) on first use.

**Seeding rule.** The registry only ever contains tenants the user has actually authenticated against. On a fresh clone the agent creates an empty file (`{ "schema": 1, "tenants": [] }`) — *not* a pre-seeded list. After the first successful `dtctl auth login`, the agent offers to record the new tenant under a nickname.

**dtctl persistence vs. agent behavior.** `dtctl config current-context` is **persistent on disk** — once you switch, it stays switched until you switch again, including across VS Code restarts. When dtctl is configured the agent treats this as the source of truth at session start, reports the active context in one line, and **does not change it without an explicit user instruction**. When only MCP is configured the agent reports the active MCP server(s) instead. There is no concept of a global "default tenant."

**Schema** (JSON, lowercase nicknames):
```jsonc
{
  "schema": 1,
  "tenants": [
    {
      "nickname": "<NICKNAME>",
      "id": "<TENANTID>",
      "context": "<TENANTID>",     // dtctl context name; defaults to id if omitted
      "url": "https://<TENANTID>.<class>.dynatrace[labs].com",
      "class": "prod",            // prod | sprint | classic (see class table)
      "safety": "readwrite-mine",  // readonly | readwrite-mine | readwrite-all | dangerously-unrestricted
      "notes": "Free-text description"
    }
  ]
}
```

**`class` field.** Values are `prod` | `sprint` | `classic` — the human-friendly labels used internally and in this repo. Note that `dtctl auth login` reports the sprint class as `hard` in its `Detected environment:` output (an internal name). The registry uses `sprint` for clarity; treat dtctl's `hard` and the registry's `sprint` as the same thing.

**`context` field.** dtctl context names are independent of tenant IDs — a user can create a context with any name (e.g. `dtctl auth login --context my-prod`). The *Connecting to a New Tenant* flow in this repo always sets `--context <id>`, so for tenants created via that flow `context` equals `id` and may be omitted. For contexts created manually with custom names, set `context` explicitly so the registry can resolve nickname → dtctl context. Resolution always runs `dtctl config use-context <context-or-id>`.

### Resolution rules ("ask, don't guess")
When the user says *"connect to / switch to **<name>**"*:
1. **Exact unique match** → echo `nickname · id · class · safety` in a one-line confirmation and proceed.
2. **Exact match but stale** (`dtctl config get-contexts` no longer has it) → tell the user, offer to re-auth or remove the entry.
3. **No match** → fall back to *Connecting to a New Tenant* (above), then offer to save a nickname at the end.
4. **Multiple matches / collision** → list all candidates and ask which one. Never pick automatically.
5. **Fuzzy / partial match** (e.g. user says "lit") → never auto-resolve. Show top candidates and ask.
6. **Ambiguous intent words** ("dev", "test", "demo", "prod", "lab") → always confirm before switching, even on a unique match.

### Save / update rules
When recording a new entry (or updating an existing one), prompt the user (use `vscode_askQuestions` with labelled options, same UX as the new-tenant flow) for:
- **URL pattern** — `https://<id>.apps.dynatrace.com` (prod) / `https://<id>.sprint.apps.dynatracelabs.com` (sprint) / `https://<id>.live.dynatrace.com` (classic).
- **Safety level** — `readwrite-mine` (repo default) / `readonly` / `readwrite-all` / `dangerously-unrestricted`. See [README.md](README.md) → *Safety Levels*.
- **Nickname** — free text, lowercased on save. **If the user does not provide one, default to the full exact tenant ID** (e.g. `guu84124`, not a 3-letter abbreviation). The user can rename it later, which overwrites the entry.
- **Context** — only ask if it differs from the tenant ID (e.g. user authenticated manually with a custom `--context` name). Otherwise omit the field; resolution falls back to `id`.

Validation before writing:
- Nickname matches `^[a-z0-9][a-z0-9._-]{1,30}$` (no spaces or weird chars; bounded length).
- Tenant ID matches the URL's host prefix — if not, ask which is right.
- If `context` is set, it must exist in `dtctl config get-contexts`. If absent, warn and offer to re-auth.
- On collision, offer three actions: rename the new one, overwrite the old one, or cancel. **Never silently overwrite.**
- Optional sanity check: run `dtctl auth whoami --plain --context <context-or-id>` after save and warn if it fails.

### Confirmation message (always identical, one line)
```
Switching context → <NICKNAME> · <TENANTID> · <class> · <safety>
Proceed?
```

### Session start
At session start the agent reports the active tenant context in one line, using whichever path(s) are configured (resolving via the registry where possible):
- If dtctl is configured: run `dtctl config current-context` and emit `Active dtctl context: <NICKNAME> · <TENANTID> · <class> · <safety>`.
- If only MCP is configured: list the configured MCP server(s) from `.vscode/mcp.json` / `.mcp.json` and emit `Active MCP server: <NICKNAME> · <TENANTID>` (one line per server if multiple).
- If both are configured: emit one line for each.

The agent does **not** auto-switch. If an active context is unknown to the registry, the agent asks the user how to proceed.

### Edge cases
- **Same tenant ID, multiple safety levels**: allowed — nickname is the key, not the ID (e.g. `<NICKNAME>-ro` and `<NICKNAME>-rw` for the same tenant).
- **Hand edits**: honor them. The agent must treat user edits as truth and not silently rewrite.
- **Removal**: confirm before removing. Offer to also `dtctl auth logout --context <id>` if the user is decommissioning entirely.
- **First run on a fresh clone**: the file does not exist. Auto-create `temp_dtctl_files/tenant-memory/` and an empty `tenants.json` (`{ "schema": 1, "tenants": [] }`) before adding the first nickname. Suggest the public baseline tenant `guu84124` (`demo.live.dynatrace.com`) as a safe first connection — the user may nickname it `demo.live` (matching its public URL) or anything else.
- **MCP exception**: `.mcp.json` and `.vscode/mcp.json` are the **only allowed locations** in the repo where tenant IDs may appear, because VS Code and the MCP launcher read them as real files. The nickname registry does not replace them; users who want the AI to reach a tenant via MCP must add a server entry in both files (see *Connecting to a New Tenant* → Path B above and `ARCHITECTURE.md` → *MCP Server*).

## DQL Rules (All Agents)
- Use unique `event.type` + `event.provider` for workflow isolation.
- Dashboard tiles are stricter than notebooks/standalone: Avoid `summarize {..} by {..}` if "'by' isnt allowed here". Prefer `fields`/`fieldsAdd bin()`/`sort`/`limit`. Validate in *exact* target context (live tile, notebook section, MCP `execute_dql`, `dtctl query`).
- Start all investigations with **problems** (never broad log searches).
- Prefer JSON payloads; re-export and verify after apply.
- Record **generic** lessons only. `dt-dql-essentials/SKILL.md` + `references/dql/*` are canonical for syntax and pitfalls.

## Sync Checklist
After any change to governing files, this file, memory, or SKILL.md:
- Update both briefing files.
- Propagate generic lessons to this file and `/memories/repo/*`.
- Update `ARCHITECTURE.md`, `CHEATSHEET.md`, relevant skills, and run `scripts/validate-tenant-write.ps1`.
- Verify no tenant-specific references in root via grep.

## Agent Behavior
- Review files first (minimal corrections).
- Use `temp_dtctl_files/` for experiments only.
- Update this file when new patterns or lessons emerge.
- The memory system (`/memories/repo/`) holds AI-side notes; committed rules live here.
- **Use clickable options for short choices.** When asking the user a question with 2–6 short fixed answers (yes/no, "do A / do B / skip", confirmations, approve/reject), use `vscode_askQuestions` with labeled options and keep `allowFreeformInput` enabled (default) so the user can still type a custom answer. Reserve plain-text questions for open-ended prompts or when each option needs a paragraph of explanation. Do **not** use clickable options for explanations, recommendations, or anything the user is meant to read rather than choose between.

This ensures predictable, safe, file-aware behavior for any user or AI.