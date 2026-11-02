local spell = Spell(SPELL_INSTANT)
spell:name("Heavy Magic Missile")
spell:words("adori vis")
spell:group("support")
spell:vocation("Sorcerer", "Druid", "Master Sorcerer", "Elder Druid")
spell:level(25)
spell:mana(350)
spell:soul(2)
spell:isAggressive(false)
spell:cooldown(2000)
spell:needLearn(false)

function spell.onCastSpell(creature, variant)
	return creature:conjureItem(2260, 2311, 10)
end

spell:register()
