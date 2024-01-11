-------------
-- Opossum --
-------------

creatura.register_mob("animalia:opossum", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_opossum.b3d",
	textures = {
		"animalia_opossum.png"
	},
	makes_footstep_sound = false,

	-- Creatura Props
	max_health = 5,
	armor_groups = {fleshy = 100},
	damage = 2,
	speed = 4,
	tracking_range = 16,
	max_boids = 0,
	despawn_after = 500,
	stepheight = 1.1,
	max_fall = 8,
	sound = {},
	hitbox = {
		width = 0.25,
		height = 0.4
	},
	animations = {
		stand = {range = {x = 1, y = 59}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 89}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 100, y = 119}, speed = 45, frame_blend = 0.3, loop = true},
		feint = {range = {x = 130, y = 130}, speed = 45, frame_blend = 0.3, loop = false},
		clean_crop = {range = {x = 171, y = 200}, speed = 15, frame_blend = 0.2, loop = false}
	},
	follow = {
		"animalia:song_bird_egg",
		"animalia:rat_raw",
		"animalia:mutton_raw",
		"animalia:beef_raw",
		"animalia:porkchop_raw",
		"animalia:poultry_raw"
	},

	-- Behavior Parameters
	is_skittish_mob = true,
	attack_list = {"animalia:rat"},

	-- Animalia Props
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = true,
	head_data = {
		offset = {x = 0, y = 0.18, z = 0},
		pitch_correction = -67,
		pivot_h = 0.65,
		pivot_v = 0.65
	},

	-- Functions
	utility_stack = {
		animalia.mob_ai.basic_wander,
		animalia.mob_ai.swim_seek_land,
		animalia.mob_ai.basic_attack,
		animalia.mob_ai.opossum_feint,
		animalia.mob_ai.opossum_seek_crop,
		animalia.mob_ai.basic_seek_food,
		animalia.mob_ai.tamed_follow_owner,
		animalia.mob_ai.basic_breed
	},

	on_eat_drop = function(self)
		animalia.protect_from_despawn(self)
	end,

	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self, 0.5, 0.75)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
	end,

	death_func = animalia.death_func,

	on_rightclick = function(self, clicker)
		if animalia.feed(self, clicker, true, true) then
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
	end,

	on_punch = animalia.punch
})

creatura.register_spawn_item("animalia:opossum", {
	col1 = "75665f",
	col2 = "ccbfb8"
})
