local spell = Spell(SPELL_INSTANT)
spell:name("Sudden Death")
spell:words("adori gran mort")
spell:group("support")
spell:vocation("Sorcerer", "Master Sorcerer")
spell:level(45)
spell:mana(985)
spell:soul(5)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2268, 3)
end

spell:register()
