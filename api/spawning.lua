--------------
-- Spawning --
--------------

local random = math.random

local path = minetest.get_modpath("animalia")

local storage = dofile(path .. "/api/storage.lua")

animalia.spawn_points = storage.spawn_points

-- Get Biomes --

local chicken_biomes = {}

local frog_biomes = {}

local pig_biomes = {}

local wolf_biomes = {}

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
    nodes = {"air", "ignore"}
})

creatura.register_mob_spawn("animalia:chicken", {
    chance = 3,
    min_group = 3,
    max_group = 5,
    biomes = chicken_biomes
})

creatura.register_mob_spawn("animalia:cow", {
    chance = 3,
    min_group = 3,
    max_group = 4,
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
    nodes = {"default:water_source"},
    send_debug = true
})

creatura.register_mob_spawn("animalia:horse", {
    chance = 3,
    min_group = 4,
    max_group = 5,
    biomes = animalia.registered_biome_groups["grassland"].biomes
})

creatura.register_mob_spawn("animalia:pig", {
    chance = 3,
    min_group = 2,
    max_group = 4,
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
    biomes = animalia.registered_biome_groups["grassland"].biomes
})

creatura.register_mob_spawn("animalia:turkey", {
    chance = 2,
    min_group = 3,
    max_group = 4,
    biomes = animalia.registered_biome_groups["boreal"].biomes
})

creatura.register_mob_spawn("animalia:wolf", {
    chance = 3,
    min_group = 2,
    max_group = 3,
    biomes = animalia.registered_biome_groups["boreal"].biomes
})

creatura.register_mob_spawn("animalia:bird", {
    chance = 4,
    min_light = 0,
    min_group = 12,
    max_group = 16,
    biomes = animalia.registered_biome_groups["common"].biomes,
    spawn_cluster = true,
    spawn_in_nodes = true,
    nodes = {"air", "ignore"}
})

creatura.register_mob_spawn("animalia:tropical_fish", {
    chance = 3,
    min_height = -128,
    max_height = 256,
    min_group = 8,
    max_group = 12,
    spawn_cluster = true,
    spawn_in_nodes = true,
    nodes = {"default:water_source"}
})

---------------------
-- Mapgen Spawning --
---------------------

local function vec_raise(v, n)
    return {x = v.x, y = v.y + n, z = v.z}
end

function is_value_in_table(tbl, val)
    for _, v in pairs(tbl) do
        if v == val then
            return true
        end
    end
    return false
end

function get_biome_name(pos)
    if not pos then return end
    return minetest.get_biome_name(minetest.get_biome_data(pos).biome)
end

function get_ground_level(pos)
    local node = minetest.get_node(pos)
    local node_def = minetest.registered_nodes[node.name]
    local height = 0
    while node_def.walkable
    and height < 4 do
        height = height + 1
        node = minetest.get_node(vec_raise(pos, height))
        node_def = minetest.registered_nodes[node.name]
    end
    return vec_raise(pos, height)
end

local function dist_to_nearest_player(pos)
    local dist
    for _, player in pairs(minetest.get_connected_players()) do
        local player_pos = player:get_pos()
        if player_pos
        and (not dist
        or dist > vector.distance(pos, player_pos)) then
            dist = vector.distance(pos, player_pos)
        end
    end
    return dist or 100
end

local function get_spawnable_mobs(pos)
    local biome = get_biome_name(pos)
    if not biome then return end
    local spawnable = {}
    for k, v in pairs(creatura.registered_mob_spawns) do
        if (not v.biomes
        or is_value_in_table(v.biomes, biome))
        and k:match("^animalia:")
        and not v.spawn_in_nodes then
            table.insert(spawnable, k)
        end
    end
    return spawnable
end

local mapgen_spawning = minetest.settings:get_bool("animalia_mapgen_spawning") or true

animalia.chunks_since_last_spawn = 0

local chunk_spawn_add_int = tonumber(minetest.settings:get("chunk_spawn_add_int")) or 6

animalia.spawn_queue = {}

minetest.register_on_generated(function(minp, maxp)
    if not mapgen_spawning then return end
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
        local spawnable_mobs = get_spawnable_mobs(center)
        if spawnable_mobs then
            local mob = spawnable_mobs[random(#spawnable_mobs)]
            table.insert(animalia.spawn_queue, {pos = center, mob = mob, group = random(3, 4)})
            table.insert(animalia.spawn_points, center)
        end
		animalia.chunks_since_last_spawn = 0
	end
end)

local respawn_interval = 15

minetest.register_globalstep(function(dtime)
    respawn_interval = respawn_interval - dtime
    if respawn_interval <= 0 then
        if #animalia.spawn_points > 0 then
            for i = 1, #animalia.spawn_points do
                local point = animalia.spawn_points[i]
                if dist_to_nearest_player(point) < 48
                and minetest.get_node_or_nil(point) then
                    local spawnable_mobs = get_spawnable_mobs(point)
                    if spawnable_mobs then
                        local mob = spawnable_mobs[random(#spawnable_mobs)]
                        local objects = minetest.get_objects_inside_radius(point, 32)
                        local spawn = true
                        if #objects > 0 then
                            for i = 1, #objects do
                                local object = objects[i]
                                if object:get_luaentity()
                                and object:get_luaentity().name:find("animalia:") then
                                    spawn = false
                                    break
                                end
                            end
                        end
                        if spawn then
                            table.insert(animalia.spawn_queue, {pos = point, mob = mob, group = random(3, 4)})
                        end
                    end
                end
            end
        end
        respawn_interval = 15
    end
end)

local chunk_spawn_queue_int  = tonumber(minetest.settings:get("chunk_spawn_queue_int")) or 16

local function spawn_queued()
    if not mapgen_spawning then return end
	local queue = animalia.spawn_queue
	if #queue > 0 then
		for i = #queue, 1, -1 do
            if queue[i].mob then
                local pos = queue[i].pos
                for _ = 1, queue[i].group do
                    pos = {
                        x = pos.x + random(-3, 3),
                        y = pos.y,
                        z = pos.z + random(-3, 3)
                    }
                    pos = get_ground_level(pos)
                    minetest.add_node(pos, {name = "creatura:spawn_node"})
                    local meta = minetest.get_meta(pos)
                    meta:set_string("mob", queue[i].mob)
                end
            end
			table.remove(animalia.spawn_queue, i)
		end
	end
	minetest.after(chunk_spawn_queue_int, spawn_queued)
end
minetest.after(chunk_spawn_queue_int, spawn_queued)