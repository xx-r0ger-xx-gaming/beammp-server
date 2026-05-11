#!/bin/bash
set -e

BEAMMP_VERSION="v3.9.2"
BEAMMP_USER="beammp"
BEAMMP_DIR="/home/beammp"

echo "==> Creating beammp user"
id -u $BEAMMP_USER &>/dev/null || useradd -m -s /bin/bash $BEAMMP_USER

echo "==> Installing dependencies"
apt-get update -qq
apt-get install -y -qq curl jq

echo "==> Downloading BeamMP-Server $BEAMMP_VERSION"
curl -sL "https://github.com/BeamMP/BeamMP-Server/releases/download/$BEAMMP_VERSION/BeamMP-Server-linux" \
    -o $BEAMMP_DIR/BeamMP-Server
chmod +x $BEAMMP_DIR/BeamMP-Server

echo "==> Creating directory structure"
mkdir -p $BEAMMP_DIR/Resources/Client
mkdir -p $BEAMMP_DIR/Resources/Server/mapvote

echo "==> Writing ServerConfig.toml"
cat > $BEAMMP_DIR/ServerConfig.toml << 'TOML'
[Misc]
UpdateReminderTime = "30s"
ImScaredOfUpdates = true

[General]
Description = "Private server - invite only"
MaxCars = 2
LogChat = true
ResourceFolder = "Resources"
IP = "::"
Name = "r0ger gaming | seattle"
Private = true
InformationPacket = true
AllowGuests = true
Port = 30814
Debug = false
Tags = "Freeroam"
AuthKey = "ff62b0ce-97c2-4136-8db9-43eb4a2ca55a"
MaxPlayers = 4
Map = "/levels/mymap/info.json"
TOML

echo "==> Writing mapvote plugin"
cat > $BEAMMP_DIR/Resources/Server/mapvote/main.lua << 'LUA'
-- mapvote/main.lua
local CONFIG_PATH = "/home/beammp/ServerConfig.toml"

local MAPS = {
    american   = "/levels/mymap/info.json",
    blackhills = "/levels/black_hills_battle/info.json",
    dirty4x4   = "/levels/dirty_4x4/info.json",
    muddy      = "/levels/itsyourboi/info.json",
    offroad    = "/levels/itsyourboi_off_road/info.json",
    island     = "/levels/OffRoadIsland/info.json",
}

local votes = {}

local function countVotes(mapName)
    local n = 0
    for _, v in pairs(votes) do
        if v == mapName then n = n + 1 end
    end
    return n
end

local function switchMap(mapName)
    local path = MAPS[mapName]
    local f = io.open(CONFIG_PATH, "r")
    if not f then
        MP.SendChatMessage(-1, "[MapVote] ERROR: could not read ServerConfig.toml")
        return
    end
    local content = f:read("*all")
    f:close()
    content = content:gsub('Map%s*=%s*"[^"]*"', 'Map = "' .. path .. '"')
    local fw = io.open(CONFIG_PATH, "w")
    if not fw then
        MP.SendChatMessage(-1, "[MapVote] ERROR: could not write ServerConfig.toml")
        return
    end
    fw:write(content)
    fw:close()
    MP.SendChatMessage(-1, "[MapVote] Switching to " .. mapName .. "! Server restarting...")
    exit()
end

function onChatMessage(player_id, player_name, message)
    local lower = message:lower()
    if lower == "!map list" then
        local names = {}
        for k in pairs(MAPS) do table.insert(names, k) end
        table.sort(names)
        MP.SendChatMessage(player_id, "[MapVote] Maps: " .. table.concat(names, ", "))
        return 1
    end
    local mapName = lower:match("^!map%s+(%S+)$")
    if mapName then
        if not MAPS[mapName] then
            MP.SendChatMessage(player_id, "[MapVote] Unknown map. Type !map list to see options.")
            return 1
        end
        votes[player_id] = mapName
        local voteCount = countVotes(mapName)
        local needed    = math.floor(MP.GetPlayerCount() / 2) + 1
        MP.SendChatMessage(-1, "[MapVote] " .. player_name .. " voted for " .. mapName ..
            " (" .. voteCount .. "/" .. needed .. " needed)")
        if voteCount >= needed then
            votes = {}
            switchMap(mapName)
        end
        return 1
    end
end

function onPlayerDisconnect(player_id)
    votes[player_id] = nil
end
LUA

echo "==> Writing idle-shutdown script"
cat > $BEAMMP_DIR/idle-shutdown.sh << 'BASH'
#!/bin/bash
# Powers off the droplet after 15 min with no connected players.
IDLE_FILE="/tmp/beammp_idle_since"
IDLE_MINUTES=15

PLAYERS=$(ss -tn state established | grep -c ":30814 " || true)

if [ "$PLAYERS" -gt 0 ]; then
    rm -f "$IDLE_FILE"
    exit 0
fi

if [ ! -f "$IDLE_FILE" ]; then
    date +%s > "$IDLE_FILE"
    exit 0
fi

IDLE_SINCE=$(cat "$IDLE_FILE")
NOW=$(date +%s)
ELAPSED=$(( (NOW - IDLE_SINCE) / 60 ))

if [ "$ELAPSED" -ge "$IDLE_MINUTES" ]; then
    logger "beammp: idle ${ELAPSED}min — shutting down"
    shutdown -h now
fi
BASH
chmod +x $BEAMMP_DIR/idle-shutdown.sh

echo "==> Installing cron job for idle shutdown (runs every 5 min)"
echo "*/5 * * * * root /home/beammp/idle-shutdown.sh" > /etc/cron.d/beammp-idle-shutdown
chmod 644 /etc/cron.d/beammp-idle-shutdown

echo "==> Writing systemd service"
cat > /etc/systemd/system/beammp.service << 'SERVICE'
[Unit]
Description=BeamMP Server
After=network.target

[Service]
Type=simple
User=beammp
WorkingDirectory=/home/beammp
ExecStart=/home/beammp/BeamMP-Server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

echo "==> Fixing permissions"
chown -R $BEAMMP_USER:$BEAMMP_USER $BEAMMP_DIR

echo "==> Enabling BeamMP service (not starting yet — maps not uploaded)"
systemctl daemon-reload
systemctl enable beammp

echo "==> Done. Upload maps then run: systemctl start beammp"
