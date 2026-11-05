local store = TalkAction("!store")

function store.onSay(player, words, param)
	MobileStore.open(player, param)
	return false
end

store:separator(" ")
store:register()
