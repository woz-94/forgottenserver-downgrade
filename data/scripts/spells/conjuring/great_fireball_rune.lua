local spell = Spell(SPELL_INSTANT)
spell:name("Great Fireball")
spell:words("adori mas flam")
spell:group("support")
spell:vocation("Sorcerer", "Master Sorcerer")
spell:level(30)
spell:mana(530)
spell:soul(3)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2304, 4)
end

spell:register()
