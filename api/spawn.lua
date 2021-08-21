

animalia.grassland_biomes = {}

animalia.temperate_biomes = {}

animalia.boreal_biomes = {}

animalia.tropical_biomes = {}

local chicken_biomes = {}

local pig_biomes = {}

local function insert_all(tbl, tbl2)
    for i = 1, #tbl2 do
        table.insert(tbl, tbl2[i])
    end
end

minetest.register_on_mods_loaded(function()
	for name in pairs(minetest.registered_biomes) do
        local biome = minetest.registered_biomes[name]
        if name:find("forest") then
			local turf = biome.node_top
			local heat = biome.heat_point or 0
			local humidity = biome.humidity_point or 50
			if turf then
				if turf:find("dirt") then
					if heat >= 40
					and humidity >= 60 then
						table.insert(animalia.tropical_biomes, name)
					else
						table.insert(animalia.boreal_biomes, name)
					end
				elseif turf:find("grass") then
					if heat >= 40 then
						table.insert(animalia.boreal_biomes, name)
					else
						table.insert(animalia.temperate_biomes, name)
					end
				elseif turf:find("litter") then
					if heat >= 40
					and humidity >= 60 then
						table.insert(animalia.tropical_biomes, name)
					else
						table.insert(animalia.temperate_biomes, name)
					end
				elseif turf:find("snow") then
					table.insert(animalia.temperate_biomes, name)
				end
			end
		else
			local turf = biome.node_top
			local heat = biome.heat_point or 0
			--local humidity = biome.humidity_point or 50
			if turf then
				if turf:find("grass")
				or (turf:find("dirt")
				and heat < 60) then
					table.insert(animalia.grassland_biomes, name)
				end
			end
		end
	end
    insert_all(chicken_biomes, animalia.grassland_biomes)
    insert_all(chicken_biomes, animalia.tropical_biomes)
    insert_all(pig_biomes, animalia.grassland_biomes)
    insert_all(pig_biomes, animalia.temperate_biomes)
    insert_all(pig_biomes, animalia.boreal_biomes)
end)

-- Chicken --

mob_core.register_spawn({
	name = "animalia:chicken",
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	min_rad = 24,
	max_rad = 256,
	group = 6,
	optional = {
		biomes = chicken_biomes
	}
}, animalia.spawn_interval, 4)

-- Cat --

local house_nodes = {}

minetest.register_on_mods_loaded(function()
	for name in pairs(minetest.registered_nodes) do
        if minetest.get_item_group(name, "stairs") > 0
		or minetest.get_item_group(name, "wood") > 0 then
			table.insert(house_nodes, name)
		end
	end
end)

mob_core.register_spawn({
	name = "animalia:cat",
	nodes = house_nodes,
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	min_rad = 24,
	max_rad = 256,
	group = 0,
}, animalia.spawn_interval, 6)

-- Cow --

mob_core.register_spawn({
	name = "animalia:cow",
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	group = 3,
	optional = {
		biomes = animalia.grassland_biomes
	}
}, animalia.spawn_interval, 2)

-- Horse --

mob_core.register_spawn({
	name = "animalia:horse",
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	group = 6,
	optional = {
		biomes = animalia.grassland_biomes
	}
}, animalia.spawn_interval, 16)

-- Pig --

mob_core.register_spawn({
	name = "animalia:pig",
	nodes = {"default:dirt_with_grass"},
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	group = 3,
	optional = {
		biomes = pig_biomes
	}
}, animalia.spawn_interval, 4)

-- Sheep --

mob_core.register_spawn({
	name = "animalia:sheep",
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	min_rad = 24,
	max_rad = 256,
	group = 6,
	optional = {
		biomes = animalia.grassland_biomes
	}
}, animalia.spawn_interval, 4)

-- Turkey --

mob_core.register_spawn({
	name = "animalia:turkey",
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	min_rad = 24,
	max_rad = 256,
	group = 6,
	optional = {
		biomes = animalia.temperate_biomes
	}
}, animalia.spawn_interval, 6)

-- Wolf --

mob_core.register_spawn({
	name = "animalia:wolf",
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	group = 4,
	optional = {
		biomes = animalia.temperate_biomes
	}
}, animalia.spawn_interval, 4)

---------------------
-- Mapgen Spawning --
---------------------

animalia.chunks_since_last_spawn = 0

local chunk_spawn_add_int = tonumber(minetest.settings:get("chunk_spawn_add_int")) or 64

animalia.spawn_queue = {}

minetest.register_on_generated(function(minp, maxp)
	animalia.chunks_since_last_spawn = animalia.chunks_since_last_spawn + 1
	local heightmap = minetest.get_mapgen_object("heightmap")
	if not heightmap then return end
	local pos = {
		x = minp.x + math.floor((maxp.x - minp.x) / 2),
		y = minp.y,
		z = minp.z + math.floor((maxp.z - minp.z) / 2)
	}
	local hm_i = (pos.x - minp.x + 1) + (((pos.z - minp.z)) * 80)
	pos.y = heightmap[hm_i]
	if animalia.chunks_since_last_spawn > chunk_spawn_add_int
	and pos.y > 0 then
		local heightmap = minetest.get_mapgen_object("heightmap")
		if not heightmap then return end
		local center = {
			x = math.floor(minp.x + ((maxp.x - minp.x) * 0.5) + 0.5),
			y = minp.y,
			z = math.floor(minp.z + ((maxp.z - minp.z) * 0.5) + 0.5),
		}
		local light = minetest.get_natural_light(center)
		while center.y < maxp.y
		and light < 10 do
			center.y = center.y + 1
			light = minetest.get_natural_light(center)
		end
        local spawnable_mobs = {}
        for i = 1, #animalia.mobs do
            local spawn_def = mob_core.registered_spawns[animalia.mobs[i]].def
            if spawn_def.optional
            and mob_core.find_val(spawn_def.optional.biomes, mob_core.get_biome_name(center))
            and (#animalia.spawn_queue < 1
            or animalia.spawn_queue[#animalia.spawn_queue].mob ~= animalia.mobs[i]) then
                table.insert(spawnable_mobs, animalia.mobs[i])
            end
        end
		table.insert(animalia.spawn_queue, {pos = center, mob = spawnable_mobs[math.random(#spawnable_mobs)]})
		animalia.chunks_since_last_spawn = 0
	end
end)

local chunk_spawn_queue_int  = tonumber(minetest.settings:get("chunk_spawn_queue_int")) or 16

local function spawn_queued()
	local queue = animalia.spawn_queue
	if #queue > 0 then
		for i = #queue, 1, -1 do
            if queue[i].mob then
                local def = mob_core.registered_spawns[queue[i].mob].def
                mob_core.spawn_at_pos(
                    queue[i].pos,
                    def.name,
                    def.nodes or nil,
                    def.group or 1,
                    def.optional or nil
                )
            end
			table.remove(animalia.spawn_queue, i)
		end
	end
	minetest.after(chunk_spawn_queue_int, spawn_queued)
end
minetest.after(chunk_spawn_queue_int, spawn_queued)