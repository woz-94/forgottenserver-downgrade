local spell = Spell(SPELL_INSTANT)
spell:name("Animate Dead")
spell:words("adana mort")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(27)
spell:mana(600)
spell:soul(5)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2316, 1)
end

spell:register()
