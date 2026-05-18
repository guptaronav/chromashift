--[[
    UIController.lua
    Shared UI utilities — kill feed, map transition screen, notifications.
    Other controllers call into this rather than managing notifications themselves.
]]

local Knit    = require(game:GetService("ReplicatedStorage").Chromashift.Packages.Knit)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIController = Knit.CreateController { Name = "UIController" }

local _notifContainer = nil  -- Frame that holds kill feed entries
local _transitionFrame = nil -- Full-screen transition overlay

-- ─────────────────────────────────────────────
-- Kill feed
-- ─────────────────────────────────────────────

local FEED_ENTRY_LIFETIME = 4  -- seconds before an entry fades out

function UIController:ShowKillFeedEntry(message: string)
    if not _notifContainer then return end

    local entry = Instance.new("TextLabel")
    entry.Size = UDim2.new(1, 0, 0, 28)
    entry.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    entry.BackgroundTransparency = 0.3
    entry.TextColor3 = Color3.new(1, 1, 1)
    entry.Text = message
    entry.Font = Enum.Font.Gotham
    entry.TextSize = 14
    entry.TextXAlignment = Enum.TextXAlignment.Left
    entry.RichText = true
    entry.Parent = _notifContainer

    -- Slide in
    entry.Position = UDim2.new(1, 0, 0, 0)
    TweenService:Create(entry, TweenInfo.new(0.2), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()

    -- Fade out and destroy after lifetime
    task.delay(FEED_ENTRY_LIFETIME, function()
        TweenService:Create(entry, TweenInfo.new(0.4), {
            TextTransparency = 1,
            BackgroundTransparency = 1,
        }):Play()
        task.wait(0.4)
        if entry and entry.Parent then entry:Destroy() end
    end)
end

-- ─────────────────────────────────────────────
-- Map transition overlay
-- ─────────────────────────────────────────────

function UIController:ShowMapTransition(mapName: string)
    if not _transitionFrame then return end

    local label = _transitionFrame:FindFirstChild("MapNameLabel")
    if label then label.Text = "Loading " .. mapName .. "..." end

    _transitionFrame.BackgroundTransparency = 1
    _transitionFrame.Visible = true

    TweenService:Create(_transitionFrame, TweenInfo.new(0.4), {
        BackgroundTransparency = 0,
    }):Play()

    -- Hide once server fires RoundStarted (RoundController will handle that)
    -- For now: auto-hide after 5 seconds as a safety fallback
    task.delay(5, function()
        self:HideMapTransition()
    end)
end

function UIController:HideMapTransition()
    if not _transitionFrame then return end
    TweenService:Create(_transitionFrame, TweenInfo.new(0.3), {
        BackgroundTransparency = 1,
    }):Play()
    task.wait(0.3)
    _transitionFrame.Visible = false
end

-- ─────────────────────────────────────────────
-- Knit lifecycle
-- ─────────────────────────────────────────────

function UIController:KnitInit() end

function UIController:KnitStart()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    -- These GUIs are created in Studio under StarterGui
    local notifGui = playerGui:WaitForChild("NotifGui", 10)
    if notifGui then
        _notifContainer = notifGui:FindFirstChild("KillFeed", true)
    end

    local overlayGui = playerGui:WaitForChild("OverlayGui", 10)
    if overlayGui then
        _transitionFrame = overlayGui:FindFirstChild("TransitionFrame", true)
    end

    -- Hide map transition when a round starts (safety cleanup)
    local RoundService = Knit.GetService("RoundService")
    RoundService.RoundStarted:Connect(function()
        self:HideMapTransition()
    end)
end

return UIController
