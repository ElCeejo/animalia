--------------
-- Reindeer --
--------------

local random = math.random

creatura.register_mob("animalia:reindeer", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_reindeer.b3d",
	textures = {"animalia_reindeer.png"},
	child_textures = {"animalia_reindeer_calf.png"},
	makes_footstep_sound = true,

	-- Creatura Props
	max_health = 15,
	damage = 0,
	speed = 3,
	tracking_range = 12,
	max_boids = 4,
	despawn_after = 500,
	stepheight = 1.1,
	--sound = {},
	hitbox = {
		width = 0.45,
		height = 0.9
	},
	animations = {
		stand = {range = {x = 1, y = 59}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 89}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 100, y = 119}, speed = 40, frame_blend = 0.3, loop = true},
		eat = {range = {x = 130, y = 150}, speed = 20, frame_blend = 0.3, loop = false}
	},
	follow = animalia.food_wheat,
	drops = {
		{name = "animalia:venison_raw", min = 1, max = 3, chance = 1},
		{name = "animalia:leather", min = 1, max = 3, chance = 2}
	},

	-- Animalia Props
	group_wander = true,
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = true,
	consumable_nodes = {
		{
			name = "default:dirt_with_grass",
			replacement = "default:dirt"
		},
		{
			name = "default:dry_dirt_with_dry_grass",
			replacement = "default:dry_dirt"
		}
	},
	head_data = {
		offset = {x = 0, y = 0.7, z = 0},
		pitch_correction = -45,
		pivot_h = 1,
		pivot_v = 1
	},

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
			utility = "animalia:eat_turf",
			step_delay = 0.25,
			get_score = function(self)
				if random(64) < 2 then
					return 0.2, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:swim_to_land",
			step_delay = 0.25,
			get_score = function(self)
				if self.in_liquid then
					return 0.3, {self}
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
					return 0.5, {self}
				end
				return 0
			end
		},
		animalia.global_utils.basic_flee
	},

	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
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

creatura.register_spawn_item("animalia:reindeer", {
	col1 = "413022",
	col2 = "d5c0a3"
})