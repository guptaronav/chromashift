--[[
    Types.lua
    Shared type definitions used across server and client.
    Luau's type system is similar to TypeScript — these are compile-time only,
    they don't affect runtime performance.
]]

local Types = {}

-- The five game states the state machine cycles through
export type GameState = "Lobby" | "Voting" | "Prep" | "Round" | "Intermission"

-- A player's role in the current round
export type PlayerRole = "Hider" | "Seeker" | "Spectator"

-- A player's status within their role
export type PlayerStatus = "Alive" | "Eliminated" | "Waiting"

-- Full runtime state tracked per player
export type PlayerState = {
    UserId: number,
    Role: PlayerRole,
    Status: PlayerStatus,
    EliminatedAt: number?,  -- Unix timestamp, nil if still alive
}

-- Map configuration — each map declares its own rules
export type MapConfig = {
    Id: string,              -- unique key, e.g. "ForestHideout"
    DisplayName: string,     -- shown in voting UI
    Description: string,
    MinPlayers: number,
    MaxPlayers: number,
    SeekerCount: number,     -- how many seekers are assigned per round
    RoundDuration: number?,  -- overrides Constants.ROUND_DURATION if set
    PrepDuration: number?,   -- overrides Constants.PREP_DURATION if set
    ThumbnailAssetId: string, -- shown on the voting card
}

-- Result of a completed round, sent to all clients for the results screen
export type RoundResult = {
    WinningSide: "Hiders" | "Seekers",
    WinReason: "TimerExpired" | "AllEliminated" | "LastHider",
    Survivors: { number },   -- array of UserIds
    Seekers: { number },
    Duration: number,        -- how long the round actually lasted (seconds)
}

-- Per-player data saved to DataStore via ProfileService
export type PlayerProfile = {
    Version: number,
    XP: number,
    Currency: number,
    Level: number,
    GamesPlayed: number,
    GamesWon: number,
    Cosmetics: { string },   -- array of owned cosmetic ids
    EquippedCosmetics: {
        Hat: string?,
        PaintEffect: string?,
        KillEffect: string?,
        Emote: string?,
    },
    DailyReward: {
        LastClaimedDate: string?,  -- "YYYY-MM-DD"
        Streak: number,
    },
}

return Types
