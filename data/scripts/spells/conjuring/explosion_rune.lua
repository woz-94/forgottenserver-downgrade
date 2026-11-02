local spell = Spell(SPELL_INSTANT)
spell:name("Explosion")
spell:words("adevo mas hur")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(31)
spell:mana(570)
spell:soul(4)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2313, 6)
end

spell:register()
