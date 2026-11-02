local spell = Spell(SPELL_INSTANT)
spell:name("Energy Field")
spell:words("adevo grav vis")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(18)
spell:mana(320)
spell:soul(2)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2277, 3)
end

spell:register()
