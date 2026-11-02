local spell = Spell(SPELL_INSTANT)
spell:name("Firebomb")
spell:words("adevo mas flam")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(27)
spell:mana(600)
spell:soul(4)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2305, 2)
end

spell:register()
