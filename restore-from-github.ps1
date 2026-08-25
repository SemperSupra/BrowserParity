<#
.SYNOPSIS
    Restore-From-GitHub: Restores personal browser configs, bookmarks, and profiles from a PRIVATE GitHub repository.
.DESCRIPTION
    1. Enforces prerequisites: Verifies 'git' and GitHub CLI ('gh') are installed and authenticated.
    2. Enforces STRICT PRIVACY SAFETY:
       - Checks the target GitHub repository via GitHub CLI to ensure it exists and is PRIVATE.
    3. Clones or pulls the latest snapshot from your private GitHub repository.
    4. Restores bookmarks, Preferences, and user.js files across Opera, Edge, Firefox, and Chrome.
    5. Re-runs BrowserParity engine to reconcile DuckDuckGo and anti-annoyance settings on top of restored profiles.
.PARAMETER Repo
    Target GitHub repository name (e.g. 'BrowserParity-mark' or 'owner/repo'). Default: 'BrowserParity-mark'.
.PARAMETER LocalPath
    Local clone/staging path for the private repo (default: '$env:USERPROFILE\.browserparity-configs').
.PARAMETER Browsers
    Target specific browsers to restore: 'All', 'Opera', 'Edge', 'Firefox', 'Chrome' (default: All).
.PARAMETER Diff
    Preview differences between the private backup and the current machine state without applying any changes.
.PARAMETER Preview
    Alias for -Diff.
.PARAMETER Launch
    Launches browser GUI windows after restoring configurations.
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Repo = "BrowserParity-mark",

    [string]$LocalPath = (Join-Path $env:USERPROFILE ".browserparity-configs"),

    [ValidateSet('All', 'Opera', 'Edge', 'Firefox', 'Chrome')]
    [string[]]$Browsers = @('Opera', 'Edge', 'Firefox', 'Chrome'),

    [ValidateSet('Home', 'Mobile')]
    [string]$Profile = 'Home',

    [switch]$Diff,
    [switch]$Preview,
    [switch]$Launch
)

$ErrorActionPreference = 'Stop'

if ($Preview) { $Diff = $true }

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "     🔄 BROWSERPARITY: RESTORE FROM PRIVATE GITHUB REPOSITORY       " -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

# 1. Prerequisite Checks: git and gh
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is required but not found in PATH. Install via: winget install --id Git.Git -e"
    exit 1
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI ('gh') is required but not found in PATH. Install via: winget install --id GitHub.cli -e"
    exit 1
}

$ghUser = $null
try {
    $ghUser = (& gh api user -q .login 2>$null).Trim()
} catch {}

if (-not $ghUser) {
    Write-Error "GitHub CLI is not authenticated. Please run 'gh auth login' first."
    exit 1
}
Write-Host "Authenticated as GitHub user: $ghUser" -ForegroundColor Green

$fullRepo = if ($Repo -match "/") { $Repo } else { "$ghUser/$Repo" }
Write-Host "Target repository: $fullRepo" -ForegroundColor Cyan

# 2. Strict Privacy Verification
Write-Host "`n[1/4] Verifying private repository status via GitHub CLI..." -ForegroundColor Yellow
$repoViewRaw = & gh repo view $fullRepo --json isPrivate,nameWithOwner 2>$null

if (-not $repoViewRaw) {
    Write-Error "Private repository '$fullRepo' not found on GitHub. Make sure you have run 'backup-to-github.ps1' first."
    exit 1
}

$repoInfo = $repoViewRaw | ConvertFrom-Json
if ($repoInfo.isPrivate -ne $true) {
    Write-Host ""
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    Write-Host "  SECURITY ALERT: REPOSITORY '$fullRepo' IS PUBLIC!" -ForegroundColor Red
    Write-Host "  BrowserParity will not restore from an unverified public repository." -ForegroundColor Red
    Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    exit 1
}
Write-Host "  [✓] Verified: Repository '$fullRepo' is PRIVATE." -ForegroundColor Green

# 3. Pull / Clone Latest Snapshot
Write-Host "`n[2/4] Pulling latest snapshot from $fullRepo..." -ForegroundColor Yellow
if (-not (Test-Path (Join-Path $LocalPath ".git"))) {
    if (Test-Path $LocalPath) { Remove-Item -Path $LocalPath -Recurse -Force | Out-Null }
    New-Item -ItemType Directory -Path (Split-Path $LocalPath -Parent) -Force | Out-Null
    & gh repo clone $fullRepo $LocalPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to clone repository '$fullRepo'."
        exit 1
    }
} else {
    & git -C $LocalPath pull --rebase origin HEAD
}

$manifestFile = Join-Path $LocalPath "manifest.json"
if (-not (Test-Path $manifestFile)) {
    Write-Error "manifest.json not found in repository '$fullRepo'."
    exit 1
}

# 4. Compute State Diff (Current Local vs Incoming Backup)
Write-Host "`n[3/4] Analyzing backup delta vs. current local state..." -ForegroundColor Yellow
$manifest = Get-Content -Path $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
$targetBrowsers = if ($Browsers -contains 'All') { @('Opera', 'Edge', 'Firefox', 'Chrome') } else { $Browsers }

$diffList = New-Object System.Collections.ArrayList

foreach ($entry in $manifest) {
    $browserMatch = $targetBrowsers | Where-Object { $entry.Category -match "^$_" }
    if (-not $browserMatch) { continue }

    $src = Join-Path $LocalPath $entry.BackupRelativePath
    $dest = $entry.OriginalFullPath

    if (Test-Path $src) {
        $srcSize = (Get-Item $src).Length
        $srcTime = (Get-Item $src).LastWriteTime

        if (-not (Test-Path $dest)) {
            $diffList.Add([PSCustomObject]@{
                "Component / Target" = "$($entry.Category) / $([System.IO.Path]::GetFileName($src))"
                "State Delta"        = "New ($srcSize bytes)"
                "Sync Action"        = "Create from Backup"
            })
        } else {
            $destSize = (Get-Item $dest).Length
            $destTime = (Get-Item $dest).LastWriteTime

            if ($src -match "Bookmarks$") {
                try {
                    $srcBm = Get-Content $src -Raw -Encoding UTF8 | ConvertFrom-Json
                    $destBm = Get-Content $dest -Raw -Encoding UTF8 | ConvertFrom-Json
                    $srcCount = ($srcBm.roots.bookmark_bar.children.Count + $srcBm.roots.other.children.Count)
                    $destCount = ($destBm.roots.bookmark_bar.children.Count + $destBm.roots.other.children.Count)
                    $diffList.Add([PSCustomObject]@{
                        "Component / Target" = "$($entry.Category) / Bookmarks"
                        "State Delta"        = "Backup: $srcCount items | Local: $destCount items"
                        "Sync Action"        = "Restore & Retain Clean Layout"
                    })
                } catch {
                    $diffList.Add([PSCustomObject]@{
                        "Component / Target" = "$($entry.Category) / Bookmarks"
                        "State Delta"        = "Size Delta: $($srcSize - $destSize) bytes"
                        "Sync Action"        = "Restore Bookmarks"
                    })
                }
            } else {
                $deltaStr = if ($srcSize -eq $destSize) { "Exact size match ($srcSize B)" } else { "Delta: $($srcSize - $destSize) bytes" }
                $diffList.Add([PSCustomObject]@{
                    "Component / Target" = "$($entry.Category) / $([System.IO.Path]::GetFileName($src))"
                    "State Delta"        = "$deltaStr"
                    "Sync Action"        = "Restore & Re-apply Parity"
                })
            }
        }
    }
}

# Check for personal network profiles in private repo
$privateProfilesDir = Join-Path $LocalPath "profiles"
if (Test-Path $privateProfilesDir) {
    Get-ChildItem -Path $privateProfilesDir -Filter "*.json" | ForEach-Object {
        $diffList.Add([PSCustomObject]@{
            "Component / Target" = "Private Network Profile ($($_.Name))"
            "State Delta"        = "Personal network & DNS rules"
            "Sync Action"        = "Merge with Engine Defaults"
        })
    }
}

Write-Host ""
$diffList | Format-Table -AutoSize | Out-String | Write-Host

# Check for snapshot browser version metadata
$snapshotInfoFile = Join-Path $LocalPath "snapshot-info.json"
if (Test-Path $snapshotInfoFile) {
    try {
        $snapshotInfo = Get-Content $snapshotInfoFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($snapshotInfo.BrowserVersions) {
            Write-Host "🔍 Snapshot Origin: $($snapshotInfo.ComputerName) | Captured: $($snapshotInfo.BackupDate)" -ForegroundColor DarkCyan
            $snapshotInfo.BrowserVersions.PSObject.Properties | ForEach-Object {
                Write-Host "  • $($_.Name): $($_.Value.Version)" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
    } catch {}
}

if ($Diff) {
    Write-Host "[~] Diff preview complete. Exiting without modifying any files." -ForegroundColor Cyan
    exit 0
}

# 5. Stop Browsers & Restore Files
Write-Host "[4/4] Stopping browser processes and restoring files..." -ForegroundColor Yellow
Get-Process -Name "opera*", "launcher*", "msedge*", "msedgewebview2*", "firefox*", "chrome*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

foreach ($entry in $manifest) {
    $browserMatch = $targetBrowsers | Where-Object { $entry.Category -match "^$_" }
    if (-not $browserMatch) { continue }

    $src = Join-Path $LocalPath $entry.BackupRelativePath
    $dest = $entry.OriginalFullPath

    if (Test-Path $src) {
        $destParent = Split-Path $dest -Parent
        if (-not (Test-Path $destParent)) { New-Item -ItemType Directory -Path $destParent -Force | Out-Null }
        Copy-Item -Path $src -Destination $dest -Force
        Write-Host "  [+] Restored: $($entry.Category) -> $dest" -ForegroundColor Green
    }
}

# 6. Reconcile Parity Rules on Restored Profiles
Write-Host "`n[+] Re-enforcing parity rules (DuckDuckGo, Dark Mode, Anti-Nag)..." -ForegroundColor Yellow
$syncScript = Join-Path $PSScriptRoot "sync-browser-parity.ps1"
if (Test-Path $syncScript) {
    if ($Launch) {
        & $syncScript -Browsers $Browsers -Profile $Profile -Launch
    } else {
        & $syncScript -Browsers $Browsers -Profile $Profile
    }
}

Write-Host "`n====================================================================" -ForegroundColor Green
Write-Host "  🎉 RESTORE COMPLETE! Browser configurations restored from $fullRepo" -ForegroundColor Green
Write-Host "====================================================================" -ForegroundColor Green
