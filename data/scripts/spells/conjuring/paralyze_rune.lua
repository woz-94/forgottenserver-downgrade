local spell = Spell(SPELL_INSTANT)
spell:name("Paralyze")
spell:words("adana ani")
spell:group("support")
spell:vocation("Druid", "Elder Druid")
spell:level(54)
spell:mana(1400)
spell:soul(3)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2278, 1)
end

spell:register()
