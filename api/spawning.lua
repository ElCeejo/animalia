--------------
-- Spawning --
--------------

local function is_value_in_table(tbl, val)
	for _, v in pairs(tbl) do
		if v == val then
			return true
		end
	end
	return false
end

local common_spawn_chance = tonumber(minetest.settings:get("animalia_common_chance")) or 30000

local ambient_spawn_chance = tonumber(minetest.settings:get("animalia_ambient_chance")) or 6000

local pest_spawn_chance = tonumber(minetest.settings:get("animalia_pest_chance")) or 2000

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

creatura.register_abm_spawn("animalia:cat", {
	chance = common_spawn_chance,
	min_height = 0,
	max_height = 1024,
	min_group = 1,
	max_group = 2,
	nodes = {"group:soil"},
	neighbors = {"group:wood"}
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
	chance = pest_spawn_chance,
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

creatura.register_abm_spawn("animalia:song_bird", {
	chance = ambient_spawn_chance,
	interval = 60,
	min_light = 0,
	min_height = 1,
	max_height = 1024,
	min_group = 6,
	max_group = 12,
	spawn_cap = 6,
	nodes = {"group:leaves", "animalia:nest_song_bird"},
	neighbors = {"group:leaves"}
})

creatura.register_on_spawn("animalia:song_bird", function(self, pos)
	local nests = minetest.find_nodes_in_area_under_air(
		{x = pos.x - 16, y = pos.y - 16, z = pos.z - 16},
		{x = pos.x + 16, y = pos.y + 16, z = pos.z + 16},
		"animalia:nest_song_bird"
	)
	if nests[1] then return end
	local node = minetest.get_node(pos)
	if node.name == "air" then
		minetest.set_node(pos, {name = "animalia:nest_song_bird"})
	else
		local nodes = minetest.find_nodes_in_area_under_air(
			{x = pos.x - 3, y = pos.y - 3, z = pos.z - 3},
			{x = pos.x + 3, y = pos.y + 7, z = pos.z + 3},
			"group:leaves"
		)
		if nodes[1] then
			pos = nodes[1]
			minetest.set_node({x = pos.x, y = pos.y + 1, z = pos.z}, {name = "animalia:nest_song_bird"})
		end
	end
end)

creatura.register_abm_spawn("animalia:frog", {
	chance = ambient_spawn_chance * 0.75,
	interval = 60,
	min_light = 0,
	min_height = -1,
	max_height = 8,
	min_group = 1,
	max_group = 2,
	neighbors = {"group:water"},
	nodes = {"group:soil"}
})

creatura.register_on_spawn("animalia:frog", function(self, pos)
	local biome_data = minetest.get_biome_data(pos)
	local biome_name = minetest.get_biome_name(biome_data.biome)

	if is_value_in_table(animalia.registered_biome_groups["tropical"].biomes, biome_name) then
		self:set_mesh(3)
	elseif is_value_in_table(animalia.registered_biome_groups["temperate"].biomes, biome_name)
	or is_value_in_table(animalia.registered_biome_groups["boreal"].biomes, biome_name) then
		self:set_mesh(1)
	elseif is_value_in_table(animalia.registered_biome_groups["grassland"].biomes, biome_name) then
		self:set_mesh(2)
	else
		self.object:remove()
	end

	local activate = self.activate_func

	activate(self)
end)

creatura.register_abm_spawn("animalia:tropical_fish", {
	chance = ambient_spawn_chance,
	min_height = -128,
	max_height = 1,
	min_group = 6,
	max_group = 12,
	nodes = {"group:water"},
	neighbors = {"group:coral"}
})
