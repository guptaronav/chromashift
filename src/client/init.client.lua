--[[
    init.client.lua  —  Client entry point
    Rojo maps src/client/ → StarterPlayerScripts/Chromashift/.
    This runs once per player when they join.

    Same pattern as the server: register all controllers, then Knit.Start().
    Knit.Start() on the CLIENT also waits for all SERVER services to be
    ready before resolving — so it's safe to call Knit.GetService() inside
    KnitStart() of any controller.
]]

local Knit = require(game:GetService("ReplicatedStorage").Chromashift.Packages.Knit)

require(script.Controllers.UIController)
require(script.Controllers.LobbyController)
require(script.Controllers.VotingController)
require(script.Controllers.RoundController)

Knit.Start():andThen(function()
    print("[Client] Chromashift client started.")
end):catch(function(err)
    error("[Client] Knit failed to start: " .. tostring(err))
end)
