--[[
    DataService.lua
    Loads and saves player profiles using ProfileService.

    ROBLOX CONCEPT: Roblox's built-in DataStore can lose data under
    race conditions (player joins/leaves quickly, server crashes).
    ProfileService wraps DataStore with session locking — only one
    server can write a player's profile at a time, preventing data loss.

    You interact with it through a "profile" object:
        profile.Data.XP += 100   -- mutate freely
        profile:Save()           -- explicit save (auto-saves on release too)
]]

local Knit = require(game:GetService("ReplicatedStorage").Chromashift.Packages.Knit)
local ProfileService = require(game:GetService("ReplicatedStorage").Chromashift.Packages.ProfileService)
local Constants = require(game:GetService("ReplicatedStorage").Chromashift.Constants)
local Types = require(game:GetService("ReplicatedStorage").Chromashift.Types)

type PlayerProfile = Types.PlayerProfile

-- The template is the default value for a brand-new player.
-- If a field is missing from a saved profile (e.g. after you add a new field),
-- ProfileService fills it in from this template automatically.
local PROFILE_TEMPLATE: PlayerProfile = {
    Version    = Constants.DATA_VERSION,
    XP         = 0,
    Currency   = 0,
    Level      = 1,
    GamesPlayed = 0,
    GamesWon   = 0,
    Cosmetics  = {},
    EquippedCosmetics = {
        Hat         = nil,
        PaintEffect = nil,
        KillEffect  = nil,
        Emote       = nil,
    },
    DailyReward = {
        LastClaimedDate = nil,
        Streak = 0,
    },
}

local ProfileStore = ProfileService.GetProfileStore("PlayerData_v" .. Constants.DATA_VERSION, PROFILE_TEMPLATE)

local DataService = Knit.CreateService {
    Name = "DataService",
    Client = {},
}

-- Private: UserId → profile object
local _profiles: { [number]: any } = {}

-- ─────────────────────────────────────────────
-- Internal helpers
-- ─────────────────────────────────────────────

local function loadProfile(player: Player)
    local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)

    if profile == nil then
        -- ProfileService couldn't load the profile (DataStore outage, etc.)
        -- Kick the player so they don't play with an empty profile and
        -- potentially lose progress.
        player:Kick("Could not load your data. Please rejoin.")
        return
    end

    -- If the player left while we were loading, release immediately
    if not player:IsDescendantOf(game) then
        profile:Release()
        return
    end

    profile:ListenToRelease(function()
        _profiles[player.UserId] = nil
        -- If somehow the profile is released while the player is still in game,
        -- kick them so they don't continue playing without data persistence.
        if player:IsDescendantOf(game) then
            player:Kick("Your session was released. Please rejoin.")
        end
    end)

    _profiles[player.UserId] = profile
end

-- ─────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────

-- Returns the raw profile data table, or nil if not loaded yet
function DataService:GetData(player: Player): PlayerProfile?
    local profile = _profiles[player.UserId]
    return profile and profile.Data or nil
end

-- Adds XP, handles level-up math, returns new level if leveled up
function DataService:AwardXP(player: Player, amount: number): number?
    local data = self:GetData(player)
    if not data then return nil end

    data.XP += amount

    -- Simple level curve: level = floor(sqrt(XP / 100)) + 1
    local newLevel = math.floor(math.sqrt(data.XP / 100)) + 1
    if newLevel > data.Level then
        data.Level = newLevel
        return newLevel  -- caller can notify the player of level-up
    end
    return nil
end

-- Adds currency (can't go below zero)
function DataService:AwardCurrency(player: Player, amount: number)
    local data = self:GetData(player)
    if not data then return end
    data.Currency = math.max(0, data.Currency + amount)
end

-- Increments game stats, called by RoundService at round end
function DataService:RecordGameResult(player: Player, won: boolean)
    local data = self:GetData(player)
    if not data then return end
    data.GamesPlayed += 1
    if won then
        data.GamesWon += 1
    end
end

-- Grants a cosmetic by id (no-op if already owned)
function DataService:GrantCosmetic(player: Player, cosmeticId: string)
    local data = self:GetData(player)
    if not data then return end
    if not table.find(data.Cosmetics, cosmeticId) then
        table.insert(data.Cosmetics, cosmeticId)
    end
end

-- ─────────────────────────────────────────────
-- Knit lifecycle
-- ─────────────────────────────────────────────

function DataService:KnitInit()
    local Players = game:GetService("Players")

    Players.PlayerAdded:Connect(function(player)
        loadProfile(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        local profile = _profiles[player.UserId]
        if profile then
            profile:Release()  -- triggers auto-save via ProfileService
        end
    end)

    -- Handle players who joined before this service initialized
    for _, player in Players:GetPlayers() do
        task.spawn(loadProfile, player)
    end
end

function DataService:KnitStart() end

return DataService
