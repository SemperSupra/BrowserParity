#requires -Version 5.1
<#
R077 public-only, synthetic Windows PowerShell 5.1 uninstall/failure-state experiment.
The old unsafe ordering is exercised exclusively on a disposable run-owned HKCU
key and temp files. No browser, extension, nativeMessaging, private code or
real executable is ever invoked. The "host" is four inert fixture bytes.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
    $PSVersionTable.PSVersion.Major -ne 5) { throw 'DENY: real Windows PowerShell 5.x required' }
if (-not $env:RUNNER_TEMP) { throw 'DENY: expected disposable GHA RUNNER_TEMP' }

$id = [guid]::NewGuid().ToString('N')
$root = 'HKCU:\Software\R077-Synthetic-' + $id
$key = $root + '\Disposable'
$folder = Join-Path $env:RUNNER_TEMP ('r077-' + $id)
$binary = Join-Path $folder 'inert-host.bin'
$manifest = Join-Path $folder 'manifest.json'
$extra = Join-Path $folder 'unexpected.txt'
$nested = Join-Path $folder 'unexpected-dir'
$bytes = [byte[]]@(0x52,0x30,0x37,0x37)
$expectedDigest = [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash($bytes)).Replace('-','').ToLowerInvariant()
$manifestText = ([ordered]@{name='synthetic.r077';path=$binary;type='stdio';allowed_origins=@('chrome-extension://' + ('a' * 32) + '/')} | ConvertTo-Json -Depth 4 -Compress)
$checks = 0
$phase = 'bootstrap'
function Require([bool]$Condition, [string]$Reason) {
    if (-not $Condition) { throw ('R077 CHECK FAIL: ' + $Reason) }
    $script:checks++
}
function ExpectDeny([scriptblock]$Attempt, [string]$Reason) {
    $denied = $false
    try { & $Attempt | Out-Null }
    catch { $denied = $_.Exception.Message.Contains('DENY:') }
    Require $denied ('expected refusal: ' + $Reason)
}
function Get-Binding {
    if (-not (Test-Path -LiteralPath $key)) { return $null }
    return (Get-Item -LiteralPath $key).GetValue('')
}
function Write-Manifest {
    [IO.File]::WriteAllText($manifest, $manifestText, [Text.UTF8Encoding]::new($false))
}
function Seed-Owned {
    if ((Test-Path -LiteralPath $folder) -or (Test-Path -LiteralPath $key)) {
        throw 'DENY: seed target unexpectedly exists'
    }
    [void][IO.Directory]::CreateDirectory($folder)
    [IO.File]::WriteAllBytes($binary, $bytes)
    Write-Manifest
    if (-not (Test-Path -LiteralPath $root)) { [void](New-Item -Path $root -ErrorAction Stop) }
    [void](New-Item -Path $key -ErrorAction Stop)
    Set-Item -Path $key -Value $manifest -ErrorAction Stop
}
function Inspect-Owned {
    $hasRegistry = Test-Path -LiteralPath $key
    $hasFolder = Test-Path -LiteralPath $folder
    if (-not $hasRegistry -and -not $hasFolder) { return 'EMPTY' }
    if (-not $hasFolder) { throw 'DENY: registry exists without managed files' }
    $directory = Get-Item -LiteralPath $folder -ErrorAction Stop
    if (($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'DENY: reparse-point managed directory'
    }
    foreach ($child in @(Get-ChildItem -LiteralPath $folder -Force -ErrorAction Stop)) {
        if ($child.PSIsContainer -or (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw 'DENY: directory or reparse-point owned content'
        }
        if ($child.Name -notin @('inert-host.bin','manifest.json')) {
            throw 'DENY: foreign file in owned directory'
        }
    }
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { throw 'DENY: missing manifest' }
    if (-not [string]::Equals([IO.File]::ReadAllText($manifest),$manifestText,[StringComparison]::Ordinal)) {
        throw 'DENY: manifest differs'
    }
    if (Test-Path -LiteralPath $binary) {
        $digest=(Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($digest -ne $expectedDigest) { throw 'DENY: binary digest mismatch' }
    }
    if ($hasRegistry) {
        $reg = Get-Item -LiteralPath $key
        $names = @($reg.GetValueNames())
        if ($names.Count -ne 1 -or $names[0] -ne '') {
            throw 'DENY: foreign registry value names'
        }
        if (@(Get-ChildItem -LiteralPath $key).Count -ne 0) {
            throw 'DENY: foreign registry subkeys'
        }
        if (-not [string]::Equals((Get-Binding),$manifest,[StringComparison]::Ordinal)) {
            throw 'DENY: foreign binding'
        }
        return 'OWN_REGISTERED'
    }
    return 'OWN_ORPHAN'
}
function Safe-Remove([bool]$Approved) {
    if (-not $Approved) { throw 'DENY: operator authorization absent' }
    # One complete preflight before *any* state change.
    $condition=Inspect-Owned
    if ($condition -eq 'EMPTY') { return 'ALREADY_REMOVED' }
    if ($condition -eq 'OWN_REGISTERED') {
        Remove-Item -LiteralPath $key -ErrorAction Stop
    }
    Remove-Item -LiteralPath $manifest -ErrorAction Stop
    if (Test-Path -LiteralPath $binary) { Remove-Item -LiteralPath $binary -ErrorAction Stop }
    if (@(Get-ChildItem -LiteralPath $folder -Force).Count -ne 0) {
        throw 'DENY: concurrent foreign file inserted'
    }
    Remove-Item -LiteralPath $folder -ErrorAction Stop
    if ($condition -eq 'OWN_ORPHAN') { return 'RECOVERED_ORPHAN' }
    return 'REMOVED'
}
try {
    $phase = 'first seed'
    Seed-Owned
    Require ((Inspect-Owned) -eq 'OWN_REGISTERED') 'synthetic seed and exact registry'
    Require ((Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant() -eq $expectedDigest) 'inert bytes digest'
    $phase = 'operator negative'
    ExpectDeny { Safe-Remove $false } 'missing operator authorization'
    Require (Test-Path -LiteralPath $key) 'unauthorized attempt preserves registration'

    $phase = 'unsafe original ordering differential'
    [IO.File]::WriteAllText($extra,'synthetic unexpected file')
    # REPRODUCE unsafe unregister-first ordering using ONLY run-owned fixture.
    Remove-Item -LiteralPath $key -ErrorAction Stop
    ExpectDeny { Inspect-Owned } 'foreign file observed after premature unregister'
    Require (-not (Test-Path -LiteralPath $key)) 'original order leaves unregistered partial install'
    Write-Output 'R077_EXPECTED_RED=UNREGISTER_FIRST_LEFT_ORPHAN'
    # Recover test state, then require safe preflight to block all mutation.
    [void](New-Item -Path $key -ErrorAction Stop)
    Set-Item -Path $key -Value $manifest -ErrorAction Stop
    ExpectDeny { Safe-Remove $true } 'extra file must preflight-deny'
    Require (Test-Path -LiteralPath $key) 'safe preflight preserved registered native binding'
    Require (Test-Path -LiteralPath $manifest) 'safe preflight preserved manifest'
    Remove-Item -LiteralPath $extra -ErrorAction Stop

    $phase = 'host substitution negative'
    [IO.File]::WriteAllBytes($binary,[byte[]]@(0x00,0x01,0x02))
    ExpectDeny { Safe-Remove $true } 'changed binary digest'
    Require (Test-Path -LiteralPath $key) 'substituted file did not unregister'
    [IO.File]::WriteAllBytes($binary,$bytes)

    $phase = 'foreign registry negative'
    Set-Item -Path $key -Value 'synthetic-untrusted-location' -ErrorAction Stop
    ExpectDeny { Safe-Remove $true } 'foreign registry value'
    Require ([string]::Equals((Get-Binding),'synthetic-untrusted-location',[StringComparison]::Ordinal)) 'foreign value left alone'
    Set-Item -Path $key -Value $manifest -ErrorAction Stop

    $phase = 'foreign registry named value negative'
    Set-ItemProperty -Path $key -Name 'synthetic-foreign' -Value 'denied' -ErrorAction Stop
    ExpectDeny { Safe-Remove $true } 'foreign named registry value'
    Require (Test-Path -LiteralPath $key) 'foreign named value did not unregister'
    Remove-ItemProperty -Path $key -Name 'synthetic-foreign' -ErrorAction Stop

    $phase = 'manifest substitution negative'
    [IO.File]::WriteAllText($manifest,'synthetic adversary')
    ExpectDeny { Safe-Remove $true } 'changed manifest'
    Require (Test-Path -LiteralPath $key) 'changed manifest did not unregister'
    Write-Manifest

    $phase = 'nested directory negative'
    [void][IO.Directory]::CreateDirectory($nested)
    ExpectDeny { Safe-Remove $true } 'foreign nested directory'
    Require (Test-Path -LiteralPath $key) 'nested directory did not unregister'
    [IO.Directory]::Delete($nested)

    $phase = 'successful removal and repeat'
    Require ((Safe-Remove $true) -eq 'REMOVED') 'exact owned registration removed'
    Require (-not (Test-Path -LiteralPath $key) -and -not (Test-Path -LiteralPath $folder)) 'remove left no state'
    Require ((Safe-Remove $true) -eq 'ALREADY_REMOVED') 'repeat removal idempotent'

    $phase = 'interrupted removal recovery'
    Seed-Owned
    Remove-Item -LiteralPath $key -ErrorAction Stop
    Require ((Inspect-Owned) -eq 'OWN_ORPHAN') 'exact orphan recognized'
    Require ((Safe-Remove $true) -eq 'RECOVERED_ORPHAN') 'safe retry cleaned exact orphan'
    Require (-not (Test-Path -LiteralPath $folder)) 'no orphan files after recovery'

    $phase = 'registry without source negative'
    [void](New-Item -Path $key -ErrorAction Stop)
    Set-Item -Path $key -Value $manifest -ErrorAction Stop
    ExpectDeny { Safe-Remove $true } 'registered without source files'
    Require (Test-Path -LiteralPath $key) 'unknown partial registration refused'
    Remove-Item -LiteralPath $key -ErrorAction Stop
    Require ((Safe-Remove $true) -eq 'ALREADY_REMOVED') 'clean final idempotent removal'
    [pscustomobject][ordered]@{
        schema_version=1;grade='REAL_WINDOWS_SYNTHETIC_TWO_PHASE_UNINSTALL'
        status='PASS';checks=$checks
        ps_version=$PSVersionTable.PSVersion.ToString()
        runner_os=[Environment]::OSVersion.VersionString
        original_order_red='UNREGISTER_FIRST_LEFT_ORPHAN'
        future_order_green='PREFLIGHT_BEFORE_MUTATION_WITH_IDEMPOTENT_REPLAY'
        owned_registry_present=[bool](Test-Path -LiteralPath $key)
        owned_directory_present=[bool](Test-Path -LiteralPath $folder)
        browser_hil=false;private_source_executed=false;promotion_authorized=false
    } | ConvertTo-Json -Compress -Depth 3
}
catch {
    Write-Output ('R077_FIRST_FAILURE_PHASE='+$phase)
    Write-Output ('R077_FIRST_FAILURE_MESSAGE='+$_.Exception.Message)
    throw
}
finally {
    # Clean up only run-owned known test fixture. Foreign unexpected content
    # makes this fail; never recurse or touch the real Chrome/Edge registry.
    if (Test-Path -LiteralPath $key) {
        $binding=Get-Binding
        if ($binding -notin @($manifest,'synthetic-untrusted-location',$null,'')) {
            throw 'DENY: foreign registry value at teardown'
        }
        Remove-Item -LiteralPath $key -ErrorAction Stop
    }
    if (Test-Path -LiteralPath $folder) {
        foreach ($known in @($extra,$binary,$manifest)) {
            if (Test-Path -LiteralPath $known -PathType Leaf) { Remove-Item -LiteralPath $known -ErrorAction Stop }
        }
        if ((Test-Path -LiteralPath $nested -PathType Container) -and
            (@(Get-ChildItem -LiteralPath $nested -Force).Count -eq 0)) {
            [IO.Directory]::Delete($nested)
        }
        if (@(Get-ChildItem -LiteralPath $folder -Force).Count -ne 0) {
            throw 'DENY: unknown test files remained at teardown'
        }
        [IO.Directory]::Delete($folder)
    }
    if (Test-Path -LiteralPath $root) {
        if (@(Get-ChildItem -LiteralPath $root).Count -ne 0) {
            throw 'DENY: unknown registry children remained at teardown'
        }
        Remove-Item -LiteralPath $root -ErrorAction Stop
    }
}
