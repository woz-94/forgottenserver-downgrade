local store = TalkAction("!store")

function store.onSay(player, words, param)
	if player:hasCondition(CONDITION_INFIGHT) then
		player:sendCancelMessage("You cannot use the store while in combat.")
		return false
	end

	MobileStore.open(player, param)
	return false
end

store:separator(" ")
store:register()
