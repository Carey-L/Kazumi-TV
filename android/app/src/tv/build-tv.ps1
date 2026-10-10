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
