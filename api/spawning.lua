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
        local nodes = minetest.find_nodes_in_area_under_air({x = pos.x - 3, y = pos.y - 3, z = pos.z - 3}, {x = pos.x + 3, y = pos.y + 7, z = pos.z + 3}, "group:leaves")
        if nodes[1] then
            pos = nodes[1]
            minetest.set_node({x = pos.x, y = pos.y + 1, z = pos.z}, {name = "animalia:nest_song_bird"})
            self.home_position = self:memorize("home_position", nodes[1])
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

local c_air = minetest.get_content_id("air")

minetest.register_on_generated(function(minp, maxp)
    if not mapgen_spawning then return end
	animalia.chunks_since_last_spawn = animalia.chunks_since_last_spawn + 1
    local max_y = maxp.y
    local min_x = minp.x
    local max_x = maxp.x
    local min_z = minp.z
    local max_z = maxp.z
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()

    local spawn_added = false

	for xcen = min_x + 8, max_x - 7, 8 do
        if spawn_added then break end
        for zcen = min_z + 8, max_z - 7, 8 do
            local surface = false -- y of above surface node
            for y = max_y, 2, -1 do
                local vi = area:index(xcen, y, zcen)
                local c_node = data[vi]
                local c_name = minetest.get_name_from_content_id(c_node)
                local c_def = minetest.registered_nodes[c_name]
                if y == max_y and c_node ~= c_air then -- if top node solid
                    break
                elseif minetest.get_item_group(c_name, "leaves") > 0 then
                    break
                elseif c_def.walkable then
                    surface = y + 1
                    break
                end
            end
            if animalia.chunks_since_last_spawn > chunk_spawn_add_int
            and surface then
                local center = {
                    x = xcen,
                    y = surface,
                    z = zcen,
                }
                local spawnable_mobs = get_spawnable_mobs(center)
                if spawnable_mobs
                and #spawnable_mobs > 0 then
                    local mob = spawnable_mobs[random(#spawnable_mobs)]
                    local spawn_def = creatura.registered_mob_spawns[mob]
                    table.insert(animalia.spawn_queue, {pos = center, mob = mob, group = random(spawn_def.min_group, spawn_def.max_group)})
                    table.insert(animalia.spawn_points, center)
                end
                spawn_added = true
                animalia.chunks_since_last_spawn = 0
            end
        end
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
                    if spawnable_mobs
                    and #spawnable_mobs > 0 then
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
                            local spawn_def = creatura.registered_mob_spawns[mob]
                            table.insert(animalia.spawn_queue, {pos = point, mob = mob, group = random(spawn_def.min_group, spawn_def.max_group)})
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
                if queue[i].group > 4
                or creatura.registered_mob_spawns[queue[i].mob].spawn_cluster then
                    pos = get_ground_level(pos)
                    minetest.add_node(pos, {name = "creatura:spawn_node"})
                    local meta = minetest.get_meta(pos)
                    meta:set_string("mob", queue[i].mob)
                    meta:set_string("cluster", queue[i].group)
                else
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
            end
			table.remove(animalia.spawn_queue, i)
		end
	end
	minetest.after(chunk_spawn_queue_int, spawn_queued)
end
minetest.after(chunk_spawn_queue_int, spawn_queued)