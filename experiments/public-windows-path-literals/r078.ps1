# Public-safe R078 PowerShell 5.1 path-string experiment.
# No private BrowserParity product source, registry, browser, profile or file IO.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'Requires Windows PowerShell 5.1'
}
$bs = [char]92
$cases = @(
    @{ name='relative'; text='.\synthetic.exe'; expected='RELATIVE' },
    @{ name='drive-relative'; text='C:synthetic.exe'; expected='DRIVE_RELATIVE' },
    @{ name='root-relative'; text=($bs + 'synthetic.exe'); expected='ROOT_RELATIVE' },
    @{ name='two-leading-backslashes'; text=([string]$bs + $bs + 'synthetic.exe'); expected='UNC' },
    @{ name='network-share'; text=([string]$bs + $bs + 'synthetic-host' + $bs + 'share' + $bs + 'synthetic.exe'); expected='UNC' },
    @{ name='drive-qualified'; text=('C:' + $bs + 'scratch' + $bs + 'synthetic.exe'); expected='DRIVE_QUALIFIED' },
    @{ name='extended-prefix'; text=([string]$bs + $bs + '?' + $bs + 'C:' + $bs + 'synthetic.exe'); expected='UNC' }
)
function Test-Category([string]$Text) {
    if ($Text -match '^[A-Za-z]:[^\\/]') { return 'DRIVE_RELATIVE' }
    if ($Text.StartsWith(([string]$bs + $bs), [StringComparison]::Ordinal)) { return 'UNC' }
    if ($Text.StartsWith([string]$bs, [StringComparison]::Ordinal)) { return 'ROOT_RELATIVE' }
    if ($Text -match '^[A-Za-z]:\\') { return 'DRIVE_QUALIFIED' }
    return 'RELATIVE'
}
$observed = @()
foreach ($case in $cases) {
    $category = Test-Category $case.text
    if ($category -ne $case.expected) {
        throw ('Mismatch for ' + $case.name + ': ' + $category + ' != ' + $case.expected)
    }
    $observed += [pscustomobject]@{
        case = $case.name
        category = $category
        is_path_rooted = [bool][IO.Path]::IsPathRooted($case.text)
    }
}
$legacy = [string]$bs + $bs + 'synthetic.exe'
$correct = [string]$bs + 'synthetic.exe'
if ((Test-Category $legacy) -ne 'UNC' -or (Test-Category $correct) -ne 'ROOT_RELATIVE') {
    throw 'Expected negative control not reproduced'
}
[pscustomobject]@{
    schema_version = 1
    grade = 'PUBLIC_SYNTHETIC_WINDOWS_PATH_LEXICAL_ONLY'
    status = 'PASS'
    checks = $observed.Count
    expected_red = 'TWO_BACKSLASH_ROOT_FIXTURE_IS_UNC'
    examples = $observed
    private_source_executed = $false
    registry_mutated = $false
    browser_hil = $false
    promotion_authorized = $false
    powershell = $PSVersionTable.PSVersion.ToString()
} | ConvertTo-Json -Depth 5 -Compress
