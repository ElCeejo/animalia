--------------
-- Spawning --
--------------

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

creatura.register_mob_spawn("animalia:bat", {
	chance = 2,
	min_radius = 4,
	max_radius = 16,
	min_light = 0,
	min_height = -512,
	max_height = 0,
	min_group = 3,
	max_group = 5,
	biomes = animalia.registered_biome_groups["cave"].biomes,
	spawn_in_nodes = true,
	spawn_on_gen = true,
	nodes = {"air", "ignore"}
})

creatura.register_mob_spawn("animalia:chicken", {
	chance = 3,
	min_group = 3,
	max_group = 5,
	spawn_on_gen = true,
	biomes = chicken_biomes
})

creatura.register_mob_spawn("animalia:cow", {
	chance = 3,
	min_group = 3,
	max_group = 4,
	spawn_on_gen = true,
	biomes = animalia.registered_biome_groups["grassland"].biomes
})

creatura.register_mob_spawn("animalia:frog", {
	chance = 2,
	min_radius = 4,
	max_radius = 16,
	min_light = 0,
	min_height = -32,
	max_height = 8,
	min_group = 2,
	max_group = 6,
	biomes = frog_biomes,
	spawn_cluster = true,
	spawn_in_nodes = true,
	spawn_on_gen = true,
	nodes = {"default:water_source"},
})

creatura.register_mob_spawn("animalia:horse", {
	chance = 3,
	min_group = 4,
	max_group = 5,
	spawn_on_gen = true,
	biomes = animalia.registered_biome_groups["grassland"].biomes
})

creatura.register_mob_spawn("animalia:pig", {
	chance = 3,
	min_group = 2,
	max_group = 4,
	spawn_on_gen = true,
	biomes = pig_biomes
})

creatura.register_mob_spawn("animalia:reindeer", {
	chance = 4,
	min_group = 6,
	max_group = 12,
	biomes = animalia.registered_biome_groups["boreal"].biomes
})

creatura.register_mob_spawn("animalia:sheep", {
	chance = 3,
	min_group = 3,
	max_group = 6,
	spawn_on_gen = true,
	biomes = animalia.registered_biome_groups["grassland"].biomes
})

creatura.register_mob_spawn("animalia:turkey", {
	chance = 2,
	min_group = 3,
	max_group = 4,
	spawn_on_gen = true,
	biomes = animalia.registered_biome_groups["boreal"].biomes
})

creatura.register_mob_spawn("animalia:wolf", {
	chance = 3,
	min_group = 2,
	max_group = 3,
	spawn_on_gen = true,
	biomes = animalia.registered_biome_groups["boreal"].biomes
})

creatura.register_mob_spawn("animalia:bird", {
	chance = 1,
	min_light = 0,
	min_group = 12,
	max_group = 16,
	biomes = animalia.registered_biome_groups["common"].biomes,
	spawn_cluster = true,
	nodes = {"group:leaves"}
})

creatura.register_on_spawn("animalia:bird", function(self, pos)
	local node = minetest.get_node(pos)
	if node.name == "air" then
		minetest.set_node(pos, {name = "animalia:nest_song_bird"})
		self.home_position = self:memorize("home_position", pos)
		self.despawn_after = self:memorize("despawn_after", nil)
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
			self.despawn_after = self:memorize("despawn_after", nil)
		end
	end
end)

creatura.register_mob_spawn("animalia:tropical_fish", {
	chance = 3,
	min_height = -128,
	max_height = 256,
	min_group = 8,
	max_group = 12,
	spawn_cluster = true,
	spawn_in_nodes = true,
	spawn_on_gen = true,
	nodes = {"default:water_source"}
})