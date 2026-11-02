local spell = Spell(SPELL_INSTANT)
spell:name("Intense Healing Rune")
spell:words("adura gran")
spell:group("support")
spell:vocation("Druid", "Elder Druid")
spell:level(15)
spell:mana(240)
spell:soul(2)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2265, 1)
end

spell:register()
