-- Yalahar quarter gate mechanisms (Alchemist Quarter entrance).
-- Each mechanism opens the gate on its side of the corridor.
local gatePositions = {
	[51157] = {
		Position(32774, 31115, 7),
		Position(32774, 31116, 7),
	},
	[51158] = {
		Position(32779, 31115, 7),
		Position(32779, 31116, 7),
		Position(32779, 31117, 7),
	},
}

local mechanism = Action()

function mechanism.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local positions = gatePositions[item.actionid]
	if not positions then
		return false
	end

	for _, position in ipairs(positions) do
		local tile = Tile(position)
		local gate = tile and tile:getItemById(9532)
		if gate then
			gate:transform(9533)
			position:sendMagicEffect(CONST_ME_POFF)
		end
	end
	return true
end

mechanism:aid(51157, 51158)
mechanism:register()
