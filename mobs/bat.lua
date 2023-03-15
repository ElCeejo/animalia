---------
-- Bat --
---------

local vec_dist = vector.distance

local function get_home_pos(self)
	local pos = self.object:get_pos()
	if not pos then return end
	local nodes = minetest.find_nodes_in_area(
		vector.subtract(pos, 16),
		vector.add(pos, 16),
		{"group:leaves", "group:stone"}
	)
	local home_dist
	local new_home
	for _, n_pos in ipairs(nodes or {}) do
		local dist = vec_dist(pos, n_pos)
		if not home_dist
		or dist < home_dist then
			n_pos.y = n_pos.y - 1
			if creatura.get_node_def(n_pos).name == "air" then
				home_dist = dist
				new_home = n_pos
			end
		end
	end
	if new_home then
		self.home_position = self:memorize("home_position", new_home)
	end
end

creatura.register_mob("animalia:bat", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_bat.b3d",
	textures = {
		"animalia_bat_1.png",
		"animalia_bat_2.png",
		"animalia_bat_3.png",
	},
	makes_footstep_sound = false,

	-- Creatura Props
	max_health = 2,
	armor_groups = {fleshy = 100},
	damage = 0,
	speed = 4,
	tracking_range = 12,
	max_boids = 3,
	despawn_after = 200,
	max_fall = 0,
	sounds = {
		random = {
			name = "animalia_bat",
			gain = 0.5,
			distance = 16
		}
	},
	hitbox = {
		width = 0.15,
		height = 0.3
	},
	animations = {
		stand = {range = {x = 1, y = 40}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 51, y = 69}, speed = 30, frame_blend = 0.3, loop = true},
		fly = {range = {x = 81, y = 99}, speed = 80, frame_blend = 0.3, loop = true},
		cling = {range = {x = 110, y = 110}, speed = 1, frame_blend = 0, loop = false}
	},
	follow = {
		"butterflies:butterfly_red",
		"butterflies:butterfly_white",
		"butterflies:butterfly_violet"
	},

	-- Animalia Props
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = false,
	roost_action = animalia.action_cling,

	-- Functions
	utility_stack = {
		{
			utility = "animalia:aerial_wander",
			step_delay = 0.25,
			get_score = function(self)
				local pos = self.object:get_pos()
				if not pos then return end
				local player = creatura.get_nearby_player(self)
				local plyr_pos = player and not player:get_player_control().sneak and player:get_pos()
				if plyr_pos then
					local dist = vec_dist(pos, plyr_pos)
					self._target = player
					self.is_landed = false
					return (self.tracking_range - dist) / self.tracking_range, {self}
				end
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
			utility = "animalia:fly_to_roost",
			get_score = function(self)
				local pos = self.object:get_pos()
				if not pos then return end
				local home = animalia.is_day and self.home_position
				if (home
				and home.x
				and vec_dist(pos, home) < 8)
				or self.is_landed then
					return 0.6, {self}
				end
				return 0
			end
		}
	},

	is_home = function(pos, home_pos)
		local dist = vec_dist(pos, home_pos)
		if dist < 4 then
			local above = {x = pos.x, y = pos.y + 1, z = pos.z}
			if creatura.get_node_def(above).walkable
			or dist < 1 then
				return true
			end
		end
		return false
	end,

	activate_func = function(self)
		animalia.initialize_api(self)
		self.home_position = self:recall("home_position") or nil
		local home_pos = self.home_position
		self.is_landed = self:recall("is_landed") or false
		self.trust = self:recall("trust") or {}
		if not home_pos
		or not creatura.get_node_def(home_pos).walkable then
			get_home_pos(self)
		end
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.do_growth(self, 60)
		animalia.rotate_to_pitch(self)
		animalia.random_sound(self)
		if not self.is_landed
		or not self.touching_ground then
			self.speed = 4
		else
			self.speed = 1
		end
		if self:timer(10)
		and math.random(10) < 2 then
			local anim = self._anim or ""
			if anim == "cling" then
				local colony = creatura.get_nearby_objects(self, self.name)
				local pos = self.object:get_pos()
				if not pos then return end
				local center = pos
				if #colony > 0 then
					local pos_sum = center
					local pos_ttl = 1
					for _, object in ipairs(colony) do
						local obj_pos = object and object:get_pos()
						if obj_pos then
							pos_sum = vector.add(pos_sum, obj_pos)
							pos_ttl = pos_ttl + 1
						end
					end
					center = vector.divide(pos_sum, pos_ttl)
				end
				center = creatura.get_ground_level(center, 8)
				if center.y < pos.y then
					local under = {x = center.x, y = center.y - 1, z = center.z}
					if creatura.get_node_def(under).walkable
					and not minetest.is_protected(center, "") then
						minetest.set_node(center, {name = "animalia:guano"})
					end
				end
			end
		end
	end,

	death_func = function(self)
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
	end,

	on_rightclick = function(self, clicker)
		if animalia.feed(self, clicker, false, false) then
			animalia.add_trust(self, clicker, 1)
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
	end,

	on_punch = animalia.punch
})

creatura.register_spawn_item("animalia:bat", {
	col1 = "392517",
	col2 = "321b0b"
})