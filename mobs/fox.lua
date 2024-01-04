---------
-- Fox --
---------

creatura.register_mob("animalia:fox", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_fox.b3d",
	textures = {
		"animalia_fox_1.png"
	},
	makes_footstep_sound = false,

	-- Creatura Props
	max_health = 10,
	armor_groups = {fleshy = 100},
	damage = 2,
	speed = 4,
	tracking_range = 16,
	max_boids = 0,
	despawn_after = 500,
	stepheight = 1.1,
	sound = {},
	hitbox = {
		width = 0.35,
		height = 0.5
	},
	animations = {
		stand = {range = {x = 1, y = 39}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 41, y = 59}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 41, y = 59}, speed = 45, frame_blend = 0.3, loop = true},
	},
	follow = {
		"animalia:rat_raw",
		"animalia:mutton_raw",
		"animalia:beef_raw",
		"animalia:porkchop_raw",
		"animalia:poultry_raw"
	},

	-- Behavior Parameters
	is_skittish_mob = true,
	attack_list = {
		"animalia:chicken",
		"animalia:rat"
	},

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
		animalia.mob_ai.fox_flee,
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

creatura.register_spawn_item("animalia:fox", {
	col1 = "d0602d",
	col2 = "c9c9c9"
})