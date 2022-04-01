---------
-- Cat --
---------

local follow = {
	"animalia:poultry_raw"
}

if minetest.registered_items["ethereal:fish_raw"] then
	follow = {
		"ethereal:fish_raw",
		"animalia:poultry_raw"
	}
end

creatura.register_mob("animalia:cat", {
    -- Stats
    max_health = 10,
    armor_groups = {fleshy = 200},
    damage = 1,
    speed = 5,
	tracking_range = 24,
    despawn_after = 2000,
	-- Entity Physics
	stepheight = 1.1,
    -- Visuals
    mesh = "animalia_cat.b3d",
	hitbox = {
		width = 0.2,
		height = 0.4
	},
	visual_size = {x = 6, y = 6},
	textures = {
		"animalia_cat_1.png",
		"animalia_cat_2.png",
		"animalia_cat_3.png",
		"animalia_cat_4.png"
	},
	animations = {
		stand = {range = {x = 1, y = 39}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 50, y = 90}, speed = 45, frame_blend = 0.3, loop = true},
		run = {range = {x = 100, y = 130}, speed = 50, frame_blend = 0.3, loop = true},
		sit = {range = {x = 140, y = 180}, speed = 10, frame_blend = 0.3, loop = true},
		smack = {range = {x = 190, y = 210}, speed = 40, frame_blend = 0.1, loop = true},
	},
    -- Misc
	catch_with_net = true,
	catch_with_lasso = true,
	sounds = {
        random = {
            name = "animalia_cat_idle",
            gain = 0.25,
            distance = 8
        },
		purr = {
            name = "animalia_cat_purr",
            gain = 0.6,
            distance = 8
        },
        hurt = {
            name = "animalia_cat_hurt",
            gain = 0.25,
            distance = 8
        },
        death = {
            name = "animalia_cat_hurt",
            gain = 0.25,
            distance = 8
        }
	},
    follow = follow,
	head_data = {
		offset = {x = 0, y = 0.22, z = 0},
		pitch_correction = -20,
		pivot_h = 0.65,
		pivot_v = 0.65
	},
    -- Function
    activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
        self._path = {}
		self.interact_sound_cooldown = 0
		self.trust_cooldown = self:recall("trust_cooldown") or 0
		self.order = self:recall("order") or "wander"
		self.owner = self:recall("owner") or nil
		self.trust = self:recall("trust") or {}
		if self.owner
		and minetest.get_player_by_name(self.owner) then
			if not animalia.pets[self.owner][self.object] then
				table.insert(animalia.pets[self.owner], self.object)
			end
		end
    end,
	utility_stack = {
		[1] = {
			utility = "animalia:skittish_wander",
			get_score = function(self)
				return 0.1, {self}
			end
		},
		[2] = {
			utility = "animalia:swim_to_land",
			get_score = function(self)
				if self.in_liquid then
					return 0.9, {self}
				end
				return 0
			end
		},
		[3] = {
			utility = "animalia:find_and_break_glass_vessels",
			get_score = function(self)
				return math.random(10) * 0.01, {self}
			end
		},
		[4] = {
			utility = "animalia:walk_ahead_of_player",
			get_score = function(self)
				local player = creatura.get_nearby_player(self)
				if player
				and player:get_player_name() then
					local trust = 0
					if not self.trust[player:get_player_name()] then
						self.trust[player:get_player_name()] = 0
						self:memorize("trust", self.trust)
					else
						trust = self.trust[player:get_player_name()]
					end
					self._nearby_player = player
					if trust > 3 then
						return math.random(10) * 0.01, {self, player}
					else
						return 0
					end
				end
				return 0
			end
		},
		[5] = {
			utility = "animalia:sit",
			get_score = function(self)
				if self.order == "sit"
				and self.trust[self.owner] > 7 then
					return 0.8, {self}
				end
				return 0
			end
		},
		[6] = {
			utility = "animalia:follow_player",
			get_score = function(self)
				if self.order == "follow"
				and minetest.get_player_by_name(self.owner)
				and self.trust[self.owner] > 7 then
					return 1, {self, minetest.get_player_by_name(self.owner)}
				end
				local trust = 0
				local player = self._nearby_player
				if player
				and player:get_player_name() then
					if not self.trust[player:get_player_name()] then
						self.trust[player:get_player_name()] = 0
						self:memorize("trust", self.trust)
					else
						trust = self.trust[player:get_player_name()]
					end
				else
					return 0
				end
				if player:get_velocity()
				and vector.length(player:get_velocity()) < 2
				and self:follow_wielded_item(player)
				and trust >= 4 then
					return 0.6, {self, player}
				elseif player:get_wielded_item():get_name() == "animalia:cat_toy" then
					return 0.6, {self, player, true}
				end
				return 0
			end
		},
		[7] = {
			utility = "animalia:mammal_breed",
			get_score = function(self)
				if self.breeding
				and animalia.get_nearby_mate(self, self.name) then
					return 0.7, {self}
				end
				return 0
			end
		}
	},
    step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self, 0.75, 0.75)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
		if self:timer(1) then
			if self.trust_cooldown > 0 then
				self.trust_cooldown = self:memorize("trust_cooldown", self.trust_cooldown - 1)
			end
			if self.interact_sound_cooldown > 0 then
				self.interact_sound_cooldown = self.interact_sound_cooldown - 1
			end
		end
    end,
    death_func = function(self)
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
    end,
	on_rightclick = function(self, clicker)
		local item_name = clicker:get_wielded_item():get_name()
		if item_name == "animalia:net" then return end
		local trust = self.trust[clicker:get_player_name()] or 0
		local pos = self:get_center_pos()
		local minppos = vector.add(pos, 1)
		local maxppos = vector.subtract(pos, 1)
		if animalia.feed(self, clicker, true, true) then
			if self.trust_cooldown <= 0
			and trust < 10 then
				self.trust[clicker:get_player_name()] = trust + 1
				self.trust_cooldown = self:memorize("trust_cooldown", 60)
				self:memorize("trust", self.trust)
				animalia.particle_spawner(pos, "creatura_particle_green.png", "float", minppos, maxppos)
			end
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
		-- Initiate trust
		if not self.trust[clicker:get_player_name()] then
			self.trust[clicker:get_player_name()] = 0
			self:memorize("trust", self.trust)
		end
		-- Increase trust by playing
		if item_name == "animalia:cat_toy"
		and self:get_utility() == "animalia:follow_player" then
			if trust < 10 then
				self.trust[clicker:get_player_name()] = trust + 1
				self:memorize("trust", self.trust)
				animalia.particle_spawner(pos, "creatura_particle_green.png", "float", minppos, maxppos)
				if self.interact_sound_cooldown <= 0 then
					self.sounds["purr"].gain = 1
					self.interact_sound_cooldown = 3
					self:play_sound("purr")
				end
			end
		end
		-- Purr to indicate trust level (louder = more trust)
		if clicker:get_player_control().sneak then
			if self.interact_sound_cooldown <= 0 then
				self.sounds["purr"].gain = 0.15 * trust
				self.interact_sound_cooldown = 3
				self:play_sound("purr")
			end
		end
		animalia.add_libri_page(self, clicker, {name = "cat", form = "pg_cat;Cats"})
		if not self.owner
		or clicker:get_player_name() ~= self.owner then
			return
		end
		if trust <= 7 then
			if self.interact_sound_cooldown <= 0 then
				self.interact_sound_cooldown = 3
				self:play_sound("random")
			end
			return
		end
		if clicker:get_player_control().sneak then
			if self.interact_sound_cooldown <= 0 then
				self.sounds["purr"].gain = 0.15 * self.trust[self.owner]
				self.interact_sound_cooldown = 3
				self:play_sound("purr")
			end
			local order = self.order
			if order == "wander" then
				self.order = "follow"
			elseif order == "follow" then
				self.order = "sit"
			else
				self.order = "wander"
			end
			self:memorize("order", self.order)
		end
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		self:initiate_utility("animalia:flee_from_player", self, puncher)
		self:set_utility_score(1)
		if not self.trust[puncher:get_player_name()] then
			self.trust[puncher:get_player_name()] = 0
		else
			local trust = self.trust[puncher:get_player_name()]
			self.trust[puncher:get_player_name()] = trust - 1
		end
		local pos = self.object:get_pos()
		pos = vector.new(pos.x, pos.y + 0.5, pos.z)
		local minppos = vector.add(pos, 1)
		local maxppos = vector.subtract(pos, 1)
		animalia.particle_spawner(pos, "creatura_particle_red.png", "float", minppos, maxppos)
		self:memorize("trust", self.trust)
	end,
	deactivate_func = function(self)
		if self.owner
		and animalia.pets[self.owner][self.object] then
			animalia.pets[self.owner][self.object] = nil
		end
	end
})

creatura.register_spawn_egg("animalia:cat", "db9764" ,"cf8d5a")