----------
-- Mice --
----------

creatura.register_mob("animalia:rat", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_rat.b3d",
	textures = {
		"animalia_rat_1.png",
		"animalia_rat_2.png",
		"animalia_rat_3.png"
	},

	-- Creatura Props
	max_health = 5,
	damage = 0,
	speed = 1,
	tracking_range = 8,
	despawn_after = 200,
	stepheight = 1.1,
	--sound = {},
	hitbox = {
		width = 0.15,
		height = 0.3
	},
	animations = {
		stand = {range = {x = 1, y = 39}, speed = 20, frame_blend = 0.3, loop = true},
		walk = {range = {x = 51, y = 69}, speed = 20, frame_blend = 0.3, loop = true},
		run = {range = {x = 81, y = 99}, speed = 45, frame_blend = 0.3, loop = true},
		eat = {range = {x = 111, y = 119}, speed = 20, frame_blend = 0.1, loop = false}
	},
	drops = {
		{name = "animalia:rat_raw", min = 1, max = 1, chance = 1}
	},

	-- Behavior Parameters
	is_skittish_mob = true,

	-- Animalia Props
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = false,

	-- Functions
	utility_stack = {
		animalia.mob_ai.basic_wander,
		animalia.mob_ai.swim_seek_land,
		animalia.mob_ai.basic_seek_crop,
		animalia.mob_ai.rat_seek_chest,
		animalia.mob_ai.basic_flee
	},

	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.do_growth(self, 60)
	end,

	death_func = function(self)
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
	end,

	on_rightclick = function(self, clicker)
		if animalia.set_nametag(self, clicker) then
			return
		end
	end,

	on_punch = animalia.punch
})

creatura.register_spawn_item("animalia:rat", {
	col1 = "605a55",
	col2 = "ff936f"
})
