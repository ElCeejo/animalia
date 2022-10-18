----------
-- Mice --
----------

creatura.register_mob("animalia:rat", {
	-- Stats
	max_health = 5,
	armor_groups = {fleshy = 100},
	damage = 0,
	speed = 3,
	tracking_range = 12,
	despawn_after = 2500,
	-- Entity Physics
	stepheight = 1.1,
	max_fall = 0,
	turn_rate = 12,
	bouyancy_multiplier = 0.5,
	-- Visuals
	mesh = "animalia_rat.b3d",
	hitbox = {
		width = 0.15,
		height = 0.3
	},
	visual_size = {x = 10, y = 10},
	textures = {
		"animalia_rat_1.png",
		"animalia_rat_2.png",
		"animalia_rat_3.png"
	},
	animations = {
		stand = {range = {x = 1, y = 39}, speed = 20, frame_blend = 0.3, loop = true},
		walk = {range = {x = 51, y = 69}, speed = 20, frame_blend = 0.3, loop = true},
		run = {range = {x = 81, y = 99}, speed = 45, frame_blend = 0.3, loop = true},
		eat = {range = {x = 111, y = 119}, speed = 20, frame_blend = 0.1, loop = false}
	},
	-- Misc
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = false,
	makes_footstep_sound = false,
	drops = {
		{name = "animalia:rat_raw", min = 1, max = 1, chance = 1}
	},
	-- Function
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
					return 0.3, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:eat_crop",
			get_score = function(self)
				if math.random(6) < 2
				or self:get_utility() == "animalia:eat_crop" then
					return 0.2, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:steal_from_chest",
			get_score = function(self)
				if math.random(12) < 2
				or self:get_utility() == "animalia:steal_from_chest" then
					return 0.2, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:flee_from_target",
			get_score = function(self)
				local target = creatura.get_nearby_object(self, {"animalia:fox", "animalia:cat"})
				if not target then
					target = creatura.get_nearby_player(self)
				end
				if target
				and target:get_pos() then
					return 0.6, {self, target}
				end
				return 0
			end
		}
	},
	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
	end,
	step_func = function(self)
		animalia.step_timers(self)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
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

creatura.register_spawn_egg("animalia:rat", "605a55", "ff936f")