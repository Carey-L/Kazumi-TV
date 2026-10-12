[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $ExtraFlutterArguments
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$outputDirectory = Join-Path $projectRoot 'build\tv'
$flutterOutput = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-tv-release.apk'
$finalOutput = Join-Path $outputDirectory 'Kazumi-TV-armv7-arm64-release.apk'

# ech_http needs CMake >=3.22, but its hook picks an SDK CMake by sorting the
# version directories as strings, so '3.6.4111459' outranks '3.22.1'. Putting
# the newest CMake first on PATH makes the hook use it instead.
function Add-NewestCmakeToPath {
    param([string] $SdkRoot)

    $cmakeRoot = Join-Path $SdkRoot 'cmake'
    if (-not (Test-Path -LiteralPath $cmakeRoot)) {
        return
    }

    $versions = Get-ChildItem -LiteralPath $cmakeRoot -Directory |
        Sort-Object { [version] ($_.Name -replace '-.*$', '') } -Descending
    foreach ($version in $versions) {
        $cmakeExe = Join-Path $version.FullName 'bin\cmake.exe'
        $ninjaExe = Join-Path $version.FullName 'bin\ninja.exe'
        if ((Test-Path -LiteralPath $cmakeExe) -and (Test-Path -LiteralPath $ninjaExe)) {
            $env:PATH = (Join-Path $version.FullName 'bin') + ';' + $env:PATH
            Write-Host "Using CMake $($version.Name): $cmakeExe"
            return
        }
    }
    Write-Warning "No usable CMake found under $cmakeRoot"
}

$sdkRoot = $env:ANDROID_SDK_ROOT
if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_HOME }
if (-not $sdkRoot) {
    $localProperties = Join-Path $projectRoot 'android\local.properties'
    if (Test-Path -LiteralPath $localProperties) {
        $match = Select-String -LiteralPath $localProperties -Pattern '^sdk\.dir=(.+)$' |
            Select-Object -First 1
        if ($match) { $sdkRoot = $match.Matches[0].Groups[1].Value.Trim() }
    }
}
if ($sdkRoot) {
    Add-NewestCmakeToPath -SdkRoot $sdkRoot
}

Push-Location $projectRoot
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get failed with exit code $LASTEXITCODE"
    }

    $buildArguments = @(
        'build',
        'apk',
        '--release',
        '--flavor',
        'tv',
        '--target-platform',
        'android-arm,android-arm64'
    )
    # dandanplay answers 403 without an AppId, so release credentials have to
    # be injected the same way CI does. Reuse the project-local defines file
    # when it exists.
    $definesFile = Join-Path $projectRoot '.kazumi_build_defines.env'
    if (Test-Path -LiteralPath $definesFile) {
        $buildArguments += @('--dart-define-from-file', ".kazumi_build_defines.env")
        Write-Host "Using credentials from .kazumi_build_defines.env"
    }
    else {
        Write-Warning "No .kazumi_build_defines.env found: dandanplay search will fail with HTTP 403."
    }
    if ($ExtraFlutterArguments) {
        $buildArguments += $ExtraFlutterArguments
    }

    & flutter @buildArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter TV build failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path -LiteralPath $flutterOutput -PathType Leaf)) {
        throw "Expected APK was not produced: $flutterOutput"
    }

    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    Copy-Item -LiteralPath $flutterOutput -Destination $finalOutput -Force

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($finalOutput)
    try {
        $entries = $archive.Entries.FullName
        $requiredEntries = @(
            'lib/arm64-v8a/libapp.so',
            'lib/armeabi-v7a/libapp.so'
        )
        foreach ($entry in $requiredEntries) {
            if ($entries -notcontains $entry) {
                throw "TV APK does not contain required ABI entry: $entry"
            }
        }
    }
    finally {
        $archive.Dispose()
    }

    Write-Host "TV APK created: $finalOutput"
}
finally {
    Pop-Location
}
