-------------
-- Chicken --
-------------

local clamp_bone_rot = animalia.clamp_bone_rot

local interp = animalia.interp

local random = math.random

local function chicken_logic(self)
	if self.hp <= 0 then
		mob_core.on_die(self)
		return
	end

	if self.status ~= "following" then
		if self.attention_span > 1 then
			self.attention_span = self.attention_span - self.dtime
			mobkit.remember(self, "attention_span", self.attention_span)
		end
	else
		self.attention_span = self.attention_span + self.dtime
		mobkit.remember(self, "attention_span", self.attention_span)
	end

	if self.fall_start
	and self.fall_start - mobkit.get_stand_pos(self).y > 2 then
		mobkit.animate(self, "flap")
		self.object:set_acceleration({x = 0, y = -3.1, z = 0})
	end

	animalia.head_tracking(self, 0.45, 0.25)

	if mobkit.timer(self, 4) then

		local prty = mobkit.get_queue_priority(self)
		local player = mobkit.get_nearby_player(self)

		mob_core.random_sound(self, 14)
		mob_core.random_drop(self, 10, 1800, "animalia:chicken_egg")

		if prty < 4
		and self.isinliquid then
			animalia.hq_go_to_land(self, 4)
		end

		if prty < 3
        and self.breeding then
            animalia.hq_fowl_breed(self, 3)
		end

		if prty == 2
		and not self.lasso_player
		and (not player
		or not mob_core.follow_holding(self, player)) then
			mobkit.clear_queue_high(self)
		end

        if prty < 2 then
			if self.caught_with_lasso
			and self.lasso_player then
				animalia.hq_follow_player(self, 2, self.lasso_player, true)
			elseif player then
				if self.attention_span < 5 then
					if mob_core.follow_holding(self, player) then
						animalia.hq_follow_player(self, 2, player)
						self.attention_span = self.attention_span + 1
					end
				end
			end
        end

		if mobkit.is_queue_empty_high(self) then
			animalia.hq_wander_group(self, 0, 8)
		end
	end
end

animalia.register_mob("chicken", {
	-- Stats
	health = 10,
	fleshy = 100,
	view_range = 8,
	lung_capacity = 10,
	-- Visual
	collisionbox = {-0.2, -0.15, -0.2, 0.2, 0.3, 0.2},
	visual_size = {x = 6, y = 6},
	mesh = "animalia_chicken.b3d",
	female_textures = {
		"animalia_chicken_1.png",
		"animalia_chicken_2.png",
		"animalia_chicken_3.png"
	},
	male_textures = {
		"animalia_rooster_1.png",
		"animalia_rooster_2.png",
		"animalia_rooster_3.png"
	},
	child_textures = {"animalia_chick.png"},
    animations = {
		stand = {range = {x = 0, y = 0}, speed = 1, frame_blend = 0.3, loop = true},
		walk = {range = {x = 10, y = 30}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 10, y = 30}, speed = 45, frame_blend = 0.3, loop = true},
        fall = {range = {x = 40, y = 60}, speed = 30, frame_blend = 0.3, loop = true},
	},
	-- Physics
	speed = 5,
	max_fall = 6,
	-- Attributes
    sounds = {
        alter_child_pitch = true,
        random = {
            name = "animalia_chicken_idle",
            gain = 0.5,
            distance = 8
        },
        hurt = {
            name = "animalia_chicken_hurt",
            gain = 0.5,
            distance = 8
        },
        death = {
            name = "animalia_chicken_death",
            gain = 0.5,
            distance = 8
        }
    },
	fall_damage = false,
	-- Behavior
	defend_owner = false,
	follow = {
		"farming:seed_cotton",
		"farming:seed_wheat"
	},
	drops = {
		{name = "animalia:feather", chance = 1, min = 1, max = 2},
		{name = "animalia:poultry_raw", chance = 1, min = 1, max = 4}
	},
	-- Functions
	head_data = {
		offset = {x = 0, y = 0.15, z = 0},
		pitch_correction = 55,
		pivot_h = 0.25,
		pivot_v = 0.55
	},
	logic = chicken_logic,
	get_staticdata = mobkit.statfunc,
	on_step = animalia.on_step,
	on_activate = animalia.on_activate,
    on_rightclick = function(self, clicker)
		if animalia.feed_tame(self, clicker, 1, false, true) then return end
		mob_core.protect(self, clicker, true)
		mob_core.nametag(self, clicker, true)
	end,
	on_punch = function(self, puncher, _, tool_capabilities, dir)
		mob_core.on_punch_basic(self, puncher, tool_capabilities, dir)
		animalia.hq_sporadic_flee(self, 10)
	end,
})

mob_core.register_spawn_egg("animalia:chicken", "c6c6c6", "d22222")

minetest.register_craftitem("animalia:poultry_raw", {
	description = "Raw Poultry",
	inventory_image = "animalia_poultry_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:poultry_cooked", {
	description = "Cooked Poultry",
	inventory_image = "animalia_poultry_cooked.png",
	on_use = minetest.item_eat(6),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:poultry_raw",
	output = "animalia:poultry_cooked",
})

minetest.register_entity("animalia:chicken_egg_sprite", {
    hp_max = 1,
    physical = true,
    collisionbox = {0, 0, 0, 0, 0, 0},
    visual = "sprite",
    visual_size = {x = 0.5, y = 0.5},
    textures = {"animalia_egg.png"},
    initial_sprite_basepos = {x = 0, y = 0},
    is_visible = true,
	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		local objects = minetest.get_objects_inside_radius(pos, 1.5)
		local cube = minetest.find_nodes_in_area(
			vector.new(pos.x - 0.5, pos.y - 0.5, pos.z - 0.5),
			vector.new(pos.x + 0.5, pos.y + 0.5, pos.z + 0.5),
			animalia.walkable_nodes)
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
				texture = "animalia_egg_fragment.png",
			})
			if random(1, 3) < 2 then
				mob_core.spawn_child(pos, "animalia:chicken")
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
	}, "animalia:chicken_egg_sprite")

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

minetest.register_craftitem("animalia:chicken_egg", {
	description = "Chicken Egg",
	inventory_image = "animalia_egg.png",
	on_use = mobs_shoot_egg,
	groups = {food_egg = 1, flammable = 2},
})

minetest.register_craftitem("animalia:chicken_egg_fried", {
	description = "Fried Chicken Egg",
	inventory_image = "animalia_egg_fried.png",
	on_use = minetest.item_eat(4),
	groups = {food_egg = 1, flammable = 2},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:chicken_egg",
	output = "animalia:chicken_egg_fried",
})

minetest.register_craftitem("animalia:feather", {
	description = "Feather",
	inventory_image = "animalia_feather.png",
	groups = {flammable = 2, feather = 1},
})