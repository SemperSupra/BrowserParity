#requires -Version 5.1
<#
Purely public, synthetic PS 5.1 Windows registry/stream behavior qualification.
No BrowserParity private source, nativeMessaging host installation, Chrome,
user session, executable launch, or credential data. Run-owned HKCU fixture only.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or $PSVersionTable.PSVersion.Major -ne 5) {
    throw 'Requires actual Windows PowerShell 5.1'
}
if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { throw 'RUNNER_TEMP required' }
$runId = [guid]::NewGuid().ToString('N')
$registryRoot = 'HKCU:\Software\R076Synthetic-' + $runId
$registryKey = $registryRoot + '\Disposable'
$dir = Join-Path $env:RUNNER_TEMP ('r076-' + $runId)
$manifest = Join-Path $dir 'fixture.json'
$binary = Join-Path $dir 'non-executable.bin'
$foreign = Join-Path $dir 'unexpected.txt'
$origin = 'chrome-extension://' + ('a' * 32) + '/'
$manifestBody = [ordered]@{
    name = 'public.synthetic.r076'
    description = 'Inert Windows PowerShell registry semantics test'
    path = $binary
    type = 'stdio'
    allowed_origins = @($origin)
} | ConvertTo-Json -Depth 4 -Compress
$checks = 0
function Check([bool]$ok, [string]$description) {
    if (-not $ok) { throw ('CHECK FAIL: ' + $description) }
    $script:checks++
}
function RefuseForeignRegistration([string]$expected) {
    if (-not (Test-Path -LiteralPath $registryKey)) { throw 'DENY: missing registry key' }
    $actual = (Get-Item -LiteralPath $registryKey).GetValue('')
    if (-not [string]::Equals($actual, $expected, [StringComparison]::Ordinal)) {
        throw 'DENY: foreign registry value'
    }
}
function RefuseUnknownFiles {
    if (@(Get-ChildItem -LiteralPath $dir -Force).Count -ne 2) {
        throw 'DENY: unexpected managed content'
    }
}
[void][IO.Directory]::CreateDirectory($dir)
try {
    Check (-not (Test-Path -LiteralPath $registryRoot)) 'fresh isolated HKCU root'
    Check (Test-Path -LiteralPath $dir) 'run-owned temp directory'
    [IO.File]::WriteAllBytes($binary, [byte[]]@(0x42, 0x50, 0x30, 0x76))
    $expectedHash = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash
    Check ($expectedHash -match '^[a-fA-F0-9]{64}$') 'SHA-256 reports valid digest'
    $stream = [IO.File]::Open($manifest, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
        try { $writer.Write($manifestBody); $writer.Flush() }
        finally { $writer.Dispose() }
    }
    finally { $stream.Dispose() }
    $bytes = [IO.File]::ReadAllBytes($manifest)
    Check ($bytes.Length -gt 0 -and $bytes[0] -ne 0xEF) 'UTF8 no BOM'
    Check ([string]::Equals([IO.File]::ReadAllText($manifest), $manifestBody, [StringComparison]::Ordinal)) 'JSON manifest exact bytes'
    $decoded = [IO.File]::ReadAllText($manifest) | ConvertFrom-Json
    Check ($decoded.allowed_origins.Count -eq 1 -and $decoded.allowed_origins[0] -eq $origin) 'manifest exact one origin'
    [void](New-Item -Path $registryRoot -ErrorAction Stop)
    [void](New-Item -Path $registryKey -ErrorAction Stop)
    $reg = Get-Item -LiteralPath $registryKey
    $reg.SetValue('', $manifest, [Microsoft.Win32.RegistryValueKind]::String)
    RefuseForeignRegistration $manifest
    Check ([string]::Equals((Get-Item -LiteralPath $registryKey).GetValue(''), $manifest, [StringComparison]::Ordinal)) 'exact HKCU default value'
    $reg.SetValue('', 'FOREIGN-REPLACEMENT', [Microsoft.Win32.RegistryValueKind]::String)
    $denied = $false
    try { RefuseForeignRegistration $manifest }
    catch { $denied = $_.Exception.Message -match '^DENY: foreign registry value' }
    Check $denied 'foreign registration must deny'
    $reg.SetValue('', $manifest, [Microsoft.Win32.RegistryValueKind]::String)
    RefuseForeignRegistration $manifest
    Check $true 'registration restored only after explicit test state'
    RefuseUnknownFiles
    Check $true 'exact two managed fixture files'
    [IO.File]::WriteAllText($foreign, 'synthetic extra')
    $denied = $false
    try { RefuseUnknownFiles }
    catch { $denied = $_.Exception.Message -match '^DENY: unexpected managed content' }
    Check $denied 'unknown extra file must block cleanup'
    [IO.File]::Delete($foreign)
    RefuseUnknownFiles
    Check $true 'safe cleanup preflight restored'
    [void](Remove-Item -LiteralPath $registryKey -ErrorAction Stop)
    [void](Remove-Item -LiteralPath $registryRoot -ErrorAction Stop)
    Check (-not (Test-Path -LiteralPath $registryRoot)) 'no HKCU fixture after cleanup'
    [IO.File]::Delete($manifest)
    [IO.File]::Delete($binary)
    [IO.Directory]::Delete($dir)
    Check (-not (Test-Path -LiteralPath $dir)) 'no temp files after cleanup'
    [pscustomobject][ordered]@{
        schema_version = 1
        test_class = 'PUBLIC_SYNTHETIC_WINDOWS_PS51_NATIVE_SEMANTICS'
        result = 'PASS'
        checks = $checks
        ps_version = $PSVersionTable.PSVersion.ToString()
        os = [Environment]::OSVersion.VersionString
        mutation_scope = 'run-owned HKCU key + RUNNER_TEMP files only'
        native_host_installed = $false
        browser_launched = $false
        real_user_hil = $false
        promotion_authorized = $false
    } | ConvertTo-Json -Depth 5 -Compress
}
finally {
    # Best-effort cleanup only the random run-owned namespace. Preserve any
    # unexpected content if it cannot be verified; an unknown state is failure.
    if (Test-Path -LiteralPath $registryRoot) {
        $keyPresent = Test-Path -LiteralPath $registryKey
        if ($keyPresent) {
            $current = (Get-Item -LiteralPath $registryKey).GetValue('')
            if ([string]::Equals($current, $manifest, [StringComparison]::Ordinal) -or
                [string]::Equals($current, 'FOREIGN-REPLACEMENT', [StringComparison]::Ordinal)) {
                Remove-Item -LiteralPath $registryKey -ErrorAction Stop
            } else { throw 'Unrecognized registry value; cannot safely clean up' }
        }
        if (@(Get-ChildItem -LiteralPath $registryRoot).Count -eq 0) {
            Remove-Item -LiteralPath $registryRoot -ErrorAction Stop
        } else { throw 'Unexpected registry subkeys; cannot safely clean up' }
    }
    if (Test-Path -LiteralPath $dir) {
        foreach ($own in @($manifest, $binary, $foreign)) {
            if (Test-Path -LiteralPath $own -PathType Leaf) { Remove-Item -LiteralPath $own -ErrorAction Stop }
        }
        if (@(Get-ChildItem -LiteralPath $dir -Force).Count -eq 0) {
            Remove-Item -LiteralPath $dir -ErrorAction Stop
        } else { throw 'Unexpected files; cannot safely clean up' }
    }
}
