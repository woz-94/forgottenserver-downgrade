local spell = Spell(SPELL_INSTANT)
spell:name("Antidote Rune")
spell:words("adana pox")
spell:group("support")
spell:vocation("Druid", "Elder Druid")
spell:level(15)
spell:mana(200)
spell:soul(1)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2266, 1)
end

spell:register()
