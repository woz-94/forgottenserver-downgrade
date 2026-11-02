local spell = Spell(SPELL_INSTANT)
spell:name("Energybomb")
spell:words("adevo mas vis")
spell:group("support")
spell:vocation("Sorcerer", "Master Sorcerer")
spell:level(37)
spell:mana(880)
spell:soul(5)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2262, 2)
end

spell:register()
