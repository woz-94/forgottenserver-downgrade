local spell = Spell(SPELL_INSTANT)
spell:name("Icicle")
spell:words("adori frigo")
spell:group("support")
spell:vocation("Druid", "Elder Druid")
spell:level(28)
spell:mana(460)
spell:soul(3)
spell:isPremium(true)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2271, 5)
end

spell:register()
