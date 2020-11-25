-------------
-- Chicken --
-------------

local blend = better_fauna.frame_blend

local random = math.random

local function chicken_logic(self)

	if self.hp <= 0 then
		mob_core.on_die(self)
		return
	end
	local prty = mobkit.get_queue_priority(self)
	local player = mobkit.get_nearby_player(self)

	if mobkit.timer(self,1) then

		mob_core.vitals(self)
		mob_core.random_drop(self, 10, 1800, "better_fauna:chicken_egg")
		mob_core.random_sound(self, 8)

		if prty < 3
        and self.breeding then
            better_fauna.hq_fowl_breed(self, 3)
		end
		
        if prty < 2
        and player then
            if self.attention_span < 5 then
                if mob_core.follow_holding(self, player) then
                    better_fauna.hq_follow_player(self, 2, player)
                    self.attention_span = self.attention_span + 1
                end
            end
		end

		if mobkit.is_queue_empty_high(self) then
			mob_core.hq_roam(self, 0)
		end
	end
end

minetest.register_entity("better_fauna:chicken",{
	max_hp = 10,
	view_range = 16,
	armor_groups = {fleshy = 100},
	physical = true,
	collide_with_objects = true,
	collisionbox = {-0.2, -0.15, -0.2, 0.2, 0.3, 0.2},
	visual_size = {x = 6, y = 6},
	scale_stage1 = 0.25,
    scale_stage2 = 0.5,
    scale_stage3 = 0.75,
	visual = "mesh",
	mesh = "better_fauna_chicken.b3d",
	female_textures = {
		"better_fauna_chicken_1.png",
		"better_fauna_chicken_2.png",
		"better_fauna_chicken_3.png"
	},
	male_textures = {
		"better_fauna_rooster_1.png",
		"better_fauna_rooster_2.png",
		"better_fauna_rooster_3.png"
	},
	child_textures = {"better_fauna_chick.png"},
    animation = {
		stand = {range = {x = 0, y = 0}, speed = 1, frame_blend = blend, loop = true},
		walk = {range = {x = 10, y = 30}, speed = 30, frame_blend = blend, loop = true},
		run = {range = {x = 10, y = 30}, speed = 45, frame_blend = blend, loop = true},
        fall = {range = {x = 40, y = 60}, speed = 30, frame_blend = blend, loop = true},
	},
    sounds = {
        alter_child_pitch = true,
        random = {
            name = "better_fauna_chicken_idle",
            gain = 1.0,
            distance = 8
        },
        hurt = {
            name = "better_fauna_chicken_hurt",
            gain = 1.0,
            distance = 8
        },
        death = {
            name = "better_fauna_chicken_death",
            gain = 1.0,
            distance = 8
        }
    },
	max_speed = 4,
	stepheight = 1.1,
	jump_height = 1.1,
	buoyancy = 0.25,
	lung_capacity = 10,
    timeout = 1200,
    ignore_liquidflag = false,
    core_growth = false,
	push_on_collide = true,
	catch_with_net = true,
	follow = {
		"farming:seed_cotton",
		"farming:seed_wheat"
	},
	drops = {
		{name = "better_fauna:feather", chance = 1, min = 1, max = 2},
		{name = "better_fauna:chicken_raw", chance = 1, min = 1, max = 4}
	},
	on_step = better_fauna.on_step,
	on_activate = better_fauna.on_activate,
	get_staticdata = mobkit.statfunc,
	phsyics = better_fauna.lightweight_physics,
	logic = chicken_logic,
    on_rightclick = function(self, clicker)
		if better_fauna.feed_tame(self, clicker, 1, false, true) then return end
		mob_core.protect(self, clicker, false)
		mob_core.nametag(self, clicker, true)
	end,
	on_punch = function(self, puncher, _, tool_capabilities, dir)
		mobkit.clear_queue_high(self)
		mob_core.on_punch_basic(self, puncher, tool_capabilities, dir)
		better_fauna.hq_sporadic_flee(self, 10, puncher)
	end,
})

mob_core.register_spawn_egg("better_fauna:chicken", "c6c6c6", "d22222")

mob_core.register_spawn({
	name = "better_fauna:chicken",
	nodes = {"default:dry_dirt_with_dry_grass", "default:dirt_with_grass"},
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	min_rad = 24,
	max_rad = 256,
	group = 6,
	optional = {
		biomes = {
			"grassland",
			"savanna",
			"rainforest"
		}
	}
}, 16, 6)


minetest.register_craftitem("better_fauna:chicken_raw", {
	description = "Raw Chicken",
	inventory_image = "better_fauna_chicken_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2},
})

minetest.register_craftitem("better_fauna:chicken_cooked", {
	description = "Cooked Chicken",
	inventory_image = "better_fauna_chicken_cooked.png",
	on_use = minetest.item_eat(6),
	groups = {flammable = 2},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "better_fauna:chicken_raw",
	output = "better_fauna:chicken_cooked",
})

minetest.register_entity("better_fauna:chicken_egg_sprite", {
    hp_max = 1,
    physical = true,
    collisionbox = {0, 0, 0, 0, 0, 0},
    visual = "sprite",
    visual_size = {x = 0.5, y = 0.5},
    textures = {"better_fauna_egg.png"},
    initial_sprite_basepos = {x = 0, y = 0},
    is_visible = true,
	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		local objects = minetest.get_objects_inside_radius(pos, 1.5)
		local cube = minetest.find_nodes_in_area(
			vector.new(pos.x - 0.5, pos.y - 0.5, pos.z - 0.5),
			vector.new(pos.x + 0.5, pos.y + 0.5, pos.z + 0.5),
			better_fauna.walkable_nodes)
		if #objects >= 2 then
			if objects[2]:get_armor_groups().fleshy then
				objects[2]:punch(self.object, 2.0, {full_punch_interval = 0.1, damage_groups = {fleshy = 1}}, nil)
			end
		end
		if #cube >= 1 then
			minetest.add_particlespawner({
				amount = 6,
				time = 0.25,
				minpos = {x = pos.x - 7/16, y = pos.y - 5/16, z = pos.z - 7/16},
				maxpos = {x = pos.x + 7/16, y = pos.y - 5/16, z = pos.z + 7/16},
				minvel = vector.new(-1, 2, -1),
				maxvel = vector.new(1, 5, 1),
				minacc = vector.new(0, -9.81, 0),
				maxacc = vector.new(0, -9.81, 0),
				collisiondetection = true,
				texture = "better_fauna_egg_fragment.png",
			})
			if random(1, 3) == 1 then
				mob_core.spawn_child(pos, "better_fauna:chicken")
				self.object:remove()
			else
				self.object:remove()
			end
		end
	end
})

local mobs_shoot_egg = function (item, player, pointed_thing)
	local pos = player:get_pos()

	minetest.sound_play("default_place_node_hard", {
		pos = pos,
		gain = 1.0,
		max_hear_distance = 5,
	})

	local vel = 19
	local gravity = 9

	local obj = minetest.add_entity({
		x = pos.x,
		y = pos.y +1.5,
		z = pos.z
	}, "better_fauna:chicken_egg_sprite")

	local ent = obj:get_luaentity()
	local dir = player:get_look_dir()

	ent.velocity = vel -- needed for api internal timing
	ent.switch = 1 -- needed so that egg doesn't despawn straight away

	obj:set_velocity({
		x = dir.x * vel,
		y = dir.y * vel,
		z = dir.z * vel
	})

	obj:set_acceleration({
		x = dir.x * -3,
		y = -gravity,
		z = dir.z * -3
	})

	-- pass player name to egg for chick ownership
	local ent2 = obj:get_luaentity()
	ent2.playername = player:get_player_name()

	item:take_item()

	return item
end

minetest.register_craftitem("better_fauna:chicken_egg", {
	description = "Chicken Egg",
	inventory_image = "better_fauna_egg.png",
	on_use = mobs_shoot_egg,
	groups = {flammable = 2},
})