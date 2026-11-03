-- Mobile store: a player-owned shop window that uses the standard NPC trade
-- packets, but does not depend on an NPC.  The catalog is the static table in
-- data/scripts/lib/mobile_store_catalog.lua; edit that file for new items.
MobileStore = MobileStore or {}

local PAGE_SIZE = 200

local function rebuildIndex()
	MobileStore.items = {}
	MobileStore.byId = {}

	for _, entry in ipairs(MobileStoreCatalog or {}) do
		local item = {
			id = entry.id,
			subType = entry.subType or 0,
			buy = entry.buy or 0,
			sell = entry.sell or 0,
			name = entry.name or ("item " .. tostring(entry.id))
		}
		MobileStore.items[#MobileStore.items + 1] = item
		MobileStore.byId[item.id] = item
	end

	table.sort(MobileStore.items, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
end

local function getEntry(itemId)
	if not MobileStore.byId then
		rebuildIndex()
	end
	return MobileStore.byId[itemId]
end

local function fail(player, text)
	player:sendCancelMessage(text)
	return false
end

local function success(player, text)
	player:sendTextMessage(MESSAGE_INFO_DESCR, text)
	return true
end

function MobileStore.open(player, param)
	if not MobileStore.byId then
		rebuildIndex()
	end

	param = tostring(param or ""):match("^%s*(.-)%s*$")
	local page = 1
	local filter = nil
	local pageNumber = tonumber(param)
	if pageNumber then
		page = math.max(1, math.floor(pageNumber))
	elseif param ~= "" then
		filter = param:lower()
	end

	local matching = {}
	for _, entry in ipairs(MobileStore.items) do
		if not filter or entry.name:lower():find(filter, 1, true) then
			matching[#matching + 1] = entry
		end
	end

	if #matching == 0 then
		return fail(player, filter and ("No items match '" .. param .. "'.") or "The store has no items.")
	end

	local pages = math.max(1, math.ceil(#matching / PAGE_SIZE))
	page = math.min(page, pages)
	local first = (page - 1) * PAGE_SIZE + 1
	local last = math.min(#matching, first + PAGE_SIZE - 1)

	local items = {}
	for index = first, last do
		local entry = matching[index]
		items[#items + 1] = {
			id = entry.id,
			subType = entry.subType,
			buy = entry.buy,
			sell = entry.sell,
			name = entry.name
		}
	end

	local detail
	if filter then
		detail = string.format("%d match(es)", #matching)
	else
		detail = string.format("%d item(s)", #matching)
	end
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,
		string.format("Mobile store: %s, page %d/%d. Use !store <page> or !store <name>.", detail, page, pages))

	player:openShopWindow(items, MobileStore.onBuy, MobileStore.onSell)
	return true
end

function MobileStore.onBuy(player, itemId, count, amount, ignoreCapacity, inBackpacks)
	local entry = getEntry(itemId)
	if not entry or entry.buy <= 0 then
		return false
	end

	amount = math.max(1, math.min(100, amount or 1))
	local itemType = ItemType(itemId)
	if not itemType then
		return false
	end

	local total = entry.buy * amount
	if inBackpacks then
		local backpackCapacity = ItemType(1988):getCapacity()
		if itemType:isStackable() then
			total = total + 20
		else
			total = total + math.max(1, math.floor(amount / (backpackCapacity > 0 and backpackCapacity or 20))) * 20
		end
	end

	if player:getTotalMoney() < total then
		return fail(player, "You do not have enough money.")
	end

	if not ignoreCapacity and player:getFreeCapacity() < itemType:getWeight() * amount then
		return fail(player, "You do not have enough capacity.")
	end

	local added
	if itemType:isFluidContainer() or itemType:isSplash() then
		added = player:addItem(itemId, amount, false, entry.subType)
	else
		added = player:addItem(itemId, amount, false)
	end

	if not added then
		return fail(player, "You do not have enough room.")
	end

	if not player:removeTotalMoney(total) then
		if itemType:isFluidContainer() or itemType:isSplash() then
			player:removeItem(itemId, amount, entry.subType)
		else
			player:removeItem(itemId, amount)
		end
		return fail(player, "You do not have enough money.")
	end

	return success(player, string.format("You bought %d %s for %d gold.", amount, entry.name, total))
end

function MobileStore.onSell(player, itemId, count, amount, ignoreEquipped)
	local entry = getEntry(itemId)
	if not entry or entry.sell <= 0 then
		return false
	end

	amount = math.max(1, math.min(100, amount or 1))
	local itemType = ItemType(itemId)
	local subType = -1
	if itemType and itemType:isFluidContainer() then
		subType = count
	end

	if not player:removeItem(itemId, amount, subType, ignoreEquipped) then
		return fail(player, "You do not have that item.")
	end

	local total = entry.sell * amount
	player:addMoney(total)
	return success(player, string.format("You sold %d %s for %d gold.", amount, entry.name, total))
end
