<#
.SYNOPSIS
    Bootstrap-New-Box: 1-Click Provisioning Wizard for Fresh Dev Machines.
.DESCRIPTION
    Automates the Day-1 onboarding flow for fresh workstations or dev sandboxes:
    1. Ensures Git and GitHub CLI ('gh') are installed via winget if missing.
    2. Installs missing browsers (Opera, Edge, Firefox, Chrome) silently via winget.
    3. (Optional) Restores your personal bookmarks, preferences, and extensions from your PRIVATE GitHub repository.
    4. Enforces baseline minimalist DuckDuckGo parity, dark mode, Segoe UI typography, and anti-annoyance settings.
    5. Launches curated Onboarding Hub tabs across all browsers for instant Cloud Sync authentication and Extension installation.
.PARAMETER Browsers
    Target specific browsers to provision: 'All', 'Opera', 'Edge', 'Firefox', 'Chrome' (default: All 4).
.PARAMETER PrivateRepo
    Optional private GitHub repository name (e.g. 'browser-parity-configs' or 'owner/repo') to restore personal bookmarks and profiles from.
.PARAMETER Profile
    Network profile: 'Home' (default: resilient DoH, *.fritz.box / *.ts.net / LAN HTTP whitelist, IPv4-optimized) or 'Mobile' (strict DoH with Quad9 threat block, strict HTTPS-only, dual-stack IPv4/IPv6).
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet('All', 'Opera', 'Edge', 'Firefox', 'Chrome')]
    [string[]]$Browsers = @('Opera', 'Edge', 'Firefox', 'Chrome'),

    [ValidateSet('Home', 'Mobile')]
    [string]$Profile = 'Home',

    [string]$PrivateRepo
)

$ErrorActionPreference = 'Stop'

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "         🚀 BROWSERPARITY: FRESH DEV BOX PROVISIONING WIZARD        " -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

$isWin = $IsWindows -or ($env:OS -match 'Windows')
$isMac = $IsMacOS -or ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX))
$isLin = $IsLinux -or ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux))

# 1. Verify / Auto-Install Prerequisites (git, gh, package managers)
if ($isWin) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "Windows Package Manager ('winget') is required but was not found on this machine."
        exit 1
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Git via winget..." -ForegroundColor Yellow
        & winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements
    }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "Installing GitHub CLI via winget..." -ForegroundColor Yellow
        & winget install --id GitHub.cli -e --silent --accept-source-agreements --accept-package-agreements
    }
} elseif ($isMac) {
    if (-not (Get-Command brew -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Homebrew on macOS..." -ForegroundColor Yellow
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { & brew install git }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { & brew install gh }
} else {
    # Linux
    if (Get-Command apt-get -ErrorAction SilentlyContinue) {
        sudo apt-get update -y
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { sudo apt-get install -y git }
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { sudo apt-get install -y gh }
    } elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { sudo dnf install -y git }
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { sudo dnf install -y gh }
    }
}

$syncScript = Join-Path $PSScriptRoot "sync-browser-parity.ps1"
if (-not (Test-Path $syncScript)) {
    Write-Error "Could not find sync engine at: $syncScript"
    exit 1
}

# 3. Install missing browsers via winget
Write-Host "`n[Step 1/3] Installing missing browsers via winget..." -ForegroundColor Yellow
& $syncScript -Browsers $Browsers -Profile $Profile -Install

# 4. Optional: Restore from Private GitHub Repo
if ($PrivateRepo) {
    $restoreScript = Join-Path $PSScriptRoot "restore-from-github.ps1"
    if (Test-Path $restoreScript) {
        Write-Host "`n[Step 2/3] Restoring configurations from private GitHub repository '$PrivateRepo'..." -ForegroundColor Yellow
        & $restoreScript -Repo $PrivateRepo -Browsers $Browsers -Profile $Profile
    }
} else {
    Write-Host "`n[Step 2/3] Applying baseline zero-state parity configurations..." -ForegroundColor Yellow
    & $syncScript -Browsers $Browsers -Profile $Profile
}

# 5. Launch Onboarding Hub
Write-Host "`n[Step 3/3] Launching Cloud Sync & Extension Hub onboarding tabs..." -ForegroundColor Yellow
& $syncScript -Browsers $Browsers -Onboard

Write-Host "`n====================================================================" -ForegroundColor Green
Write-Host "                   🎉 WORKSTATION ONBOARDING READY!                " -ForegroundColor Green
Write-Host "====================================================================" -ForegroundColor Green
Write-Host @"

📋 Quick 2-Minute Onboarding Checklist:
1. Browser Sync: Log in to your respective browser accounts in the opened tabs.
2. Extensions: Click 'Add to Browser' on Consent-O-Matic, Violentmonkey, and Adblockers.
3. Violentmonkey Userscripts:
   - Open Violentmonkey Settings -> 'Sync' tab -> Connect to Google Drive (or OneDrive/WebDAV).
   - Your userscripts (including 'userscripts/agent-page-extractor.user.js') will automatically sync!

Private Backup Command:
  .\backup-to-github.ps1

Private Restore Command:
  .\restore-from-github.ps1
"@ -ForegroundColor Cyan
