local spell = Spell(SPELL_INSTANT)
spell:name("Chameleon")
spell:words("adevo ina")
spell:group("support")
spell:vocation("Druid", "Elder Druid")
spell:level(27)
spell:mana(600)
spell:soul(2)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2291, 1)
end

spell:register()
