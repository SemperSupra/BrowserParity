#requires -Version 5.1
<#
R078 independent PUBLIC synthetic Windows junction/source containment bake-off.
Random run-owned RUNNER_TEMP only; no private code, native host, browser,
credential, account, real extension, or actual host executable is used.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
    $PSVersionTable.PSVersion.Major -ne 5) { throw 'DENY: actual Windows PowerShell 5 required' }
if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { throw 'DENY: RUNNER_TEMP required' }

$runId=[guid]::NewGuid().ToString('N')
$root=Join-Path $env:RUNNER_TEMP ('r078-' + $runId)
$normal=Join-Path $root 'normal'
$outside=Join-Path $root 'outside'
$alias=Join-Path $root 'alias'
$normalFile=Join-Path $normal 'inert.exe'
$outsideFile=Join-Path $outside 'inert.exe'
$throughAlias=Join-Path $alias 'inert.exe'
$missingInAlias=Join-Path $alias 'missing.exe'
$checks=0
$phase='preflight'
$qualified=$null

function Check([bool]$ok,[string]$label) {
    if (-not $ok) { throw ('R078 CHECK FAIL: ' + $label) }
    $script:checks++
}
function Assert-NoReparsePath([string]$PathValue) {
    if ([string]::IsNullOrWhiteSpace($PathValue) -or
        $PathValue -notmatch '^[A-Za-z]:\' -or
        $PathValue -match '(^|[\/])\.\.?([\/]|$)') {
        throw 'DENY: noncanonical drive-local path'
    }
    $cursor=[IO.Path]::GetFullPath($PathValue)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $entry=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'DENY: reparse-point path component'
            }
        }
        $parent=[IO.Path]::GetDirectoryName($cursor)
        if ([string]::IsNullOrEmpty($parent) -or
            [string]::Equals($parent,$cursor,[StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $cursor=$parent
    }
}
function ExpectRefusal([scriptblock]$action,[string]$reason,[string]$label) {
    $got=$null
    try { & $action | Out-Null } catch { $got=$_.Exception.Message }
    Check (-not [string]::IsNullOrEmpty($got) -and $got.Contains($reason)) $label
}
try {
    [void][IO.Directory]::CreateDirectory($normal)
    [void][IO.Directory]::CreateDirectory($outside)
    [IO.File]::WriteAllBytes($normalFile,[byte[]]@(0x52,0x30,0x37,0x38))
    [IO.File]::WriteAllBytes($outsideFile,[byte[]]@(0x52,0x30,0x37,0x38))
    $phase='junction creation'
    # Native cmd built-in: run-owned NTFS junction, no administrative rights
    # and no Windows Developer Mode symlink privilege requested.
    $command='mklink /J "'+$alias+'" "'+$outside+'"'
    $output = @(cmd.exe /d /c $command 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw ('R078 junction creation denied: exit '+$LASTEXITCODE+', output='+($output -join ' '))
    }
    Check (Test-Path -LiteralPath $throughAlias -PathType Leaf) 'junction resolves inert file'
    $leaf=Get-Item -LiteralPath $throughAlias -ErrorAction Stop
    Check (($leaf.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'leaf appears regular'
    $junction=Get-Item -LiteralPath $alias -Force -ErrorAction Stop
    Check (($junction.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'ancestor is reparse'
    Check ([IO.Path]::IsPathRooted($throughAlias)) 'unsafe root-only path admission accepts alias'
    Check ([IO.Path]::GetExtension($throughAlias) -eq '.exe') 'unsafe extension check accepts alias'
    $h=(Get-FileHash -LiteralPath $throughAlias -Algorithm SHA256).Hash
    Check ($h -match '^[a-fA-F0-9]{64}$') 'unsafe leaf digest also works through junction'
    Write-Output 'R078_EXPECTED_RED=REGULAR_LEAF_DIGEST_ACCEPTS_JUNCTION_PARENT'

    $phase='ancestor validation'
    Assert-NoReparsePath $normalFile
    Check $true 'direct owned regular file accepted'
    Assert-NoReparsePath (Join-Path $normal 'missing.exe')
    Check $true 'missing final file with regular parent accepted for preflight'
    ExpectRefusal { Assert-NoReparsePath $throughAlias } 'DENY: reparse-point path component' 'junction regular leaf denied'
    ExpectRefusal { Assert-NoReparsePath $missingInAlias } 'DENY: reparse-point path component' 'missing final file through junction denied'
    ExpectRefusal { Assert-NoReparsePath $alias } 'DENY: reparse-point path component' 'junction directory itself denied'
    ExpectRefusal { Assert-NoReparsePath '\\unc-host\test\file.exe' } 'DENY: noncanonical drive-local path' 'UNC refused'
    ExpectRefusal { Assert-NoReparsePath '\relative-root.exe' } 'DENY: noncanonical drive-local path' 'drive-root relative refused'
    ExpectRefusal { Assert-NoReparsePath 'C:drive-relative.exe' } 'DENY: noncanonical drive-local path' 'drive-relative refused'
    ExpectRefusal { Assert-NoReparsePath (Join-Path $normal '..\outside\inert.exe') } 'DENY: noncanonical drive-local path' 'dotdot traversal refused'
    ExpectRefusal { Assert-NoReparsePath (Join-Path $normal '.\inert.exe') } 'DENY: noncanonical drive-local path' 'dot segment refused'

    $phase='junction isolated cleanup'
    # Delete junction itself, NOT target or unknown descendants.
    [IO.Directory]::Delete($alias)
    Check (-not (Test-Path -LiteralPath $alias)) 'junction link absent'
    Check (Test-Path -LiteralPath $outsideFile -PathType Leaf) 'junction target file preserved'
    Assert-NoReparsePath $normalFile
    Check $true 'direct file unaffected by deletion of alias'
    [IO.File]::Delete($normalFile)
    [IO.File]::Delete($outsideFile)
    [IO.Directory]::Delete($normal)
    [IO.Directory]::Delete($outside)
    [IO.Directory]::Delete($root)
    Check (-not (Test-Path -LiteralPath $root)) 'run-owned scratch absent'
    $qualified=[pscustomobject][ordered]@{
        schema_version=1
        grade='PUBLIC_REAL_WINDOWS_NTFS_JUNCTION_ANCESTOR_DIFFERENTIAL'
        result='PASS'
        checks=$checks
        ps_version=$PSVersionTable.PSVersion.ToString()
        runner_os=[Environment]::OSVersion.VersionString
        expected_red='REGULAR_LEAF_DIGEST_ACCEPTS_JUNCTION_PARENT'
        green='EXISTING_ANCESTOR_REPARSE_DENIED'
        cleanup_complete=$true
        private_source_executed=$false
        browser_hil=$false
        promotion_authorized=$false
    }
}
catch {
    Write-Output ('R078_FIRST_FAILURE_PHASE='+$phase)
    Write-Output ('R078_FIRST_FAILURE_MESSAGE='+$_.Exception.Message)
    throw
}
finally {
    # Do not recurse through a junction. Only delete named run-owned files.
    if ([IO.Directory]::Exists($alias)) { [IO.Directory]::Delete($alias) }
    if ([IO.File]::Exists($normalFile)) { [IO.File]::Delete($normalFile) }
    if ([IO.File]::Exists($outsideFile)) { [IO.File]::Delete($outsideFile) }
    foreach($dir in @($normal,$outside,$root)) {
        if ([IO.Directory]::Exists($dir)) {
            if (@(Get-ChildItem -LiteralPath $dir -Force).Count -ne 0) {
                throw ('R078 DENY: unexpected run-owned content at '+$dir)
            }
            [IO.Directory]::Delete($dir)
        }
    }
}
if ($null -eq $qualified) { throw 'R078 no post-cleanup qualification receipt' }
$qualified | ConvertTo-Json -Depth 3 -Compress
exit 0
