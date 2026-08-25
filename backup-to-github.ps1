<#
.SYNOPSIS
    Backup-To-GitHub: Backs up personal browser configs, bookmarks, and profiles to a PRIVATE GitHub repository.
.DESCRIPTION
    1. Enforces prerequisites: Verifies 'git' and GitHub CLI ('gh') are installed and authenticated.
    2. Enforces STRICT PRIVACY SAFETY:
       - Checks the target GitHub repository via GitHub CLI.
       - If the repository does not exist, automatically creates it as PRIVATE.
       - If the repository exists and is PUBLIC, HALTS WITH AN ERROR to prevent accidental data leaks.
    3. Captures live profiles and bookmarks for Opera, Edge, Firefox, and Chrome.
    4. Commits and pushes timestamped snapshots to your private GitHub repository.
.PARAMETER Repo
    Target GitHub repository name (e.g. 'BrowserParity-mark' or 'owner/repo'). Default: 'BrowserParity-mark'.
.PARAMETER LocalPath
    Local clone/staging path for the private repo (default: '$env:USERPROFILE\.browserparity-configs').
.PARAMETER Browsers
    Target specific browsers to backup: 'All', 'Opera', 'Edge', 'Firefox', 'Chrome' (default: All).
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Repo = "BrowserParity-mark",

    [string]$LocalPath = (Join-Path $env:USERPROFILE ".browserparity-configs"),

    [ValidateSet('All', 'Opera', 'Edge', 'Firefox', 'Chrome')]
    [string[]]$Browsers = @('Opera', 'Edge', 'Firefox', 'Chrome')
)

$ErrorActionPreference = 'Stop'

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "      🔒 BROWSERPARITY: BACKUP TO PRIVATE GITHUB REPOSITORY         " -ForegroundColor Cyan
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

# Verify gh authentication
$ghUser = $null
try {
    $ghUser = (& gh api user -q .login 2>$null).Trim()
} catch {}

if (-not $ghUser) {
    Write-Error "GitHub CLI is not authenticated. Please run 'gh auth login' first."
    exit 1
}
Write-Host "Authenticated as GitHub user: $ghUser" -ForegroundColor Green

# Resolve full repository name (owner/repo)
$fullRepo = if ($Repo -match "/") { $Repo } else { "$ghUser/$Repo" }
Write-Host "Target repository: $fullRepo" -ForegroundColor Cyan

# 2. Strict Privacy Verification
Write-Host "`n[1/4] Verifying private repository status via GitHub CLI..." -ForegroundColor Yellow
$repoViewRaw = & gh repo view $fullRepo --json isPrivate,nameWithOwner 2>$null

if (-not $repoViewRaw) {
    # Repository does not exist -> Create as PRIVATE
    Write-Host "  Repository '$fullRepo' does not exist." -ForegroundColor DarkGray
    Write-Host "  [+] Creating new PRIVATE GitHub repository: $fullRepo ..." -ForegroundColor Yellow
    & gh repo create $fullRepo --private --description "Private browser profile snapshots, bookmarks, and configs for BrowserParity"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create private repository '$fullRepo'."
        exit 1
    }
    Write-Host "  [✓] Successfully created private repository '$fullRepo'." -ForegroundColor Green
} else {
    # Repository exists -> Check isPrivate
    $repoInfo = $repoViewRaw | ConvertFrom-Json
    if ($repoInfo.isPrivate -ne $true) {
        Write-Host ""
        Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
        Write-Host "  SECURITY ALERT: REPOSITORY '$fullRepo' IS PUBLIC!" -ForegroundColor Red
        Write-Host "  BrowserParity STRICTLY REFUSES to upload personal browser bookmarks," -ForegroundColor Red
        Write-Host "  session states, or profile configurations to a public repository." -ForegroundColor Red
        Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
        Write-Host "`nTo fix this, change the repository visibility to private:" -ForegroundColor Yellow
        Write-Host "  gh repo edit $fullRepo --visibility private`n" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [✓] Verified: Repository '$fullRepo' is PRIVATE." -ForegroundColor Green
}

# 3. Clone or Sync Local Staging Directory
Write-Host "`n[2/4] Synchronizing local staging directory at: $LocalPath..." -ForegroundColor Yellow
if (-not (Test-Path (Join-Path $LocalPath ".git"))) {
    if (Test-Path $LocalPath) { Remove-Item -Path $LocalPath -Recurse -Force | Out-Null }
    New-Item -ItemType Directory -Path (Split-Path $LocalPath -Parent) -Force | Out-Null
    & gh repo clone $fullRepo $LocalPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to clone repository '$fullRepo' into '$LocalPath'."
        exit 1
    }
} else {
    try {
        & git -C $LocalPath pull --rebase --quiet 2>$null
    } catch {
        Write-Warning "Could not rebase local staging repo. Proceeding with local state."
    }
}

# 4. Capture Browser Profiles & Bookmarks
Write-Host "`n[3/4] Capturing live browser profiles, bookmarks, and preferences..." -ForegroundColor Yellow

$targetBrowsers = if ($Browsers -contains 'All') { @('Opera', 'Edge', 'Firefox', 'Chrome') } else { $Browsers }
$manifest = @()
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Stage-ProfileFile {
    param([string]$FilePath, [string]$Category)
    if (Test-Path $FilePath) {
        $categoryDir = Join-Path $LocalPath $Category
        if (-not (Test-Path $categoryDir)) { New-Item -ItemType Directory -Path $categoryDir -Force | Out-Null }
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        $destPath = Join-Path $categoryDir $fileName
        Copy-Item -Path $FilePath -Destination $destPath -Force
        $relPath = "$Category/$fileName"
        $script:manifest += [PSCustomObject]@{
            Category           = $Category
            BackupRelativePath = $relPath
            OriginalFullPath   = $FilePath
            LastModified       = (Get-Item $FilePath).LastWriteTimeUtc.ToString("o")
        }
        Write-Host "  [+] Captured: $Category -> $fileName" -ForegroundColor DarkGray
    }
}

if ($targetBrowsers -contains 'Opera') {
    $operaDir = Join-Path $env:APPDATA "Opera Software\Opera Stable"
    Stage-ProfileFile -FilePath (Join-Path $operaDir "Default\Preferences") -Category "Opera"
    Stage-ProfileFile -FilePath (Join-Path $operaDir "Preferences") -Category "Opera"
    Stage-ProfileFile -FilePath (Join-Path $operaDir "Default\Bookmarks") -Category "Opera"
}

if ($targetBrowsers -contains 'Edge') {
    $edgeDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    Stage-ProfileFile -FilePath (Join-Path $edgeDir "Default\Preferences") -Category "Edge"
    Stage-ProfileFile -FilePath (Join-Path $edgeDir "Default\Bookmarks") -Category "Edge"
    Stage-ProfileFile -FilePath (Join-Path $edgeDir "Local State") -Category "Edge"
}

if ($targetBrowsers -contains 'Firefox') {
    $ffRoots = @(
        "$env:APPDATA\Mozilla\Firefox\Profiles",
        "$env:LOCALAPPDATA\Packages\Mozilla.MozillaFirefox_jag0gd4e3s9p2\LocalSmart Cardhe\Roaming\Mozilla\Firefox\Profiles"
    )
    foreach ($root in $ffRoots) {
        if (Test-Path $root) {
            Get-ChildItem -Path $root -Directory | ForEach-Object {
                Stage-ProfileFile -FilePath (Join-Path $_.FullName "user.js") -Category "Firefox/$($_.Name)"
                Stage-ProfileFile -FilePath (Join-Path $_.FullName "prefs.js") -Category "Firefox/$($_.Name)"
            }
        }
    }
}

if ($targetBrowsers -contains 'Chrome') {
    $chromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    Stage-ProfileFile -FilePath (Join-Path $chromeDir "Default\Preferences") -Category "Chrome"
    Stage-ProfileFile -FilePath (Join-Path $chromeDir "Default\Bookmarks") -Category "Chrome"
    Stage-ProfileFile -FilePath (Join-Path $chromeDir "Local State") -Category "Chrome"
}

# 5. Seed or Preserve Personal Network Profiles in Private Repo
$profilesDir = Join-Path $LocalPath "profiles"
if (-not (Test-Path $profilesDir)) {
    New-Item -ItemType Directory -Path $profilesDir -Force | Out-Null
}

$homeProfilePath = Join-Path $profilesDir "Home.json"
if (-not (Test-Path $homeProfilePath)) {
    $defaultHome = [ordered]@{
        "ProfileName"     = "Home"
        "Description"     = "Personal home office network profile with LAN and FRITZ!Box exclusions"
        "DohMode"         = "automatic"
        "DohTemplate"     = "https://dns.quad9.net/dns-query"
        "ExcludedDomains" = "fritz.box,*.fritz.box,*.ts.net,*.local,*.lan,localhost,127.0.0.1,10.*,192.168.*,100.*"
        "HttpsMode"       = "first"
        "PreferIpv4"      = $true
    }
    $homeJson = ConvertTo-Json -InputObject $defaultHome -Depth 10
    [System.IO.File]::WriteAllText($homeProfilePath, $homeJson, $utf8NoBom)
    Write-Host "  [+] Seeded personal Home profile: profiles/Home.json" -ForegroundColor DarkGray
}

$mobileProfilePath = Join-Path $profilesDir "Mobile.json"
if (-not (Test-Path $mobileProfilePath)) {
    $defaultMobile = [ordered]@{
        "ProfileName"     = "Mobile"
        "Description"     = "Travel / Untrusted hotspot network profile with strict DoH and HTTPS-Only"
        "DohMode"         = "secure"
        "DohTemplate"     = "https://dns.quad9.net/dns-query"
        "ExcludedDomains" = "localhost,127.0.0.1"
        "HttpsMode"       = "only"
        "PreferIpv4"      = $false
    }
    $mobileJson = ConvertTo-Json -InputObject $defaultMobile -Depth 10
    [System.IO.File]::WriteAllText($mobileProfilePath, $mobileJson, $utf8NoBom)
    Write-Host "  [+] Seeded personal Mobile profile: profiles/Mobile.json" -ForegroundColor DarkGray
}

# 6. Synchronize Version Registry & Snapshot Metadata
$regPath = Join-Path (Join-Path $PSScriptRoot "backups") "version-registry.json"
if (Test-Path $regPath) {
    Copy-Item -Path $regPath -Destination (Join-Path $LocalPath "version-registry.json") -Force
}
$regData = if (Test-Path $regPath) { Get-Content $regPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }

$metadata = [ordered]@{
    ComputerName    = $env:COMPUTERNAME
    UserName        = $env:USERNAME
    BackupDate      = (Get-Date).ToString("o")
    Browsers        = $targetBrowsers
    BrowserVersions = if ($regData -and $regData.Browsers) { $regData.Browsers } else { @{} }
    FilesCount      = $manifest.Count
}
$metadataJson = ConvertTo-Json -InputObject $metadata -Depth 5
[System.IO.File]::WriteAllText((Join-Path $LocalPath "snapshot-info.json"), $metadataJson, $utf8NoBom)

$manifestJson = ConvertTo-Json -InputObject $manifest -Depth 10
[System.IO.File]::WriteAllText((Join-Path $LocalPath "manifest.json"), $manifestJson, $utf8NoBom)

# Add standard .gitignore inside the private repo
$privateGitignore = @"
*.tmp
*.log
Thumbs.db
"@
[System.IO.File]::WriteAllText((Join-Path $LocalPath ".gitignore"), $privateGitignore, $utf8NoBom)

# 7. Commit and Push to Private GitHub Repo
Write-Host ("`n[4/4] Committing and pushing to private repository: " + $fullRepo + "...") -ForegroundColor Yellow

& git -C $LocalPath add .
$changes = & git -C $LocalPath status --porcelain

if ($changes) {
    $nowStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $commitMsg = "chore(snapshot): backup from $env:COMPUTERNAME on $nowStr"
    & git -C $LocalPath commit -m $commitMsg
    & git -C $LocalPath push origin HEAD
    Write-Host ("  [✓] Snapshot pushed successfully to " + $fullRepo + "!") -ForegroundColor Green
} else {
    Write-Host "  [~] No changes detected; private repository is already up to date." -ForegroundColor DarkGray
}

Write-Host "`n====================================================================" -ForegroundColor Green
Write-Host ("  🎉 BACKUP COMPLETE! Configs safely stored in " + $fullRepo + " (PRIVATE)  ") -ForegroundColor Green
Write-Host "====================================================================" -ForegroundColor Green
