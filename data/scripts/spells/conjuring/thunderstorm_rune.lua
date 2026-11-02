local spell = Spell(SPELL_INSTANT)
spell:name("Thunderstorm")
spell:words("adori mas vis")
spell:group("support")
spell:vocation("Sorcerer", "Master Sorcerer")
spell:level(28)
spell:mana(430)
spell:soul(3)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2315, 4)
end

spell:register()
