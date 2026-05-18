--[[
    PlayerStateService.lua
    Owns the runtime role/status of every player in the current round.
    Other services read from here — they never store role data themselves.

    ROBLOX CONCEPT: A "Knit Service" is server-only code that can expose
    methods to the client via the Client = {} table. Knit automatically
    creates a RemoteFunction for each Client method, so you never manually
    create RemoteEvents. Think of it like an RPC layer.
]]

local Knit = require(game:GetService("ReplicatedStorage").Chromashift.Packages.Knit)
local Types = require(game:GetService("ReplicatedStorage").Chromashift.Types)

type PlayerState = Types.PlayerState
type PlayerRole = Types.PlayerRole
type PlayerStatus = Types.PlayerStatus

local PlayerStateService = Knit.CreateService {
    Name = "PlayerStateService",

    -- Methods listed here are callable from the CLIENT via:
    --   local PSS = Knit.GetController("...") -- client can't call services directly
    -- Instead, clients call these through the generated remote:
    --   PlayerStateService.Client.GetMyState:CallServer()
    Client = {
        -- Fired to a specific client when their own state changes
        -- ROBLOX CONCEPT: A Signal here becomes a RemoteEvent automatically
        StateChanged = Knit.CreateSignal(),
    },
}

-- Private: UserId → PlayerState
local _states: { [number]: PlayerState } = {}

-- ─────────────────────────────────────────────
-- Public API (called by other SERVER services)
-- ─────────────────────────────────────────────

-- Call at round start with the full player list and their assigned roles
function PlayerStateService:AssignRoles(players: { Player }, roleMap: { [number]: PlayerRole })
    _states = {}
    for _, player in players do
        local role = roleMap[player.UserId] or "Spectator"
        _states[player.UserId] = {
            UserId      = player.UserId,
            Role        = role,
            Status      = "Alive",
            EliminatedAt = nil,
        }
        -- Tell the client their own role
        self.Client.StateChanged:Fire(player, _states[player.UserId])
    end
end

-- Eliminate a hider — called by RoundService when a seeker scores a hit
function PlayerStateService:EliminatePlayer(player: Player)
    local state = _states[player.UserId]
    if not state or state.Status ~= "Alive" then return end

    state.Status = "Eliminated"
    state.EliminatedAt = os.time()

    self.Client.StateChanged:Fire(player, state)
    print(string.format("[PlayerStateService] %s eliminated", player.Name))
end

-- Returns the PlayerState for one player (nil if not in a round)
function PlayerStateService:GetState(player: Player): PlayerState?
    return _states[player.UserId]
end

-- Returns all players currently alive with the given role
function PlayerStateService:GetAliveByRole(role: PlayerRole): { Player }
    local result = {}
    for userId, state in _states do
        if state.Role == role and state.Status == "Alive" then
            local player = game:GetService("Players"):GetPlayerByUserId(userId)
            if player then
                table.insert(result, player)
            end
        end
    end
    return result
end

-- Returns how many hiders are still alive
function PlayerStateService:CountAliveHiders(): number
    local count = 0
    for _, state in _states do
        if state.Role == "Hider" and state.Status == "Alive" then
            count += 1
        end
    end
    return count
end

-- Wipes all state — called when returning to lobby
function PlayerStateService:Reset()
    _states = {}
end

-- ─────────────────────────────────────────────
-- Client-facing API
-- ─────────────────────────────────────────────

-- Client calls this to get their own role at any time
function PlayerStateService.Client:GetMyState(player: Player): PlayerState?
    return PlayerStateService:GetState(player)
end

-- ─────────────────────────────────────────────
-- Knit lifecycle
-- ─────────────────────────────────────────────

function PlayerStateService:KnitInit()
    -- Clean up state when a player leaves mid-round
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        _states[player.UserId] = nil
    end)
end

function PlayerStateService:KnitStart() end

return PlayerStateService
