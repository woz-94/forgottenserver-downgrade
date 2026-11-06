-- Fallback for levers/mechanisms/switches that have an action/unique id but no
-- script in this datapack. When used, open nearby closed doors and gates.
-- Scripted levers keep priority: TFS resolves unique id, then action id, then
-- item id, so this only runs when the specific script is missing.

local closedToOpen = {}

local function addPairs(list, delta)
	for _, id in ipairs(list) do
		closedToOpen[id] = id + delta
	end
end

addPairs(closedDoors, 1)
addPairs(lockedDoors, 2)
addPairs(closedExtraDoors, 1)
addPairs(closedHouseDoors, 1)
addPairs(closedQuestDoors, 1)
addPairs(closedLevelDoors, 1)

-- Yalahar / custom gate pair.
closedToOpen[9532] = 9533

local leverIds = {
	1945, 1946,
	5505, 5506, 5507, 5508, 5509, 5510, 5511, 5512,
	9531, 9534,
	9825, 9826, 9827, 9828,
	10029, 10030, 10044, 10045,
	11062, 11063,
	20220, 20221, 20223, 20224, 20225,
	23062, 23063, 23064, 23065, 23066, 23067,
	23076, 23077, 23078, 23079,
	23151, 23152, 23153, 23154, 23158, 23159,
	23415, 23416, 23423, 23430,
	23496, 23497, 23498, 23499, 23500, 23501, 23502, 23503,
	23519, 23522, 23661,
	24127, 24161, 24190, 24191, 24194,
	33158, 33181, 33182,
	35243, 35244, 35245, 35246, 35247, 35248, 35249, 35250,
}

local RADIUS = 8

local mechanism = Action()

function mechanism.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local position = item:getPosition()
	local opened = false

	for dx = -RADIUS, RADIUS do
		for dy = -RADIUS, RADIUS do
			for dz = -1, 1 do
				local tile = Tile(Position(position.x + dx, position.y + dy, position.z + dz))
				local things = tile and tile:getItems()
				if things then
					for _, thing in ipairs(things) do
						local openId = closedToOpen[thing:getId()]
						if openId then
							thing:transform(openId)
							opened = true
						end
					end
				end
			end
		end
	end

	if opened then
		position:sendMagicEffect(CONST_ME_POFF)
	end
	return true
end

for _, id in ipairs(leverIds) do
	mechanism:id(id)
end
mechanism:register()
