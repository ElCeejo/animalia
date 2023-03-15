---------
-- Owl --
---------

local abs = math.abs

local vec_dist = vector.distance

local function get_home_pos(self)
	local pos = self.object:get_pos()
	if not pos then return end
	local leaves = minetest.find_nodes_in_area_under_air(
		vector.subtract(pos, 16),
		vector.add(pos, 16),
		"group:leaves"
	)
	local home_dist
	local new_home
	for _, leaf_pos in ipairs(leaves or {}) do
		local dist = vec_dist(pos, leaf_pos)
		if not home_dist
		or dist < home_dist then
			home_dist = dist
			new_home = leaf_pos
		end
	end
	if new_home then
		new_home.y = new_home.y + 1
		self.home_position = self:memorize("home_position", new_home)
	end
end

creatura.register_mob("animalia:owl", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_owl.b3d",
	textures = {
		"animalia_owl.png"
	},
	makes_footstep_sound = false,

	-- Creatura Props
	max_health = 10,
	damage = 2,
	speed = 4,
	tracking_range = 16,
	max_boids = 0,
	despawn_after = 500,
	max_fall = 0,
	sound = {}, -- TODO
	hitbox = {
		width = 0.15,
		height = 0.3
	},
	animations = {
		stand = {range = {x = 1, y = 60}, speed = 20, frame_blend = 0.3, loop = true},
		fly = {range = {x = 71, y = 89}, speed = 30, frame_blend = 0.3, loop = true},
		glide = {range = {x = 101, y = 119}, speed = 20, frame_blend = 0.2, loop = true},
		fly_punch = {range = {x = 131, y = 149}, speed = 20, frame_blend = 0.1, loop = false},
		eat = {range = {x = 161, y = 179}, speed = 20, frame_blend = 0.1, loop = false}
	},
	follow = {"animalia:rat_raw"},
	drops = {
		{name = "animalia:feather", min = 1, max = 2, chance = 1}
	},

	-- Animalia Props
	flee_puncher = true, -- TODO
	catch_with_net = true,
	catch_with_lasso = false,
	roost_action = animalia.action_roost,

	-- Functions
	on_eat_drop = function(self)
		animalia.protect_from_despawn(self)
		get_home_pos(self)
	end,

	is_home = function(pos, home_pos)
		if abs(pos.x - home_pos.x) < 0.5
		and abs(pos.z - home_pos.z) < 0.5 then
			if abs(pos.y - home_pos.y) < 0.75 then
				return true
			else
				local under = {x = home_pos.x, y = home_pos.y, z = home_pos.z}
				local name = minetest.get_node(under).name
				if minetest.get_node_group(name, "leaves") > 0 then
					return true
				end
			end
		end
		return false
	end,

	wander_action = creatura.action_move,

	utility_stack = {
		{
			utility = "animalia:aerial_wander",
			--step_delay = 0.25,
			get_score = function(self)
				if not self.is_landed
				or self.in_liquid then
					return 0.1, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:fly_to_roost",
			get_score = function(self)
				local pos = self.object:get_pos()
				if not pos then return end
				local player = creatura.get_nearby_player(self)
				local plyr_pos = player and player:get_pos()
				if plyr_pos then
					local dist = vector.distance(pos, plyr_pos)
					if dist < 3 then
						return 0
					end
				end
				local home = animalia.is_day and self.home_position
				if home
				and vec_dist(pos, home) < 8 then
					return 0.2, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:fly_to_food",
			get_score = function(self)
				local cooldown = self.eat_cooldown or 0
				if cooldown > 0 then
					self.eat_cooldown = cooldown - 1
					return 0
				end
				local food_item = animalia.get_dropped_food(self, "animalia:rat_raw")
				if food_item then
					return 0.3, {self, food_item}
				end
				return 0
			end
		},
		{
			utility = "animalia:raptor_hunt",
			get_score = function(self)
				if math.random(12) > 1
				and (self:get_utility() or "") ~= "animalia:raptor_hunt" then
					return 0
				end
				local target = self._target or creatura.get_nearby_object(self, {"animalia:rat", "animalia:song_bird"})
				local tgt_pos = target and target:get_pos()
				if tgt_pos then
					return 0.4, {self, target}
				end
				return 0
			end
		},
	},

	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
		self._tp2home = self:recall("_tp2home") or nil
		self.home_position = self:recall("home_position") or nil
		local home_pos = self.home_position
		if self._tp2home
		and home_pos then
			self.object:set_pos(home_pos)
		end
		self.is_landed = self:recall("is_landed") or false
		if not home_pos
		or creatura.get_node_def(home_pos).walkable then
			get_home_pos(self)
		end
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
		animalia.rotate_to_pitch(self)
		if not self.is_landed
		or not self.touching_ground then
			self.speed = 5
		else
			self.speed = 1
		end
	end,

	death_func = function(self)
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
	end,

	deactivate_func = function(self)
		if self:get_utility()
		and self:get_utility() == "animalia:fly_to_roost" then
			local pos = self.home_position
			local node = minetest.get_node_or_nil(pos)
			if node
			and not creatura.get_node_def(node.name).walkable
			and minetest.get_natural_light(pos) > 0 then
				self:memorize("_tp2home", true)
			end
		end
	end,

	on_rightclick = function(self, clicker)
		if animalia.feed(self, clicker, false, false) then
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
	end,

	on_punch = animalia.punch
})

creatura.register_spawn_item("animalia:owl", {
	col1 = "412918",
	col2 = "735b46"
})