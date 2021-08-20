animalia = {}
better_fauna = animalia

animalia.mobkit_mobs = {}
animalia.walkable_nodes = {}
animalia.spawn_interval = 60
animalia.mobs = {}

minetest.register_on_mods_loaded(function()
	for name in pairs(minetest.registered_entities) do
        local mob = minetest.registered_entities[name]
        if mob.logic or mob.brainfunc then
            table.insert(animalia.mobkit_mobs, name)
        end
	end
	for name in pairs(minetest.registered_nodes) do
		if name ~= "air" and name ~= "ignore" then
			if minetest.registered_nodes[name].walkable then
				table.insert(animalia.walkable_nodes, name)
			end
		end
	end
end)

animalia.grassland_biomes = {}

animalia.temperate_biomes = {}

animalia.boreal_biomes = {}

animalia.tropical_biomes = {}

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
end)

animalia.frame_blend = 0

if minetest.has_feature("object_step_has_moveresult") then
	animalia.frame_blend = 0.3
end

function animalia.register_mob(name, def)
	minetest.register_entity("animalia:".. name, {
		physical = true,
		collide_with_objects = true,
		visual = "mesh",
		makes_footstep_sound = true,
		static_save = true,
		timeout = 0,
		-- Stats
		max_hp = def.health or 20,
		armor_groups = {fleshy = def.fleshy},
		view_range = def.view_range or 32,
		lung_capacity = def.lung_capacity or 10,
		-- Visual
		collisionbox = def.collisionbox,
		visual_size = def.visual_size,
		mesh = def.mesh,
		textures = def.textures or nil,
		scale_stage1 = def.scale_stage1 or 0.75,
		scale_stage2 = def.scale_stage2 or 0.85,
		scale_stage3 = def.scale_stage3 or 0.95,
		female_textures = def.female_textures or nil,
		male_textures = def.male_textures or nil,
		child_textures = def.child_textures or nil,
		animation = def.animations,
		-- Physics
		ignore_liquidflag = false,
		push_on_collide = true,
		buoyancy = def.buoyancy or 0.25,
		max_speed = def.speed,
		jump_height = def.jump_height or 1.1,
		stepheight = def.stepheight or 0,
		max_fall = def.max_fall or 2,
		-- Attributes
		sounds = def.sounds,
		obstacle_avoidance_range = def.obstacle_avoidance_range or nil,
		surface_avoidance_range = def.surface_avoidance_range or nil,
		floor_avoidance_range = def.floor_avoidance_range or nil,
		fall_damage = def.fall_damage or true,
		igniter_damage = def.igniter_damage or 2,
		reach = def.reach or 2,
		damage = def.damage or 2,
		knockback = def.knockback or 4,
		punch_cooldown = def.punch_cooldown or 1,
		core_growth = def.growth or true,
		catch_with_net = def.catch_with_net or true,
		driver_scale = def.driver_scale or nil,
		player_rotation = def.player_rotation or nil,
		driver_attach_at = def.driver_attach_at or nil,
		driver_attach_bone = def.driver_attach_bone or nil,
		driver_eye_offset = def.driver_eye_offset or nil,
		-- Behavior
		defend_owner = def.defend_owner,
		follow = def.follow,
		consumable_nodes = def.consumable_nodes or nil,
		drops = def.drops,
		-- Functions
		head_data = def.head_data or nil,
		register_targets = def.register_targets or nil,
		physics = def.physics or nil,
		logic = def.logic,
		get_staticdata = mobkit.statfunc,
		on_step = def.on_step,
		on_activate = def.on_activate,
		on_rightclick = def.on_rightclick,
		on_punch = def.on_punch,
	})
	table.insert(animalia.mobs, "animalia:" .. name)
end

local path = minetest.get_modpath("animalia")

dofile(path.."/api/api.lua")
dofile(path.."/craftitems.lua")
dofile(path.."/mobs/cat.lua")
dofile(path.."/mobs/chicken.lua")
dofile(path.."/mobs/cow.lua")
dofile(path.."/mobs/horse.lua")
dofile(path.."/mobs/pig.lua")
dofile(path.."/mobs/sheep.lua")
dofile(path.."/mobs/turkey.lua")
dofile(path.."/mobs/wolf.lua")
dofile(path.."/api/legacy_convert.lua")

animalia.chunks_since_last_spawn = 0

local chunk_spawn_add_int = tonumber(minetest.settings:get("chunk_spawn_add_int")) or 32

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
		table.insert(animalia.spawn_queue, {pos = center, mob = animalia.mobs[math.random(#animalia.mobs)]})
		animalia.chunks_since_last_spawn = 0
	end
end)

local chunk_spawn_queue_int  = tonumber(minetest.settings:get("chunk_spawn_queue_int")) or 10

local function spawn_queued()
	local queue = animalia.spawn_queue
	if #queue > 0 then
		for i = #queue, 1, -1 do
			local def = mob_core.registered_spawns[queue[i].mob].def
			mob_core.spawn_at_pos(
				queue[i].pos,
				def.name,
				def.nodes or nil,
				def.group or 1,
				def.optional or nil
			)
			table.remove(animalia.spawn_queue, i)
		end
	end
	minetest.after(chunk_spawn_queue_int, spawn_queued)
end
minetest.after(chunk_spawn_queue_int, spawn_queued)


minetest.log("action", "[MOD] Animalia [0.2] loaded")
