--------------
-- Spawning --
--------------

local common_spawn_chance = tonumber(minetest.settings:get("animalia_common_chance")) or 20000

local ambient_spawn_chance = tonumber(minetest.settings:get("animalia_ambient_chance")) or 6000

local pest_spawn_chance = tonumber(minetest.settings:get("animalia_pest_chance")) or 4000

local predator_spawn_chance = tonumber(minetest.settings:get("animalia_predator_chance")) or 30000

-- Get Biomes --

local chicken_biomes = {}

local frog_biomes = {}

local pig_biomes = {}

local function insert_all(tbl, tbl2)
	for i = 1, #tbl2 do
		table.insert(tbl, tbl2[i])
	end
end

minetest.register_on_mods_loaded(function()
	insert_all(chicken_biomes, animalia.registered_biome_groups["grassland"].biomes)
	insert_all(chicken_biomes, animalia.registered_biome_groups["tropical"].biomes)
	insert_all(pig_biomes, animalia.registered_biome_groups["temperate"].biomes)
	insert_all(pig_biomes, animalia.registered_biome_groups["boreal"].biomes)
	insert_all(frog_biomes, animalia.registered_biome_groups["swamp"].biomes)
	insert_all(frog_biomes, animalia.registered_biome_groups["tropical"].biomes)
end)

creatura.register_abm_spawn("animalia:chicken", {
	chance = common_spawn_chance,
	min_height = 0,
	max_height = 1024,
	min_group = 3,
	max_group = 5,
	biomes = chicken_biomes,
	nodes = {"group:soil"},
})

creatura.register_abm_spawn("animalia:cow", {
	chance = common_spawn_chance,
	min_height = 0,
	max_height = 1024,
	min_group = 3,
	max_group = 4,
	biomes = animalia.registered_biome_groups["grassland"].biomes,
	nodes = {"group:soil"},
	neighbors = {"air", "group:grass", "group:flora"}
})

creatura.register_abm_spawn("animalia:fox", {
	chance = predator_spawn_chance,
	min_height = 0,
	max_height = 1024,
	min_group = 1,
	max_group = 2,
	biomes = animalia.registered_biome_groups["boreal"].biomes,
	nodes = {"group:soil"},
})

creatura.register_abm_spawn("animalia:horse", {
	chance = common_spawn_chance,
	min_height = 0,
	max_height = 1024,
	min_group = 3,
	max_group = 4,
	biomes = animalia.registered_biome_groups["grassland"].biomes,
	nodes = {"group:soil"},
	neighbors = {"air", "group:grass", "group:flora"}
})

creatura.register_abm_spawn("animalia:rat", {
	chance = 2000,
	interval = 60,
	min_height = -1,
	max_height = 1024,
	min_group = 1,
	max_group = 3,
	spawn_in_nodes = true,
	nodes = {"group:crop"}
})

creatura.register_abm_spawn("animalia:owl", {
	chance = predator_spawn_chance,
	interval = 60,
	min_height = 3,
	max_height = 1024,
	min_group = 1,
	max_group = 1,
	spawn_cap = 1,
	nodes = {"group:leaves"}
})

creatura.register_abm_spawn("animalia:pig", {
	chance = common_spawn_chance,
	min_height = 0,
	max_height = 1024,
	min_group = 2,
	max_group = 3,
	biomes = pig_biomes,
	nodes = {"group:soil"},
})

creatura.register_abm_spawn("animalia:reindeer", {
	chance = common_spawn_chance,
	min_height = 0,
	max_height = 1024,
	min_group = 6,
	max_group = 8,
	biomes = animalia.registered_biome_groups["boreal"].biomes,
	nodes = {"group:soil"},
})

creatura.register_abm_spawn("animalia:sheep", {
	chance = common_spawn_chance,
	min_height = 0,
	max_height = 1024,
	min_group = 3,
	max_group = 6,
	biomes = animalia.registered_biome_groups["grassland"].biomes,
	nodes = {"group:soil"},
	neighbors = {"air", "group:grass", "group:flora"}
})

creatura.register_abm_spawn("animalia:turkey", {
	chance = common_spawn_chance,
	min_height = 0,
	max_height = 1024,
	min_group = 3,
	max_group = 4,
	biomes = animalia.registered_biome_groups["boreal"].biomes,
	nodes = {"group:soil"},
})

creatura.register_abm_spawn("animalia:wolf", {
	chance = predator_spawn_chance,
	min_height = 0,
	max_height = 1024,
	min_group = 2,
	max_group = 3,
	biomes = animalia.registered_biome_groups["boreal"].biomes,
	nodes = {"group:soil"},
})

-- Ambient Spawning

creatura.register_abm_spawn("animalia:bat", {
	chance = ambient_spawn_chance,
	interval = 30,
	min_light = 0,
	min_height = -31000,
	max_height = 1,
	min_group = 3,
	max_group = 5,
	spawn_cap = 6,
	nodes = {"group:stone"}
})

creatura.register_abm_spawn("animalia:bird", {
	chance = ambient_spawn_chance,
	interval = 60,
	min_light = 0,
	min_height = 1,
	max_height = 1024,
	min_group = 6,
	max_group = 12,
	spawn_cap = 12,
	nodes = {"group:leaves"},
	neighbors = {"group:leaves"}
})

creatura.register_on_spawn("animalia:bird", function(self, pos)
	local nests = minetest.find_nodes_in_area_under_air(
		{x = pos.x - 12, y = pos.y - 12, z = pos.z - 12},
		{x = pos.x + 12, y = pos.y + 12, z = pos.z + 12},
		"animalia:nest_song_bird"
	)
	if nests[1] then
		self.home_position = self:memorize("home_position", nests[1])
		return
	end
	local node = minetest.get_node(pos)
	if node.name == "air" then
		minetest.set_node(pos, {name = "animalia:nest_song_bird"})
		self.home_position = self:memorize("home_position", pos)
	else
		local nodes = minetest.find_nodes_in_area_under_air(
			{x = pos.x - 3, y = pos.y - 3, z = pos.z - 3},
			{x = pos.x + 3, y = pos.y + 7, z = pos.z + 3},
			"group:leaves"
		)
		if nodes[1] then
			pos = nodes[1]
			minetest.set_node({x = pos.x, y = pos.y + 1, z = pos.z}, {name = "animalia:nest_song_bird"})
			self.home_position = self:memorize("home_position", {x = pos.x, y = pos.y + 1, z = pos.z})
		end
	end
end)

creatura.register_abm_spawn("animalia:frog", {
	chance = ambient_spawn_chance,
	interval = 60,
	min_light = 0,
	min_height = -1,
	max_height = 8,
	min_group = 2,
	max_group = 4,
	neighbors = {"group:water"},
	nodes = {"group:soil"}
})

creatura.register_abm_spawn("animalia:tropical_fish", {
	chance = ambient_spawn_chance,
	min_height = -128,
	max_height = 1,
	min_group = 6,
	max_group = 12,
	nodes = {"group:water"},
	neighbors = {"group:coral"}
})