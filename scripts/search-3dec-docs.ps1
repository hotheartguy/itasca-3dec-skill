[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Query,

    [string]$DocRoot = $env:ITASCA_DOC_ROOT,

    [string]$Executable = $env:ITASCA_3DEC_CONSOLE,

    [ValidateRange(1, 500)]
    [int]$MaxResults = 50
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-DocumentationRoot {
    param(
        [string]$RequestedRoot,
        [string]$RequestedExecutable
    )

    $candidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        $candidates.Add($RequestedRoot)
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestedExecutable)) {
        $executableDirectory = Split-Path -Parent $RequestedExecutable
        $candidates.Add((Join-Path $executableDirectory 'doc'))
    }

    $candidates.Add(
        'C:\Program Files\Itasca\Itasca Software Subscription\exe64\doc'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw 'Cannot locate Itasca documentation. Set -DocRoot or ITASCA_DOC_ROOT.'
}

$resolvedDocRoot = Resolve-DocumentationRoot `
    -RequestedRoot $DocRoot `
    -RequestedExecutable $Executable

$ripgrep = Get-Command 'rg' -ErrorAction SilentlyContinue
if ($null -ne $ripgrep) {
    $results = & $ripgrep.Source `
        '--line-number' `
        '--ignore-case' `
        '--glob' '*.html' `
        '--' $Query $resolvedDocRoot
    $ripgrepExitCode = $LASTEXITCODE
    $results | Select-Object -First $MaxResults
    exit $ripgrepExitCode
}

$htmlFiles = Get-ChildItem -LiteralPath $resolvedDocRoot -Recurse -File -Filter '*.html'
$matches = $htmlFiles |
    Select-String -Pattern $Query -CaseSensitive:$false |
    Select-Object -First $MaxResults

foreach ($match in $matches) {
    '{0}:{1}:{2}' -f $match.Path, $match.LineNumber, $match.Line.Trim()
}
