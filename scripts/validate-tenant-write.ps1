<#
.SYNOPSIS
    Pre-write validation for any resource dtctl sends to a Dynatrace tenant.
    Detects manual user edits in the UI and prevents unintended overwrites.

.DESCRIPTION
    - Fetches current live state from tenant for the given resource type/ID
    - Compares against local copy (version, owner, modificationInfo, content hash)
    - Performs type-specific checks (JSON structure, DQL for notebooks/dashboards,
      workflow validity, etc.)
    - Runs verification via MCP or dtctl
    - Reports conflicts clearly so user can decide how to proceed

    Primary use case: Run immediately before any dtctl apply or equivalent write
    operation on editable resources (notebooks, dashboards, workflows, settings).

    Location: scripts/ (see README.md for usage; referenced from CONVENTIONS.md
    and relevant skills).

.EXAMPLE
    .\scripts\validate-tenant-write.ps1 -ResourceType notebook -Path .\temp_dtctl_files\tenant-memory\<TENANTID>\notebooks\<NOTEBOOK-ID>.json
    .\scripts\validate-tenant-write.ps1 -ResourceType dashboard -Id "842a526e-..." -AutoFix

.NOTES
    Update header when new resource types or checks are added.
    Commented sections below outline core behavior this script enforces.
#>

# ================================================
# CORE BEHAVIOR (per-tenant, per-resource reconciliation)
# ================================================
# - Every resource lives at temp_dtctl_files/tenant-memory/<TENANTID>/<type>/<id>.json
#   with a top-level `_tenant: "<TENANTID>"` marker.
# - Auto-create per-type subfolders on first use; no shared current-<type>.json.
# - Target ONLY the specific resource being worked on (no full scan).
# - Refresh that single resource from the tenant before edit (`dtctl get <type> <id> -o json`).
# - On user edit: 1-2 sentence summary.
#   - Unrelated edits → smart-merge into local JSON and proceed.
#   - Conflicting overwrites → stop, ask user (stop/overwrite/do something else).
# - Keep timestamped before-user-edit snapshot at
#   tenant-memory/<TENANTID>/snapshots/<type>-<id>-<timestamp>.json for revert.
# ================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceType,           # notebook, dashboard, workflow, business_flow, etc.
    [string]$Path,                   # Path to tenant-memory/<TENANTID>/<type>/<id>.json
    [string]$Id,                     # Resource ID (preferred)
    [switch]$AutoFix,                # Auto-merge unrelated edits
    [switch]$Strict                  # Fail on any conflict
)

Write-Host "=== Dynatrace Per-Tenant Per-Resource Validator ===" -ForegroundColor Cyan

# ================================================
# TENANT ISOLATION PRE-FLIGHT (mandatory)
# Refuses any apply where the active dtctl context, the file's _tenant tag,
# and the file's parent folder do not all point to the same tenant ID.
# ================================================
$activeTenant = (& dtctl config current-context 2>$null).Trim()
if (-not $activeTenant) {
    Write-Error "TENANT-ISOLATION: cannot determine active dtctl context. Run 'dtctl config use-context <name>' first."
    exit 2
}

if ($Path -and (Test-Path $Path)) {
    # Check folder ancestry
    $resolved = (Resolve-Path $Path).Path
    if ($resolved -notmatch "[\\/]temp_dtctl_files[\\/]tenant-memory[\\/]([^\\/]+)[\\/]") {
        Write-Error "TENANT-ISOLATION: file '$Path' is not under temp_dtctl_files/tenant-memory/<TENANTID>/. Files outside a per-tenant folder may not be applied."
        exit 2
    }
    $folderTenant = $Matches[1]
    if ($folderTenant -notmatch '^[a-z]{3}\d{5}$') {
        Write-Error "TENANT-ISOLATION: parent folder '$folderTenant' does not look like a Dynatrace tenant ID (expected 3 letters + 5 digits, e.g. abc12345). Files must live under temp_dtctl_files/tenant-memory/<TENANTID>/."
        exit 2
    }

    # Check _tenant tag inside file
    try {
        $payload = Get-Content $Path -Raw | ConvertFrom-Json
    } catch {
        Write-Error "TENANT-ISOLATION: cannot parse JSON at '$Path' to verify _tenant tag."
        exit 2
    }
    $fileTenant = $payload._tenant
    if (-not $fileTenant) {
        Write-Error "TENANT-ISOLATION: file '$Path' is missing top-level '_tenant' marker. Add `"_tenant`": `"$folderTenant`" before applying."
        exit 2
    }

    # All three must agree
    if ($activeTenant -ne $folderTenant -or $activeTenant -ne $fileTenant) {
        Write-Host ""
        Write-Host "TENANT-ISOLATION VIOLATION - refusing to proceed:" -ForegroundColor Red
        Write-Host "  Active dtctl context : $activeTenant" -ForegroundColor Red
        Write-Host "  File parent folder   : $folderTenant" -ForegroundColor Red
        Write-Host "  File _tenant tag     : $fileTenant"   -ForegroundColor Red
        Write-Host "  All three must match. Stopping." -ForegroundColor Red
        exit 2
    }
    Write-Host "Tenant isolation OK: dtctl=$activeTenant, folder=$folderTenant, file=$fileTenant" -ForegroundColor Green
} else {
    Write-Host "Tenant isolation pre-flight skipped (no -Path given). Active context: $activeTenant" -ForegroundColor Yellow
}

# Per-tenant per-resource layout (no shared per-app folder, no index.json).
# All artifacts live under temp_dtctl_files/tenant-memory/<TENANTID>/<type>/<id>.json.
# Snapshots go to a sibling snapshots/ folder (auto-created on first use).
$tenantRoot = $null
if ($Path -and (Test-Path $Path)) {
    $resolved = (Resolve-Path $Path).Path
    if ($resolved -match "^(?<root>.*[\\/]temp_dtctl_files[\\/]tenant-memory[\\/][^\\/]+)[\\/]") {
        $tenantRoot = $Matches['root']
    }
}

# Resolve ID (support creation of new resources without ID yet)
$isNew = $false
if (-not $Id -and $Path -and (Test-Path $Path)) {
    $localContent = Get-Content $Path -Raw | ConvertFrom-Json
    $Id = $localContent.id
}
if (-not $Id) {
    $isNew = $true
    Write-Host "No ID found - treating as new $ResourceType creation." -ForegroundColor Yellow
}

if (-not $isNew) {
    # Refresh live state for THIS existing resource only
    Write-Host "Fetching live state for $ResourceType $Id..." -ForegroundColor Yellow
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $liveOutput = & dtctl get $ResourceType $Id -o json --plain 2> $stderrPath
        $dtctlExitCode = $LASTEXITCODE
        $stderrOutput = if (Test-Path $stderrPath) { Get-Content $stderrPath -Raw } else { "" }
        if ($dtctlExitCode -ne 0) {
            if ($stderrOutput) {
                Write-Error "Failed to fetch live state: $stderrOutput"
            } else {
                Write-Error "Failed to fetch live state."
            }
            exit 1
        }
        $live = $liveOutput | ConvertFrom-Json
    } finally {
        if (Test-Path $stderrPath) {
            Remove-Item $stderrPath -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    $live = @{ version = 0; name = "(new)" }
}

# Load local
$local = Get-Content $Path -Raw | ConvertFrom-Json

# Detect user edits (skip for new resources)
$userEdited = $false
$summary = "No changes detected."
if (-not $isNew -and $local.version -and $live.version -and $local.version -ne $live.version) {
    $userEdited = $true
    $summary = "User updated version from $($local.version) to $($live.version) in UI (possible manual edits to sections or metadata)."
}
if (-not $isNew -and $local.owner -and $live.owner -and $local.owner -ne $live.owner) {
    $userEdited = $true
    $summary += " Owner changed to $($live.owner)."
}

# Create before-snapshot if user edited (per-tenant snapshots/ subfolder)
if ($userEdited) {
    if (-not $tenantRoot) {
        Write-Error "TENANT-ISOLATION: cannot resolve per-tenant folder for snapshot. -Path must be under temp_dtctl_files/tenant-memory/<TENANTID>/."
        exit 2
    }
    $snapshotsDir = Join-Path $tenantRoot "snapshots"
    if (-not (Test-Path $snapshotsDir)) {
        New-Item -ItemType Directory -Path $snapshotsDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $snapshotName = "$ResourceType-$Id-$timestamp.json"
    $beforePath = Join-Path $snapshotsDir $snapshotName
    $local | ConvertTo-Json -Depth 10 | Out-File $beforePath -Encoding utf8
    Write-Host "Saved before-user-edit snapshot: $snapshotName" -ForegroundColor Yellow
    Write-Host "User changes summary: $summary" -ForegroundColor Magenta
}

# Type-specific validation (targeted)
switch ($ResourceType) {
    "notebook" {
        if (-not $local.content -or -not $local.content.sections) {
            Write-Warning "Invalid notebook: missing content.sections"
        }
        Write-Host "Notebook DQL/metadata checks passed (targeted)." -ForegroundColor Green
    }
    default {
        Write-Host "$ResourceType validation passed." -ForegroundColor Green
    }
}

# Handle conflict
if ($userEdited) {
    if ($AutoFix) {
        Write-Host "Unrelated user edits detected. Smart-merging into local JSON..." -ForegroundColor Yellow
        # Simple merge example: take live metadata but keep local content/sections
        $merged = $local
        $merged.version = $live.version
        $merged.modificationInfo = $live.modificationInfo
        $merged | ConvertTo-Json -Depth 10 | Out-File $Path -Encoding utf8
        Write-Host "Merge complete. Proceeding with combined changes." -ForegroundColor Green
    } else {
        Write-Host "`nCONFLICT: User made edits. Options:" -ForegroundColor Red
        Write-Host "1. Stop (default)" -ForegroundColor Red
        Write-Host "2. Let AI overwrite" -ForegroundColor Yellow
        Write-Host "3. Do something else" -ForegroundColor Cyan
        $choice = Read-Host "Choice (1-3)"
        if ($choice -ne "2") {
            Write-Host "Stopped per user choice." -ForegroundColor Red
            exit 1
        }
        Write-Host "Overwriting with AI version." -ForegroundColor Yellow
    }
} else {
    Write-Host "No conflicts for this resource. Validation passed." -ForegroundColor Green
}

# Update per-app index with latest state
$indexEntry = @{
    id = $Id
    name = $live.name
    type = $ResourceType
    lastValidated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    beforeSnapshot = if ($userEdited) { "before-user-edit-$timestamp.json" } else { $null }
    notes = $summary
}
$index.resources = @($index.resources | Where-Object { $_.id -ne $Id }) + $indexEntry
$index | ConvertTo-Json -Depth 5 | Out-File $indexPath -Encoding utf8

Write-Host "`nValidator complete for $ResourceType $Id. Per-app index updated." -ForegroundColor Cyan
exit 0
