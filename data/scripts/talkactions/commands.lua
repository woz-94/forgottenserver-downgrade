-- In-game command list, in the spirit of !spells: only the commands the
-- player can actually use, grouped by the access they require, with a short
-- summary on the same line.
--
-- Talk actions carry no text of their own, so the descriptions live in the
-- catalogue below. A talk action that is missing here still shows up (with a
-- placeholder) and the server logs which word is undocumented, so a stale
-- entry can never hide a working command.

local dialogItemId = 1950

local accessTitles = {
	[ACCOUNT_TYPE_NORMAL] = "Player",
	[ACCOUNT_TYPE_TUTOR] = "Tutor",
	[ACCOUNT_TYPE_SENIORTUTOR] = "Senior Tutor",
	[ACCOUNT_TYPE_GAMEMASTER] = "Gamemaster",
	[ACCOUNT_TYPE_COMMUNITYMANAGER] = "Community Manager",
	[ACCOUNT_TYPE_GOD] = "God"
}

-- words: the form shown in game. aliases: every other word the same talk
-- action was registered with (the engine only reports the last one).
local catalogue = {
	-- Public commands
	{words = "!buyhouse", desc = "Buy the house you are facing."},
	{words = "!buypremium", desc = "Buy premium days with gold."},
	{words = "!changesex", desc = "Change your character's sex."},
	{words = "!commands", aliases = {"/commands"}, usage = "[all|filter]",
	 desc = "Show the commands you can use."},
	{words = "!deathlist", usage = "<player>", desc = "Show a player's recent deaths."},
	{words = "!kills", desc = "Show your unjustified kills."},
	{words = "!leavehouse", desc = "Give up the house you own."},
	{words = "!online", aliases = {"/online"}, desc = "List the players online."},
	{words = "!sellhouse", usage = "<player>", desc = "Transfer your house to a player."},
	{words = "!serverinfo", desc = "Show server rates and settings."},
	{words = "!spells", usage = "[all|group]", desc = "List your spells."},
	{words = "!store", usage = "[page|name]", desc = "Open the mobile store."},
	{words = "!uptime", desc = "Show how long the server has been up."},

	-- Access commands
	{words = "/addskill", usage = "<player>, <skill>[, n]", desc = "Add skill points to a player."},
	{words = "/addtutor", usage = "<player>", desc = "Promote a player to tutor."},
	{words = "/attr", usage = "<attribute>, <value>", desc = "Set an attribute on the thing in front."},
	{words = "/ban", usage = "<player>[, reason]", desc = "Ban a player's account."},
	{words = "/B", usage = "<text>", desc = "Broadcast a message to everyone."},
	{words = "/chameleon", usage = "<item>", desc = "Take the appearance of an item."},
	{words = "/clean", desc = "Remove loose items from the map."},
	{words = "/cliport", desc = "Toggle cliport mode."},
	{words = "/closeserver", usage = "[reason]", desc = "Block new logins."},
	{words = "/i", usage = "<item>[, count[, n]]", desc = "Create an item."},
	{words = "/down", desc = "Go down one floor."},
	{words = "/up", desc = "Go up one floor."},
	{words = "/raid", usage = "<name>", desc = "Start a raid by name."},
	{words = "/ghost", desc = "Toggle ghost mode."},
	{words = "/hide", desc = "Toggle hidden health and mana."},
	{words = "/info", usage = "<player>", desc = "Show a player's details."},
	{words = "/ipban", usage = "<player>", desc = "Ban a player's IP address."},
	{words = "/kick", usage = "<player>", desc = "Disconnect a player."},
	{words = "/looktype", usage = "<id>", desc = "Change your look type."},
	{words = "/mccheck", desc = "List players sharing an IP."},
	{words = "/openserver", desc = "Allow new logins again."},
	{words = "/owner", usage = "[player|none]", desc = "Set or clear the house owner."},
	{words = "/m", usage = "<monster>", desc = "Create a monster."},
	{words = "/s", usage = "<npc>", desc = "Create an NPC."},
	{words = "/summon", usage = "<monster>", desc = "Create a monster and summon it."},
	{words = "/reload", usage = "<type>", desc = "Reload scripts and data."},
	{words = "/removetutor", usage = "<player>", desc = "Demote a tutor to player."},
	{words = "/r", desc = "Remove the thing you are facing."},
	{words = "/c", usage = "<creature>", desc = "Teleport a creature to you."},
	{words = "/t", desc = "Teleport to your home temple."},
	{words = "/a", usage = "<n>", desc = "Teleport n tiles forward."},
	{words = "/goto", usage = "<creature>", desc = "Teleport to a creature."},
	{words = "/town", usage = "<name|id>", desc = "Teleport to a town temple."},
	{words = "/pos", aliases = {"!pos"}, usage = "[x,y,z]", desc = "Show your position or teleport."},
	{words = "/unban", usage = "<player>", desc = "Lift bans from an account or IP."},

	-- Test commands
	{words = "!x", usage = "<effect id>", desc = "Test: draw distance effects."},
	{words = "!z", usage = "<effect id>", desc = "Test: draw a magic effect."}
}

local byWord = {}
for _, entry in ipairs(catalogue) do
	byWord[entry.words:lower()] = entry
	for _, alias in ipairs(entry.aliases or {}) do
		byWord[alias:lower()] = entry
	end
end

local warned = {}
local function resolve(word)
	local entry = byWord[word:lower()]
	if entry then
		return entry
	end

	if not warned[word] then
		warned[word] = true
		print("[!commands] no catalogue entry for '" .. word .. "'.")
	end
	return {words = word, desc = "No description yet."}
end

local function trim(str)
	return str:match("^%s*(.-)%s*$")
end

local function canUse(player, talkaction)
	if talkaction:access() and not player:getGroup():getAccess() then
		return false
	end
	return player:getAccountType() >= talkaction:accountType()
end

-- Sort key and section title for a command, based on what it requires.
local function groupOf(talkaction)
	if not talkaction:access() then
		return 0, "Player"
	end

	local accountType = talkaction:accountType()
	if accountType <= ACCOUNT_TYPE_NORMAL then
		return 1, "Access Player"
	end
	return accountType, accessTitles[accountType] or "Access"
end

local function columnOf(item)
	if item.usage then
		return item.words .. " " .. item.usage
	end
	return item.words
end

local function sortItems(items)
	table.sort(items, function(a, b)
		if a.group ~= b.group then return a.group < b.group end
		return a.words:lower() < b.words:lower()
	end)
end

local function buildSections(items, prefix)
	local sections = {}
	local current = nil
	for _, item in ipairs(items) do
		if not current or current.group ~= item.group then
			current = {group = item.group, title = (prefix or "") .. item.title,
			           items = {}}
			sections[#sections + 1] = current
		end
		current.items[#current.items + 1] = item
	end
	return sections
end

local commands = TalkAction("!commands", "/commands")

function commands.onSay(player, words, param)
	param = trim(param or ""):lower()

	local showAll = false
	local filter = nil
	if param == "all" then
		showAll = true
	elseif param ~= "" then
		filter = param
	end

	local usable, locked = {}, {}
	local seen = {}
	for _, talkaction in ipairs(Game.getTalkActions()) do
		local word = talkaction:getWords()
		local entry = word and resolve(word)
		local key = entry and entry.words:lower()
		if key and not seen[key] then
			seen[key] = true

			local haystack = (entry.words .. " " .. (entry.usage or "") .. " " ..
			                     entry.desc):lower()
			if not filter or haystack:find(filter, 1, true) then
				local group, title = groupOf(talkaction)
				local item = {words = entry.words, usage = entry.usage,
				              desc = entry.desc, group = group, title = title}
				if canUse(player, talkaction) then
					usable[#usable + 1] = item
				else
					locked[#locked + 1] = item
				end
			end
		end
	end

	sortItems(usable)
	sortItems(locked)

	local width = 16
	for _, item in ipairs(usable) do
		width = math.max(width, #columnOf(item))
	end
	for _, item in ipairs(locked) do
		width = math.max(width, #columnOf(item))
	end
	width = math.min(width, 32)
	local format = "%-" .. width .. "s %s"

	local accountType = player:getAccountType()
	local myTitle = "Player"
	if player:getGroup():getAccess() then
		myTitle = accessTitles[accountType] or "Player"
	end

	local lines = {}
	lines[#lines + 1] = ("Commands - %s (%d available)"):format(myTitle, #usable)
	if filter then
		lines[#lines + 1] = ("Filter: %s"):format(filter)
	end

	local function addSections(sections)
		for _, section in ipairs(sections) do
			lines[#lines + 1] = ""
			lines[#lines + 1] = ("%s (%d)"):format(section.title, #section.items)
			for _, item in ipairs(section.items) do
				lines[#lines + 1] = string.format(format, columnOf(item), item.desc)
			end
		end
	end

	addSections(buildSections(usable))

	local showLocked = showAll or filter ~= nil
	if showLocked and #locked > 0 then
		addSections(buildSections(locked, "Locked - requires "))
	end

	if #usable == 0 and (#locked == 0 or not showLocked) then
		lines[#lines + 1] = ""
		if filter then
			lines[#lines + 1] = ("No commands match '%s'."):format(filter)
		else
			lines[#lines + 1] = "No commands found."
		end
	elseif not showLocked and #locked > 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = ("%d more command(s) need higher access - type !commands all"):format(
		                        #locked)
	end

	player:showTextDialog(dialogItemId, table.concat(lines, "\n"))
	return false
end

commands:separator(" ")
commands:register()
