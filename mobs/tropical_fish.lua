----------
-- Fish --
----------

creatura.register_mob("animalia:tropical_fish", {
    -- Stats
    max_health = 5,
    armor_groups = {fleshy = 150},
    damage = 0,
    speed = 2,
	tracking_range = 6,
    despawn_after = 2500,
	-- Entity Physics
	stepheight = 0.1,
	max_fall = 8,
	turn_rate = 8,
	boid_seperation = 0.3,
	bouyancy_multiplier = 0,
    -- Visuals
    mesh = "animalia_clownfish.b3d",
	hitbox = {
		width = 0.15,
		height = 0.3
	},
    visual_size = {x = 7, y = 7},
	textures = {
		"animalia_clownfish.png",
		"animalia_blue_tang.png",
		"animalia_angelfish.png"
	},
    animations = {
		swim = {range = {x = 1, y = 20}, speed = 20, frame_blend = 0.3, loop = true},
		flop = {range = {x = 30, y = 40}, speed = 20, frame_blend = 0.3, loop = true},
	},
    -- Misc
	catch_with_net = true,
	catch_with_lasso = false,
	makes_footstep_sound = false,
    -- Function
	utility_stack = {
		{
			utility = "animalia:schooling",
			get_score = function(self)
				return 0.1, {self}
			end
		},
		{
			utility = "animalia:flop",
			get_score = function(self)
				if not self.in_liquid then
					self:hurt(1)
					return 1, {self}
				end
				return 0
			end
		},
	},
    activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
		if self.texture_no == 3 then
			self.object:set_properties({
				mesh = "animalia_angelfish.b3d",
			})
		end
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
		animalia.add_libri_page(self, clicker, {name = "tropical_fish", form = "pg_tropical_fish;Tropical Fish"})
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
	end
})

creatura.register_spawn_egg("animalia:tropical_fish", "e28821", "f6e5d2")

animalia.alias_mob("animalia:clownfish", "animalia:tropical_fish")
animalia.alias_mob("animalia:blue_tang", "animalia:tropical_fish")
animalia.alias_mob("animalia:angelfish", "animalia:tropical_fish")