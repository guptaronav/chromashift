--[[
    LobbyController.lua
    Client-side handler for the lobby phase.

    ROBLOX CONCEPT: A "Knit Controller" is the client equivalent of a Service.
    Controllers run inside StarterPlayerScripts — one copy per player.
    They can call server services via Knit.GetService() which auto-generates
    the remote connection. They CANNOT talk to other players directly.

    ROBLOX CONCEPT: LocalScript code cannot access ServerScriptService.
    It CAN access ReplicatedStorage and StarterGui. The UI lives in
    StarterGui, but we reference it through PlayerGui (the player's
    personal copy that Roblox makes automatically).
]]

local Knit   = require(game:GetService("ReplicatedStorage").Chromashift.Packages.Knit)
local Players = game:GetService("Players")

local LobbyController = Knit.CreateController { Name = "LobbyController" }

-- We'll set these in KnitStart once services/UI are guaranteed ready
local _lobbyUI       = nil  -- ScreenGui reference
local _playerCount   = nil  -- TextLabel
local _countdownLabel = nil -- TextLabel
local _VotingService = nil

-- ─────────────────────────────────────────────
-- UI helpers
-- ─────────────────────────────────────────────

local function showLobbyUI()
    if _lobbyUI then _lobbyUI.Enabled = true end
end

local function hideLobbyUI()
    if _lobbyUI then _lobbyUI.Enabled = false end
end

-- ─────────────────────────────────────────────
-- Knit lifecycle
-- ─────────────────────────────────────────────

function LobbyController:KnitInit() end

function LobbyController:KnitStart()
    -- Get service proxies (these are the client-side remotes Knit generates)
    local LobbyService  = Knit.GetService("LobbyService")
    _VotingService = Knit.GetService("VotingService")

    -- Find UI — created separately in Studio under StarterGui
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    _lobbyUI = playerGui:WaitForChild("LobbyGui", 10)

    if _lobbyUI then
        _playerCount    = _lobbyUI:FindFirstChild("PlayerCount",   true)
        _countdownLabel = _lobbyUI:FindFirstChild("CountdownLabel", true)
        showLobbyUI()
    end

    -- ── Server → Client signals ──────────────────

    -- Roster changed — update waiting player count
    LobbyService.LobbyUpdated:Connect(function(current: number, required: number)
        if _playerCount then
            _playerCount.Text = string.format("Players: %d / %d needed", current, required)
        end
        if _countdownLabel then
            _countdownLabel.Text = current >= required and "Starting soon..." or "Waiting for players..."
        end
    end)

    -- Pre-game countdown ticking
    LobbyService.CountdownTick:Connect(function(seconds: number)
        if _countdownLabel then
            _countdownLabel.Text = string.format("Starting in %d...", seconds)
        end
    end)

    -- Voting started — hide lobby UI (VotingController takes over)
    _VotingService.VotingStarted:Connect(function()
        hideLobbyUI()
    end)
end

return LobbyController
