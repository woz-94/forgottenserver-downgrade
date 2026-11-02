local spell = Spell(SPELL_INSTANT)
spell:name("Energy Wall")
spell:words("adevo mas grav vis")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(41)
spell:mana(1000)
spell:soul(5)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2279, 4)
end

spell:register()
