----------
-- Frog --
----------

local random = math.random

local vec_dist = vector.distance

creatura.register_mob("animalia:frog", {
    -- Stats
    max_health = 5,
    armor_groups = {fleshy = 200},
    damage = 0,
    speed = 4,
	tracking_range = 16,
    despawn_after = 2500,
	-- Entity Physics
	stepheight = 1.1,
	max_fall = 100,
	turn_rate = 10,
	bouyancy_multiplier = 0,
    -- Visuals
    mesh = "animalia_frog.b3d",
    hitbox = {
		width = 0.15,
		height = 0.3
	},
    visual_size = {x = 7, y = 7},
	textures = {
		"animalia_frog_1.png",
		"animalia_frog_2.png"
	},
	child_textures = {
		"animalia_tadpole.png"
	},
	animations = {
		stand = {range = {x = 1, y = 40}, speed = 10, frame_blend = 0.3, loop = true},
		float = {range = {x = 90, y = 90}, speed = 1, frame_blend = 0.3, loop = true},
		swim = {range = {x = 90, y = 110}, speed = 50, frame_blend = 0.3, loop = true},
		walk = {range = {x = 50, y = 80}, speed = 50, frame_blend = 0.3, loop = true}
	},
    -- Misc
	makes_footstep_sound = true,
	catch_with_net = true,
	catch_with_lasso = true,
	sounds = {
		random = {
            name = "animalia_frog",
            gain = 0.5,
            distance = 32,
			variations = 3
        }
    },
    follow = {
		"butterflies:butterfly_red",
		"butterflies:butterfly_white",
		"butterflies:butterfly_violet"
	},
	head_data = {
		offset = {x = 0, y = 0.43, z = 0},
		pitch_correction = -15,
		pivot_h = 0.3,
		pivot_v = 0.3
	},
    -- Function
	utility_stack = {
		[1] = {
			utility = "animalia:wander",
			get_score = function(self)
				return 0.1, {self}
			end
		},
		[2] = {
			utility = "animalia:wander_water_surface",
			get_score = function(self)
				if self.in_liquid then
					return 0.11, {self}
				end
				return 0
			end
		},
		[3] = {
			utility = "animalia:eat_bug_nodes",
			get_score = function(self)
				local pos = self.object:get_pos()
				if math.random(12) * 0.01 then
					local food = minetest.find_nodes_in_area(vector.subtract(pos, 1.5), vector.add(pos, 1.5), self.follow)
					if food[1] then
						return 0.2, {self}
					end
				end
				return 0
			end
		},
		[4] = {
			utility = "animalia:flop",
			get_score = function(self)
				if not self.in_liquid
				and self.growth_scale <= 0.6 then
					return 1
				end
				return 0
			end
		},
		[5] = {
			utility = "animalia:breed_water_surface",
			get_score = function(self)
				if self.breeding
				and animalia.get_nearby_mate(self, self.name)
				and self.in_liquid then
					return 1
				end
				return 0
			end
		},
		[6] = {
			utility = "animalia:flee_from_player",
			get_score = function(self)
				if self.in_liquid then return 0 end
				local player = creatura.get_nearby_player(self)
				if player
				and player:get_player_name() then
					local trust = self.trust[player:get_player_name()] or 0
					self._nearby_player = player -- stored to memory to avoid calling get_nearby_player again
					return (10 - (vec_dist(self.object:get_pos(), player:get_pos()) + trust)) * 0.1, {self, player}
				end
				return 0
			end
		},
		[7] = {
			utility = "animalia:flee_to_water",
			get_score = function(self)
				if self.in_liquid then return 0 end
				local pos = self.object:get_pos()
				local water = minetest.find_nodes_in_area(vector.subtract(pos, 1.5), vector.add(pos, 1.5), {"default:water_source"})
				if not water[1] then return 0 end
				local player = self._nearby_player
				if player
				and player:get_player_name() then
					local trust = self.trust[player:get_player_name()] or 0
					return (10 - (vec_dist(self.object:get_pos(), player:get_pos()) + trust)) * 0.1, {self, player}
				end
				return 0
			end
		}
	},
    activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
		self.trust = self:recall("trust") or {}
		for i = 1, 15 do
			local frame = 120 + i
			local anim = {range = {x = frame, y = frame}, speed = 1, frame_blend = 0.3, loop = false}
			self.animations["tongue_" .. i] = anim
		end
    end,
    step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self, 0.2, 0.2)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
		if self:timer(random(5, 10)) then
			self:play_sound("random")
		end
		local props = self.object:get_properties()
		if self.growth_scale <= 0.6
		and props.mesh ~= "animalia_tadpole.b3d" then
			self.object:set_properties({
				mesh = "animalia_tadpole.b3d"
			})
		end
    end,
    death_func = function(self)
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
    end,
	on_rightclick = function(self, clicker)
		if animalia.feed(self, clicker, false, true) then
			local name = clicker:get_player_name()
			if self.trust[name] then
				self.trust[name] = self.trust[name] + 1
			else
				self.trust[name] = 1
			end
			if self.trust[name] > 5 then self.trust[name] = 5 end
			self:memorize("trust", self.trust)
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
		animalia.add_libri_page(self, clicker, {name = "frog", form = "pg_frog;Frogs"})
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		self.trust[puncher:get_player_name()] = 0
		self:memorize("trust", self.trust)
	end
})

creatura.register_spawn_egg("animalia:frog", "67942e", "294811")