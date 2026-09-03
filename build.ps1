<#
.SYNOPSIS
  Downloads, compiles, and launches Aseprite from source on Windows.

.DESCRIPTION
  First run: downloads the latest Aseprite source release and the matching
  pre-built Skia library, configures and compiles Aseprite with CMake +
  Ninja using the Visual Studio 2022 toolchain, then launches it.

  Every run after that just launches the already-built aseprite.exe.

.PARAMETER Rebuild
  Wipe the downloaded source/Skia and the build output, and start over.

.PARAMETER NoRun
  Build (if needed) but don't launch Aseprite afterwards.
#>
param(
    [switch]$Rebuild,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    throw "This script only supports Windows."
}

$root      = $PSScriptRoot
$depsDir   = Join-Path $root '.deps'
$srcDir    = Join-Path $depsDir 'aseprite-src'
$skiaDir   = Join-Path $depsDir 'skia'
$buildDir  = Join-Path $root 'build'
$exePath   = Join-Path $buildDir 'bin\aseprite.exe'

function Write-Step($msg) {
    Write-Host "==> $msg" -ForegroundColor Cyan
}

if ($Rebuild) {
    Write-Step "Rebuild requested: removing .deps\ and build\"
    Remove-Item -Recurse -Force $buildDir, $depsDir -ErrorAction SilentlyContinue
}

# --- Fast path: already built, just launch it -----------------------------
if ((Test-Path $exePath) -and -not $Rebuild) {
    Write-Step "Aseprite is already built"
    if (-not $NoRun) {
        Write-Step "Launching Aseprite"
        Start-Process $exePath
    }
    return
}

# --- Prerequisites ----------------------------------------------------------
function Ensure-Tool($cmdName, $wingetId) {
    if (Get-Command $cmdName -ErrorAction SilentlyContinue) { return }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Step "$cmdName not found, installing via winget ($wingetId)"
        winget install --id $wingetId -e --accept-source-agreements --accept-package-agreements
    }
    if (-not (Get-Command $cmdName -ErrorAction SilentlyContinue)) {
        throw "$cmdName is required but wasn't found (and couldn't be auto-installed). " +
              "Install it and re-run this script."
    }
}

Write-Step "Checking prerequisites"
Ensure-Tool 'cmake' 'Kitware.CMake'
Ensure-Tool 'ninja' 'Ninja-build.Ninja'

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    throw "Visual Studio 2022 wasn't found. Install Visual Studio 2022 Community " +
          "with the 'Desktop development with C++' workload: " +
          "https://visualstudio.microsoft.com/downloads/"
}
$vsPath = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath
if (-not $vsPath) {
    throw "Visual Studio is installed, but the 'Desktop development with C++' workload " +
          "isn't. Add it via the Visual Studio Installer."
}

$vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvars64.bat'
Write-Step "Loading the MSVC x64 developer environment"
$envOutput = cmd.exe /c "`"$vcvars`" && set"
foreach ($line in $envOutput) {
    if ($line -match '^([^=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
}
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    throw "MSVC compiler (cl.exe) still isn't on PATH after loading vcvars64.bat."
}

# --- Download Aseprite source (GitHub Releases) -----------------------------
if (-not (Test-Path (Join-Path $srcDir 'CMakeLists.txt'))) {
    Write-Step "Looking up the latest Aseprite release"
    $release = Invoke-RestMethod 'https://api.github.com/repos/aseprite/aseprite/releases/latest' `
        -Headers @{ 'User-Agent' = 'aseprite-compiler-script' }
    $asset = $release.assets | Where-Object { $_.name -like 'Aseprite-*-Source.zip' } | Select-Object -First 1
    if (-not $asset) {
        throw "Couldn't find a Source.zip asset on the latest Aseprite release ($($release.tag_name))."
    }

    New-Item -ItemType Directory -Force -Path $depsDir | Out-Null
    $zipPath = Join-Path $depsDir $asset.name
    Write-Step "Downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath

    Write-Step "Extracting Aseprite source"
    Expand-Archive -Path $zipPath -DestinationPath $srcDir -Force
}

# --- Download the matching pre-built Skia -----------------------------------
$skiaTag    = (Get-Content (Join-Path $srcDir 'laf\misc\skia-tag.txt')).Trim()
$skiaLibDir = Join-Path $skiaDir 'out\Release-x64'

if (-not (Test-Path (Join-Path $skiaLibDir 'skia.lib'))) {
    $skiaUrl = "https://github.com/aseprite/skia/releases/download/$skiaTag/Skia-Windows-Release-x64.zip"
    $skiaZip = Join-Path $depsDir 'skia.zip'
    New-Item -ItemType Directory -Force -Path $skiaDir | Out-Null

    Write-Step "Downloading Skia ($skiaTag) for Windows x64"
    Invoke-WebRequest -Uri $skiaUrl -OutFile $skiaZip

    Write-Step "Extracting Skia"
    Expand-Archive -Path $skiaZip -DestinationPath $skiaDir -Force
}

# --- Configure + build -------------------------------------------------------
Write-Step "Configuring with CMake"
$cmakeArgs = @(
    '-B', $buildDir,
    '-S', $srcDir,
    '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=RelWithDebInfo',
    '-DLAF_BACKEND=skia',
    "-DSKIA_DIR=$skiaDir",
    "-DSKIA_LIBRARY_DIR=$skiaLibDir",
    "-DSKIA_LIBRARY=$skiaLibDir\skia.lib"
)
& cmake @cmakeArgs
if ($LASTEXITCODE -ne 0) { throw "cmake configuration failed." }

Write-Step "Building Aseprite (this can take a while on the first run)"
& cmake --build $buildDir --target aseprite
if ($LASTEXITCODE -ne 0) { throw "Build failed." }

if (-not (Test-Path $exePath)) {
    throw "Build finished but $exePath wasn't produced."
}

Write-Step "Build complete: $exePath"
if (-not $NoRun) {
    Write-Step "Launching Aseprite"
    Start-Process $exePath
}
