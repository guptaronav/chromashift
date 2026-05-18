--[[
    LobbyService.lua
    Manages the lobby phase: waiting for players, countdown, then triggering
    the voting → game cycle.

    This service LISTENS to GameStateMachine and REACTS — it does not call
    Transition() itself except to kick off the first voting phase.
]]

local Knit = require(game:GetService("ReplicatedStorage").Chromashift.Packages.Knit)
local GameStateMachine = require(script.Parent.GameStateMachine)
local Constants = require(game:GetService("ReplicatedStorage").Chromashift.Constants)

local LobbyService = Knit.CreateService {
    Name = "LobbyService",
    Client = {
        -- Fired to all clients with the current player count and min required
        LobbyUpdated = Knit.CreateSignal(),
        -- Fired to all clients when the pre-game countdown changes
        CountdownTick = Knit.CreateSignal(),
    },
}

-- Private
local _countdownActive = false

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function getPlayerCount(): number
    return #game:GetService("Players"):GetPlayers()
end

-- Broadcast the current lobby state to all clients (so the waiting UI stays fresh)
local function broadcastLobbyState(self)
    local count = getPlayerCount()
    -- Use the smallest minPlayers across all eligible maps as the threshold
    -- (LobbyService doesn't know which map will be picked yet)
    local threshold = Constants.MIN_PLAYERS_DEFAULT
    for _, player in game:GetService("Players"):GetPlayers() do
        self.Client.LobbyUpdated:Fire(player, count, threshold)
    end
end

-- Runs the countdown then fires the state transition
local function runCountdown(self)
    if _countdownActive then return end
    _countdownActive = true

    for i = Constants.LOBBY_COUNTDOWN, 1, -1 do
        -- Check mid-countdown if enough players still present
        if getPlayerCount() < Constants.MIN_PLAYERS_DEFAULT then
            _countdownActive = false
            broadcastLobbyState(self)
            return
        end

        for _, player in game:GetService("Players"):GetPlayers() do
            self.Client.CountdownTick:Fire(player, i)
        end

        task.wait(1)
    end

    _countdownActive = false
    GameStateMachine:Transition("Voting")
end

-- ─────────────────────────────────────────────
-- Knit lifecycle
-- ─────────────────────────────────────────────

function LobbyService:KnitInit()
    local Players = game:GetService("Players")

    -- When any player joins or leaves while in Lobby, refresh the UI
    -- and check if we've hit the threshold to start a countdown
    local function onRosterChange()
        if not GameStateMachine:Is("Lobby") then return end

        broadcastLobbyState(self)

        if getPlayerCount() >= Constants.MIN_PLAYERS_DEFAULT and not _countdownActive then
            task.spawn(runCountdown, self)
        end
    end

    Players.PlayerAdded:Connect(onRosterChange)
    Players.PlayerRemoving:Connect(onRosterChange)

    -- When a round ends and we return to Lobby, refresh state
    GameStateMachine:OnStateChanged(function(new)
        if new == "Lobby" then
            _countdownActive = false
            broadcastLobbyState(self)
            -- Check immediately if we can already start a new countdown
            if getPlayerCount() >= Constants.MIN_PLAYERS_DEFAULT then
                task.spawn(runCountdown, self)
            end
        end
    end)
end

function LobbyService:KnitStart()
    -- Initial broadcast when the server first starts
    broadcastLobbyState(self)
end

return LobbyService
