local spell = Spell(SPELL_INSTANT)
spell:name("Wild Growth")
spell:words("adevo grav vita")
spell:group("support")
spell:vocation("Druid", "Elder Druid")
spell:level(27)
spell:mana(600)
spell:soul(5)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2269, 2)
end

spell:register()
