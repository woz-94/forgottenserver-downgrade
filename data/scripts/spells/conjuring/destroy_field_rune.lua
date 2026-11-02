local spell = Spell(SPELL_INSTANT)
spell:name("Destroy Field")
spell:words("adito grav")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Paladin", "Master Sorcerer", "Elder Druid", "Royal Paladin")
spell:level(17)
spell:mana(120)
spell:soul(2)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2261, 3)
end

spell:register()
