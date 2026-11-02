local spell = Spell(SPELL_INSTANT)
spell:name("Holy Missile")
spell:words("adori san")
spell:group("support")
spell:vocation("Paladin", "Royal Paladin")
spell:level(27)
spell:mana(350)
spell:soul(3)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2295, 5)
end

spell:register()
