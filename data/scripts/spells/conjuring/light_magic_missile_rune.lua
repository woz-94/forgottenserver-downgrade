local spell = Spell(SPELL_INSTANT)
spell:name("Light Magic Missile")
spell:words("adori min vis")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(15)
spell:mana(120)
spell:soul(1)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2287, 10)
end

spell:register()
