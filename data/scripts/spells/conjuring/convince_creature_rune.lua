local spell = Spell(SPELL_INSTANT)
spell:name("Convince Creature")
spell:words("adeta sio")
spell:group("support")
spell:vocation("Druid", "Elder Druid")
spell:level(16)
spell:mana(200)
spell:soul(3)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2290, 1)
end

spell:register()
