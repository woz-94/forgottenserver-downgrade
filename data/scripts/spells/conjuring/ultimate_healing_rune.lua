local spell = Spell(SPELL_INSTANT)
spell:name("Ultimate Healing Rune")
spell:words("adura vita")
spell:group("support")
spell:vocation("Druid", "Elder Druid")
spell:level(24)
spell:mana(400)
spell:soul(3)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2273, 1)
end

spell:register()
