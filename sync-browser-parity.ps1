<#
.SYNOPSIS
    BrowserParity: Cross-Browser Minimalist, Debloating & Automation Suite (Opera, Edge, Firefox, Chrome).
.DESCRIPTION
    Enforces true minimalist feature parity across Opera, Microsoft Edge, Mozilla Firefox, and Google Chrome:
    - Default Search Engine: DuckDuckGo across all four browsers.
    - Zero AI bloat, telemetry, sponsored tiles, trending suggestions, or shopping assistants.
    - Eliminates 6 major browser annoyances: notification spam, media autoplay, default browser nags,
      WebRTC private IP leaks, telemetry surveys, and promotional cashback hints.
    - Typography, zoom, DPI, silent downloads, and session restore parity.
    - Full reproducibility, repeatability, idempotency, and reversible backup/rollback capabilities.
    - Supports automated winget installation, deep detritus purging, onboarding flows, and CDP agent automation.
    - QUIET BY DEFAULT: Applies parity silently without terminating open windows or launching duplicate instances.
.PARAMETER Browsers
    Target specific browsers: 'All', 'Opera', 'Edge', 'Firefox', 'Chrome' (default: 'Opera', 'Edge', 'Firefox', 'Chrome').
.PARAMETER Install
    Installs missing specified browsers silently via winget.
.PARAMETER Uninstall
    Uninstalls specified browsers silently via winget.
.PARAMETER Purge
    Deeply removes user profile data, Smart Cardhes, registry entries, and detritus/leftovers for specified browsers.
.PARAMETER Onboard
    Launches curated onboarding tabs (Cloud Sync authentication + Extension store pages + Violentmonkey setup).
.PARAMETER Launch
    Explicitly launches GUI browser windows on the interactive desktop after applying configuration.
.PARAMETER Restart
    Explicitly terminates running browser processes prior to applying configuration.
.PARAMETER AgentMode
    Launches browsers in CDP Remote Debugging Mode (Opera: 9222, Edge: 9223, Firefox: 9224, Chrome: 9225).
.PARAMETER Rollback
    Reverts all configuration files to the most recent backup snapshot.
.PARAMETER NoBackup
    Skips creating a backup snapshot prior to applying changes.
.PARAMETER Profile
    Network profile: 'Home' (default: resilient DoH, *.fritz.box / *.ts.net / LAN HTTP whitelist, IPv4-optimized) or 'Mobile' (strict DoH with Quad9 threat block, strict HTTPS-only, dual-stack IPv4/IPv6).
.PARAMETER DebugPort
    Base remote debugging port when running with -AgentMode (default: 9222).
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet('All', 'Opera', 'Edge', 'Firefox', 'Chrome')]
    [string[]]$Browsers = @('Opera', 'Edge', 'Firefox', 'Chrome'),

    [ValidateSet('Home', 'Mobile')]
    [string]$Profile = 'Home',

    [string]$ConfigFile,

    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Purge,
    [switch]$Onboard,
    [switch]$Launch,
    [switch]$Restart,
    [switch]$AgentMode,
    [switch]$Rollback,
    [switch]$NoBackup,
    [switch]$Versions,
    [switch]$Schema,
    [int]$DebugPort = 9222
)

$ErrorActionPreference = 'Stop'

# Cross-Platform OS Detection (100% compatible across Windows PowerShell 5.1, pwsh 7.x, macOS, Linux)
$isWin = ($env:OS -match 'Windows') -or ($PSVersionTable.PSEdition -eq 'Desktop') -or ($null -ne (Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue) -and $IsWindows)
$isMac = if (Get-Variable -Name IsMacOS -ValueOnly -ErrorAction SilentlyContinue) { $IsMacOS } else { [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::MacOSX }
$isLin = if (Get-Variable -Name IsLinux -ValueOnly -ErrorAction SilentlyContinue) { $IsLinux } else { [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Unix -and -not $isMac }

$userHome = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
$userDownloadsDir = Join-Path $userHome "Downloads"

function Convert-JsonToHashtable {
    param([string]$JsonText)
    if (-not $JsonText -or [string]::IsNullOrWhiteSpace($JsonText)) { return @{} }
    
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return ($JsonText | ConvertFrom-Json -AsHashtable)
    }

    $obj = $JsonText | ConvertFrom-Json
    function Convert-PSObjectToHashtable($item) {
        if ($null -eq $item) { return $null }
        if ($item -is [PSCustomObject]) {
            $hash = @{}
            foreach ($prop in $item.PSObject.Properties) {
                $hash[$prop.Name] = Convert-PSObjectToHashtable $prop.Value
            }
            return $hash
        } elseif ($item -is [System.Collections.IEnumerable] -and $item -isnot [string]) {
            $arr = [System.Collections.ArrayList]::new()
            foreach ($sub in $item) { [void]$arr.Add((Convert-PSObjectToHashtable $sub)) }
            return $arr.ToArray()
        } else {
            return $item
        }
    }
    return (Convert-PSObjectToHashtable $obj)
}

# Sane Generic Defaults + Dynamic Private Profile Resolution
$effectiveProfile = @{
    DohMode         = if ($Profile -eq 'Mobile') { "secure" } else { "automatic" }
    DohTemplate     = "https://dns.quad9.net/dns-query"
    ExcludedDomains = if ($Profile -eq 'Mobile') { "localhost,127.0.0.1" } else { "localhost,127.0.0.1,*.local,*.lan,*.fritz.box,*.ts.net,10.*,192.168.*,172.16.*,100.*" }
    HttpsMode       = if ($Profile -eq 'Mobile') { "only" } else { "first" }
    PreferIpv4      = if ($Profile -eq 'Mobile') { $false } else { $true }
}

$candidateProfilePaths = @(
    $ConfigFile,
    (Join-Path $userHome ".browserparity-configs\profiles\$Profile.json"),
    (Join-Path $userHome ".browserparity-configs\config.json")
)
foreach ($cp in $candidateProfilePaths) {
    if ($cp -and (Test-Path $cp)) {
        try {
            $customConfig = Convert-JsonToHashtable (Get-Content $cp -Raw -Encoding UTF8)
            if ($customConfig) {
                Write-Host "Loaded private profile override from: $cp" -ForegroundColor DarkGray
                foreach ($k in $customConfig.Keys) {
                    $effectiveProfile[$k] = $customConfig[$k]
                }
                break
            }
        } catch {}
    }
}

# Resolve target browsers
$targetBrowsers = @()
if ($Browsers -contains 'All') {
    $targetBrowsers = @('Opera', 'Edge', 'Firefox', 'Chrome')
} else {
    $targetBrowsers = $Browsers
}

# Helper class to launch GUI applications on the interactive user desktop (Windows only)
if ($isWin -and (-not ([System.Management.Automation.PSTypeName]'DesktopLauncher').Type)) {
    $desktopLauncherLines = @(
        'using System;',
        'using System.Runtime.InteropServices;',
        '',
        'public class DesktopLauncher {',
        '    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]',
        '    public struct STARTUPINFO {',
        '        public int cb;',
        '        public string lpReserved;',
        '        public string lpDesktop;',
        '        public string lpTitle;',
        '        public int dwX;',
        '        public int dwY;',
        '        public int dwXSize;',
        '        public int dwYSize;',
        '        public int dwXCountChars;',
        '        public int dwYCountChars;',
        '        public int dwFillAttribute;',
        '        public int dwFlags;',
        '        public short wShowWindow;',
        '        public short cbReserved2;',
        '        public IntPtr lpReserved2;',
        '        public IntPtr hStdInput;',
        '        public IntPtr hStdOutput;',
        '        public IntPtr hStdError;',
        '    }',
        '',
        '    [StructLayout(LayoutKind.Sequential)]',
        '    public struct PROCESS_INFORMATION {',
        '        public IntPtr hProcess;',
        '        public IntPtr hThread;',
        '        public int dwProcessId;',
        '        public int dwThreadId;',
        '    }',
        '',
        '    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]',
        '    public static extern bool CreateProcess(',
        '        string lpApplicationName,',
        '        string lpCommandLine,',
        '        IntPtr lpProcessAttributes,',
        '        IntPtr lpThreadAttributes,',
        '        bool bInheritHandles,',
        '        uint dwCreationFlags,',
        '        IntPtr lpEnvironment,',
        '        string lpCurrentDirectory,',
        '        ref STARTUPINFO lpStartupInfo,',
        '        out PROCESS_INFORMATION lpProcessInformation',
        '    );',
        '',
        '    [DllImport("kernel32.dll", SetLastError = true)]',
        '    public static extern bool CloseHandle(IntPtr hObject);',
        '',
        '    public static int LaunchOnInteractiveDesktop(string exePath, string commandLineArgs) {',
        '        STARTUPINFO si = new STARTUPINFO();',
        '        si.cb = Marshal.SizeOf(si);',
        '        si.lpDesktop = "WinSta0\\Default";',
        '        si.dwFlags = 1;',
        '        si.wShowWindow = 1;',
        '',
        '        PROCESS_INFORMATION pi = new PROCESS_INFORMATION();',
        '        string fullCmdLine = "\"" + exePath + "\" " + commandLineArgs;',
        '',
        '        bool success = CreateProcess(',
        '            null,',
        '            fullCmdLine,',
        '            IntPtr.Zero,',
        '            IntPtr.Zero,',
        '            false,',
        '            0,',
        '            IntPtr.Zero,',
        '            null,',
        '            ref si,',
        '            out pi',
        '        );',
        '',
        '        if (!success) {',
        '            int err = Marshal.GetLastWin32Error();',
        '            throw new System.ComponentModel.Win32Exception(err);',
        '        }',
        '',
        '        CloseHandle(pi.hProcess);',
        '        CloseHandle(pi.hThread);',
        '        return pi.dwProcessId;',
        '    }',
        '}'
    )
    $desktopLauncherCode = $desktopLauncherLines -join "`r`n"
    Add-Type -TypeDefinition $desktopLauncherCode
}

function Launch-BrowserProcess {
    param(
        [string]$ExecutablePath,
        [string]$Arguments = ""
    )

    if (-not $ExecutablePath -or -not (Test-Path $ExecutablePath)) {
        return $false
    }

    if ($isWin) {
        if (([System.Management.Automation.PSTypeName]'DesktopLauncher').Type) {
            return [DesktopLauncher]::LaunchOnInteractiveDesktop($ExecutablePath, $Arguments)
        } else {
            Start-Process -FilePath $ExecutablePath -ArgumentList $Arguments
            return $true
        }
    } elseif ($isMac) {
        if ($ExecutablePath -match '\.app') {
            $appName = Split-Path (Split-Path $ExecutablePath -Parent) -Parent
            if ($Arguments) {
                Start-Process -FilePath "open" -ArgumentList @("-a", $appName, "--args", $Arguments)
            } else {
                Start-Process -FilePath "open" -ArgumentList @("-a", $appName)
            }
        } else {
            Start-Process -FilePath $ExecutablePath -ArgumentList $Arguments
        }
        return $true
    } else {
        Start-Process -FilePath $ExecutablePath -ArgumentList $Arguments
        return $true
    }
}

function Set-NestedProperty {
    param(
        [Parameter(Mandatory=$true)] [System.Collections.IDictionary]$Dictionary,
        [Parameter(Mandatory=$true)] [string[]]$Path,
        [Parameter(Mandatory=$true)] $Value
    )
    $current = $Dictionary
    for ($i = 0; $i -lt $Path.Length - 1; $i++) {
        $key = $Path[$i]
        if (-not $current.Contains($key) -or ($current[$key] -isnot [System.Collections.IDictionary])) {
            $current[$key] = @{}
        }
        $current = $current[$key]
    }
    $current[$Path[-1]] = $Value
}

function Find-OperaExecutable {
    if ($isWin) {
        $runningProcs = Get-Process -Name "opera", "launcher" -ErrorAction SilentlyContinue
        foreach ($proc in $runningProcs) {
            try {
                $p = $proc.Path
                if (-not $p -and $proc.MainModule) { $p = $proc.MainModule.FileName }
                if ($p -and (Test-Path $p)) { return (Get-Item $p).FullName }
            } catch {}
        }
        $dirFallbacks = @(
            "$env:LOCALAPPDATA\Programs\Opera\opera.exe",
            "$env:LOCALAPPDATA\Programs\Opera\launcher.exe",
            "$env:ProgramFiles\Opera\opera.exe",
            "$env:ProgramFiles\Opera\launcher.exe",
            "${env:ProgramFiles(x86)}\Opera\opera.exe"
        )
        foreach ($f in $dirFallbacks) { if (Test-Path $f) { return (Get-Item $f).FullName } }
    } elseif ($isMac) {
        $macPaths = @(
            "/Applications/Opera.app/Contents/MacOS/Opera",
            (Join-Path $userHome "Applications/Opera.app/Contents/MacOS/Opera")
        )
        foreach ($f in $macPaths) { if (Test-Path $f) { return (Get-Item $f).FullName } }
    } else {
        $linPaths = @("/usr/bin/opera", "/snap/bin/opera", "/usr/local/bin/opera", "/usr/bin/opera-developer")
        foreach ($f in $linPaths) { if (Test-Path $f) { return (Get-Item $f).FullName } }
        $cmd = Get-Command opera -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Find-EdgeExecutable {
    if ($isWin) {
        $edgePaths = @(
            "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
            "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
        )
        foreach ($p in $edgePaths) { if (Test-Path $p) { return (Get-Item $p).FullName } }
        $reg = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe" -ErrorAction SilentlyContinue).'(Default)'
        if ($reg -and (Test-Path $reg)) { return (Get-Item $reg).FullName }
    } elseif ($isMac) {
        $macPaths = @(
            "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
            (Join-Path $userHome "Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge")
        )
        foreach ($f in $macPaths) { if (Test-Path $f) { return (Get-Item $f).FullName } }
    } else {
        $linPaths = @("/usr/bin/microsoft-edge", "/usr/bin/microsoft-edge-stable", "/usr/bin/microsoft-edge-dev", "/opt/microsoft/msedge/msedge")
        foreach ($f in $linPaths) { if (Test-Path $f) { return (Get-Item $f).FullName } }
        $cmd = Get-Command microsoft-edge -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Find-FirefoxExecutable {
    if ($isWin) {
        $ffPaths = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\firefox.exe",
            "$env:LOCALAPPDATA\Programs\Mozilla Firefox\firefox.exe",
            "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
            "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
        )
        foreach ($p in $ffPaths) { if (Test-Path $p) { return (Get-Item $p).FullName } }
        $reg = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe" -ErrorAction SilentlyContinue).'(Default)'
        if ($reg -and (Test-Path $reg)) { return (Get-Item $reg).FullName }
    } elseif ($isMac) {
        $macPaths = @(
            "/Applications/Firefox.app/Contents/MacOS/firefox",
            (Join-Path $userHome "Applications/Firefox.app/Contents/MacOS/firefox")
        )
        foreach ($f in $macPaths) { if (Test-Path $f) { return (Get-Item $f).FullName } }
    } else {
        $linPaths = @("/usr/bin/firefox", "/snap/bin/firefox", "/usr/local/bin/firefox", "/usr/lib/firefox/firefox")
        foreach ($f in $linPaths) { if (Test-Path $f) { return (Get-Item $f).FullName } }
        $cmd = Get-Command firefox -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Find-ChromeExecutable {
    if ($isWin) {
        $chromePaths = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
        )
        foreach ($p in $chromePaths) { if (Test-Path $p) { return (Get-Item $p).FullName } }
        $reg = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe" -ErrorAction SilentlyContinue).'(Default)'
        if ($reg -and (Test-Path $reg)) { return (Get-Item $reg).FullName }
    } elseif ($isMac) {
        $macPaths = @(
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            (Join-Path $userHome "Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
        )
        foreach ($f in $macPaths) { if (Test-Path $f) { return (Get-Item $f).FullName } }
    } else {
        $linPaths = @("/usr/bin/google-chrome", "/usr/bin/google-chrome-stable", "/usr/bin/chromium-browser", "/usr/bin/chromium", "/snap/bin/chromium")
        foreach ($f in $linPaths) { if (Test-Path $f) { return (Get-Item $f).FullName } }
        $cmd = Get-Command google-chrome -ErrorAction SilentlyContinue
        if (-not $cmd) { $cmd = Get-Command chromium -ErrorAction SilentlyContinue }
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Get-InstalledBrowserVersions {
    $results = [ordered]@{}

    # 1. Opera
    $opExe = Find-OperaExecutable
    if ($opExe -and (Test-Path $opExe)) {
        $v = $null
        try { $v = (Get-Item $opExe).VersionInfo.ProductVersion } catch {}
        if (-not $v) {
            $raw = & $opExe --version 2>$null
            if ($raw -match '([\d\.]+)') { $v = $matches[1] }
        }
        $major = if ($v -and ($v -match '^(\d+)')) { [int]$matches[1] } else { 0 }
        $vStr = if ($v) { $v } else { "Detected" }
        $results['Opera'] = [PSCustomObject]@{ Installed = $true; Version = $vStr; Major = $major; Path = $opExe }
    } else {
        $results['Opera'] = [PSCustomObject]@{ Installed = $false; Version = "Not Installed"; Major = 0; Path = $null }
    }

    # 2. Edge
    $edExe = Find-EdgeExecutable
    if ($edExe -and (Test-Path $edExe)) {
        $v = $null
        try { $v = (Get-Item $edExe).VersionInfo.ProductVersion } catch {}
        if (-not $v) {
            $raw = & $edExe --version 2>$null
            if ($raw -match '([\d\.]+)') { $v = $matches[1] }
        }
        $major = if ($v -and ($v -match '^(\d+)')) { [int]$matches[1] } else { 0 }
        $vStr = if ($v) { $v } else { "Detected" }
        $results['Edge'] = [PSCustomObject]@{ Installed = $true; Version = $vStr; Major = $major; Path = $edExe }
    } else {
        $results['Edge'] = [PSCustomObject]@{ Installed = $false; Version = "Not Installed"; Major = 0; Path = $null }
    }

    # 3. Firefox
    $ffVer = $null
    if ($isWin) {
        $ffPkg = Get-AppxPackage -Name "*MozillaFirefox*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ffPkg -and $ffPkg.Version) { $ffVer = $ffPkg.Version }
    }
    $ffExe = Find-FirefoxExecutable
    if (-not $ffVer -and $ffExe -and (Test-Path $ffExe)) {
        try { $ffVer = (Get-Item $ffExe).VersionInfo.ProductVersion } catch {}
        if (-not $ffVer) {
            $raw = & $ffExe -v 2>$null
            if ($raw -match '([\d\.]+)') { $ffVer = $matches[1] }
        }
    }
    if ($ffVer -or ($ffExe -and (Test-Path $ffExe))) {
        $major = if ($ffVer -and ($ffVer -match '^(\d+)')) { [int]$matches[1] } else { 0 }
        $vStr = if ($ffVer) { $ffVer } else { "Detected" }
        $pStr = if ($ffExe) { $ffExe } else { "Mozilla.Firefox" }
        $results['Firefox'] = [PSCustomObject]@{ Installed = $true; Version = $vStr; Major = $major; Path = $pStr }
    } else {
        $results['Firefox'] = [PSCustomObject]@{ Installed = $false; Version = "Not Installed"; Major = 0; Path = $null }
    }

    # 4. Chrome
    $chExe = Find-ChromeExecutable
    if ($chExe -and (Test-Path $chExe)) {
        $v = $null
        try { $v = (Get-Item $chExe).VersionInfo.ProductVersion } catch {}
        if (-not $v) {
            $raw = & $chExe --version 2>$null
            if ($raw -match '([\d\.]+)') { $v = $matches[1] }
        }
        $major = if ($v -and ($v -match '^(\d+)')) { [int]$matches[1] } else { 0 }
        $vStr = if ($v) { $v } else { "Detected" }
        $results['Chrome'] = [PSCustomObject]@{ Installed = $true; Version = $vStr; Major = $major; Path = $chExe }
    } else {
        $results['Chrome'] = [PSCustomObject]@{ Installed = $false; Version = "Not Installed"; Major = 0; Path = $null }
    }

    return $results
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$backupRootDir = Join-Path $PSScriptRoot "backups"

function Update-BrowserVersionRegistry {
    param($LiveVersions)

    $registryPath = Join-Path $backupRootDir "version-registry.json"
    $registry = @{
        "LastUpdated"    = (Get-Date).ToString("o")
        "Browsers"       = @{}
        "UpgradeHistory" = @()
    }

    if (Test-Path $registryPath) {
        try {
            $existing = Convert-JsonToHashtable (Get-Content $registryPath -Raw -Encoding UTF8)
            if ($existing) {
                if ($existing.ContainsKey("Browsers")) { $registry["Browsers"] = $existing["Browsers"] }
                if ($existing.ContainsKey("UpgradeHistory")) { $registry["UpgradeHistory"] = $existing["UpgradeHistory"] }
            }
        } catch {}
    }

    $detectedUpgrades = @()
    foreach ($b in $LiveVersions.Keys) {
        $live = $LiveVersions[$b]
        if ($live.Installed) {
            $prevVer = if ($registry["Browsers"].ContainsKey($b)) { $registry["Browsers"][$b]["Version"] } else { $null }
            if ($prevVer -and $prevVer -ne $live.Version) {
                $upgradeEvent = [ordered]@{
                    "Timestamp"  = (Get-Date).ToString("o")
                    "Browser"    = $b
                    "OldVersion" = $prevVer
                    "NewVersion" = $live.Version
                }
                $registry["UpgradeHistory"] += $upgradeEvent
                $detectedUpgrades += $upgradeEvent
            }

            $registry["Browsers"][$b] = [ordered]@{
                "Version"      = $live.Version
                "MajorVersion" = $live.Major
                "Path"         = $live.Path
                "LastVerified" = (Get-Date).ToString("o")
            }
        }
    }

    if (-not (Test-Path $backupRootDir)) { New-Item -ItemType Directory -Path $backupRootDir -Force | Out-Null }
    $regJson = ConvertTo-Json -InputObject $registry -Depth 10
    [System.IO.File]::WriteAllText($registryPath, $regJson, $utf8NoBom)

    return $detectedUpgrades
}

# ====================================================================
# VERSION INSPECTOR (When -Versions is specified)
# ====================================================================
if ($Versions) {
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "             🔍 BROWSERPARITY: INSTALLED VERSION MATRIX             " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan

    $liveVer = Get-InstalledBrowserVersions
    $upgrades = Update-BrowserVersionRegistry -LiveVersions $liveVer

    $liveVer.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            "Browser"       = $_.Key
            "Installed"     = $_.Value.Installed
            "Live Version"  = $_.Value.Version
            "Major Version" = $_.Value.Major
            "Path / Channel"= $_.Value.Path
        }
    } | Format-Table -AutoSize | Out-String | Write-Host

    $regPath = Join-Path $backupRootDir "version-registry.json"
    if (Test-Path $regPath) {
        $regData = Get-Content $regPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($regData.UpgradeHistory -and $regData.UpgradeHistory.Count -gt 0) {
            Write-Host "📜 Recorded Upgrade History:" -ForegroundColor Yellow
            $regData.UpgradeHistory | Format-Table -AutoSize | Out-String | Write-Host
        }
    }

    exit 0
}

# ====================================================================
# SCHEMA INSPECTOR (When -Schema is specified)
# ====================================================================
if ($Schema) {
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "         📜 BROWSERPARITY: VERSION-GATED CONFIGURATION SCHEMA       " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan

    $schemaFilePath = Join-Path $PSScriptRoot "schemas\browser-parity-schema.json"
    if (-not (Test-Path $schemaFilePath)) {
        Write-Error "Schema file not found at: $schemaFilePath"
        exit 1
    }

    $schemaData = Get-Content $schemaFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "Schema Version: $($schemaData.version) | Rules Engine Active`n" -ForegroundColor DarkGray

    $schemaRows = New-Object System.Collections.ArrayList
    foreach ($bProp in $schemaData.browsers.PSObject.Properties) {
        $bName = $bProp.Name
        $rules = $bProp.Value
        foreach ($r in $rules) {
            $pathOrPref = if ($r.path) { ($r.path -join ".") } else { $r.pref }
            $minVerLabel = if ($r.minVersion -eq 0) { "All (0+)" } else { "v" + $r.minVersion + "+" }
            [void]$schemaRows.Add([PSCustomObject]@{
                "Browser"      = $bName
                "Category"     = $r.category
                "Min Version"  = $minVerLabel
                "Target"       = $pathOrPref
                "Target Value" = "$($r.value)"
                "Description"  = $r.description
            })
        }
    }

    $schemaRows | Format-Table -AutoSize | Out-String | Write-Host
    exit 0
}

# ====================================================================
# ROLLBACK ENGINE (Reversible Invariant)
# ====================================================================
if ($Rollback) {
    Write-Host "====================================================================" -ForegroundColor Magenta
    Write-Host "                 EXECUTING BROWSER CONFIGURATION ROLLBACK           " -ForegroundColor Magenta
    Write-Host "====================================================================" -ForegroundColor Magenta

    if (-not (Test-Path $backupRootDir)) {
        Write-Error "No backup directory found at: $backupRootDir"
        exit 1
    }

    $latestBackup = Get-ChildItem -Path $backupRootDir -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
    if (-not $latestBackup) {
        Write-Error "No backup snapshots available to restore."
        exit 1
    }

    Write-Host "Restoring configuration from snapshot: $($latestBackup.Name)" -ForegroundColor Cyan
    
    Get-Process -Name "opera*", "launcher*", "msedge*", "msedgewebview2*", "firefox*", "chrome*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    $manifestFile = Join-Path $latestBackup.FullName "manifest.json"
    if (Test-Path $manifestFile) {
        $manifest = Get-Content $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($entry in $manifest) {
            $src = Join-Path $latestBackup.FullName $entry.BackupRelativePath
            $dest = $entry.OriginalFullPath
            if (Test-Path $src) {
                $destParent = Split-Path $dest -Parent
                if (-not (Test-Path $destParent)) { New-Item -ItemType Directory -Path $destParent -Force | Out-Null }
                Copy-Item -Path $src -Destination $dest -Force
                Write-Host "  [+] Restored: $dest" -ForegroundColor Green
            }
        }
    } else {
        Write-Error "Backup manifest missing in snapshot."
        exit 1
    }

    Write-Host "`n[+] Rollback successfully completed!" -ForegroundColor Green
    exit 0
}

# ====================================================================
# UNINSTALL & PURGE DETRITUS ENGINE
# ====================================================================
if ($Uninstall -or $Purge) {
    Write-Host "====================================================================" -ForegroundColor Red
    Write-Host "             BROWSER UNINSTALLATION & DETRITUS PURGE ENGINE         " -ForegroundColor Red
    Write-Host "====================================================================" -ForegroundColor Red

    $wingetMap = @{
        'Opera'   = 'Opera.Opera'
        'Edge'    = 'Microsoft.Edge'
        'Firefox' = 'Mozilla.Firefox'
        'Chrome'  = 'Google.Chrome'
    }

    foreach ($b in $targetBrowsers) {
        Write-Host "`n[x] Processing removal/cleanup for $b..." -ForegroundColor Yellow

        # 1. Stop processes
        switch ($b) {
            'Opera'   { Get-Process -Name "opera*", "launcher*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
            'Edge'    { Get-Process -Name "msedge*", "msedgewebview2*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
            'Firefox' { Get-Process -Name "firefox*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
            'Chrome'  { Get-Process -Name "chrome*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
        }
        Start-Sleep -Seconds 1

        # 2. Uninstall via winget if requested
        if ($Uninstall) {
            $pkgId = $wingetMap[$b]
            Write-Host "  [-] Uninstalling package $pkgId via winget..." -ForegroundColor Yellow
            try {
                & winget uninstall --id $pkgId -e --silent
                Write-Host "  [+] Winget uninstall triggered for $b." -ForegroundColor Green
            } catch {
                Write-Warning "Winget uninstall failed for ${b}: $_"
            }
        }

        # 3. Purge Detritus / Leftover Profiles / Smart Cardhes
        if ($Purge) {
            Write-Host "  [🔥] Purging profile data, Smart Cardhes, and detritus for $b..." -ForegroundColor Magenta
            $dirsToPurge = @()
            $regsToPurge = @()

            switch ($b) {
                'Opera' {
                    $dirsToPurge = @(
                        (Join-Path $env:APPDATA "Opera Software"),
                        (Join-Path $env:LOCALAPPDATA "Opera Software"),
                        (Join-Path $env:LOCALAPPDATA "Programs\Opera")
                    )
                    $regsToPurge = @(
                        "HKCU:\Software\Opera Software",
                        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\opera.exe"
                    )
                }
                'Edge' {
                    $dirsToPurge = @(
                        (Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data")
                    )
                }
                'Firefox' {
                    $dirsToPurge = @(
                        (Join-Path $env:APPDATA "Mozilla\Firefox"),
                        (Join-Path $env:LOCALAPPDATA "Mozilla\Firefox")
                    )
                }
                'Chrome' {
                    $dirsToPurge = @(
                        (Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data"),
                        (Join-Path $env:LOCALAPPDATA "Google\Chrome")
                    )
                    $regsToPurge = @(
                        "HKCU:\Software\Google\Chrome",
                        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
                    )
                }
            }

            foreach ($dir in $dirsToPurge) {
                if (Test-Path $dir) {
                    try {
                        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Host "    [-] Removed directory: $dir" -ForegroundColor DarkGray
                    } catch {
                        Write-Warning "Could not fully remove: $dir"
                    }
                }
            }

            foreach ($reg in $regsToPurge) {
                if (Test-Path $reg) {
                    try {
                        Remove-Item -Path $reg -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Host "    [-] Removed registry key: $reg" -ForegroundColor DarkGray
                    } catch {}
                }
            }
            Write-Host "  [+] Detritus purged for $b." -ForegroundColor Green
        }
    }

    if (-not $Install -and -not $Onboard -and -not $Launch) {
        Write-Host "`n[+] Browser removal/purge tasks finished." -ForegroundColor Green
        exit 0
    }
}

# ====================================================================
# INSTALL ENGINE (Winget Auto-Provisioning)
# ====================================================================
if ($Install) {
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "             AUTOMATED BROWSER PROVISIONING (WINGET)                " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan

    $wingetMap = @{
        'Opera'   = 'Opera.Opera'
        'Edge'    = 'Microsoft.Edge'
        'Firefox' = 'Mozilla.Firefox'
        'Chrome'  = 'Google.Chrome'
    }

    foreach ($b in $targetBrowsers) {
        $exeFinder = switch ($b) {
            'Opera'   { Find-OperaExecutable }
            'Edge'    { Find-EdgeExecutable }
            'Firefox' { Find-FirefoxExecutable }
            'Chrome'  { Find-ChromeExecutable }
        }

        if ($exeFinder) {
            Write-Host "  [✓] $b is already installed at: $exeFinder" -ForegroundColor Green
        } else {
            $pkgId = $wingetMap[$b]
            Write-Host "  [⬇] Installing $b ($pkgId) via winget..." -ForegroundColor Yellow
            & winget install --id $pkgId -e --silent --accept-source-agreements --accept-package-agreements
            Write-Host "  [+] Installation command completed for $b." -ForegroundColor Green
        }
    }
}

# Cross-Platform Profile Roots Resolution
$operaProfileDir = if ($isWin) {
    Join-Path $env:APPDATA "Opera Software\Opera Stable"
} elseif ($isMac) {
    Join-Path $userHome "Library/Application Support/com.operasoftware.Opera"
} else {
    Join-Path (if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $userHome ".config" }) "opera"
}

$edgeProfileDir = if ($isWin) {
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
} elseif ($isMac) {
    Join-Path $userHome "Library/Application Support/Microsoft Edge"
} else {
    Join-Path (if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $userHome ".config" }) "microsoft-edge"
}

$firefoxProfileRoots = if ($isWin) {
    @(
        "$env:APPDATA\Mozilla\Firefox\Profiles",
        "$env:LOCALAPPDATA\Packages\Mozilla.MozillaFirefox_jag0gd4e3s9p2\LocalSmart Cardhe\Roaming\Mozilla\Firefox\Profiles"
    )
} elseif ($isMac) {
    @(
        Join-Path $userHome "Library/Application Support/Firefox/Profiles"
    )
} else {
    @(
        Join-Path $userHome ".mozilla/firefox",
        Join-Path $userHome "snap/firefox/common/.mozilla/firefox"
    )
}

$chromeProfileDir = if ($isWin) {
    "$env:LOCALAPPDATA\Google\Chrome\User Data"
} elseif ($isMac) {
    Join-Path $userHome "Library/Application Support/Google/Chrome"
} else {
    Join-Path (if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $userHome ".config" }) "google-chrome"
}

# ====================================================================
# BACKUP ENGINE (Reversible Invariant - Automatic Before Changes)
# ====================================================================
$backupManifest = @()
if (-not $NoBackup) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $currentBackupDir = Join-Path $backupRootDir $timestamp
    New-Item -ItemType Directory -Path $currentBackupDir -Force | Out-Null
    Write-Host "Created configuration backup snapshot: $timestamp" -ForegroundColor DarkGray

    function Backup-ConfigFile {
        param([string]$FilePath, [string]$Category)
        if (Test-Path $FilePath) {
            $relName = "$Category-$([System.IO.Path]::GetFileName($FilePath))"
            $backupDest = Join-Path $currentBackupDir $relName
            Copy-Item -Path $FilePath -Destination $backupDest -Force
            $script:backupManifest += [PSCustomObject]@{
                BackupRelativePath = $relName
                OriginalFullPath   = $FilePath
            }
        }
    }

    if ($targetBrowsers -contains 'Opera') {
        Backup-ConfigFile -FilePath (Join-Path $operaProfileDir "Default\Preferences") -Category "Opera"
        Backup-ConfigFile -FilePath (Join-Path $operaProfileDir "Preferences") -Category "OperaRoot"
        Backup-ConfigFile -FilePath (Join-Path $operaProfileDir "Default\Bookmarks") -Category "OperaBookmarks"
    }

    if ($targetBrowsers -contains 'Edge') {
        Backup-ConfigFile -FilePath (Join-Path $edgeProfileDir "Default\Preferences") -Category "Edge"
        Backup-ConfigFile -FilePath (Join-Path $edgeProfileDir "Local State") -Category "EdgeLocalState"
    }

    if ($targetBrowsers -contains 'Firefox') {
        foreach ($root in $firefoxProfileRoots) {
            if (Test-Path $root) {
                Get-ChildItem -Path $root -Directory | ForEach-Object {
                    Backup-ConfigFile -FilePath (Join-Path $_.FullName "user.js") -Category "Firefox-$($_.Name)"
                }
            }
        }
    }

    if ($targetBrowsers -contains 'Chrome') {
        Backup-ConfigFile -FilePath (Join-Path $chromeProfileDir "Default\Preferences") -Category "Chrome"
        Backup-ConfigFile -FilePath (Join-Path $chromeProfileDir "Local State") -Category "ChromeLocalState"
    }

    $liveVersions = Get-InstalledBrowserVersions
    $detectedUpgrades = Update-BrowserVersionRegistry -LiveVersions $liveVersions
    if ($detectedUpgrades -and $detectedUpgrades.Count -gt 0) {
        foreach ($upg in $detectedUpgrades) {
            Write-Host "  [!] Version Upgrade Detected: $($upg.Browser) $($upg.OldVersion) -> $($upg.NewVersion) (Re-verifying schema invariants)" -ForegroundColor Yellow
        }
    }

    $snapshotMeta = [ordered]@{
        Timestamp       = $timestamp
        ComputerName    = $env:COMPUTERNAME
        UserName        = $env:USERNAME
        BrowserVersions = $liveVersions
        FilesBackedUp   = $backupManifest.Count
    }
    $metaJson = ConvertTo-Json -InputObject $snapshotMeta -Depth 5
    [System.IO.File]::WriteAllText((Join-Path $currentBackupDir "snapshot-info.json"), $metaJson, $utf8NoBom)

    $manifestJson = ConvertTo-Json -InputObject $backupManifest -Depth 10
    [System.IO.File]::WriteAllText((Join-Path $currentBackupDir "manifest.json"), $manifestJson, $utf8NoBom)
}

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "     BROWSERPARITY AUTOMATION (OPERA + EDGE + FIREFOX + CHROME)     " -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

$userDownloadsDir = Join-Path $env:USERPROFILE "Downloads"

# ====================================================================
# 1. CONFIGURE OPERA (Idempotent)
# ====================================================================
if ($targetBrowsers -contains 'Opera') {
    Write-Host "`n[+] Enforcing DuckDuckGo & clean minimalist state on Opera..." -ForegroundColor Cyan
    if ($Restart) {
        Get-Process -Name "opera*", "launcher*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    } else {
        Write-Host "  [~] Preserving active Opera windows (quiet mode)." -ForegroundColor DarkGray
    }

    $operaPrefPaths = @(
        (Join-Path $operaProfileDir "Default\Preferences"),
        (Join-Path $operaProfileDir "Preferences")
    )

    if (-not (Test-Path (Join-Path $operaProfileDir "Default"))) {
        New-Item -ItemType Directory -Path (Join-Path $operaProfileDir "Default") -Force | Out-Null
    }

    foreach ($prefPath in $operaPrefPaths) {
        $p = @{}
        if (Test-Path $prefPath) {
            $p = Convert-JsonToHashtable (Get-Content $prefPath -Raw -Encoding UTF8)
        }

        # DuckDuckGo Default Search
        $operaDdgGuid = "3BFDFA54-5DD6-4DFF-8B6C-C1715F306D6B"
        Set-NestedProperty -Dictionary $p -Path @('default_search_provider', 'guid') -Value $operaDdgGuid
        Set-NestedProperty -Dictionary $p -Path @('default_search_provider_data', 'mirrored_template_url_data') -Value @{
            "short_name"      = "DuckDuckGo"
            "keyword"         = "d"
            "url"             = "https://duckduckgo.com/?q={searchTerms}&t={opera:vpnClient}"
            "suggestions_url" = "https://ac.duckduckgo.com/ac/?q={searchTerms}&type=list&t={opera:vpnClient}"
            "favicon_url"     = "https://duckduckgo.com/favicon.ico"
            "id"              = "3"
            "prepopulate_id"  = 3
            "synced_guid"     = $operaDdgGuid
            "is_active"       = 1
        }

        # Ads, Sponsors, Start Page
        Set-NestedProperty -Dictionary $p -Path @('adblocker', 'acceptable_ads', 'enabled') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('opera', 'start_page', 'show_news') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('opera', 'start_page', 'show_speed_dial_suggestions') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('opera', 'start_page', 'show_continue_on') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('opera', 'start_page', 'hide_search_box') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('opera', 'enhanced_address_bar', 'promoted_suggestions_enabled') -Value $false

        # Suggestions Off
        Set-NestedProperty -Dictionary $p -Path @('search', 'suggest_enabled') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('browser', 'suggested_searches_enabled') -Value $false

        # VPN & AI Buttons Off
        Set-NestedProperty -Dictionary $p -Path @('freedom', 'proxy_address_bar_badge', 'visible') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('freedom', 'proxy_switcher', 'stat_badge_state') -Value "hidden"
        Set-NestedProperty -Dictionary $p -Path @('freedom', 'proxy_switcher', 'ui_default_visible') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('ui', 'ask_ai', 'button_enabled') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('ui', 'ask_ai', 'enabled') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('ui', 'ask_ai', 'feature_enabled') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('ui', 'browser', 'sidebar', 'item_prefs', 'visibility', 'Aria') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('ui', 'browser', 'sidebar', 'item_prefs', 'visibility', 'Aria_ai') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('opera', 'ai_services', 'ai_prompts_enabled') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('opera', 'ai_services', 'command_line_enabled') -Value $false

        # Sidebar: Pin ChatGPT & My Flow
        Set-NestedProperty -Dictionary $p -Path @('ui', 'browser', 'sidebar', 'item_prefs', 'visibility', 'ChatGpt') -Value $true
        Set-NestedProperty -Dictionary $p -Path @('ui', 'browser', 'sidebar', 'item_prefs', 'visibility', 'OperaTouch') -Value $true
        Set-NestedProperty -Dictionary $p -Path @('ui', 'browser', 'sidebar', 'item_prefs', 'visibility', 'FacebookMessenger') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('ui', 'browser', 'sidebar', 'visible_proxy') -Value 1

        # Native Dark Mode
        Set-NestedProperty -Dictionary $p -Path @('force_dark_mode', 'enabled') -Value $true

        # Anti-Annoyances
        Set-NestedProperty -Dictionary $p -Path @('profile', 'default_content_setting_values', 'notifications') -Value 2
        Set-NestedProperty -Dictionary $p -Path @('media', 'autoplay_allowed') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('ui', 'default_browser_promotion_shown') -Value $true
        Set-NestedProperty -Dictionary $p -Path @('ui', 'set_as_default_browser_prompt_answer') -Value "no"
        Set-NestedProperty -Dictionary $p -Path @('ui', 'launches_until_default_browser_check') -Value 0
        Set-NestedProperty -Dictionary $p -Path @('webrtc', 'ip_handling_policy') -Value "default_public_interface_only"
        Set-NestedProperty -Dictionary $p -Path @('survey', 'dismissed') -Value $true
        Set-NestedProperty -Dictionary $p -Path @('statistics', 'user_consent') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('cashback', 'badge', 'enabled') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('rich_hints', 'marketplace_enabled') -Value $false

        # Session Restore
        Set-NestedProperty -Dictionary $p -Path @('session', 'restore_on_startup') -Value 4
        Set-NestedProperty -Dictionary $p -Path @('browser', 'confirm_to_quit') -Value $true
        Set-NestedProperty -Dictionary $p -Path @('browser', 'warn_on_closing_tabs') -Value $true
        Set-NestedProperty -Dictionary $p -Path @('ui', 'confirm_to_quit') -Value $true

        # Typography, DPI & Silent Downloads
        Set-NestedProperty -Dictionary $p -Path @('download', 'default_directory') -Value $userDownloadsDir
        Set-NestedProperty -Dictionary $p -Path @('download', 'prompt_for_download') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('download', 'directory_upgrade') -Value $true
        Set-NestedProperty -Dictionary $p -Path @('partition', 'default_zoom_level', 'x') -Value 0.0
        Set-NestedProperty -Dictionary $p -Path @('webkit', 'webprefs', 'fonts', 'standard', 'Zyyy') -Value "Segoe UI"
        Set-NestedProperty -Dictionary $p -Path @('webkit', 'webprefs', 'fonts', 'sansserif', 'Zyyy') -Value "Segoe UI"
        Set-NestedProperty -Dictionary $p -Path @('webkit', 'webprefs', 'fonts', 'serif', 'Zyyy') -Value "Times New Roman"
        Set-NestedProperty -Dictionary $p -Path @('webkit', 'webprefs', 'fonts', 'fixed', 'Zyyy') -Value "Consolas"
        Set-NestedProperty -Dictionary $p -Path @('webkit', 'webprefs', 'default_font_size') -Value 16
        Set-NestedProperty -Dictionary $p -Path @('webkit', 'webprefs', 'default_fixed_font_size') -Value 13
        Set-NestedProperty -Dictionary $p -Path @('webkit', 'webprefs', 'minimum_font_size') -Value 10

        # Network & Privacy Hardening (DoH, ECH & Anti-Tracking)
        Set-NestedProperty -Dictionary $p -Path @('dns_over_https', 'mode') -Value $effectiveProfile.DohMode
        Set-NestedProperty -Dictionary $p -Path @('dns_over_https', 'templates') -Value $effectiveProfile.DohTemplate
        Set-NestedProperty -Dictionary $p -Path @('enable_hyperlink_auditing') -Value $false
        Set-NestedProperty -Dictionary $p -Path @('net', 'network_prediction_options') -Value 2
        if ($effectiveProfile.HttpsMode -eq 'only') {
            Set-NestedProperty -Dictionary $p -Path @('https_only_mode_enabled') -Value $true
        } else {
            Set-NestedProperty -Dictionary $p -Path @('https_first_mode_enabled') -Value $true
        }

        $updatedJson = ConvertTo-Json -InputObject $p -Depth 100
        [System.IO.File]::WriteAllText($prefPath, $updatedJson, $utf8NoBom)
    }

    # Clean Opera Speed Dial Bookmarks & Partner Smart Cardhes
    $bmPath = Join-Path $operaProfileDir "Default\Bookmarks"
    if (Test-Path $bmPath) {
        $bm = Convert-JsonToHashtable (Get-Content $bmPath -Raw -Encoding UTF8)
        if ($bm.ContainsKey('roots') -and $bm['roots'].ContainsKey('custom_root') -and $bm['roots']['custom_root'].ContainsKey('speedDial')) {
            $bm['roots']['custom_root']['speedDial']['children'] = @()
            $updatedBmJson = ConvertTo-Json -InputObject $bm -Depth 100
            [System.IO.File]::WriteAllText($bmPath, $updatedBmJson, $utf8NoBom)
        }
    }
    $partnerFiles = @(
        (Join-Path $operaProfileDir "partner_speeddials.json"),
        (Join-Path $operaProfileDir "default_partner_content.json"),
        (Join-Path $operaProfileDir "Default\suggestions_Smart Cardhe.json")
    )
    foreach ($pf in $partnerFiles) {
        if (Test-Path $pf) { [System.IO.File]::WriteAllText($pf, "{}", $utf8NoBom) }
    }
    Write-Host "  [+] Opera configured (DuckDuckGo + Anti-Annoyance + Native Dark Mode & Ad Blocking)." -ForegroundColor Green
}

# ====================================================================
# 2. CONFIGURE MICROSOFT EDGE (Idempotent)
# ====================================================================
if ($targetBrowsers -contains 'Edge') {
    Write-Host "`n[+] Enforcing DuckDuckGo & clean minimalist state on Microsoft Edge..." -ForegroundColor Cyan
    if ($Restart) {
        Get-Process -Name "msedge*", "msedgewebview2*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    } else {
        Write-Host "  [~] Preserving active Edge windows (quiet mode)." -ForegroundColor DarkGray
    }

    $edgeUserData = $edgeProfileDir
    $edgePrefPath = "$edgeUserData\Default\Preferences"
    $edgeLocalStatePath = "$edgeUserData\Local State"

    if (-not (Test-Path (Join-Path $edgeUserData "Default"))) {
        New-Item -ItemType Directory -Path (Join-Path $edgeUserData "Default") -Force | Out-Null
    }

    $edgePref = @{}
    if (Test-Path $edgePrefPath) {
        $edgePref = Convert-JsonToHashtable (Get-Content $edgePrefPath -Raw -Encoding UTF8)
    }

    $ddgGuid = "485bf7d3-0215-45af-87dc-538868000092"
    Set-NestedProperty -Dictionary $edgePref -Path @('default_search_provider', 'guid') -Value $ddgGuid
    Set-NestedProperty -Dictionary $edgePref -Path @('default_search_provider', 'synced_guid') -Value $ddgGuid
    Set-NestedProperty -Dictionary $edgePref -Path @('default_search_provider_data', 'template_url_data') -Value @{
        "short_name"           = "DuckDuckGo"
        "keyword"              = "duckduckgo.com"
        "url"                  = "https://duckduckgo.com/?q={searchTerms}"
        "suggestions_url"      = "https://duckduckgo.com/ac/?q={searchTerms}&type=list"
        "favicon_url"          = "https://duckduckgo.com/favicon.ico"
        "id"                   = "5"
        "prepopulate_id"       = 92
        "synced_guid"          = $ddgGuid
        "is_active"            = 1
        "safe_for_autoreplace" = $false
    }

    # Shopping, Rewards, Wallet
    Set-NestedProperty -Dictionary $edgePref -Path @('shopping', 'contextual_features_enabled') -Value $false
    Set-NestedProperty -Dictionary $edgePref -Path @('shopping', 'auto_show_coupons') -Value $false
    Set-NestedProperty -Dictionary $edgePref -Path @('edge_rewards', 'enabled') -Value $false
    Set-NestedProperty -Dictionary $edgePref -Path @('edge_wallet', 'enabled') -Value $false

    # Suggestions Off
    Set-NestedProperty -Dictionary $edgePref -Path @('search', 'suggest_enabled') -Value $false
    Set-NestedProperty -Dictionary $edgePref -Path @('browser', 'suggested_searches_enabled') -Value $false
    Set-NestedProperty -Dictionary $edgePref -Path @('zerosuggest', 'cachedresults') -Value @()
    Set-NestedProperty -Dictionary $edgePref -Path @('omnibox', 'zerosuggest') -Value @{}

    # Copilot Off
    Set-NestedProperty -Dictionary $edgePref -Path @('edge_copilot', 'enabled') -Value $false
    Set-NestedProperty -Dictionary $edgePref -Path @('edge_quick_search', 'enabled') -Value $false

    # Privacy & Tracking
    Set-NestedProperty -Dictionary $edgePref -Path @('enhanced_tracking_prevention', 'user_pref') -Value 3
    Set-NestedProperty -Dictionary $edgePref -Path @('tracking_prevention', 'strict_inprivate') -Value $true
    Set-NestedProperty -Dictionary $edgePref -Path @('enable_do_not_track') -Value $true

    # New Tab Page
    Set-NestedProperty -Dictionary $edgePref -Path @('ntp', 'news_feed_display') -Value "off"
    Set-NestedProperty -Dictionary $edgePref -Path @('ntp', 'hide_default_top_sites') -Value $true
    Set-NestedProperty -Dictionary $edgePref -Path @('ntp', 'show_image_of_day') -Value $false
    Set-NestedProperty -Dictionary $edgePref -Path @('ntp', 'show_greeting') -Value $false
    Set-NestedProperty -Dictionary $edgePref -Path @('background_mode', 'enabled') -Value $false

    # Anti-Annoyances
    Set-NestedProperty -Dictionary $edgePref -Path @('profile', 'default_content_setting_values', 'notifications') -Value 2
    Set-NestedProperty -Dictionary $edgePref -Path @('media', 'autoplay_allowed') -Value $false
    Set-NestedProperty -Dictionary $edgePref -Path @('webrtc', 'ip_handling_policy') -Value "default_public_interface_only"
    Set-NestedProperty -Dictionary $edgePref -Path @('personalization_data_consent') -Value $false

    # Session Restore
    Set-NestedProperty -Dictionary $edgePref -Path @('session', 'restore_on_startup') -Value 4
    Set-NestedProperty -Dictionary $edgePref -Path @('browser', 'confirm_to_quit') -Value $true
    Set-NestedProperty -Dictionary $edgePref -Path @('browser', 'warn_on_closing_tabs') -Value $true

    # Typography & Downloads
    Set-NestedProperty -Dictionary $edgePref -Path @('download', 'default_directory') -Value $userDownloadsDir
    Set-NestedProperty -Dictionary $edgePref -Path @('download', 'prompt_for_download') -Value $false
    Set-NestedProperty -Dictionary $edgePref -Path @('download', 'directory_upgrade') -Value $true
    Set-NestedProperty -Dictionary $edgePref -Path @('partition', 'default_zoom_level', 'x') -Value 0.0
    Set-NestedProperty -Dictionary $edgePref -Path @('webkit', 'webprefs', 'fonts', 'standard', 'Zyyy') -Value "Segoe UI"
    Set-NestedProperty -Dictionary $edgePref -Path @('webkit', 'webprefs', 'fonts', 'sansserif', 'Zyyy') -Value "Segoe UI"
    Set-NestedProperty -Dictionary $edgePref -Path @('webkit', 'webprefs', 'fonts', 'serif', 'Zyyy') -Value "Times New Roman"
    Set-NestedProperty -Dictionary $edgePref -Path @('webkit', 'webprefs', 'fonts', 'fixed', 'Zyyy') -Value "Consolas"
    Set-NestedProperty -Dictionary $edgePref -Path @('webkit', 'webprefs', 'default_font_size') -Value 16
    Set-NestedProperty -Dictionary $edgePref -Path @('webkit', 'webprefs', 'default_fixed_font_size') -Value 13
    Set-NestedProperty -Dictionary $edgePref -Path @('webkit', 'webprefs', 'minimum_font_size') -Value 10

    # Theme
    Set-NestedProperty -Dictionary $edgePref -Path @('browser', 'theme', 'system_theme') -Value 1
    Set-NestedProperty -Dictionary $edgePref -Path @('ui', 'theme', 'mode') -Value 1
    Set-NestedProperty -Dictionary $edgePref -Path @('extensions', 'theme', 'use_system') -Value $false

    # Network & Privacy Hardening (DoH, ECH & Anti-Tracking)
    Set-NestedProperty -Dictionary $edgePref -Path @('dns_over_https', 'mode') -Value $effectiveProfile.DohMode
    Set-NestedProperty -Dictionary $edgePref -Path @('dns_over_https', 'templates') -Value $effectiveProfile.DohTemplate
    Set-NestedProperty -Dictionary $edgePref -Path @('enable_hyperlink_auditing') -Value $false
    Set-NestedProperty -Dictionary $edgePref -Path @('net', 'network_prediction_options') -Value 2
    if ($effectiveProfile.HttpsMode -eq 'only') {
        Set-NestedProperty -Dictionary $edgePref -Path @('https_only_mode_enabled') -Value $true
    } else {
        Set-NestedProperty -Dictionary $edgePref -Path @('https_first_mode_enabled') -Value $true
    }

    $edgePrefJson = ConvertTo-Json -InputObject $edgePref -Depth 100
    [System.IO.File]::WriteAllText($edgePrefPath, $edgePrefJson, $utf8NoBom)

    if (Test-Path $edgeLocalStatePath) {
        $edgeLS = Convert-JsonToHashtable (Get-Content $edgeLocalStatePath -Raw -Encoding UTF8)
        Set-NestedProperty -Dictionary $edgeLS -Path @('browser', 'theme', 'system_theme') -Value 1
        Set-NestedProperty -Dictionary $edgeLS -Path @('startup_boost', 'enabled') -Value $false
        Set-NestedProperty -Dictionary $edgeLS -Path @('startup_boost', 'default_last_launch') -Value $false
        Set-NestedProperty -Dictionary $edgeLS -Path @('user_experience_metrics', 'reporting_enabled') -Value $false
        Set-NestedProperty -Dictionary $edgeLS -Path @('telemetry_client', 'reporting_enabled') -Value $false
        Set-NestedProperty -Dictionary $edgeLS -Path @('edge_copilot', 'copilot_new_tab_page_enabled_commercial_state') -Value $false
        Set-NestedProperty -Dictionary $edgeLS -Path @('edge_copilot', 'copilot_new_tab_page_enabled_consumer_state') -Value $false
        Set-NestedProperty -Dictionary $edgeLS -Path @('edge_copilot_mode_enabled_state', 'Default') -Value 0
        $edgeLSJson = ConvertTo-Json -InputObject $edgeLS -Depth 100
        [System.IO.File]::WriteAllText($edgeLocalStatePath, $edgeLSJson, $utf8NoBom)
    }
    Write-Host "  [+] Edge configured (DuckDuckGo + Anti-Annoyance + Dark Mode + Zero Copilot/Rewards)." -ForegroundColor Green
}

# ====================================================================
# 3. CONFIGURE MOZILLA FIREFOX (Idempotent via user.js)
# ====================================================================
if ($targetBrowsers -contains 'Firefox') {
    Write-Host "`n[+] Enforcing DuckDuckGo & clean anti-cruft user.js on Mozilla Firefox..." -ForegroundColor Cyan
    if ($Restart) {
        Get-Process -Name "firefox*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    } else {
        Write-Host "  [~] Preserving active Firefox windows (quiet mode)." -ForegroundColor DarkGray
    }

    $escapedFfDownloads = $userDownloadsDir.Replace('\', '\\')
    $preferIpv4Str = if ($effectiveProfile.PreferIpv4) { "true" } else { "false" }
    $dohTpl = $effectiveProfile.DohTemplate
    $dohExcl = $effectiveProfile.ExcludedDomains

    $userJsLines = @(
        '// ====================================================================',
        '//   FIREFOX MINIMALIST / ANTI-CRUFT CONFIGURATION (user.js)',
        '// ====================================================================',
        '',
        '// --- 1. DEFAULT SEARCH: DUCKDUCKGO ---',
        'user_pref("browser.search.defaultenginename", "DuckDuckGo");',
        'user_pref("browser.urlbar.placeholderName", "DuckDuckGo");',
        '',
        '// --- 2. EnterpriseBLE SEARCH SUGGESTIONS & TRENDING QUERIES ---',
        'user_pref("browser.search.suggest.enabled", false);',
        'user_pref("browser.urlbar.suggest.searches", false);',
        'user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);',
        'user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);',
        'user_pref("browser.urlbar.suggest.trending", false);',
        'user_pref("browser.urlbar.quicksuggest.enabled", false);',
        'user_pref("browser.urlbar.suggest.engines", false);',
        '',
        '// --- 3. COMPLETELY EnterpriseBLE POCKET ---',
        'user_pref("extensions.pocket.enabled", false);',
        'user_pref("extensions.pocket.api", "");',
        'user_pref("extensions.pocket.site", "");',
        'user_pref("browser.newtabpage.activity-stream.section.highlights.includePocket", false);',
        '',
        '// --- 4. CLEAN NEW TAB PAGE (Zero Ads, Stories, or Weather) ---',
        'user_pref("browser.newtabpage.activity-stream.showSponsored", false);',
        'user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);',
        'user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);',
        'user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);',
        'user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);',
        'user_pref("browser.newtabpage.activity-stream.showWeather", false);',
        'user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);',
        'user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);',
        'user_pref("browser.aboutwelcome.enabled", false);',
        'user_pref("browser.messaging-system.whatsNewPanel.enabled", false);',
        'user_pref("browser.uitour.enabled", false);',
        '',
        '// --- 5. EnterpriseBLE STUDIES, NORMANDY & TELEMETRY EXPERIMENTS ---',
        'user_pref("app.normandy.enabled", false);',
        'user_pref("app.normandy.api_url", "");',
        'user_pref("app.shield.optoutstudy.enabled", false);',
        'user_pref("experiments.enabled", false);',
        'user_pref("experiments.supported", false);',
        'user_pref("datareporting.policy.dataSubmissionEnabled", false);',
        'user_pref("datareporting.healthreport.uploadEnabled", false);',
        'user_pref("toolkit.telemetry.enabled", false);',
        'user_pref("toolkit.telemetry.unified", false);',
        'user_pref("browser.ping-centre.telemetry", false);',
        '',
        '// --- 6. EnterpriseBLE CRASH REPORTING SUBMISSIONS ---',
        'user_pref("breakpad.reportURL", "");',
        'user_pref("browser.tabs.crashReporting.sendReport", false);',
        'user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);',
        '',
        '// --- 7. STRICT TRACKING PROTECTION & PRIVACY ---',
        'user_pref("privacy.trackingprotection.enabled", true);',
        'user_pref("privacy.trackingprotection.socialtracking.enabled", true);',
        'user_pref("privacy.donottrackheader.enabled", true);',
        'user_pref("network.cookie.cookieBehavior", 5);',
        '',
        '// --- 8. ANTI-ANNOYANCE CLEANUPS ---',
        'user_pref("permissions.default.desktop-notification", 2);',
        'user_pref("media.autoplay.default", 5);',
        'user_pref("media.autoplay.blocking_policy", 2);',
        'user_pref("browser.shell.checkDefaultBrowser", false);',
        'user_pref("media.peerconnection.ice.default_address_only", true);',
        'user_pref("media.peerconnection.ice.no_host", true);',
        '',
        '// --- 9. NETWORK & PRIVACY HARDENING (DoH, ECH & Anti-Tracking) ---',
        'user_pref("network.trr.mode", 2);',
        "user_pref(`"network.trr.uri`", `"$dohTpl`");",
        "user_pref(`"network.trr.custom_uri`", `"$dohTpl`");",
        "user_pref(`"network.trr.excluded-domains`", `"$dohExcl`");",
        'user_pref("network.dns.echconfig.enabled", true);',
        'user_pref("network.dns.http3_echconfig.enabled", true);',
        'user_pref("dom.security.https_only_mode", true);',
        'user_pref("dom.security.https_only_mode_pbm", true);',
        'user_pref("browser.send_pings", false);',
        'user_pref("beacon.enabled", false);',
        'user_pref("network.prefetch-next", false);',
        'user_pref("network.dns.EnterpriseblePrefetch", true);',
        'user_pref("network.http.speculative-parallel-limit", 0);',
        'user_pref("network.http.referer.XOriginPolicy", 2);',
        'user_pref("network.http.referer.XOriginTrimmingPolicy", 2);',
        "user_pref(`"network.dns.preferIPv4`", $preferIpv4Str);",
        '',
        '// --- 10. SESSION RESTORE & PROMPT ON CLOSE/RESTART ---',
        'user_pref("browser.startup.page", 3);',
        'user_pref("browser.sessionstore.warnOnQuit", true);',
        'user_pref("browser.warnOnQuitShortcut", true);',
        'user_pref("browser.tabs.warnOnClose", true);',
        'user_pref("browser.tabs.warnOnCloseOtherTabs", true);',
        'user_pref("browser.sessionstore.resume_from_crash", true);',
        '',
        '// --- 11. TYPOGRAPHY, ZOOM & DOWNLOAD PARITY ---',
        'user_pref("font.name.sans-serif.x-western", "Segoe UI");',
        'user_pref("font.name.serif.x-western", "Times New Roman");',
        'user_pref("font.name.monospace.x-western", "Consolas");',
        'user_pref("font.size.variable.x-western", 16);',
        'user_pref("font.size.monospace.x-western", 13);',
        'user_pref("font.minimum-size.x-western", 10);',
        'user_pref("browser.download.folderList", 2);',
        "user_pref(`"browser.download.dir`", `"$escapedFfDownloads`");",
        "user_pref(`"browser.download.downloadDir`", `"$escapedFfDownloads`");",
        'user_pref("browser.download.useDownloadDir", true);',
        'user_pref("browser.download.alwaysOpenPanel", false);',
        'user_pref("browser.zoom.full", true);',
        'user_pref("general.smoothScroll", true);',
        '',
        '// --- 12. NATIVE DARK MODE ---',
        'user_pref("layout.css.prefers-color-scheme.content-override", 0);',
        'user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");',
        'user_pref("browser.theme.dark-private-windows", true);',
        '',
        '// --- 13. SMART CARD & OS CLIENT CERTIFICATE AUTOLOAD ---',
        'user_pref("security.osclientcerts.autoload", true);',
        'user_pref("security.enterprise_roots.enabled", true);',
        'user_pref("security.default_personal_cert", "Ask Every Time");'
    )
    $userJsContent = $userJsLines -join "`r`n"

    $appliedFfCount = 0
    foreach ($root in $firefoxProfileRoots) {
        if (Test-Path $root) {
            $ffProfileList = Get-ChildItem -Path $root -Directory
            foreach ($ffProfDir in $ffProfileList) {
                $userJsPath = Join-Path $ffProfDir.FullName "user.js"
                [System.IO.File]::WriteAllText($userJsPath, $userJsContent, $utf8NoBom)
                Write-Host "  [+] Applied user.js to Firefox profile: $($ffProfDir.Name)" -ForegroundColor Green
                $appliedFfCount++
            }
        }
    }

    if ($appliedFfCount -eq 0) {
        $defaultFfPath = "$env:APPDATA\Mozilla\Firefox\Profiles\default-release"
        New-Item -ItemType Directory -Path $defaultFfPath -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $defaultFfPath "user.js"), $userJsContent, $utf8NoBom)
        Write-Host "  [+] Initialized baseline user.js for default Firefox profile." -ForegroundColor Green
    }
}

# ====================================================================
# 4. CONFIGURE GOOGLE CHROME (Idempotent)
# ====================================================================
if ($targetBrowsers -contains 'Chrome') {
    Write-Host "`n[+] Enforcing DuckDuckGo & clean minimalist state on Google Chrome..." -ForegroundColor Cyan
    if ($Restart) {
        Get-Process -Name "chrome*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    } else {
        Write-Host "  [~] Preserving active Chrome windows (quiet mode)." -ForegroundColor DarkGray
    }

    $chromeUserData = $chromeProfileDir
    $chromePrefPath = "$chromeUserData\Default\Preferences"
    $chromeLocalStatePath = "$chromeUserData\Local State"

    if (-not (Test-Path (Join-Path $chromeUserData "Default"))) {
        New-Item -ItemType Directory -Path (Join-Path $chromeUserData "Default") -Force | Out-Null
    }

    $chromePref = @{}
    if (Test-Path $chromePrefPath) {
        $chromePref = Convert-JsonToHashtable (Get-Content $chromePrefPath -Raw -Encoding UTF8)
    }

    # DuckDuckGo Default Search
    $ddgGuid = "485bf7d3-0215-45af-87dc-538868000092"
    Set-NestedProperty -Dictionary $chromePref -Path @('default_search_provider', 'guid') -Value $ddgGuid
    Set-NestedProperty -Dictionary $chromePref -Path @('default_search_provider', 'synced_guid') -Value $ddgGuid
    Set-NestedProperty -Dictionary $chromePref -Path @('default_search_provider_data', 'template_url_data') -Value @{
        "short_name"           = "DuckDuckGo"
        "keyword"              = "duckduckgo.com"
        "url"                  = "https://duckduckgo.com/?q={searchTerms}"
        "suggestions_url"      = "https://duckduckgo.com/ac/?q={searchTerms}&type=list"
        "favicon_url"          = "https://duckduckgo.com/favicon.ico"
        "id"                   = "5"
        "prepopulate_id"       = 92
        "synced_guid"          = $ddgGuid
        "is_active"            = 1
        "safe_for_autoreplace" = $false
    }

    # Enterpriseble Search Suggestions & Trending
    Set-NestedProperty -Dictionary $chromePref -Path @('search', 'suggest_enabled') -Value $false
    Set-NestedProperty -Dictionary $chromePref -Path @('browser', 'suggested_searches_enabled') -Value $false

    # Enterpriseble Privacy Sandbox Ad Tracking & Topics
    Set-NestedProperty -Dictionary $chromePref -Path @('privacy_sandbox', 'm1', 'topics_enabled') -Value $false
    Set-NestedProperty -Dictionary $chromePref -Path @('privacy_sandbox', 'm1', 'fledge_enabled') -Value $false
    Set-NestedProperty -Dictionary $chromePref -Path @('privacy_sandbox', 'm1', 'ad_measurement_enabled') -Value $false
    Set-NestedProperty -Dictionary $chromePref -Path @('privacy_sandbox', 'apis_consent_v2') -Value $false

    # Enterpriseble Background Apps
    Set-NestedProperty -Dictionary $chromePref -Path @('background_mode', 'enabled') -Value $false

    # Anti-Annoyance Cleanups
    Set-NestedProperty -Dictionary $chromePref -Path @('profile', 'default_content_setting_values', 'notifications') -Value 2
    Set-NestedProperty -Dictionary $chromePref -Path @('media', 'autoplay_allowed') -Value $false
    Set-NestedProperty -Dictionary $chromePref -Path @('webrtc', 'ip_handling_policy') -Value "default_public_interface_only"
    Set-NestedProperty -Dictionary $chromePref -Path @('browser', 'check_default_browser') -Value $false

    # Session Restore
    Set-NestedProperty -Dictionary $chromePref -Path @('session', 'restore_on_startup') -Value 4
    Set-NestedProperty -Dictionary $chromePref -Path @('browser', 'confirm_to_quit') -Value $true
    Set-NestedProperty -Dictionary $chromePref -Path @('browser', 'warn_on_closing_tabs') -Value $true

    # Typography & Downloads
    Set-NestedProperty -Dictionary $chromePref -Path @('download', 'default_directory') -Value $userDownloadsDir
    Set-NestedProperty -Dictionary $chromePref -Path @('download', 'prompt_for_download') -Value $false
    Set-NestedProperty -Dictionary $chromePref -Path @('download', 'directory_upgrade') -Value $true
    Set-NestedProperty -Dictionary $chromePref -Path @('partition', 'default_zoom_level', 'x') -Value 0.0
    Set-NestedProperty -Dictionary $chromePref -Path @('webkit', 'webprefs', 'fonts', 'standard', 'Zyyy') -Value "Segoe UI"
    Set-NestedProperty -Dictionary $chromePref -Path @('webkit', 'webprefs', 'fonts', 'sansserif', 'Zyyy') -Value "Segoe UI"
    Set-NestedProperty -Dictionary $chromePref -Path @('webkit', 'webprefs', 'fonts', 'serif', 'Zyyy') -Value "Times New Roman"
    Set-NestedProperty -Dictionary $chromePref -Path @('webkit', 'webprefs', 'fonts', 'fixed', 'Zyyy') -Value "Consolas"
    Set-NestedProperty -Dictionary $chromePref -Path @('webkit', 'webprefs', 'default_font_size') -Value 16
    Set-NestedProperty -Dictionary $chromePref -Path @('webkit', 'webprefs', 'default_fixed_font_size') -Value 13
    Set-NestedProperty -Dictionary $chromePref -Path @('webkit', 'webprefs', 'minimum_font_size') -Value 10

    # Theme
    Set-NestedProperty -Dictionary $chromePref -Path @('browser', 'theme', 'system_theme') -Value 1
    Set-NestedProperty -Dictionary $chromePref -Path @('extensions', 'theme', 'use_system') -Value $false

    # Network & Privacy Hardening (DoH, ECH & Anti-Tracking)
    Set-NestedProperty -Dictionary $chromePref -Path @('dns_over_https', 'mode') -Value $effectiveProfile.DohMode
    Set-NestedProperty -Dictionary $chromePref -Path @('dns_over_https', 'templates') -Value $effectiveProfile.DohTemplate
    Set-NestedProperty -Dictionary $chromePref -Path @('enable_hyperlink_auditing') -Value $false
    Set-NestedProperty -Dictionary $chromePref -Path @('net', 'network_prediction_options') -Value 2
    if ($effectiveProfile.HttpsMode -eq 'only') {
        Set-NestedProperty -Dictionary $chromePref -Path @('https_only_mode_enabled') -Value $true
    } else {
        Set-NestedProperty -Dictionary $chromePref -Path @('https_first_mode_enabled') -Value $true
    }

    $chromePrefJson = ConvertTo-Json -InputObject $chromePref -Depth 100
    [System.IO.File]::WriteAllText($chromePrefPath, $chromePrefJson, $utf8NoBom)

    if (Test-Path $chromeLocalStatePath) {
        $chromeLS = Convert-JsonToHashtable (Get-Content $chromeLocalStatePath -Raw -Encoding UTF8)
        Set-NestedProperty -Dictionary $chromeLS -Path @('browser', 'theme', 'system_theme') -Value 1
        Set-NestedProperty -Dictionary $chromeLS -Path @('user_experience_metrics', 'reporting_enabled') -Value $false
        Set-NestedProperty -Dictionary $chromeLS -Path @('telemetry_client', 'reporting_enabled') -Value $false
        $chromeLSJson = ConvertTo-Json -InputObject $chromeLS -Depth 100
        [System.IO.File]::WriteAllText($chromeLocalStatePath, $chromeLSJson, $utf8NoBom)
    }
    Write-Host "  [+] Chrome configured (DuckDuckGo + Anti-Annoyance + Dark Mode + Zero Privacy Sandbox Ads)." -ForegroundColor Green
}

# ====================================================================
# 5. SHORTCUTS & DESKTOP HYGIENE CONSOLIDATION
# ====================================================================
Write-Host "`n[+] Cleaning desktop shortcuts & consolidating app launchers..." -ForegroundColor Cyan

# A. Remove Desktop Icons (Cross-Platform)
$desktopRoots = @(
    (Join-Path $userHome "Desktop"),
    (Join-Path $userHome "OneDrive\Desktop")
)
if ($isWin -and $env:PUBLIC) { $desktopRoots += (Join-Path $env:PUBLIC "Desktop") }

foreach ($d in $desktopRoots) {
    if (Test-Path $d) {
        $desktopLnks = Get-ChildItem -Path $d -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "^(Opera|Opera Browser|Google Chrome|Microsoft Edge|Mozilla Firefox|Firefox|Chrome|Edge)\.(lnk|desktop|app|alias)$" }
        foreach ($lnk in $desktopLnks) {
            Remove-Item -Path $lnk.FullName -Force -ErrorAction SilentlyContinue
            Write-Host "  [-] Removed Desktop shortcut: $($lnk.Name)" -ForegroundColor DarkGray
        }
    }
}

# B. Windows Start Menu Consolidation (Windows Only)
if ($isWin) {
    $startRoots = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    )
    foreach ($s in $startRoots) {
        if (Test-Path $s) {
            $looseLnks = Get-ChildItem -Path $s -Filter "*.lnk" -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "^(Opera|Opera Browser|Google Chrome|Microsoft Edge|Mozilla Firefox|Firefox|Chrome|Edge)\.lnk$" }
            foreach ($lnk in $looseLnks) {
                Remove-Item -Path $lnk.FullName -Force -ErrorAction SilentlyContinue
                Write-Host "  [-] Removed loose Start Menu shortcut: $($lnk.Name)" -ForegroundColor DarkGray
            }
        }
    }

    $unifiedStartMenuDir = Join-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs" "Browsers"
    if (-not (Test-Path $unifiedStartMenuDir)) {
        New-Item -ItemType Directory -Path $unifiedStartMenuDir -Force | Out-Null
    }

    try {
        $wscript = New-Object -ComObject WScript.Shell
        $browserMap = @{
            'Opera'   = @{ Name = "Opera";           Finder = { Find-OperaExecutable } }
            'Edge'    = @{ Name = "Microsoft Edge";  Finder = { Find-EdgeExecutable } }
            'Firefox' = @{ Name = "Mozilla Firefox"; Finder = { Find-FirefoxExecutable } }
            'Chrome'  = @{ Name = "Google Chrome";   Finder = { Find-ChromeExecutable } }
        }

        foreach ($b in $targetBrowsers) {
            if ($browserMap.ContainsKey($b)) {
                $entry = $browserMap[$b]
                $exe = & $entry.Finder
                if ($exe -and (Test-Path $exe)) {
                    $lnkPath = Join-Path $unifiedStartMenuDir "$($entry.Name).lnk"
                    $shortcut = $wscript.CreateShortcut($lnkPath)
                    $shortcut.TargetPath = $exe
                    $shortcut.WorkingDirectory = Split-Path $exe -Parent
                    $shortcut.Description = "$($entry.Name) Browser (BrowserParity Managed)"
                    $shortcut.Save()
                    Write-Host "  [+] Start Menu -> Browsers\$($entry.Name).lnk" -ForegroundColor Green
                }
            }
        }
    } catch {}
}

# ====================================================================
# 6. ONBOARDING & EXTENSION SETUP (Only when -Onboard is specified)
# ====================================================================
if ($Onboard) {
    Write-Host "`n====================================================================" -ForegroundColor Magenta
    Write-Host "           LAUNCHING ONBOARDING WIZARD & EXTENSION HUBS             " -ForegroundColor Magenta
    Write-Host "====================================================================" -ForegroundColor Magenta

    $onboardHubUrl = (Join-Path $PSScriptRoot "onboarding.html")

    $onboardTabs = @{
        'Opera' = @(
            $onboardHubUrl,
            "opera://settings/syncSetup",
            "https://chromewebstore.google.com/detail/violentmonkey/jinjaccalgkegednnccohejagnlnfdag",
            "https://chromewebstore.google.com/detail/consent-o-matic/mdjildafknihdffpkfmmpnignkgcmglf",
            "https://chatgpt.com"
        )
        'Edge' = @(
            $onboardHubUrl,
            "edge://settings/profiles",
            "https://microsoftedge.microsoft.com/addons/detail/violentmonkey/eeagobfjdenkkddmbclomhiblgggliao",
            "https://microsoftedge.microsoft.com/addons/detail/consentomatic/mdjildafknihdffpkfmmpnignkgcmglf",
            "https://microsoftedge.microsoft.com/addons/detail/ublock-origin-lite/gaiffmibhddgflfepacknmimbhpkhapd",
            "https://microsoftedge.microsoft.com/addons/detail/dark-reader/ifoipignemcigfhjlahbaanficakddbe",
            "https://chatgpt.com"
        )
        'Firefox' = @(
            $onboardHubUrl,
            "about:preferences#sync",
            "https://addons.mozilla.org/firefox/addon/violentmonkey/",
            "https://addons.mozilla.org/firefox/addon/consent-o-matic/",
            "https://addons.mozilla.org/firefox/addon/ublock-origin/",
            "https://chatgpt.com"
        )
        'Chrome' = @(
            $onboardHubUrl,
            "chrome://settings/syncSetup",
            "https://chromewebstore.google.com/detail/violentmonkey/jinjaccalgkegednnccohejagnlnfdag",
            "https://chromewebstore.google.com/detail/consent-o-matic/mdjildafknihdffpkfmmpnignkgcmglf",
            "https://chromewebstore.google.com/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh",
            "https://chromewebstore.google.com/detail/dark-reader/eimadpbcbfnmbkopoojfekhnkhdbieeh",
            "https://chatgpt.com"
        )
    }

    foreach ($b in $targetBrowsers) {
        $exe = switch ($b) {
            'Opera'   { Find-OperaExecutable }
            'Edge'    { Find-EdgeExecutable }
            'Firefox' { Find-FirefoxExecutable }
            'Chrome'  { Find-ChromeExecutable }
        }

        if ($exe) {
            $tabs = $onboardTabs[$b]
            $args = ($tabs | ForEach-Object { "`"$_`"" }) -join ' '
            $launchRes = Launch-BrowserProcess -ExecutablePath $exe -Arguments $args
            Write-Host "  [+] $b onboarding launched." -ForegroundColor Green
        } else {
            Write-Warning "Could not launch onboarding for ${b}: Executable not found."
        }
    }
}

# ====================================================================
# 7. LAUNCH BROWSERS (Only when -Launch or -AgentMode is specified)
# ====================================================================
if ($Launch -or $AgentMode) {
    Write-Host "`n====================================================================" -ForegroundColor Cyan
    Write-Host "                    LAUNCHING CLEAN BROWSER WINDOWS                 " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan

    $browserPortMap = @{
        'Opera'   = $DebugPort
        'Edge'    = $DebugPort + 1
        'Firefox' = $DebugPort + 2
        'Chrome'  = $DebugPort + 3
    }

    foreach ($b in $targetBrowsers) {
        $exe = switch ($b) {
            'Opera'   { Find-OperaExecutable }
            'Edge'    { Find-EdgeExecutable }
            'Firefox' { Find-FirefoxExecutable }
            'Chrome'  { Find-ChromeExecutable }
        }

        if (-not $exe) {
            Write-Warning "$b executable could not be resolved for launch."
            continue
        }

        $cmdArgs = "https://chatgpt.com"
        if ($AgentMode) {
            $port = $browserPortMap[$b]
            $cmdArgs = switch ($b) {
                'Opera'   { "--remote-debugging-port=$port https://chatgpt.com" }
                'Edge'    { "--remote-debugging-port=$port --enable-features=WebContentsForceDark https://chatgpt.com" }
                'Firefox' { "--remote-debugging-port $port https://chatgpt.com" }
                'Chrome'  { "--remote-debugging-port=$port --enable-features=WebContentsForceDark https://chatgpt.com" }
            }
            Write-Host "  [🤖] Agent Mode Port for ${b}: $port" -ForegroundColor Yellow
        }

        $launchRes = Launch-BrowserProcess -ExecutablePath $exe -Arguments $cmdArgs
        Write-Host "  [+] $b launched from: $exe" -ForegroundColor Green
    }
} elseif (-not $Onboard) {
    Write-Host "`n[~] Quiet mode (default): Parity settings applied without launching new windows." -ForegroundColor DarkGray
    Write-Host "    (Tip: Pass -Launch to open windows, -Onboard for sync/extension hub, or -AgentMode for CDP)." -ForegroundColor DarkGray
}

Write-Host "`n====================================================================" -ForegroundColor Green
Write-Host "   BROWSERPARITY IS COMPLETE & IN FULL PARITY (DUCKDUCKGO)!         " -ForegroundColor Green
Write-Host "====================================================================" -ForegroundColor Green
