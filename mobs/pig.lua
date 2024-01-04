---------
-- Pig --
---------

creatura.register_mob("animalia:pig", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_pig.b3d",
	female_textures = {
		"animalia_pig_1.png",
		"animalia_pig_2.png",
		"animalia_pig_3.png"
	},
	male_textures = {
		"animalia_pig_1.png^animalia_pig_tusks.png",
		"animalia_pig_2.png^animalia_pig_tusks.png",
		"animalia_pig_3.png^animalia_pig_tusks.png"
	},
	child_textures = {
		"animalia_pig_1.png",
		"animalia_pig_2.png",
		"animalia_pig_3.png"
	},
	makes_footstep_sound = true,

	-- Creatura Props
	max_health = 20,
	damage = 2,
	speed = 3,
	tracking_range = 12,
	despawn_after = 500,
	stepheight = 1.1,
	sounds = {
		random = {
			name = "animalia_pig",
			gain = 1.0,
			distance = 8
		},
		hurt = {
			name = "animalia_pig_hurt",
			gain = 1.0,
			distance = 8
		},
		death = {
			name = "animalia_pig_death",
			gain = 1.0,
			distance = 8
		}
	},
	hitbox = {
		width = 0.35,
		height = 0.7
	},
	animations = {
		stand = {range = {x = 1, y = 60}, speed = 20, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 89}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 100, y = 119}, speed = 40, frame_blend = 0.3, loop = true},
	},
	follow = animalia.food_crops,
	drops = {
		{name = "animalia:porkchop_raw", min = 1, max = 3, chance = 1}
	},

	-- Behavior Parameters
	is_herding_mob = true,

	-- Animalia Props
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = true,
	birth_count = 2,
	head_data = {
		offset = {x = 0, y = 0.7, z = 0},
		pitch_correction = 0,
		pivot_h = 0.5,
		pivot_v = 0.3
	},

	-- Functions
	utility_stack = {
		animalia.mob_ai.basic_wander,
		animalia.mob_ai.swim_seek_land,
		animalia.mob_ai.basic_seek_crop,
		animalia.mob_ai.tamed_follow_owner,
		animalia.mob_ai.basic_breed,
		animalia.mob_ai.basic_flee
	},

	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.do_growth(self, 60)
		animalia.head_tracking(self)
		animalia.update_lasso_effects(self)
		animalia.random_sound(self)
	end,

	death_func = animalia.death_func,

	on_rightclick = function(self, clicker)
		if animalia.feed(self, clicker, false, true) then
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
	end,

	on_punch = animalia.punch
})

creatura.register_spawn_item("animalia:pig", {
	col1 = "e0b1a7",
	col2 = "cc9485"
})