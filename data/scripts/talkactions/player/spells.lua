local spellbookItemId = 2175

local groupOrder = {attack = 1, healing = 2, support = 3, none = 4}

local function trim(str)
	return str:match("^%s*(.-)%s*$")
end

local function formatSpell(spell)
	local words = spell.words
	if spell.params > 0 then
		words = words .. ' "..."'
	end

	local cost
	if spell.manapercent > 0 then
		cost = spell.manapercent .. "% mana"
	else
		cost = spell.mana .. " mana"
	end
	if spell.soul and spell.soul > 0 then
		cost = cost .. ", " .. spell.soul .. " soul"
	end

	return string.format("%-22s %-22s lvl %-3d %s", words, spell.name,
	                     spell.level, cost)
end

local function buildLines(header, spells)
	local lines = {header}
	table.sort(spells, function(a, b)
		if a.level ~= b.level then return a.level < b.level end
		if groupOrder[a.group] ~= groupOrder[b.group] then
			return (groupOrder[a.group] or 99) < (groupOrder[b.group] or 99)
		end
		return a.name < b.name
	end)

	for _, spell in ipairs(spells) do
		lines[#lines + 1] = formatSpell(spell)
	end
	return lines
end

local spells = TalkAction("!spells")

function spells.onSay(player, words, param)
	param = trim(param or ""):lower()

	local showAll = false
	local filterGroup = nil
	if param == "all" then
		showAll = true
	elseif param == "attack" or param == "healing" or param == "support" then
		filterGroup = param
	elseif param ~= "" then
		player:sendTextMessage(MESSAGE_INFO_DESCR,
		                       "Usage: !spells, !spells all, !spells attack|healing|support")
		return false
	end

	local playerLevel = player:getLevel()
	local usable, locked = {}, {}
	for _, spell in ipairs(player:getInstantSpells()) do
		if spell.level > 0 and (not filterGroup or spell.group == filterGroup) then
			if spell.level <= playerLevel then
				usable[#usable + 1] = spell
			else
				locked[#locked + 1] = spell
			end
		end
	end

	local title = ("%s - level %d"):format(player:getVocation():getName(),
	                                      playerLevel)
	if filterGroup then
		title = title .. (" (%s spells)"):format(filterGroup)
	end

	local lines = {}
	table.insert(lines, title)
	table.insert(lines, "")

	local usableLines = buildLines(("Usable now (%d)"):format(#usable), usable)
	for _, line in ipairs(usableLines) do
		lines[#lines + 1] = line
	end

	if showAll and #locked > 0 then
		lines[#lines + 1] = ""
		local lockedLines = buildLines(("Locked by level (%d)"):format(#locked),
		                               locked)
		for _, line in ipairs(lockedLines) do
			lines[#lines + 1] = line
		end
	end

	if #usable == 0 and (not showAll or #locked == 0) then
		lines[#lines + 1] = "No spells found."
	end

	if not showAll and #locked > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = ("%d more known spell(s) - type !spells all"):format(
		                        #locked)
	end

	player:showTextDialog(spellbookItemId, table.concat(lines, "\n"))
	return false
end

spells:register()
