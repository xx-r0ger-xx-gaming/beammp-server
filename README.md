# r0ger gaming | seattle — BeamMP Server

Private BeamNG.drive multiplayer server for the Seattle crew.

## Connecting

- **Direct connect:** `64.23.165.84:30814`
- Server is password protected — ask r0ger for the password
- Max 4 players

> The server shuts down automatically after 15 minutes with no players. To start it, use the [DigitalOcean console](https://cloud.digitalocean.com) or ping r0ger.

---

## In-Game Map Voting

Once connected, use chat to vote on the active map. A majority of connected players triggers the switch — the server will restart into the new map automatically.

| Command | Description |
|---------|-------------|
| `!map list` | Show all available maps |
| `!map <name>` | Vote for a map |

**Available maps:**

| Chat name | Map |
|-----------|-----|
| `american` | American Road |
| `blackhills` | Black Hills Battle Ultra 4 Off-Road |
| `dirty4x4` | Dirty 4x4 Offroad |
| `muddy` | IYB Muddy & Dirty Off-Road |
| `offroad` | IYB Off-Road |
| `island` | Off-Road Island |

---

## Server Management (admin)

### Power on/off
The server powers off automatically after 15 minutes idle. To start it manually:
- Use the [DigitalOcean console](https://cloud.digitalocean.com) to power the droplet on
- **Droplet:** `beamng-server-new` (ID: 570428643, region: SFO3)

### Adding new maps

1. Download the map `.zip` from [beamng.com/resources](https://www.beamng.com/resources/categories/terrains-levels-maps.9/) (requires BeamNG account)
2. Drop the zip into `maps/`
3. Make sure the droplet is powered on
4. Run from this repo:
   ```powershell
   .\sync-maps.ps1
   ```
   This uploads the zip to the server, auto-detects the internal map name, and updates `maps/manifest.json`.
5. Add an entry to the `MAPS` table in `plugins/mapvote/main.lua` with a short chat-friendly alias, then redeploy:
   ```powershell
   scp -i "$env:USERPROFILE\.ssh\beamng_server" plugins\mapvote\main.lua root@64.23.165.84:/home/beammp/Resources/Server/mapvote/main.lua
   ```

### Switching the active map (without chat / no players online)

```powershell
.\switch-map.ps1
```

Shows a numbered list of maps from `maps/manifest.json` and restarts the server into your selection.

---

## Infrastructure

| | |
|-|--|
| **Host** | DigitalOcean SFO3 |
| **OS** | Ubuntu 22.04 LTS |
| **Size** | s-1vcpu-1gb ($6/mo) |
| **IP** | 64.23.165.84 |
| **Port** | 30814 TCP+UDP |
| **BeamMP version** | v3.9.2 |
| **Service** | `systemd beammp.service` (starts on boot, restarts automatically) |
| **SSH key** | `~/.ssh/beamng_server` |

### Key paths on server

| Path | Description |
|------|-------------|
| `/home/beammp/BeamMP-Server` | Server binary |
| `/home/beammp/ServerConfig.toml` | Server config (map, name, password, etc.) |
| `/home/beammp/Resources/Client/` | Map zips served to connecting players |
| `/home/beammp/Resources/Server/mapvote/` | Map voting Lua plugin |
