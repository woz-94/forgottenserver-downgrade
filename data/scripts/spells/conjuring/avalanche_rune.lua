local spell = Spell(SPELL_INSTANT)
spell:name("Avalanche")
spell:words("adori mas frigo")
spell:group("support")
spell:vocation("Druid", "Elder Druid")
spell:level(30)
spell:mana(530)
spell:soul(3)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2274, 4)
end

spell:register()
