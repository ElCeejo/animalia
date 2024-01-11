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
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_cat.b3d",
	textures = {
		"animalia_cat_1.png",
		"animalia_cat_2.png",
		"animalia_cat_3.png",
		"animalia_cat_4.png",
		"animalia_cat_5.png",
		"animalia_cat_6.png",
		"animalia_cat_7.png",
		"animalia_cat_8.png",
		"animalia_cat_9.png",
		"animalia_cat_ash.png",
		"animalia_cat_birch.png",
	},
	use_texture_alpha = false,
	makes_footstep_sound = false,
	backface_culling = true,
	glow = 0,

	-- Creatura Props
	max_health = 10,
	damage = 1,
	speed = 3,
	tracking_range = 16,
	max_boids = 0,
	despawn_after = 500,
	max_fall = 0,
	stepheight = 1.1,
	sounds = {
		random = {
			name = "animalia_cat",
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
	hitbox = {
		width = 0.2,
		height = 0.4
	},
	animations = {
		stand = {range = {x = 1, y = 60}, speed = 20, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 89}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 100, y = 119}, speed = 40, frame_blend = 0.3, loop = true},
		sit = {range = {x = 130, y = 139}, speed = 10, frame_blend = 0.3, loop = true},
	},
	follow = follow,
	drops = {},

	-- Behavior Parameters
	is_skittish_mob = true,

	-- Animalia Props
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = true,
	head_data = {
		offset = {x = 0, y = 0.14, z = 0},
		pitch_correction = -25,
		pivot_h = 0.4,
		pivot_v = 0.4
	},

	-- Functions
	utility_stack = {
		animalia.mob_ai.basic_wander,
		animalia.mob_ai.swim_seek_land,
		animalia.mob_ai.cat_seek_vessel,
		animalia.mob_ai.cat_stay,
		animalia.mob_ai.cat_play_with_owner,
		animalia.mob_ai.cat_follow_owner,
		animalia.mob_ai.basic_attack,
		animalia.mob_ai.basic_breed
	},

	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
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

	step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self, 0.75, 0.75)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
		animalia.random_sound(self)
		if self:timer(1) then
			if self.interact_sound_cooldown > 0 then
				self.interact_sound_cooldown = self.interact_sound_cooldown - 1
			end
		end
	end,

	death_func = animalia.death_func,

	deactivate_func = function(self)
		if self.owner then
			for i, object in ipairs(animalia.pets[self.owner] or {}) do
				if object == self.object then
					animalia.pets[self.owner][i] = nil
				end
			end
		end
		if self.enemies
		and self.enemies[1]
		and self.memorize then
			self.enemies[1] = nil
			self.enemies = self:memorize("enemies", self.enemies)
		end
	end,

	on_rightclick = function(self, clicker)
		local item_name = clicker:get_wielded_item():get_name()
		if item_name == "animalia:net" then return end
		local trust = self.trust[clicker:get_player_name()] or 0
		local pos = self.object:get_pos()
		if not pos then return end
		if animalia.feed(self, clicker, true, true) then
			animalia.add_trust(self, clicker, 1)
			animalia.particle_spawner(pos, "creatura_particle_green.png", "float")
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
		-- Purr to indicate trust level (louder = more trust)
		if clicker:get_player_control().sneak then
			if self.interact_sound_cooldown <= 0 then
				self.sounds["purr"].gain = 0.15 * trust
				self.interact_sound_cooldown = 3
				self:play_sound("purr")
			end
		end
		if not self.owner
		or clicker:get_player_name() ~= self.owner then
			return
		end
		if trust <= 5 then
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
				minetest.chat_send_player(clicker:get_player_name(), "Cat is following")
				self.order = "follow"
				self:initiate_utility("animalia:follow_player", self, clicker, true)
				self:set_utility_score(0.7)
			elseif order == "follow" then
				minetest.chat_send_player(clicker:get_player_name(), "Cat is sitting")
				self.order = "sit"
				self:initiate_utility("animalia:stay", self)
				self:set_utility_score(0.5)
			else
				minetest.chat_send_player(clicker:get_player_name(), "Cat is wandering")
				self.order = "wander"
				self:set_utility_score(0)
			end
			self:memorize("order", self.order)
		end
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		self:initiate_utility("animalia:flee_from_player", self, puncher)
		self:set_utility_score(1)
		animalia.add_trust(self, puncher, -1)
		local pos = self.object:get_pos()
		animalia.particle_spawner(pos, "creatura_particle_red.png", "float")
	end
})

creatura.register_spawn_item("animalia:cat", {
	col1 = "db9764",
	col2 = "cf8d5a"
})
