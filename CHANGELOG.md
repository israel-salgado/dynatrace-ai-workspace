# Changelog

All notable changes to **this workspace** (`dt-mcp-server`) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## What this changelog covers

This repo is a Dynatrace **MCP workspace** — it configures the [Dynatrace MCP server](https://github.com/dynatrace-oss/dynatrace-mcp) and ships skills, prompts, conventions, and per-app reconciliation contracts on top of it so an AI assistant (GitHub Copilot, Claude) can talk to a Dynatrace tenant in plain English.

It is also configured **assuming the user has [`dtctl`](https://github.com/dynatrace-oss/dtctl) installed alongside MCP**, so the agent can use the best of both paths (see [README.md](README.md#two-paths-to-dynatrace) → *Two paths to Dynatrace* for the capability matrix and [CONVENTIONS.md](CONVENTIONS.md#tool-selection-mcp-vs-dtctl) → *Tool Selection* for the per-task rubric).

Entries here track changes to:
- Workspace docs (`README.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`, `CHEATSHEET.md`, `CLAUDE.md`, `.github/copilot-instructions.md`)
- MCP server configuration (`.mcp.json`, `.vscode/mcp.json`)
- Skills, prompts, and validation scripts (`.agents/skills/`, `.github/prompts/`, `scripts/`)

`dtctl` is a **separate project in a separate repository** with its own release cadence and changelog. For dtctl release notes see [github.com/dynatrace-oss/dtctl/blob/main/CHANGELOG.md](https://github.com/dynatrace-oss/dtctl/blob/main/CHANGELOG.md).

---

## [Unreleased]

### Added
- **Tool Selection rubric (MCP vs `dtctl`)** in `CONVENTIONS.md` and condensed in both briefing files (`CLAUDE.md`, `.github/copilot-instructions.md`) so the agent can pick the right path per task — prefer-MCP / prefer-dtctl / either-works bullets plus continuity tiebreakers.
- **"This is an MCP repo"** clarification section in `README.md` that unambiguously separates this repo from the `dtctl` repo while documenting the assumed-both-installed posture.
- **Two paths to Dynatrace** capability table in `README.md` (19 verified rows comparing MCP and `dtctl` coverage).
- **Path A / Path B** dual procedure in `CONVENTIONS.md` → *Connecting to a New Tenant* (dtctl context vs MCP server entry; users may configure either, both, or neither).
- **`scripts/validate-tenant-write.ps1`**: pre-write validator that runs before any tenant write on editable resources (notebooks, dashboards, workflows). Detects manual user edits and performs type-specific checks.
- **`CONVENTIONS.md`**: committed single source of truth for all agent rules (initialization sequence, Workspace & Temp File Conventions, Live State Reconciliation & Conflict Protection, DQL rules, Sync Checklist).

### Changed
- **Briefing files** (`CLAUDE.md`, `.github/copilot-instructions.md`): session-start, switch-context, and connecting-new-tenant sections rebalanced so the agent no longer assumes `dtctl` is present. Three branches per check (dtctl-only / MCP-only / both) with matching report formats.
- **`CHEATSHEET.md`**: skills table, session-management, and switch-context blocks rebalanced to mirror the briefing files.
- **`NICKNAME` placeholder** in `.mcp.json` / `.vscode/mcp.json` (committed templates) so the per-machine tenant entry can be renamed in place without touching the schema.
- **Beginner-friendly README rewrite** of Step 4 (`mcp.json` configuration) — broken into 4.A / 4.B / 4.C / 4.D, with explicit instructions for non-technical users.
- **Redundancy reduction**: briefing files delegate detailed workspace rules to `CONVENTIONS.md`. Memory file is now lightweight AI-side notes only.

### Removed
- **`ELI5.md`**: deleted the standalone beginner-friendly install guide; its useful content was absorbed into the README's Setup section.

### Fixed
- **Dashboard tile DQL parser quirks**: documented the "'by' isnt allowed here" failure mode and the `fields` / `fieldsAdd bin()` / `sort` / `limit` workaround in the DQL skill and CONVENTIONS.

---

For releases of the underlying `dtctl` CLI (a separate project), see the [dtctl changelog](https://github.com/dynatrace-oss/dtctl/blob/main/CHANGELOG.md).
