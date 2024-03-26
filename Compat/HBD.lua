local mapData = QuestieCompat.UiMapData -- table { width, height, left, top, .instance, .name, .mapType }

-- data for the azeroth world map
-- table { width, height, left, top }
local worldMapData = {
    [0] = { 48033.24, 32020.8, 36867.97, 14848.84 },
    [1] = { 47908.72, 31935.28, 8552.61, 18467.83 },
    [571] = { 47662.7, 31772.19, 25198.53, 11072.07 },
}

local HBD = {}
QuestieCompat.HBD = HBD

--- Convert local/point coordinates to world coordinates in yards
-- @param x X position in 0-1 point coordinates
-- @param y Y position in 0-1 point coordinates
-- @param zone uiMapID of the zone
function HBD:GetWorldCoordinatesFromZone(x, y, zone)
    local data = mapData[zone]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil, nil end
    if not x or not y then return nil, nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = left - width * x, top - height * y

    return x, y, data.instance
end

--- Convert world coordinates to local/point zone coordinates
-- @param x Global X position
-- @param y Global Y position
-- @param zone uiMapID of the zone
-- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
function HBD:GetZoneCoordinatesFromWorld(x, y, zone, allowOutOfBounds)
    local data = mapData[zone]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil end
    if not x or not y then return nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = (left - x) / width, (top - y) / height

    -- verify the coordinates fall into the zone
    if not allowOutOfBounds and (x < 0 or x > 1 or y < 0 or y > 1) then return nil, nil end

    return x, y
end

--- Convert world coordinates to local/point zone coordinates on the azeroth world map
-- @param x Global X position
-- @param y Global Y position
-- @param instance Instance to translate coordinates from
-- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
function HBD:GetAzerothWorldMapCoordinatesFromWorld(x, y, instance, allowOutOfBounds)
    local data = worldMapData[instance]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil end
    if not x or not y then return nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = (left - x) / width, (top - y) / height

    -- verify the coordinates fall into the zone
    if not allowOutOfBounds and (x < 0 or x > 1 or y < 0 or y > 1) then return nil, nil end

    return x, y
end

--- Return the distance from an origin position to a destination position in the same instance/continent.
-- @param instanceID instance ID
-- @param oX origin X
-- @param oY origin Y
-- @param dX destination X
-- @param dY destination Y
-- @return distance, deltaX, deltaY
function HBD:GetWorldDistance(instanceID, oX, oY, dX, dY)
    if not oX or not oY or not dX or not dY then return nil, nil, nil end
    local deltaX, deltaY = dX - oX, dY - oY
    return (deltaX * deltaX + deltaY * deltaY)^0.5, deltaX, deltaY
end

--- Return the distance between two points on the same continent
-- @param oZone origin zone uiMapID
-- @param oX origin X, in local zone/point coordinates
-- @param oY origin Y, in local zone/point coordinates
-- @param dZone destination zone uiMapID
-- @param dX destination X, in local zone/point coordinates
-- @param dY destination Y, in local zone/point coordinates
-- @return distance, deltaX, deltaY in yards
function HBD:GetZoneDistance(oZone, oX, oY, dZone, dX, dY)
    local oInstance, dInstance
    oX, oY, oInstance = self:GetWorldCoordinatesFromZone(oX, oY, oZone)
    if not oX then return nil, nil, nil end

    -- translate dX, dY to the origin zone
    dX, dY, dInstance = self:GetWorldCoordinatesFromZone(dX, dY, dZone)
    if not dX then return nil, nil, nil end

    if oInstance ~= dInstance then return nil, nil, nil end

    return self:GetWorldDistance(oInstance, oX, oY, dX, dY)
end

--- Get the current world position of the player
-- The position is transformed to the current continent, if applicable
-- @return x, y, instanceID
function HBD:GetPlayerWorldPosition()
    local x, y, uiMapID = HBD:GetPlayerZonePosition()
    if not x or not y then return nil, nil, nil end

    x, y, instanceID = HBD:GetWorldCoordinatesFromZone(x, y, uiMapID)
    if x and y then
        return x, y, instanceID
    end
    return nil, nil, nil
end

--- Get the current zone and level of the player
-- The returned mapFile can represent a micro dungeon, if the player currently is inside one.
-- @return uiMapID, mapType
function HBD:GetPlayerZone()
    return QuestieCompat.GetCurrentPlayerPosition()
end

--- Get the current position of the player on a zone level
-- The returned values are local point coordinates, 0-1. The mapFile can represent a micro dungeon.
-- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
-- @return x, y, uiMapID, mapType
function HBD:GetPlayerZonePosition(allowOutOfBounds)
    -- get the current position
    local uiMapID, x, y = QuestieCompat.GetCurrentPlayerPosition()

    if uiMapID and x and y then
        return x, y, uiMapID
    end
    return nil, nil, nil, nil
end