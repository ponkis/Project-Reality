[CmdletBinding()]
param(
    [ValidateSet('BuildMod', 'Stage', 'Audit', 'All')]
    [string] $Task = 'All',

    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',

    [string] $CMakePath,

    [string] $PythonPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-CMake {
    if ($CMakePath) {
        return (Resolve-Path -LiteralPath $CMakePath).Path
    }

    $command = Get-Command cmake -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw 'CMake was not found. Pass -CMakePath explicitly.'
}

function Resolve-Python {
    $candidates = @()

    if ($PythonPath) {
        $candidates += (Resolve-Path -LiteralPath $PythonPath).Path
    } else {
        $command = Get-Command python -ErrorAction SilentlyContinue
        if ($command) {
            $candidates += $command.Source
        }

        $candidates += 'C:\Users\xxski\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
    }

    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate)) {
            continue
        }

        & $candidate -c 'import PIL' *> $null
        if ($LASTEXITCODE -eq 0) {
            return $candidate
        }
    }

    throw 'No Python interpreter with Pillow was found. Pass -PythonPath explicitly.'
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory)] [string] $Executable,
        [Parameter(Mandatory)] [string[]] $Arguments
    )

    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Executable failed with exit code $LASTEXITCODE."
    }
}

function Build-Mod {
    $cmake = Resolve-CMake
    $python = Resolve-Python
    $source = Join-Path $repoRoot 'project'
    $build = Join-Path $source 'build'

    Invoke-Checked -Executable $cmake -Arguments @(
        '-S', $source,
        '-B', $build,
        "-DPython3_EXECUTABLE:FILEPATH=$python"
    )
    Invoke-Checked -Executable $cmake -Arguments @('--build', $build, '--config', $Configuration)
}

function Stage-Runtime {
    $engineBuild = Join-Path $repoRoot 'engine\build\project-reality'
    $runtime = Join-Path $engineBuild $Configuration
    $executable = Join-Path $runtime 'Ghostship.exe'

    if (-not (Test-Path -LiteralPath $executable)) {
        throw "Ghostship has not been built for ${Configuration}: $executable"
    }

    foreach ($archiveName in @('ghostship.o2r', 'sm64.o2r')) {
        $archive = Join-Path $engineBuild $archiveName
        if (-not (Test-Path -LiteralPath $archive)) {
            throw "Missing private runtime archive: $archive"
        }
        Copy-Item -LiteralPath $archive -Destination $runtime -Force
    }

    $controllerDatabase = Join-Path $engineBuild 'gamecontrollerdb.txt'
    if (-not (Test-Path -LiteralPath $controllerDatabase)) {
        throw "Missing generated controller database: $controllerDatabase"
    }
    Copy-Item -LiteralPath $controllerDatabase -Destination $runtime -Force

    $runtimeConfig = Join-Path $runtime 'ghostship.cfg.json'
    if (-not (Test-Path -LiteralPath $runtimeConfig)) {
        $defaultConfig = Join-Path $repoRoot 'config\project-reality.defaults.json'
        Copy-Item -LiteralPath $defaultConfig -Destination $runtimeConfig
    }

    $modOutput = Join-Path $repoRoot 'project\output'
    foreach ($required in @(
        'manifest.json',
        'build.gen',
        'dist\main.c',
        'project_reality\title_logo',
        'project_reality\paintings\bbh1',
        'project_reality\paintings\bbh2',

        'project_reality\paintings\ddd1',
        'project_reality\paintings\ddd2',
        'project_reality\paintings\hmc1',
        'project_reality\paintings\hmc2',
        'project_reality\paintings\sml1',
        'project_reality\paintings\sml2',
        'project_reality\paintings\ssl1',
        'project_reality\paintings\ssl2',
        'project_reality\audio\haha.wav',
        'project_reality\audio\yeah.wav',
        'project_reality\audio\comeon.wav',
        'project_reality\audio\input.wav',
        'sound\samples\sfx_mario\19_mario_yippee',
        'sound\samples\sfx_mario_peach\08_mario_punch_yah',
        'sound\samples\sfx_mario\13_mario_press_start_to_play',
        'sound\samples\sfx_mario\12_mario_hello'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $modOutput $required))) {
            throw "Project Reality mod output is incomplete; missing $required."
        }
    }

    $modsDirectory = Join-Path $runtime 'mods'
    $modTarget = Join-Path $modsDirectory 'project-reality-core'
    New-Item -ItemType Directory -Force -Path $modsDirectory | Out-Null

    if (Test-Path -LiteralPath $modTarget) {
        $resolvedRuntime = (Resolve-Path -LiteralPath $runtime).Path
        $resolvedTarget = (Resolve-Path -LiteralPath $modTarget).Path
        $expectedTarget = Join-Path $resolvedRuntime 'mods\project-reality-core'
        if ($resolvedTarget -ne $expectedTarget) {
            throw "Refusing to replace unexpected staging path: $resolvedTarget"
        }
        Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $modTarget | Out-Null
    Copy-Item -Path (Join-Path $modOutput '*') -Destination $modTarget -Recurse -Force
    Write-Host "Staged Project Reality runtime: $executable"
}

switch ($Task) {
    'BuildMod' { Build-Mod }
    'Stage' { Stage-Runtime }
    'Audit' { & (Join-Path $PSScriptRoot 'check-sensitive-files.ps1') }
    'All' {
        Build-Mod
        Stage-Runtime
        & (Join-Path $PSScriptRoot 'check-sensitive-files.ps1')
    }
}
