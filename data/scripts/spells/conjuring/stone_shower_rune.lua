local spell = Spell(SPELL_INSTANT)
spell:name("Stone Shower")
spell:words("adori mas tera")
spell:group("support")
spell:vocation("Druid", "Elder Druid")
spell:level(28)
spell:mana(430)
spell:soul(3)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2288, 4)
end

spell:register()
