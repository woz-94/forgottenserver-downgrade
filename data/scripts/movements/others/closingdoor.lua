local closingDoor = MoveEvent()
closingDoor:type("stepout")

function closingDoor.onStepOut(creature, item, position, fromPosition)
    local tile = Tile(position)
    if tile:getCreatureCount() > 0 then
        return true
    end

    local newPosition = {x = position.x + 1, y = position.y, z = position.z}
    local query = Tile(newPosition):queryAdd(creature)
    if query ~= RETURNVALUE_NOERROR or query == RETURNVALUE_NOTENOUGHROOM then
        newPosition.x = newPosition.x - 1
        newPosition.y = newPosition.y + 1
        query = Tile(newPosition):queryAdd(creature)
    end

    if query == RETURNVALUE_NOERROR or query ~= RETURNVALUE_NOTENOUGHROOM then
        doRelocate(position, newPosition)
    end

    local i, tileItem, tileCount = 1, true, tile:getThingCount()
    while tileItem and i < tileCount do
        tileItem = tile:getThing(i)
        if tileItem and tileItem:getUniqueId() ~= item.uid and tileItem:getType():isMovable() then
            tileItem:remove()
        else
            i = i + 1
        end
    end

    item:transform(item.itemid - 1)
    return true
end

-- Closing doors (open doors that close when stepped out). Regular and house
-- doors stay open; only experienced/quest doors auto-close.
local openDoorTables = {openQuestDoors, openLevelDoors}
local closingDoorIds = {}
for _, doors in ipairs(openDoorTables) do
    for _, doorId in ipairs(doors) do
        if not closingDoorIds[doorId] then
            closingDoorIds[doorId] = true
            closingDoor:id(doorId)
        end
    end
end
closingDoor:register()

