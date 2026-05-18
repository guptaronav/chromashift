--[[
    RoundController.lua
    Handles all in-round client logic:
    - Showing role splash (Hider / Seeker)
    - Seeker blindfold during prep phase
    - HUD timer
    - Seeker click detection → sends AttemptElimination to server
    - Elimination feedback
    - Results screen

    ROBLOX CONCEPT: UserInputService handles mouse/touch input on the client.
    We use it here to detect clicks for the seeker's detector tool.
    All we do client-side is SEND the request — the server validates and confirms.
]]

local Knit               = require(game:GetService("ReplicatedStorage").Chromashift.Packages.Knit)
local UserInputService   = game:GetService("UserInputService")
local Players            = game:GetService("Players")
local Constants          = require(game:GetService("ReplicatedStorage").Chromashift.Constants)

local RoundController = Knit.CreateController { Name = "RoundController" }

local LocalPlayer = Players.LocalPlayer

-- State
local _myRole         = nil  -- "Hider" | "Seeker"
local _blindfoldFrame = nil
local _hudUI          = nil
local _timerLabel     = nil
local _roleLabel      = nil
local _rolePill       = nil
local _crosshair      = nil
local _cooldownLabel  = nil
local _aliveLabel     = nil
local _resultUI       = nil

-- Cooldown tracking (mirrors server; prevents spam clicks)
local _lastShotTime = 0
local _RoundService = nil

-- ─────────────────────────────────────────────
-- Blindfold helpers
-- ─────────────────────────────────────────────

local function showBlindfold()
    if _blindfoldFrame then
        _blindfoldFrame.Visible = true
    end
end

local function hideBlindfold()
    if _blindfoldFrame then
        _blindfoldFrame.Visible = false
    end
end

-- ─────────────────────────────────────────────
-- Seeker click input
-- ─────────────────────────────────────────────

local function onSeekerClick()
    if _myRole ~= "Seeker" then return end

    local now = tick()
    if (now - _lastShotTime) < Constants.DETECTOR_COOLDOWN then return end

    -- Raycast from camera center into the world to find a player character
    local camera = workspace.CurrentCamera
    local unitRay = camera:ScreenPointToRay(
        camera.ViewportSize.X / 2,
        camera.ViewportSize.Y / 2
    )

    local params = RaycastParams.new()
    -- Exclude our own character from the raycast
    local myChar = LocalPlayer.Character
    if myChar then
        params.FilterDescendantsInstances = { myChar }
        params.FilterType = Enum.RaycastFilterType.Exclude
    end

    local result = workspace:Raycast(
        unitRay.Origin,
        unitRay.Direction * Constants.DETECTOR_RANGE,
        params
    )

    if not result then return end

    -- Walk up the part hierarchy to find a player character model
    local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
    if not hitModel then return end

    local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
    if not hitPlayer then return end

    -- Client-side range check (server will re-verify, this just reduces wasted remotes)
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local hitHRP = hitModel:FindFirstChild("HumanoidRootPart")
    if not myHRP or not hitHRP then return end

    local dist = (myHRP.Position - hitHRP.Position).Magnitude
    if dist > Constants.DETECTOR_RANGE then return end

    -- Send to server for authoritative confirmation
    _lastShotTime = now
    _RoundService.AttemptElimination:CallServer(hitPlayer.UserId)
end

-- ─────────────────────────────────────────────
-- Knit lifecycle
-- ─────────────────────────────────────────────

function RoundController:KnitInit() end

function RoundController:KnitStart()
    _RoundService = Knit.GetService("RoundService")
    local PlayerStateService = Knit.GetService("PlayerStateService")

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    _hudUI        = playerGui:WaitForChild("HudGui", 10)
    _resultUI     = playerGui:WaitForChild("ResultGui", 10)

    if _hudUI then
        _timerLabel     = _hudUI:FindFirstChild("TimerLabel",     true)
        _roleLabel      = _hudUI:FindFirstChild("RoleLabel",      true)
        _rolePill       = _hudUI:FindFirstChild("RolePill",       true)
        _crosshair      = _hudUI:FindFirstChild("Crosshair",      true)
        _cooldownLabel  = _hudUI:FindFirstChild("CooldownLabel",  true)
        _aliveLabel     = _hudUI:FindFirstChild("AliveLabel",     true)
        _blindfoldFrame = _hudUI:FindFirstChild("Blindfold",      true)
        _hudUI.Enabled = false
    end

    if _resultUI then
        _resultUI.Enabled = false
    end

    -- ── Round started ────────────────────────────
    _RoundService.RoundStarted:Connect(function(data)
        _myRole = data.Role
        _lastShotTime = 0

        if _hudUI then
            _hudUI.Enabled = true
            if _roleLabel then
                _roleLabel.Text = _myRole == "Seeker" and "YOU ARE THE SEEKER" or "HIDE!"
            end
        end

        -- Style role pill
        if _rolePill then
            _rolePill.BackgroundColor3 = _myRole == "Seeker"
                and Color3.fromRGB(248, 113, 113)
                or  Color3.fromRGB(74, 222, 128)
        end

        -- Seekers start blinded during prep
        if _myRole == "Seeker" then
            showBlindfold()
        end
    end)

    -- ── Seeker released (prep phase ended) ──────
    _RoundService.SeekerReleased:Connect(function()
        hideBlindfold()
        if _myRole == "Seeker" then
            if _crosshair     then _crosshair.Visible    = true end
            if _cooldownLabel then _cooldownLabel.Visible = true end

            UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    onSeekerClick()
                    -- Flash cooldown label red briefly
                    if _cooldownLabel then
                        _cooldownLabel.Text = "● COOLDOWN"
                        _cooldownLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
                        task.delay(Constants.DETECTOR_COOLDOWN, function()
                            if _cooldownLabel then
                                _cooldownLabel.Text = "● READY"
                                _cooldownLabel.TextColor3 = Color3.fromRGB(74, 222, 128)
                            end
                        end)
                    end
                end
            end)
        end
    end)

    -- ── Timer tick ──────────────────────────────
    _RoundService.TimerTick:Connect(function(phase: string, remaining: number)
        if _timerLabel then
            local mins = math.floor(remaining / 60)
            local secs = remaining % 60
            _timerLabel.Text = string.format("%d:%02d", mins, secs)
        end
    end)

    -- ── Someone got eliminated ───────────────────
    _RoundService.HiderEliminated:Connect(function(data)
        local eliminated = Players:GetPlayerByUserId(data.EliminatedUserId)
        local seeker     = Players:GetPlayerByUserId(data.SeekerUserId)
        local msg = string.format("%s found %s!",
            seeker and seeker.Name or "?",
            eliminated and eliminated.Name or "?"
        )
        -- UIController handles the kill feed notification
        local UIController = Knit.GetController("UIController")
        if UIController then
            UIController:ShowKillFeedEntry(msg)
        end
    end)

    -- ── Round ended ──────────────────────────────
    _RoundService.RoundEnded:Connect(function(result)
        hideBlindfold()
        if _hudUI then _hudUI.Enabled = false end

        if _resultUI then
            _resultUI.Enabled = true
            local winLabel = _resultUI:FindFirstChild("WinLabel", true)
            if winLabel then
                local localState = PlayerStateService:GetMyState():expect()
                local localWon = (
                    (result.WinningSide == "Hiders" and localState and localState.Role == "Hider" and localState.Status == "Alive")
                    or (result.WinningSide == "Seekers" and localState and localState.Role == "Seeker")
                )
                winLabel.Text = localWon and "YOU WIN!" or "YOU LOSE"
                winLabel.TextColor3 = localWon
                    and Color3.fromRGB(80, 220, 120)
                    or Color3.fromRGB(220, 80, 80)
            end

            -- Hide results after intermission (server will transition to Lobby)
            task.delay(Constants.INTERMISSION_DURATION - 1, function()
                if _resultUI then _resultUI.Enabled = false end
            end)
        end
    end)
end

return RoundController
