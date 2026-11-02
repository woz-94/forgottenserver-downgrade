local spell = Spell(SPELL_INSTANT)
spell:name("Poison Wall")
spell:words("adevo mas grav pox")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(29)
spell:mana(640)
spell:soul(3)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2289, 4)
end

spell:register()
