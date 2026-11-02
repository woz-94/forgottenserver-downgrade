local spell = Spell(SPELL_INSTANT)
spell:name("Fire Field")
spell:words("adevo grav flam")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(15)
spell:mana(240)
spell:soul(1)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2301, 3)
end

spell:register()
