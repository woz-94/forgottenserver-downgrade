local spell = Spell(SPELL_INSTANT)
spell:name("Stalagmite")
spell:words("adori tera")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(24)
spell:mana(400)
spell:soul(2)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2292, 10)
end

spell:register()
