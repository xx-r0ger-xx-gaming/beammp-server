-- mapvote/main.lua
-- In-game chat commands:
--   !map list        show available maps
--   !map <name>      vote for a map (majority of connected players triggers switch)
--
-- Majority = floor(players/2)+1. Votes reset after a switch or when a voter disconnects.

local CONFIG_PATH = "/home/beammp/ServerConfig.toml"

local MAPS = {
    american   = "/levels/mymap/info.json",
    blackhills = "/levels/black_hills_battle/info.json",
    dirty4x4   = "/levels/dirty_4x4/info.json",
    muddy      = "/levels/itsyourboi/info.json",
    offroad    = "/levels/itsyourboi_off_road/info.json",
    island     = "/levels/OffRoadIsland/info.json",
}

local votes = {}  -- { [player_id] = "mapname" }

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
        local voteCount  = countVotes(mapName)
        local needed     = math.floor(MP.GetPlayerCount() / 2) + 1
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
