--[[
    GameStateMachine.lua
    THE single source of truth for what state the game is in.

    ROBLOX CONCEPT: This is a plain ModuleScript, not a Knit service.
    That's intentional — Knit services can depend on it, but it has no
    dependencies of its own. It's the foundation everything else builds on.

    Usage:
        local GSM = require(Services.GameStateMachine)
        GSM:Transition("Voting")
        GSM:OnStateChanged(function(new, old) ... end)
        local state = GSM:GetState()
]]

local Types = require(script.Parent.Parent.Parent.shared.Types)
type GameState = Types.GameState

-- Which transitions are legal. Anything not listed here is rejected with a warning.
local VALID_TRANSITIONS: { [GameState]: { GameState } } = {
    Lobby        = { "Voting" },
    Voting       = { "Prep", "Lobby" },       -- back to Lobby if players drop below min
    Prep         = { "Round", "Lobby" },
    Round        = { "Intermission", "Lobby" },
    Intermission = { "Lobby" },
}

-- Module table (acts like a singleton — there is exactly one game state machine per server)
local GameStateMachine = {}
GameStateMachine.__index = GameStateMachine

-- Private state
local _state: GameState = "Lobby"
local _listeners: { (new: GameState, old: GameState) -> () } = {}

-- Returns the current state string
function GameStateMachine:GetState(): GameState
    return _state
end

-- Returns true if the given state is the current one
function GameStateMachine:Is(state: GameState): boolean
    return _state == state
end

--[[
    Attempts to move to newState.
    Returns true on success, false if the transition is invalid.
    All registered listeners are fired asynchronously via task.spawn
    so a slow listener never blocks the caller.
]]
function GameStateMachine:Transition(newState: GameState): boolean
    local allowed = VALID_TRANSITIONS[_state]
    if not table.find(allowed, newState) then
        warn(string.format(
            "[GameStateMachine] Rejected transition: %s → %s",
            _state, newState
        ))
        return false
    end

    local oldState = _state
    _state = newState

    print(string.format("[GameStateMachine] %s → %s", oldState, newState))

    for _, listener in _listeners do
        task.spawn(listener, newState, oldState)
    end

    return true
end

--[[
    Registers a function to call whenever the state changes.
    Returns a disconnect function — call it to stop listening.

    Example:
        local disconnect = GSM:OnStateChanged(function(new, old)
            if new == "Round" then startHUD() end
        end)
        -- later:
        disconnect()
]]
function GameStateMachine:OnStateChanged(
    listener: (new: GameState, old: GameState) -> ()
): () -> ()
    table.insert(_listeners, listener)
    return function()
        local idx = table.find(_listeners, listener)
        if idx then
            table.remove(_listeners, idx)
        end
    end
end

return GameStateMachine
