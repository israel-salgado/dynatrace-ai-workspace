<#
.SYNOPSIS
    Refreshes the app working context registry by re-exporting live state for active apps.
    Part of the context tracking system for notebooks, dashboards, workflows, etc.

.DESCRIPTION
    Reads app-working-context.json, re-exports live state for each resource using dtctl,
    updates the registry with latest metadata, and runs validation.
    This enforces the Live State Reconciliation rule across all active apps.

.PARAMETER RegistryPath
    Path to the app-working-context.json file (default: ..\temp_dtctl_files\app-working-context.json)

.PARAMETER ResourceType
    Optional: Refresh only one type ("notebook", "dashboard", "workflow", etc.)

.EXAMPLE
    .\refresh-context.ps1
    .\refresh-context.ps1 -ResourceType notebook
#>

param(
    [string]$RegistryPath = "..\temp_dtctl_files\app-working-context.json",
    [string]$ResourceType = $null
)

$ErrorActionPreference = "Stop"
Write-Host "=== Refreshing App Working Context ===" -ForegroundColor Cyan

# Load registry
if (-not (Test-Path $RegistryPath)) {
    Write-Error "Registry not found at $RegistryPath. Run setup first."
}

$registry = Get-Content $RegistryPath | ConvertFrom-Json
$updated = $false

$typesToProcess = if ($ResourceType) { @($ResourceType) } else { @("notebooks", "dashboards", "workflows") }

foreach ($type in $typesToProcess) {
    $apps = $registry.activeApps.$type
    if (-not $apps -or $apps.Count -eq 0) { continue }

    $resourceName = $type.TrimEnd('s')  # notebooks -> notebook

    Write-Host "Processing $type..." -ForegroundColor Yellow

    for ($i = 0; $i -lt $apps.Count; $i++) {
        $app = $apps[$i]
        if (-not $app.id) { continue }

        $liveFile = $app.liveStateFile
        if (-not $liveFile) { $liveFile = "..\temp_dtctl_files\temp_$($type)_files\live-$($app.name).json" }

        $dir = Split-Path $liveFile -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

        Write-Host "  Re-exporting $($app.name) (ID: $($app.id))..." -ForegroundColor Gray

        try {
            $dtctlArgs = @("get", $resourceName, $app.id, "-o", "json", "--plain")
            $liveJson = & dtctl @dtctlArgs

            $liveJson | Out-File -FilePath $liveFile -Encoding utf8
            $liveObj = $liveJson | ConvertFrom-Json

            # Update registry metadata
            $app.version = $liveObj.version
            $app.name = $liveObj.name
            $app.lastModified = $liveObj.modificationInfo.lastModifiedTime
            $app.conflictStatus = "clean"
            $updated = $true

            Write-Host "    ✓ Updated live state for $($app.name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "    Failed to refresh $($app.id): $($_.Exception.Message)"
            $app.conflictStatus = "refresh-failed"
        }
    }
}

if ($updated) {
    $registry.lastValidated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
    $registry.validationStatus = "validated"
    $registry | ConvertTo-Json -Depth 10 | Out-File -FilePath $RegistryPath -Encoding utf8
    Write-Host "`nRegistry updated successfully." -ForegroundColor Green
}

# Run validator on the registry
Write-Host "`nRunning validator on registry..." -ForegroundColor Cyan
$validatorPath = "..\scripts\validate-tenant-write.ps1"
$validatorCommand = Get-Command $validatorPath -ErrorAction Stop

if ($validatorCommand.Parameters.ContainsKey("Registry")) {
    & $validatorPath -Registry $RegistryPath
}
else {
    & $validatorPath
}
Write-Host "`nContext refresh complete. Review temp_dtctl_files/app-working-context.json" -ForegroundColor Cyan
