--[[
    MapConfigs.lua
    Every playable map is registered here.
    To add a new map: duplicate one entry, give it a unique Id,
    and make sure the matching map folder exists under /maps/.

    The map folder structure (built in Roblox Studio, exported via Rojo):
        maps/ForestHideout/
            Map.rbxmx        -- the actual Studio model
            Thumbnail.png    -- shown in voting UI (upload separately)
]]

local Types = require(script.Parent.Types)

-- Convenience so Luau gives us type checking on each config entry
type MapConfig = Types.MapConfig

local MapConfigs: { [string]: MapConfig } = {

    ForestHideout = {
        Id             = "ForestHideout",
        DisplayName    = "Forest Hideout",
        Description    = "Dense canopy and mossy rocks — green blends rule here.",
        MinPlayers     = 2,
        MaxPlayers     = 12,
        SeekerCount    = 1,
        RoundDuration  = 180,
        PrepDuration   = 60,
        ThumbnailAssetId = "rbxassetid://0",  -- replace with real asset ID after upload
    },

    UrbanJungle = {
        Id             = "UrbanJungle",
        DisplayName    = "Urban Jungle",
        Description    = "Concrete walls and neon signs — gray and cyan dominate.",
        MinPlayers     = 4,
        MaxPlayers     = 20,
        SeekerCount    = 2,
        RoundDuration  = 240,
        PrepDuration   = 75,
        ThumbnailAssetId = "rbxassetid://0",
    },

}

-- Returns an array of all map configs (used by VotingService to pick candidates)
function MapConfigs.GetAll(): { MapConfig }
    local result = {}
    for _, config in MapConfigs do
        if type(config) == "table" then
            table.insert(result, config)
        end
    end
    return result
end

-- Returns configs that support a given player count
function MapConfigs.GetEligible(playerCount: number): { MapConfig }
    local result = {}
    for _, config in MapConfigs.GetAll() do
        if playerCount >= config.MinPlayers and playerCount <= config.MaxPlayers then
            table.insert(result, config)
        end
    end
    return result
end

return MapConfigs
