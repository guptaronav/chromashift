--[[
    VotingService.lua
    Manages the map voting phase.

    Flow:
    1. LobbyService tells us voting has started
    2. We pick 3 eligible maps at random and send them to all clients
    3. Clients vote (RemoteFunction call)
    4. When the timer expires we tally votes, pick a winner, and return it
       so RoundService can load the correct map

    ROBLOX CONCEPT: task.delay() is Roblox's version of setTimeout().
    task.spawn() is like spawning a coroutine — it runs concurrently
    without blocking the caller.
]]

local Knit = require(game:GetService("ReplicatedStorage").Chromashift.Packages.Knit)
local MapConfigs = require(game:GetService("ReplicatedStorage").Chromashift.MapConfigs)
local Constants = require(game:GetService("ReplicatedStorage").Chromashift.Constants)
local Types = require(game:GetService("ReplicatedStorage").Chromashift.Types)

type MapConfig = Types.MapConfig

local VotingService = Knit.CreateService {
    Name = "VotingService",
    Client = {
        -- Fired to all clients when voting starts; payload is the 3 candidate maps
        VotingStarted = Knit.CreateSignal(),
        -- Fired every second with the updated vote counts (for live UI)
        VoteTallied   = Knit.CreateSignal(),
        -- Fired to all clients when voting ends with the winning map
        VotingEnded   = Knit.CreateSignal(),
    },
}

-- Private
local _candidates: { MapConfig } = {}
local _votes: { [number]: string } = {}  -- UserId → mapId

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function pickCandidates(playerCount: number): { MapConfig }
    local eligible = MapConfigs.GetEligible(playerCount)
    -- Fisher-Yates shuffle then take up to 3
    for i = #eligible, 2, -1 do
        local j = math.random(i)
        eligible[i], eligible[j] = eligible[j], eligible[i]
    end
    local result = {}
    for i = 1, math.min(3, #eligible) do
        table.insert(result, eligible[i])
    end
    return result
end

local function tallyVotes(): { [string]: number }
    local counts: { [string]: number } = {}
    for _, mapId in _votes do
        counts[mapId] = (counts[mapId] or 0) + 1
    end
    -- Ensure every candidate has an entry even with 0 votes
    for _, cfg in _candidates do
        if not counts[cfg.Id] then
            counts[cfg.Id] = 0
        end
    end
    return counts
end

local function pickWinner(counts: { [string]: number }): MapConfig
    local bestId = nil
    local bestCount = -1
    local tied: { string } = {}

    for mapId, count in counts do
        if count > bestCount then
            bestCount = count
            bestId = mapId
            tied = { mapId }
        elseif count == bestCount then
            table.insert(tied, mapId)
        end
    end

    -- Break ties randomly
    local winnerId = tied[math.random(#tied)]
    for _, cfg in _candidates do
        if cfg.Id == winnerId then
            return cfg
        end
    end

    -- Fallback (should never reach here if candidates is non-empty)
    return _candidates[1]
end

-- ─────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────

--[[
    Runs the full voting phase asynchronously.
    Returns the winning MapConfig when done.
    Caller should await this in a coroutine / task.spawn.
]]
function VotingService:RunVoting(playerCount: number): MapConfig
    _candidates = pickCandidates(playerCount)
    _votes = {}

    if #_candidates == 0 then
        -- No eligible maps — shouldn't happen in a shipped game but guard anyway
        warn("[VotingService] No eligible maps for player count:", playerCount)
        return MapConfigs.GetAll()[1]
    end

    -- Send candidates to all clients
    for _, player in game:GetService("Players"):GetPlayers() do
        self.Client.VotingStarted:Fire(player, _candidates, Constants.VOTING_DURATION)
    end

    -- Tick the vote display every second
    local elapsed = 0
    while elapsed < Constants.VOTING_DURATION do
        task.wait(1)
        elapsed += 1

        local counts = tallyVotes()
        for _, player in game:GetService("Players"):GetPlayers() do
            self.Client.VoteTallied:Fire(player, counts, Constants.VOTING_DURATION - elapsed)
        end
    end

    local counts = tallyVotes()
    local winner = pickWinner(counts)

    for _, player in game:GetService("Players"):GetPlayers() do
        self.Client.VotingEnded:Fire(player, winner)
    end

    print(string.format("[VotingService] Winner: %s", winner.DisplayName))
    return winner
end

-- ─────────────────────────────────────────────
-- Client API
-- ─────────────────────────────────────────────

-- Client calls this to cast or change their vote
function VotingService.Client:CastVote(player: Player, mapId: string)
    -- Validate the mapId is actually one of the current candidates
    local valid = false
    for _, cfg in _candidates do
        if cfg.Id == mapId then
            valid = true
            break
        end
    end
    if not valid then
        warn(string.format("[VotingService] %s voted for invalid map: %s", player.Name, mapId))
        return
    end
    _votes[player.UserId] = mapId
end

-- ─────────────────────────────────────────────
-- Knit lifecycle
-- ─────────────────────────────────────────────

function VotingService:KnitInit() end
function VotingService:KnitStart() end

return VotingService
