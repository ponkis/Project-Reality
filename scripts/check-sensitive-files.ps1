[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$repositories = @(
    @{ Name = 'Project Reality'; Path = $repoRoot },
    @{ Name = 'Ghostship'; Path = Join-Path $repoRoot 'engine' },
    @{ Name = 'Torch'; Path = Join-Path $repoRoot 'engine\Torch' }
)

$blockedPattern = '(?i)(^|/)(baserom[^/]*|[^/]+[.](z64|n64|v64|rom|o2r|otr))$'
$violations = @()

foreach ($repository in $repositories) {
    $gitMarker = Join-Path $repository.Path '.git'
    if (-not (Test-Path -LiteralPath $gitMarker)) {
        continue
    }

    $tracked = @(& git -C $repository.Path ls-files)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect tracked files in $($repository.Name)."
    }

    $staged = @(& git -C $repository.Path diff --cached --name-only --diff-filter=ACMR)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect staged files in $($repository.Name)."
    }

    foreach ($file in @($tracked + $staged | Sort-Object -Unique)) {
        $normalized = $file.Replace('\', '/')
        if ($normalized -match $blockedPattern) {
            $violations += "$($repository.Name): $normalized"
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Error ("Sensitive or generated files are tracked/staged:`n  " + ($violations -join "`n  "))
    exit 1
}

Write-Host 'Sensitive-file audit passed: no ROM or resource archive is tracked or staged.'
