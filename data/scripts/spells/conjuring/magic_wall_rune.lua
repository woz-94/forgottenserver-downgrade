local spell = Spell(SPELL_INSTANT)
spell:name("Magic Wall")
spell:words("adevo grav tera")
spell:group("support")
spell:vocation("Sorcerer", "Master Sorcerer")
spell:level(32)
spell:mana(750)
spell:soul(5)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2293, 3)
end

spell:register()
