--[[
    VotingController.lua
    Renders the map voting UI and handles player vote input.

    The voting UI shows 3 map cards. The player clicks one to vote.
    They can change their vote any time before the timer expires.
    Live vote counts update every second via VoteTallied.
]]

local Knit    = require(game:GetService("ReplicatedStorage").Chromashift.Packages.Knit)
local Players = game:GetService("Players")

local VotingController = Knit.CreateController { Name = "VotingController" }

local _votingUI      = nil
local _timerLabel    = nil
local _cardsFrame    = nil
local _VotingService = nil
local _myVote: string? = nil
local _candidates    = {}

-- ─────────────────────────────────────────────
-- Card building
-- ─────────────────────────────────────────────

local function clearCards()
    if not _cardsFrame then return end
    for _, child in _cardsFrame:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end
end

local function buildCards(candidates)
    if not _cardsFrame then return end
    clearCards()
    _candidates = candidates

    for _, cfg in candidates do
        -- In a real build these are proper GUI objects built in Studio.
        -- Here we create them procedurally so the controller is self-contained
        -- and testable without needing a Studio GUI already set up.
        local card = Instance.new("TextButton")
        card.Name = cfg.Id
        card.Size = UDim2.new(0.3, 0, 1, 0)
        card.Text = cfg.DisplayName .. "\n" .. cfg.Description
        card.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        card.TextColor3 = Color3.new(1,1,1)
        card.TextWrapped = true
        card.Font = Enum.Font.GothamBold
        card.TextSize = 16
        card.Parent = _cardsFrame

        card.Activated:Connect(function()
            _myVote = cfg.Id
            -- Visual: highlight selected card
            for _, sibling in _cardsFrame:GetChildren() do
                if sibling:IsA("TextButton") then
                    sibling.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
                end
            end
            card.BackgroundColor3 = Color3.fromRGB(80, 120, 200)

            -- Tell the server
            _VotingService.CastVote:CallServer(cfg.Id)
        end)
    end
end

local function updateVoteCounts(counts: { [string]: number })
    if not _cardsFrame then return end
    for _, card in _cardsFrame:GetChildren() do
        if card:IsA("TextButton") then
            local count = counts[card.Name] or 0
            -- Append vote count below map name (find or create a sub-label)
            local voteLabel = card:FindFirstChild("VoteCount")
            if not voteLabel then
                voteLabel = Instance.new("TextLabel")
                voteLabel.Name = "VoteCount"
                voteLabel.Size = UDim2.new(1, 0, 0, 24)
                voteLabel.Position = UDim2.new(0, 0, 1, -28)
                voteLabel.BackgroundTransparency = 1
                voteLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
                voteLabel.Font = Enum.Font.Gotham
                voteLabel.TextSize = 14
                voteLabel.Parent = card
            end
            voteLabel.Text = string.format("%d vote%s", count, count == 1 and "" or "s")
        end
    end
end

-- ─────────────────────────────────────────────
-- Knit lifecycle
-- ─────────────────────────────────────────────

function VotingController:KnitInit() end

function VotingController:KnitStart()
    _VotingService = Knit.GetService("VotingService")

    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    _votingUI   = playerGui:WaitForChild("VotingGui", 10)

    if _votingUI then
        _timerLabel = _votingUI:FindFirstChild("TimerLabel", true)
        _cardsFrame = _votingUI:FindFirstChild("CardsFrame", true)
        _votingUI.Enabled = false
    end

    _VotingService.VotingStarted:Connect(function(candidates, duration)
        _myVote = nil
        if _votingUI then _votingUI.Enabled = true end
        if _timerLabel then _timerLabel.Text = tostring(duration) end
        buildCards(candidates)
    end)

    _VotingService.VoteTallied:Connect(function(counts, remaining)
        if _timerLabel then _timerLabel.Text = tostring(remaining) end
        updateVoteCounts(counts)
    end)

    _VotingService.VotingEnded:Connect(function(winningMap)
        if _votingUI then _votingUI.Enabled = false end
        -- UIController will show a "Loading [MapName]..." screen
        local UIController = Knit.GetController("UIController")
        if UIController then
            UIController:ShowMapTransition(winningMap.DisplayName)
        end
    end)
end

return VotingController
