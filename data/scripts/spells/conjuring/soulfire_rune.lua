local spell = Spell(SPELL_INSTANT)
spell:name("Soulfire")
spell:words("adevo res flam")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(27)
spell:mana(600)
spell:soul(3)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2308, 3)
end

spell:register()
