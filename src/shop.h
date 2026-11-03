// Copyright 2023 The Forgotten Server Authors. All rights reserved.
// Use of this source code is governed by the GPL-2.0 License that can be found in the LICENSE file.

#ifndef FS_SHOP_H
#define FS_SHOP_H

#include <cstdint>

class LuaScriptInterface;
class Player;

/**
 * A shop window owner.  NPCs implement this through their Lua callbacks, and
 * player-owned shops (the mobile store) implement it with callbacks in the
 * Scripts interface.
 */
class ShopOwner
{
public:
	virtual ~ShopOwner() = default;

	virtual void onPlayerTrade(Player* player, int32_t callback, uint16_t itemId, uint8_t count, uint8_t amount,
	                           bool ignore = false, bool inBackpacks = false) = 0;
	virtual void onPlayerEndTrade(Player* player, int32_t buyCallback, int32_t sellCallback) = 0;
};

class LuaShopOwner final : public ShopOwner
{
public:
	explicit LuaShopOwner(LuaScriptInterface* interface) : interface(interface) {}

	void onPlayerTrade(Player* player, int32_t callback, uint16_t itemId, uint8_t count, uint8_t amount,
	                   bool ignore = false, bool inBackpacks = false) override;
	void onPlayerEndTrade(Player* player, int32_t buyCallback, int32_t sellCallback) override;

private:
	LuaScriptInterface* interface;
};

#endif // FS_SHOP_H
