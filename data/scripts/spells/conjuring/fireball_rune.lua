local spell = Spell(SPELL_INSTANT)
spell:name("Fireball")
spell:words("adori flam")
spell:group("support")
spell:vocation("Sorcerer", "Master Sorcerer")
spell:level(27)
spell:mana(460)
spell:soul(3)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2302, 5)
end

spell:register()
