local spell = Spell(SPELL_INSTANT)
spell:name("Poison Bomb")
spell:words("adevo mas pox")
spell:group("support")
spell:vocation("Druid", "Elder Druid")
spell:level(25)
spell:mana(520)
spell:soul(2)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2286, 2)
end

spell:register()
