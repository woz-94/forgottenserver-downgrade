local spell = Spell(SPELL_INSTANT)
spell:name("Poison Field")
spell:words("adevo grav pox")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(14)
spell:mana(200)
spell:soul(1)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2285, 3)
end

spell:register()
