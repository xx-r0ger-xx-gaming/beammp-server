# switch-map.ps1
# Changes the active map on the BeamMP server and restarts the service.
# Usage: .\switch-map.ps1              (interactive picker)
#        .\switch-map.ps1 <map-name>   (e.g. "black-hills-battle-ultra-4-off-road")

param([string]$MapName)

$server   = "root@146.190.117.12"
$sshKey   = "$env:USERPROFILE\.ssh\beamng_server"
$manifest = Join-Path $PSScriptRoot "maps\manifest.json"

if (-not (Test-Path $manifest)) {
    Write-Error "No manifest found at $manifest — run .\sync-maps.ps1 first."
    exit 1
}

$maps = Get-Content $manifest | ConvertFrom-Json -AsHashtable

if (-not $MapName) {
    $keys = @($maps.Keys | Sort-Object)
    Write-Host "Available maps:"
    for ($i = 0; $i -lt $keys.Count; $i++) {
        Write-Host "  [$($i+1)] $($keys[$i])  ->  $($maps[$keys[$i]])"
    }
    $choice = Read-Host "Enter number"
    $MapName = $keys[[int]$choice - 1]
}

if (-not $maps.ContainsKey($MapName)) {
    Write-Error "Unknown map '$MapName'. Run .\sync-maps.ps1 to refresh the manifest."
    exit 1
}

$internalPath = $maps[$MapName]
Write-Host "Switching to: $MapName"
Write-Host "  path: $internalPath"

$cmd = @"
sed -i 's|^Map = .*|Map = "$internalPath"|' /home/beammp/ServerConfig.toml && systemctl restart beammp && echo 'Done — server restarted.'
"@
ssh -i $sshKey $server $cmd
