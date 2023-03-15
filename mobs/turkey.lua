------------
-- Turkey --
------------

creatura.register_mob("animalia:turkey", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_turkey.b3d",
	female_textures = {"animalia_turkey_hen.png"},
	male_textures = {"animalia_turkey_tom.png"},
	child_textures = {"animalia_turkey_chick.png"},
	makes_footstep_sound = true,

	-- Creatura Props
	max_health = 8,
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
			name = "animalia_turkey",
			gain = 0.5,
			distance = 8
		},
		hurt = {
			name = "animalia_turkey_hurt",
			gain = 0.5,
			distance = 8
		},
		death = {
			name = "animalia_turkey_death",
			gain = 0.5,
			distance = 8
		}
	},
	hitbox = {
		width = 0.3,
		height = 0.6
	},
	animations = {
		stand = {range = {x = 0, y = 0}, speed = 1, frame_blend = 0.3, loop = true},
		walk = {range = {x = 10, y = 30}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 40, y = 60}, speed = 45, frame_blend = 0.3, loop = true},
		fall = {range = {x = 70, y = 90}, speed = 30, frame_blend = 0.3, loop = true},
	},
	follow = animalia.food_seeds,
	drops = {
		{name = "animalia:poultry_raw", min = 1, max = 4, chance = 1},
		{name = "animalia:feather", min = 1, max = 3, chance = 2}
	},

	-- Animalia Props
	group_wander = true,
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = true,
	head_data = {
		offset = {x = 0, y = 0.15, z = 0},
		pitch_correction = 45,
		pivot_h = 0.45,
		pivot_v = 0.65
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
			animalia.random_drop_item(self, "animalia:turkey_egg", 10)
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

creatura.register_spawn_item("animalia:turkey", {
	col1 = "352b22",
	col2 = "2f2721"
})
