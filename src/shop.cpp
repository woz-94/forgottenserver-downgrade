// Copyright 2023 The Forgotten Server Authors. All rights reserved.
// Use of this source code is governed by the GPL-2.0 License that can be found in the LICENSE file.

#include "otpch.h"

#include "shop.h"

#include "luascript.h"
#include "player.h"

void LuaShopOwner::onPlayerTrade(Player* player, int32_t callback, uint16_t itemId, uint8_t count, uint8_t amount,
                                 bool ignore, bool inBackpacks)
{
	if (!interface || callback == -1) {
		return;
	}

	// onBuy/onSell(player, itemid, count, amount, ignore, inbackpacks)
	if (!interface->reserveScriptEnv()) {
		std::cout << "[Error - LuaShopOwner::onPlayerTrade] Call stack overflow" << std::endl;
		return;
	}

	ScriptEnvironment* env = interface->getScriptEnv();
	env->setScriptId(-1, interface);

	lua_State* L = interface->getLuaState();
	Lua::pushCallback(L, callback);
	Lua::pushUserdata<Player>(L, player);
	Lua::setMetatable(L, -1, "Player");
	lua_pushinteger(L, itemId);
	lua_pushinteger(L, count);
	lua_pushinteger(L, amount);
	Lua::pushBoolean(L, ignore);
	Lua::pushBoolean(L, inBackpacks);
	interface->callVoidFunction(6);

	player->sendSaleItemList();
}

void LuaShopOwner::onPlayerEndTrade(Player*, int32_t buyCallback, int32_t sellCallback)
{
	if (!interface) {
		return;
	}

	lua_State* L = interface->getLuaState();
	if (buyCallback != -1) {
		luaL_unref(L, LUA_REGISTRYINDEX, buyCallback);
	}
	if (sellCallback != -1) {
		luaL_unref(L, LUA_REGISTRYINDEX, sellCallback);
	}
}
