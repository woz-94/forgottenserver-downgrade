local spell = Spell(SPELL_INSTANT)
spell:name("Desintegrate")
spell:words("adito tera")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Paladin", "Master Sorcerer", "Elder Druid", "Royal Paladin")
spell:level(21)
spell:mana(200)
spell:soul(3)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2310, 3)
end

spell:register()
