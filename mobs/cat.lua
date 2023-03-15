---------
-- Cat --
---------

local random = math.random

local vec_dist, vec_add, vec_sub = vector.distance, vector.add, vector.subtract

local follow = {
	"animalia:poultry_raw"
}

if minetest.registered_items["ethereal:fish_raw"] then
	follow = {
		"ethereal:fish_raw",
		"animalia:poultry_raw"
	}
end

local function find_glass_vessel(self)
	local pos = self.object:get_pos()
	if not pos then return end

	local nodes = minetest.find_nodes_in_area(vec_sub(pos, 6), vec_add(pos, 6),
												{"vessels:glass_bottle", "vessels:drinking_glass"}) or {}
	if #nodes < 1 then return end
	return nodes[math.random(#nodes)]
end

local function destroy_glass_vessel(self, pos)
	if not minetest.is_protected(pos, "") then
		minetest.remove_node(pos)
		minetest.add_item(pos, "vessels:glass_fragments")
		return true
	end
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
	skittish_wander = true,

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
			utility = "animalia:walk_to_pos_and_interact",
			step_delay = 0.25,
			get_score = function(self)
				if random(2) < 2 then
					return 0.2, {self, find_glass_vessel, destroy_glass_vessel, nil, 10}
				end
				return 0
			end
		},
		{
			utility = "animalia:bother_player",
			step_delay = 0.25,
			get_score = function(self)
				if random(24) > 1 then return 0 end
				local owner = self.owner and minetest.get_player_by_name(self.owner)
				local pos = self.object:get_pos()
				if not pos then return end
				local trust = self.trust[self.owner] or 0
				if trust > 3
				and owner
				and vec_dist(pos, owner:get_pos()) < self.tracking_range then
					return 0.2, {self, owner}
				end
				return 0
			end
		},
		{
			utility = "animalia:stay",
			step_delay = 0.25,
			get_score = function(self)
				local trust = (self.owner and self.trust[self.owner]) or 0
				if trust < 5 then return 0 end
				local order = self.order or "wander"
				if order == "sit" then
					return 0.5, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:play_with_player",
			step_delay = 0.25,
			get_score = function(self)
				if self.trust_cooldown > 0 then return 0 end
				local owner = self.owner and minetest.get_player_by_name(self.owner)
				if owner
				and owner:get_wielded_item():get_name() == "animalia:cat_toy" then
					return 0.6, {self, owner}
				end
				return 0
			end
		},
		{
			utility = "animalia:follow_player",
			get_score = function(self)
				local lasso_tgt = self._lassod_to
				local lasso = type(lasso_tgt) == "string" and minetest.get_player_by_name(lasso_tgt)
				local trust = (self.owner and self.trust[self.owner]) or 0
				local owner = self.owner and self.order == "follow" and trust > 4 and minetest.get_player_by_name(self.owner)
				local force = (lasso and lasso ~= false) or (owner and owner ~= false)
				local player = (force and (owner or lasso)) or creatura.get_nearby_player(self)
				if player
				and self:follow_wielded_item(player) then
					return 0.6, {self, player, force}
				end
				return 0
			end
		},
		{
			utility = "animalia:attack_target",
			get_score = function(self)
				local target = self._target or creatura.get_nearby_object(self, "animalia:rat")
				local tgt_pos = target and target:get_pos()
				if tgt_pos
				and self:is_pos_safe(tgt_pos) then
					return 0.7, {self, target}
				end
				return 0
			end
		},
		{
			utility = "animalia:breed",
			step_delay = 0.25,
			get_score = function(self)
				if self.breeding
				and animalia.get_nearby_mate(self, self.name) then
					return 0.8, {self}
				end
				return 0
			end
		}
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
