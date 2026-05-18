--[[
    UIBuilder.lua
    Creates every ScreenGui the game needs at runtime, in code.
    Called once from init.client.lua before Knit starts.

    Why code instead of Studio? Because it's version-controlled, editable
    from any text editor, and doesn't require Rojo to sync Studio model files.

    ROBLOX CONCEPT: ScreenGui is the top-level container for 2D UI.
    It lives in PlayerGui (the player's personal copy of StarterGui).
    Each ScreenGui has a ZIndexBehavior and ResetOnSpawn property.
]]

local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- ─── Design tokens ────────────────────────────────────────────────────────────

local COLOR = {
    BG          = Color3.fromRGB(10,  12,  26),   -- near-black navy
    SURFACE     = Color3.fromRGB(20,  23,  45),   -- card surface
    SURFACE2    = Color3.fromRGB(30,  34,  62),   -- elevated surface
    ACCENT      = Color3.fromRGB(139, 92,  246),  -- purple
    ACCENT2     = Color3.fromRGB(236, 72,  153),  -- pink
    SUCCESS     = Color3.fromRGB(74,  222, 128),  -- green
    DANGER      = Color3.fromRGB(248, 113, 113),  -- red
    WARNING     = Color3.fromRGB(251, 191, 36),   -- yellow
    TEXT        = Color3.fromRGB(248, 250, 252),
    TEXT_DIM    = Color3.fromRGB(148, 163, 184),
    BORDER      = Color3.fromRGB(51,  65,  85),
    SEEKER      = Color3.fromRGB(248, 113, 113),  -- red tint for seeker role
    HIDER       = Color3.fromRGB(74,  222, 128),  -- green tint for hider role
}

local FONT = {
    DISPLAY = Enum.Font.GothamBlack,
    BOLD    = Enum.Font.GothamBold,
    SEMI    = Enum.Font.GothamSemibold,
    BODY    = Enum.Font.Gotham,
}

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function gui(className, props, parent)
    local inst = Instance.new(className)
    for k, v in props do
        inst[k] = v
    end
    inst.Parent = parent
    return inst
end

local function frame(props, parent)
    props.BackgroundColor3 = props.BackgroundColor3 or COLOR.SURFACE
    props.BorderSizePixel = props.BorderSizePixel or 0
    return gui("Frame", props, parent)
end

local function label(props, parent)
    props.BackgroundTransparency = props.BackgroundTransparency or 1
    props.BorderSizePixel = props.BorderSizePixel or 0
    props.TextColor3 = props.TextColor3 or COLOR.TEXT
    props.Font = props.Font or FONT.BODY
    props.TextSize = props.TextSize or 16
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
    props.RichText = true
    return gui("TextLabel", props, parent)
end

local function corner(radius, parent)
    return gui("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function padding(px, parent)
    return gui("UIPadding", {
        PaddingTop    = UDim.new(0, px),
        PaddingBottom = UDim.new(0, px),
        PaddingLeft   = UDim.new(0, px),
        PaddingRight  = UDim.new(0, px),
    }, parent)
end

local function stroke(color, thickness, parent)
    return gui("UIStroke", {
        Color = color or COLOR.BORDER,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function makeScreen(name, zIndex, resetOnSpawn)
    return gui("ScreenGui", {
        Name         = name,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = resetOnSpawn ~= false,
        Enabled      = false,
        DisplayOrder = zIndex or 1,
    }, PlayerGui)
end

-- ─── 1. LobbyGui ──────────────────────────────────────────────────────────────

local function buildLobbyGui()
    local screen = makeScreen("LobbyGui", 1)

    -- Full background
    local bg = frame({
        Name = "Background",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = COLOR.BG,
    }, screen)

    -- Subtle gradient overlay
    gui("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 10, 40)),
            ColorSequenceKeypoint.new(1, COLOR.BG),
        }),
        Rotation = 135,
    }, bg)

    -- Center card
    local card = frame({
        Name = "Card",
        Size = UDim2.new(0, 440, 0, 320),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLOR.SURFACE,
    }, bg)
    corner(16, card)
    stroke(COLOR.BORDER, 1, card)
    padding(32, card)

    gui("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, card)

    -- Game title
    label({
        Name = "Title",
        Text = "<b>CHROMASHIFT</b>",
        TextSize = 42,
        Font = FONT.DISPLAY,
        TextColor3 = COLOR.TEXT,
        Size = UDim2.new(1, 0, 0, 52),
        LayoutOrder = 1,
    }, card)

    -- Subtitle with accent gradient effect via RichText
    label({
        Name = "Subtitle",
        Text = '<font color="rgb(139,92,246)">Hide</font> · <font color="rgb(236,72,153)">Seek</font> · <font color="rgb(74,222,128)">Blend</font>',
        TextSize = 18,
        Font = FONT.SEMI,
        Size = UDim2.new(1, 0, 0, 24),
        LayoutOrder = 2,
    }, card)

    -- Divider
    frame({
        Size = UDim2.new(0.6, 0, 0, 1),
        BackgroundColor3 = COLOR.BORDER,
        LayoutOrder = 3,
    }, card)

    -- Player count
    label({
        Name = "PlayerCount",
        Text = "Waiting for players...",
        TextSize = 15,
        Font = FONT.BODY,
        TextColor3 = COLOR.TEXT_DIM,
        Size = UDim2.new(1, 0, 0, 22),
        LayoutOrder = 4,
    }, card)

    -- Countdown
    label({
        Name = "CountdownLabel",
        Text = "",
        TextSize = 22,
        Font = FONT.BOLD,
        TextColor3 = COLOR.WARNING,
        Size = UDim2.new(1, 0, 0, 30),
        LayoutOrder = 5,
    }, card)

    -- Pulsing dot strip (decorative)
    local dots = frame({
        Size = UDim2.new(1, 0, 0, 8),
        BackgroundTransparency = 1,
        LayoutOrder = 6,
    }, card)
    for i = 1, 5 do
        local dot = frame({
            Size = UDim2.new(0, 8, 0, 8),
            Position = UDim2.new((i - 1) * 0.22 + 0.02, 0, 0, 0),
            BackgroundColor3 = i == 3 and COLOR.ACCENT or COLOR.BORDER,
        }, dots)
        corner(4, dot)
    end

    return screen
end

-- ─── 2. VotingGui ─────────────────────────────────────────────────────────────

local function buildVotingGui()
    local screen = makeScreen("VotingGui", 2)

    local bg = frame({
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = COLOR.BG,
        BackgroundTransparency = 0.15,
    }, screen)

    -- Header bar
    local header = frame({
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 72),
        BackgroundColor3 = COLOR.SURFACE,
    }, bg)

    label({
        Text = "VOTE FOR A MAP",
        TextSize = 22,
        Font = FONT.DISPLAY,
        Size = UDim2.new(0.7, 0, 1, 0),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
    }, header)

    -- Timer pill (top right)
    local timerPill = frame({
        Name = "TimerPill",
        Size = UDim2.new(0, 80, 0, 40),
        Position = UDim2.new(1, -16, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = COLOR.SURFACE2,
    }, header)
    corner(20, timerPill)
    stroke(COLOR.ACCENT, 1, timerPill)

    label({
        Name = "TimerLabel",
        Text = "30",
        TextSize = 20,
        Font = FONT.BOLD,
        TextColor3 = COLOR.WARNING,
        Size = UDim2.fromScale(1, 1),
    }, timerPill)

    -- Cards frame
    local cardsFrame = frame({
        Name = "CardsFrame",
        Size = UDim2.new(1, -64, 1, -100),
        Position = UDim2.new(0, 32, 0, 88),
        BackgroundTransparency = 1,
    }, bg)

    gui("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 16),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, cardsFrame)

    return screen
end

-- ─── 3. HudGui ────────────────────────────────────────────────────────────────

local function buildHudGui()
    local screen = makeScreen("HudGui", 3)

    -- Full-screen blindfold (seekers during prep)
    local blindfold = frame({
        Name = "Blindfold",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        Visible = false,
        ZIndex = 10,
    }, screen)

    label({
        Text = '<b>SEEKING BEGINS SOON...</b>\n<font size="16">Eyes forward. Listen carefully.</font>',
        TextSize = 28,
        Font = FONT.DISPLAY,
        TextColor3 = COLOR.TEXT_DIM,
        Size = UDim2.fromScale(1, 1),
    }, blindfold)

    -- Top bar
    local topBar = frame({
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = COLOR.BG,
        BackgroundTransparency = 0.3,
    }, screen)

    -- Role label (left)
    local rolePill = frame({
        Name = "RolePill",
        Size = UDim2.new(0, 120, 0, 36),
        Position = UDim2.new(0, 16, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = COLOR.HIDER,
    }, topBar)
    corner(18, rolePill)

    label({
        Name = "RoleLabel",
        Text = "HIDER",
        TextSize = 14,
        Font = FONT.BOLD,
        TextColor3 = COLOR.BG,
        Size = UDim2.fromScale(1, 1),
    }, rolePill)

    -- Timer (center)
    local timerFrame = frame({
        Size = UDim2.new(0, 100, 0, 40),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLOR.SURFACE2,
    }, topBar)
    corner(8, timerFrame)

    label({
        Name = "TimerLabel",
        Text = "3:00",
        TextSize = 22,
        Font = FONT.DISPLAY,
        TextColor3 = COLOR.TEXT,
        Size = UDim2.fromScale(1, 1),
    }, timerFrame)

    -- Alive counter (right)
    local alivePill = frame({
        Size = UDim2.new(0, 130, 0, 36),
        Position = UDim2.new(1, -16, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = COLOR.SURFACE2,
    }, topBar)
    corner(18, alivePill)

    label({
        Name = "AliveLabel",
        Text = "👁  Hiders: —",
        TextSize = 13,
        Font = FONT.SEMI,
        TextColor3 = COLOR.TEXT_DIM,
        Size = UDim2.fromScale(1, 1),
    }, alivePill)

    -- Phase label (below timer, small)
    label({
        Name = "PhaseLabel",
        Text = "PREP PHASE",
        TextSize = 11,
        Font = FONT.SEMI,
        TextColor3 = COLOR.TEXT_DIM,
        Position = UDim2.new(0.5, 0, 0, 60),
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0, 200, 0, 18),
    }, screen)

    -- Crosshair (seekers only, hidden by default)
    local crosshair = frame({
        Name = "Crosshair",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Visible = false,
    }, screen)

    -- Horizontal line
    frame({
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.fromScale(0, 0.5),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.4,
    }, crosshair)

    -- Vertical line
    frame({
        Size = UDim2.new(0, 2, 1, 0),
        Position = UDim2.fromScale(0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.4,
    }, crosshair)

    -- Cooldown indicator ring (seekers) — shown as a thin arc at screen center bottom
    label({
        Name = "CooldownLabel",
        Text = "● READY",
        TextSize = 12,
        Font = FONT.SEMI,
        TextColor3 = COLOR.SUCCESS,
        Position = UDim2.new(0.5, 0, 0.5, 24),
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0, 120, 0, 18),
        Visible = false,
    }, screen)

    return screen
end

-- ─── 4. ResultGui ─────────────────────────────────────────────────────────────

local function buildResultGui()
    local screen = makeScreen("ResultGui", 5)

    local bg = frame({
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = COLOR.BG,
        BackgroundTransparency = 0.2,
    }, screen)

    local card = frame({
        Name = "ResultCard",
        Size = UDim2.new(0, 480, 0, 340),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = COLOR.SURFACE,
    }, bg)
    corner(20, card)
    stroke(COLOR.BORDER, 1, card)

    gui("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, card)
    padding(28, card)

    label({
        Name = "WinLabel",
        Text = "YOU WIN!",
        TextSize = 52,
        Font = FONT.DISPLAY,
        TextColor3 = COLOR.SUCCESS,
        Size = UDim2.new(1, 0, 0, 64),
        LayoutOrder = 1,
    }, card)

    label({
        Name = "SubLabel",
        Text = "Hiders survived the round",
        TextSize = 16,
        Font = FONT.BODY,
        TextColor3 = COLOR.TEXT_DIM,
        Size = UDim2.new(1, 0, 0, 22),
        LayoutOrder = 2,
    }, card)

    frame({
        Size = UDim2.new(0.5, 0, 0, 1),
        BackgroundColor3 = COLOR.BORDER,
        LayoutOrder = 3,
    }, card)

    -- XP row
    local xpRow = frame({
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = COLOR.SURFACE2,
        LayoutOrder = 4,
    }, card)
    corner(8, xpRow)

    label({
        Name = "XPLabel",
        Text = "+0 XP",
        TextSize = 18,
        Font = FONT.BOLD,
        TextColor3 = COLOR.WARNING,
        Size = UDim2.fromScale(1, 1),
    }, xpRow)

    -- Next round countdown
    label({
        Name = "NextLabel",
        Text = "Next round in 15...",
        TextSize = 13,
        Font = FONT.BODY,
        TextColor3 = COLOR.TEXT_DIM,
        Size = UDim2.new(1, 0, 0, 20),
        LayoutOrder = 5,
    }, card)

    return screen
end

-- ─── 5. NotifGui (Kill Feed) ──────────────────────────────────────────────────

local function buildNotifGui()
    local screen = makeScreen("NotifGui", 4)
    screen.Enabled = true  -- always on, feed is just empty when idle

    local killFeed = frame({
        Name = "KillFeed",
        Size = UDim2.new(0, 280, 0, 200),
        Position = UDim2.new(1, -12, 0.5, -100),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
    }, screen)

    gui("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, killFeed)

    return screen
end

-- ─── 6. OverlayGui (Map Transition) ──────────────────────────────────────────

local function buildOverlayGui()
    local screen = makeScreen("OverlayGui", 10)

    local transitionFrame = frame({
        Name = "TransitionFrame",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = COLOR.BG,
        BackgroundTransparency = 1,
        Visible = false,
    }, screen)

    gui("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 12),
    }, transitionFrame)

    label({
        Text = "CHROMASHIFT",
        TextSize = 32,
        Font = FONT.DISPLAY,
        TextColor3 = COLOR.ACCENT,
        Size = UDim2.new(1, 0, 0, 40),
    }, transitionFrame)

    label({
        Name = "MapNameLabel",
        Text = "Loading map...",
        TextSize = 18,
        Font = FONT.BODY,
        TextColor3 = COLOR.TEXT_DIM,
        Size = UDim2.new(1, 0, 0, 28),
    }, transitionFrame)

    -- Loading bar
    local barBg = frame({
        Size = UDim2.new(0, 240, 0, 4),
        BackgroundColor3 = COLOR.SURFACE2,
    }, transitionFrame)
    corner(2, barBg)

    local barFill = frame({
        Name = "BarFill",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = COLOR.ACCENT,
    }, barBg)
    corner(2, barFill)

    -- Animate the bar fill
    task.spawn(function()
        while true do
            task.wait(0.016)
            if transitionFrame.Visible then
                local t = (tick() % 1.2) / 1.2
                barFill.Size = UDim2.new(t, 0, 1, 0)
            end
        end
    end)

    return screen
end

-- ─── Build all GUIs ──────────────────────────────────────────────────────────

local UIBuilder = {}

function UIBuilder.BuildAll()
    buildLobbyGui()
    buildVotingGui()
    buildHudGui()
    buildResultGui()
    buildNotifGui()
    buildOverlayGui()
    print("[UIBuilder] All GUIs created.")
end

return UIBuilder
