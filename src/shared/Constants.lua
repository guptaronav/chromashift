--[[
    Constants.lua
    Single source of truth for all tunable values in the game.
    Change numbers here — never hardcode them in service files.
]]

local Constants = {}

-- Round timing (seconds)
Constants.LOBBY_COUNTDOWN      = 10   -- countdown before voting starts once minPlayers reached
Constants.VOTING_DURATION      = 30   -- how long map voting lasts
Constants.PREP_DURATION        = 60   -- how long hiders have to hide before seekers release
Constants.ROUND_DURATION       = 180  -- maximum round length (3 minutes)
Constants.INTERMISSION_DURATION = 15  -- results screen before next lobby

-- Seeker tool
Constants.DETECTOR_RANGE       = 20   -- max stud range for the seeker's raycast click
Constants.DETECTOR_COOLDOWN    = 2.5  -- seconds between seeker shots
Constants.DETECTOR_DAMAGE      = 100  -- instant elimination (hiders have 100 HP)

-- Paint system (Phase 2 — values reserved here so they're easy to find)
Constants.PAINT_SAMPLE_RANGE   = 10   -- studs away you can sample a surface color
Constants.PAINT_APPLY_COOLDOWN = 0.5  -- seconds between paint applications

-- Lobby
Constants.MIN_PLAYERS_DEFAULT  = 2    -- fallback if map config doesn't specify
Constants.MAX_PLAYERS_DEFAULT  = 10

-- XP rewards
Constants.XP_WIN_HIDER         = 150
Constants.XP_SURVIVE_FULL      = 100  -- bonus for surviving the entire round
Constants.XP_WIN_SEEKER        = 100
Constants.XP_ELIMINATION       = 25   -- per hider eliminated (seeker)
Constants.XP_PARTICIPATE       = 25   -- consolation for losing

-- Economy
Constants.CURRENCY_WIN         = 50
Constants.CURRENCY_PARTICIPATE = 10

-- Data
Constants.DATA_VERSION         = 1    -- bump this to wipe old saves during development

return Constants
