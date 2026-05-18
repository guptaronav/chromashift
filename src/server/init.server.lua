--[[
    init.server.lua  —  Server entry point
    This is the FIRST file Roblox runs on the server when the game starts.
    Its only job is to load Knit, register all services, then start Knit.

    ROBLOX CONCEPT: Rojo maps src/server/ → ServerScriptService/Chromashift/.
    A file named init.server.lua inside a folder becomes that folder's Script,
    which Roblox runs automatically at game start.

    IMPORTANT: The order services are required here does NOT matter for
    initialization. Knit calls KnitInit() on all services first, then
    KnitStart() on all of them. This means services can safely get references
    to each other inside KnitStart() (but NOT KnitInit()).
]]

local Knit = require(game:GetService("ReplicatedStorage").Chromashift.Packages.Knit)

-- Register every service with Knit before calling Start()
require(script.Services.DataService)
require(script.Services.PlayerStateService)
require(script.Services.GameStateMachine)  -- not a Knit service, just forces it to load
require(script.Services.LobbyService)
require(script.Services.VotingService)
require(script.Services.RoundService)

-- Knit.Start() calls KnitInit() on all services, then KnitStart() on all.
-- It returns a Promise — we await it and crash loudly if something fails.
Knit.Start():andThen(function()
    print("[Server] Chromashift server started successfully.")
end):catch(function(err)
    error("[Server] Knit failed to start: " .. tostring(err))
end)
