--[[
    RoundService.lua
    Drives the Prep and Round states.

    Responsibilities:
    - Randomly assigns seekers from the current player list
    - Applies seeker blindfold during prep phase (client handles the actual UI;
      server locks movement)
    - Runs the round timer
    - Validates seeker hit attempts (server-side raycast confirmation)
    - Detects win conditions and transitions to Intermission
    - Awards XP/currency at round end

    ROBLOX CONCEPT: Humanoid is the component that controls player movement.
    Setting WalkSpeed = 0 freezes them. AnchorRootPart = true is the
    server-authoritative way to prevent all movement, even with exploits.
]]

local Knit            = require(game:GetService("ReplicatedStorage").Chromashift.Packages.Knit)
local GameStateMachine = require(script.Parent.GameStateMachine)
local Constants        = require(game:GetService("ReplicatedStorage").Chromashift.Constants)
local Types            = require(game:GetService("ReplicatedStorage").Chromashift.Types)

type MapConfig = Types.MapConfig
type RoundResult = Types.RoundResult

local RoundService = Knit.CreateService {
    Name = "RoundService",
    Client = {
        -- Fired to all clients at round start with role info and timer
        RoundStarted      = Knit.CreateSignal(),
        -- Fired every second with remaining time
        TimerTick         = Knit.CreateSignal(),
        -- Fired to all clients when a hider is eliminated
        HiderEliminated   = Knit.CreateSignal(),
        -- Fired to all clients with the final RoundResult
        RoundEnded        = Knit.CreateSignal(),
        -- Fired to a specific seeker: their blindfold should drop
        SeekerReleased    = Knit.CreateSignal(),
    },
}

-- Private
local _activeMap: MapConfig? = nil
local _seekerCooldowns: { [number]: number } = {}  -- UserId → last fire timestamp
local _roundActive = false

-- ─────────────────────────────────────────────
-- Seeker assignment
-- ─────────────────────────────────────────────

local function assignRoles(players: { Player }, seekerCount: number): { [number]: Types.PlayerRole }
    local shuffled = table.clone(players)
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    local roleMap: { [number]: Types.PlayerRole } = {}
    for i, player in shuffled do
        roleMap[player.UserId] = (i <= seekerCount) and "Seeker" or "Hider"
    end
    return roleMap
end

-- ─────────────────────────────────────────────
-- Movement lock / unlock helpers
-- ─────────────────────────────────────────────

local function lockPlayer(player: Player)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.Anchored = true end
    if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
end

local function unlockPlayer(player: Player)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.Anchored = false end
    if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
end

-- ─────────────────────────────────────────────
-- Core round loop
-- ─────────────────────────────────────────────

function RoundService:StartRound(mapConfig: MapConfig)
    _activeMap = mapConfig
    _seekerCooldowns = {}
    _roundActive = true

    local Players = game:GetService("Players")
    local allPlayers = Players:GetPlayers()
    local seekerCount = mapConfig.SeekerCount

    -- Assign roles
    local roleMap = assignRoles(allPlayers, seekerCount)
    local PlayerStateService = Knit.GetService("PlayerStateService")
    PlayerStateService:AssignRoles(allPlayers, roleMap)

    -- Lock seekers during prep
    local seekers = PlayerStateService:GetAliveByRole("Seeker")
    for _, seeker in seekers do
        lockPlayer(seeker)
    end

    -- Tell all clients the round started (they'll show role splash screen)
    local prepDuration = mapConfig.PrepDuration or Constants.PREP_DURATION
    for _, player in allPlayers do
        self.Client.RoundStarted:Fire(player, {
            Role          = roleMap[player.UserId],
            MapId         = mapConfig.Id,
            PrepDuration  = prepDuration,
            RoundDuration = mapConfig.RoundDuration or Constants.ROUND_DURATION,
        })
    end

    -- Prep phase countdown
    for i = prepDuration, 1, -1 do
        task.wait(1)
        for _, player in Players:GetPlayers() do
            self.Client.TimerTick:Fire(player, "Prep", i)
        end
    end

    -- Release seekers
    for _, seeker in PlayerStateService:GetAliveByRole("Seeker") do
        unlockPlayer(seeker)
        self.Client.SeekerReleased:Fire(seeker)
    end

    GameStateMachine:Transition("Round")

    -- Round timer
    local roundDuration = mapConfig.RoundDuration or Constants.ROUND_DURATION
    local elapsed = 0

    while elapsed < roundDuration and _roundActive do
        task.wait(1)
        elapsed += 1

        for _, player in Players:GetPlayers() do
            self.Client.TimerTick:Fire(player, "Round", roundDuration - elapsed)
        end

        -- Check win condition: all hiders eliminated
        if PlayerStateService:CountAliveHiders() == 0 then
            self:_endRound("AllEliminated")
            return
        end
    end

    -- Timer ran out — last hider(s) win
    if _roundActive then
        self:_endRound("TimerExpired")
    end
end

-- ─────────────────────────────────────────────
-- Round end + XP awards
-- ─────────────────────────────────────────────

function RoundService:_endRound(reason: string)
    _roundActive = false

    local PlayerStateService = Knit.GetService("PlayerStateService")
    local DataService = Knit.GetService("DataService")
    local Players = game:GetService("Players")

    local survivors = PlayerStateService:GetAliveByRole("Hider")
    local seekers   = PlayerStateService:GetAliveByRole("Seeker")

    local hiderWon = (reason == "TimerExpired" or reason == "LastHider") and #survivors > 0
    local winningSide: "Hiders" | "Seekers" = hiderWon and "Hiders" or "Seekers"

    -- Award XP and currency to all players
    for _, player in Players:GetPlayers() do
        local state = PlayerStateService:GetState(player)
        if not state then continue end

        local xp = Constants.XP_PARTICIPATE
        local currency = Constants.CURRENCY_PARTICIPATE

        if state.Role == "Hider" and state.Status == "Alive" then
            xp += Constants.XP_WIN_HIDER
            if reason == "TimerExpired" then xp += Constants.XP_SURVIVE_FULL end
            currency += Constants.CURRENCY_WIN
            DataService:RecordGameResult(player, true)
        elseif state.Role == "Seeker" and winningSide == "Seekers" then
            xp += Constants.XP_WIN_SEEKER
            currency += Constants.CURRENCY_WIN
            DataService:RecordGameResult(player, true)
        else
            DataService:RecordGameResult(player, false)
        end

        local newLevel = DataService:AwardXP(player, xp)
        DataService:AwardCurrency(player, currency)

        -- TODO: fire level-up event to client if newLevel is non-nil (Phase 3)
    end

    -- Build result payload
    local survivorIds = {}
    for _, p in survivors do table.insert(survivorIds, p.UserId) end
    local seekerIds = {}
    for _, p in seekers do table.insert(seekerIds, p.UserId) end

    local result: RoundResult = {
        WinningSide = winningSide,
        WinReason   = reason :: any,
        Survivors   = survivorIds,
        Seekers     = seekerIds,
        Duration    = (_activeMap and (_activeMap.RoundDuration or Constants.ROUND_DURATION)) or 0,
    }

    for _, player in Players:GetPlayers() do
        self.Client.RoundEnded:Fire(player, result)
    end

    -- Intermission then back to Lobby
    GameStateMachine:Transition("Intermission")
    task.wait(Constants.INTERMISSION_DURATION)

    PlayerStateService:Reset()
    _activeMap = nil
    GameStateMachine:Transition("Lobby")
end

-- ─────────────────────────────────────────────
-- Seeker hit validation (anti-exploit critical)
-- ─────────────────────────────────────────────

--[[
    The client fires this when the seeker clicks on a target.
    We re-run the raycast on the SERVER using the seeker's actual position.
    The client is NEVER trusted for hit confirmation.

    ROBLOX CONCEPT: RaycastParams lets you filter out parts you don't want
    to hit (like the seeker's own character or non-player geometry).
]]
function RoundService.Client:AttemptElimination(seeker: Player, targetUserId: number)
    if not GameStateMachine:Is("Round") then return end

    local PlayerStateService = Knit.GetService("PlayerStateService")

    -- Verify seeker role
    local seekerState = PlayerStateService:GetState(seeker)
    if not seekerState or seekerState.Role ~= "Seeker" or seekerState.Status ~= "Alive" then
        return
    end

    -- Cooldown check
    local now = os.clock()
    local lastFire = _seekerCooldowns[seeker.UserId] or 0
    if (now - lastFire) < Constants.DETECTOR_COOLDOWN then
        return  -- silently ignore — client UI should already prevent spam
    end
    _seekerCooldowns[seeker.UserId] = now

    -- Get target
    local target = game:GetService("Players"):GetPlayerByUserId(targetUserId)
    if not target or not target.Character then return end

    local targetState = PlayerStateService:GetState(target)
    if not targetState or targetState.Role ~= "Hider" or targetState.Status ~= "Alive" then
        return
    end

    -- Server-side range check
    local seekerChar = seeker.Character
    if not seekerChar then return end

    local seekerHRP = seekerChar:FindFirstChild("HumanoidRootPart")
    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not seekerHRP or not targetHRP then return end

    local distance = (seekerHRP.Position - targetHRP.Position).Magnitude
    if distance > Constants.DETECTOR_RANGE then
        warn(string.format(
            "[RoundService] %s attempted hit on %s but range was %.1f (max %d)",
            seeker.Name, target.Name, distance, Constants.DETECTOR_RANGE
        ))
        return
    end

    -- Server raycast: make sure there's no wall between them
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { seekerChar, target.Character }
    params.FilterType = Enum.RaycastFilterType.Exclude

    local origin    = seekerHRP.Position
    local direction = (targetHRP.Position - origin)
    local result    = workspace:Raycast(origin, direction, params)

    -- If the ray hit something (a wall) before reaching the target, it's blocked
    if result and result.Instance then
        local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
        if hitChar ~= target.Character then
            return  -- obstructed
        end
    end

    -- All checks passed — eliminate
    PlayerStateService:EliminatePlayer(target)

    for _, player in game:GetService("Players"):GetPlayers() do
        RoundService.Client.HiderEliminated:Fire(player, {
            EliminatedUserId = target.UserId,
            SeekerUserId     = seeker.UserId,
        })
    end

    -- Immediate win check after each elimination
    if PlayerStateService:CountAliveHiders() == 0 then
        _roundActive = false
        task.spawn(function()
            RoundService:_endRound("AllEliminated")
        end)
    end
end

-- ─────────────────────────────────────────────
-- Knit lifecycle
-- ─────────────────────────────────────────────

function RoundService:KnitInit()
    -- When voting ends, start the round
    GameStateMachine:OnStateChanged(function(new)
        if new == "Voting" then
            task.spawn(function()
                local VotingService = Knit.GetService("VotingService")
                local playerCount = #game:GetService("Players"):GetPlayers()
                local mapConfig = VotingService:RunVoting(playerCount)

                GameStateMachine:Transition("Prep")
                RoundService:StartRound(mapConfig)
            end)
        end
    end)
end

function RoundService:KnitStart() end

return RoundService
