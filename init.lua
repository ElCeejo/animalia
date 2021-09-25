animalia = {}
better_fauna = animalia

animalia.mobkit_mobs = {}
animalia.walkable_nodes = {}
animalia.spawn_interval = tonumber(minetest.settings:get("animalia_spawn_int")) or 60
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

animalia.frame_blend = 0

if minetest.has_feature("object_step_has_moveresult") then
	animalia.frame_blend = 0.3
end

local fancy_step = minetest.settings:get_bool("animalia_fancy_step")

local stepheight = 1.1

if fancy_step then
	stepheight = 0.1
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
		stepheight = stepheight,
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

local spawn_mobs = minetest.settings:get_bool("spawn_mobs") or true

dofile(path.."/api/api.lua")
if spawn_mobs then
	dofile(path.."/api/spawn.lua")
end
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

local convert_redo_items = minetest.settings:get_bool("convert_redo_items") or false

if convert_redo_items then
	minetest.register_alias_force("mobs:lasso","animalia:lasso")
	minetest.register_alias_force("mobs:saddle","animalia:saddle")
	minetest.register_alias_force("mobs:shears","animalia:shears")
	minetest.register_alias_force("mobs_animal:chicken_raw","animalia:poultry_raw")
	minetest.register_alias_force("mobs_animal:chicken_feather","animalia:feather")
	minetest.register_alias_force("mobs:meat_raw" ,"animalia:beef_raw")
	minetest.register_alias_force("mobs:meat","animalia:beef_cooked")
	minetest.register_alias_force("mobs_animal:mutton_raw","animalia:mutton_raw")
	minetest.register_alias_force("mobs_animal:mutton_cooked","animalia:mutton_cooked")
	minetest.register_alias_force("mobs:leather" ,"animalia:leather")
	minetest.register_alias_force("mobs_animal:egg","animalia:chicken_egg")
	minetest.register_alias_force("mobs_animal:chicken_egg_fried" ,"animalia:chicken_egg_fried")
	minetest.register_alias_force("mobs_animal:milk_bucket","animalia:bucket_milk")
	minetest.register_alias_force("mobs_animal:chicken_cooked" ,"animalia:poultry_cooked")
	minetest.register_alias_force("mobs_animal:pork_raw" ,"animalia:porkchop_raw")
	minetest.register_alias_force("mobs_animal:pork_cooked","animalia:porkchop_cooked")
end

minetest.log("action", "[MOD] Animalia [0.2] loaded")
