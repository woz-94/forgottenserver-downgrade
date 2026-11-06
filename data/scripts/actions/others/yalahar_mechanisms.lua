-- Yalahar city gate mechanisms.
--
-- The pair mechanisms at z=5 teleport the player through the quarter wall.
-- Normally they require the In Service of Yalahar questline; here they are
-- always usable. The z=7 mechanisms open the Alchemist Quarter gate.

local teleports = {
	[51151] = Position(32729, 31200, 5),
	[51152] = Position(32734, 31200, 5),
	[51153] = Position(32744, 31161, 5),
	[51154] = Position(32744, 31164, 5),
	[51155] = Position(32776, 31141, 5),
	[51156] = Position(32776, 31145, 5),
	[51159] = Position(32874, 31202, 5),
	[51160] = Position(32869, 31202, 5),
	[51161] = Position(32855, 31252, 5),
	[51162] = Position(32853, 31248, 5),
	[51163] = Position(32834, 31269, 5),
	[51164] = Position(32833, 31266, 5),
}

local gates = {
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
	local destination = teleports[item.actionid]
	if destination then
		local from = player:getPosition()
		from:sendMagicEffect(CONST_ME_TELEPORT)
		player:teleportTo(destination)
		destination:sendMagicEffect(CONST_ME_TELEPORT)
		return true
	end

	local positions = gates[item.actionid]
	if positions then
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

	return false
end

for aid in pairs(teleports) do
	mechanism:aid(aid)
end
for aid in pairs(gates) do
	mechanism:aid(aid)
end
mechanism:register()
