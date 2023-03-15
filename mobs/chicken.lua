-------------
-- Chicken --
-------------

creatura.register_mob("animalia:chicken", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
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
	child_textures = {"animalia_chicken_child.png"},
	makes_footstep_sound = true,

	-- Creatura Props
	max_health = 5,
	armor_groups = {fleshy = 100},
	damage = 0,
	speed = 2,
	tracking_range = 8,
	max_boids = 3,
	despawn_after = 500,
	max_fall = 0,
	stepheight = 1.1,
	sounds = {
		random = {
			name = "animalia_chicken",
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
	hitbox = {
		width = 0.25,
		height = 0.5
	},
	animations = {
		stand = {range = {x = 1, y = 39}, speed = 20, frame_blend = 0.3, loop = true},
		walk = {range = {x = 41, y = 59}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 41, y = 59}, speed = 45, frame_blend = 0.3, loop = true},
		eat = {range = {x = 61, y = 89}, speed = 45, frame_blend = 0.3, loop = true},
		fall = {range = {x = 91, y = 99}, speed = 70, frame_blend = 0.3, loop = true}
	},
	follow = animalia.food_seeds,
	drops = {
		{name = "animalia:poultry_raw", min = 1, max = 3, chance = 1},
		{name = "animalia:feather", min = 1, max = 3, chance = 2}
	},

	-- Animalia Props
	group_wander = true,
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = true,
	head_data = {
		offset = {x = 0, y = 0.45, z = 0},
		pitch_correction = 40,
		pivot_h = 0.25,
		pivot_v = 0.55
	},
	move_chance = 2,
	idle_time = 1,

	-- Functions
	utility_stack = {
		{
			utility = "animalia:wander",
			step_delay = 0.25,
			get_score = function(self)
				return 0.1, {self}
			end
		},
		{
			utility = "animalia:swim_to_land",
			step_delay = 0.25,
			get_score = function(self)
				if self.in_liquid then
					return 0.5, {self}
				end
				return 0
			end
		},
		animalia.global_utils.basic_follow,
		{
			utility = "animalia:breed",
			step_delay = 0.25,
			get_score = function(self)
				if self.breeding
				and animalia.get_nearby_mate(self, self.name) then
					return 0.4, {self}
				end
				return 0
			end
		},
		animalia.global_utils.basic_flee
	},

	add_child = function(self)
		local pos = self.object:get_pos()
		if not pos then return end
		animalia.particle_spawner(pos, "animalia_egg_fragment.png", "splash", pos, pos)
		local object = minetest.add_entity(pos, self.name)
		local ent = object:get_luaentity()
		ent.growth_scale = 0.7
		animalia.initialize_api(ent)
		animalia.protect_from_despawn(ent)
	end,

	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self, 0.75, 0.75)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
		animalia.random_sound(self)
		if self.fall_start then
			self:set_gravity(-4.9)
			self:animate("fall")
		end
		if (self.growth_scale or 1) > 0.8
		and self.gender == "female"
		and self:timer(60) then
			animalia.random_drop_item(self, "animalia:chicken_egg", 10)
		end
	end,

	death_func = function(self)
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
	end,

	on_rightclick = function(self, clicker)
		if animalia.feed(self, clicker, false, true) then
			return
		end
		animalia.set_nametag(self, clicker)
	end,

	on_punch = animalia.punch
})

creatura.register_spawn_item("animalia:chicken", {
	col1 = "c6c6c6",
	col2 = "d22222"
})
