# sync-maps.ps1
# Uploads all zips from .\maps\ to the BeamMP server.
# Auto-detects internal map names and writes .\maps\manifest.json.

$ErrorActionPreference = "Stop"

$server    = "root@146.190.117.12"
$sshKey    = "$env:USERPROFILE\.ssh\beamng_server"
$remoteDir = "/home/beammp/Resources/Client"
$mapsDir   = Join-Path $PSScriptRoot "maps"
$manifest  = Join-Path $mapsDir "manifest.json"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$zips = Get-ChildItem $mapsDir -Filter "*.zip"
if (-not $zips) {
    Write-Host "No zip files found in $mapsDir — drop map zips there and re-run."
    exit 0
}

# Load existing manifest so we don't lose entries for maps not in this run
$known = @{}
if (Test-Path $manifest) {
    $known = Get-Content $manifest | ConvertFrom-Json -AsHashtable
}

foreach ($zip in $zips) {
    # Peek inside the zip for levels/<name>/info.json to get the internal map path
    $internalPath = $null
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
        $entry = $archive.Entries |
            Where-Object { $_.FullName -match '^levels/[^/]+/info\.json$' } |
            Select-Object -First 1
        if ($entry) {
            $mapFolder = ($entry.FullName -split '/')[1]
            $internalPath = "/levels/$mapFolder/info.json"
        }
        $archive.Dispose()
    } catch {
        Write-Warning "Could not inspect $($zip.Name): $_"
    }

    Write-Host "Uploading $($zip.Name)..." -NoNewline
    scp -i $sshKey -q $zip.FullName "${server}:${remoteDir}/"
    Write-Host " done"

    if ($internalPath) {
        $known[$zip.BaseName] = $internalPath
        Write-Host "  internal path: $internalPath"
    } else {
        Write-Warning "  could not detect internal map name for $($zip.Name)"
    }
}

$known | ConvertTo-Json -Depth 3 | Set-Content $manifest
Write-Host "`nManifest saved to $manifest"
Write-Host "Run .\switch-map.ps1 to change the active map."
