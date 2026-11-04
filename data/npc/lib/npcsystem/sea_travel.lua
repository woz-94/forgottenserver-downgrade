-- Shared sea travel network.
--
-- Every sailing NPC registers the same destinations so a player can reach any
-- port from any captain.  Travel is free everywhere; StdModule.travel no longer
-- charges or requires premium, so the cost/premium fields here are inert but
-- kept explicit for clarity.
SeaTravel = {
	destinations = {
		{ name = 'Thais',          keys = {'thais'},                       x = 32310, y = 32210, z = 6 },
		{ name = 'Carlin',         keys = {'carlin'},                      x = 32387, y = 31820, z = 6 },
		{ name = "Ab'Dendriel",    keys = {"ab'dendriel", 'abdendriel', 'ab dendriel'}, x = 32734, y = 31668, z = 6 },
		{ name = 'Edron',          keys = {'edron'},                       x = 33173, y = 31764, z = 6 },
		{ name = 'Venore',         keys = {'venore'},                      x = 32954, y = 32022, z = 6 },
		{ name = 'Darashia',       keys = {'darashia'},                    x = 33289, y = 32480, z = 6 },
		{ name = 'Port Hope',      keys = {'port hope'},                   x = 32527, y = 32784, z = 6 },
		{ name = 'Ankrahmun',      keys = {'ankrahmun'},                   x = 33092, y = 32883, z = 6 },
		{ name = 'Liberty Bay',    keys = {'liberty bay'},                 x = 32285, y = 32892, z = 6 },
		{ name = 'Yalahar',        keys = {'yalahar'},                     x = 32816, y = 31272, z = 6 },
		{ name = 'Svargrond',      keys = {'svargrond'},                   x = 32341, y = 31108, z = 6 },
		{ name = 'Cormaya',        keys = {'cormaya'},                     x = 33287, y = 31955, z = 6 },
		{ name = 'Oramond',        keys = {'oramond'},                     x = 33479, y = 31985, z = 7 },
		{ name = 'Krailos',        keys = {'krailos'},                     x = 33493, y = 31712, z = 6 },
		{ name = 'Farmine',        keys = {'farmine'},                     x = 33158, y = 31226, z = 7 },
		{ name = 'Zao',            keys = {'zao'},                         x = 33030, y = 31553, z = 9 },
		{ name = 'Goroma',         keys = {'goroma'},                      x = 32161, y = 32558, z = 6 },
		{ name = 'Calassa',        keys = {'calassa'},                     x = 31911, y = 32710, z = 6 },
		{ name = 'Sea Serpent',    keys = {'sea serpent'},                 x = 31942, y = 31043, z = 6 },
		{ name = 'Peg Leg',        keys = {'peg leg'},                     x = 32346, y = 32625, z = 7 },
		{ name = 'Fenrock',        keys = {'fenrock'},                     x = 32563, y = 31313, z = 7 },
		{ name = 'Mistrock',       keys = {'mistrock'},                    x = 32640, y = 31439, z = 7 },
		{ name = 'Vengoth',        keys = {'vengoth'},                     x = 32857, y = 31549, z = 7 },
		{ name = 'Sunken Quarter', keys = {'sunken quarter', 'sunken'},    x = 32941, y = 31182, z = 7 },
		{ name = 'Meluna',         keys = {'meluna'},                      x = 32088, y = 32470, z = 7 },
		{ name = 'Fibula',         keys = {'fibula'},                      x = 32153, y = 32457, z = 7 },
		{ name = 'Okolnir',        keys = {'okolnir'},                     x = 32225, y = 31381, z = 7 },
		{ name = 'Helheim',        keys = {'helheim'},                     x = 32462, y = 31174, z = 7 },
		{ name = 'Tyrsung',        keys = {'tyrsung'},                     x = 32333, y = 31227, z = 7 },
		{ name = 'Raider Camp',    keys = {'raider camp'},                 x = 32154, y = 31375, z = 7 },
		{ name = 'Gengia',         keys = {'gengia'},                      x = 17012, y = 21228, z = 6 },
		{ name = 'Oken',           keys = {'oken'},                        x = 21959, y = 16496, z = 6 },
		{ name = 'Pyre',           keys = {'pyre'},                        x = 13062, y = 16630, z = 6 },
		{ name = 'Zenit',          keys = {'zenit'},                       x = 23003, y = 21346, z = 6 },
		{ name = 'Vinea',          keys = {'vinea'},                       x = 22752, y = 21134, z = 6 },
		{ name = 'Ilania',         keys = {'ilania'},                      x = 22191, y = 16630, z = 7 },
	},
}

function SeaTravel.add(keywordHandler, npcHandler)
	for _, destination in ipairs(SeaTravel.destinations) do
		keywordHandler:addKeyword(destination.keys, StdModule.travel, {
			npcHandler = npcHandler,
			premium = false,
			level = 0,
			cost = 0,
			destination = { x = destination.x, y = destination.y, z = destination.z },
		})
	end

	local names = {}
	for _, destination in ipairs(SeaTravel.destinations) do
		names[#names + 1] = '{' .. destination.name .. '}'
	end
	local text = 'Where do you want to go? ' .. table.concat(names, ', ') .. '.'
	keywordHandler:addKeyword({'sail'}, StdModule.say, { npcHandler = npcHandler, onlyFocus = true, text = text })
	keywordHandler:addKeyword({'passage'}, StdModule.say, { npcHandler = npcHandler, onlyFocus = true, text = text })
	keywordHandler:addKeyword({'where'}, StdModule.say, { npcHandler = npcHandler, onlyFocus = true, text = text })
end
