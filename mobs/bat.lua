---------
-- Bat --
---------

local guano_accumulation = minetest.settings:get_bool("guano_accumulation")

-- Math --

local function clamp(val, min, max)
	if val < min then
		val = min
	elseif max < val then
		val = max
	end
	return val
end

local random = math.random
local floor = math.floor

-- Vector Math --

local vec_dist = vector.distance
local vec_add = vector.add

local function vec_raise(v, n)
	return {x = v.x, y = v.y + n, z = v.z}
end

---------------
-- Utilities --
---------------

local function get_roost(pos, range)
	local walkable = minetest.find_nodes_in_area(
		{x = pos.x + range, y = pos.y + range, z = pos.z + range},
		{x = pos.x - range, y = pos.y, z = pos.z - range},
		animalia.walkable_nodes
	)
	if #walkable < 1 then return end
	local roosts = {}
	for i = 1, #walkable do
		local i_pos = walkable[i]
		local n_pos = {
			x = i_pos.x,
			y = i_pos.y - 1,
			z = i_pos.z
		}
		if creatura.get_node_def(n_pos).name == "air"
		and minetest.line_of_sight(pos, n_pos) then
			table.insert(roosts, n_pos)
		end
	end
	return roosts[random(#roosts)]
end

local function is_node_walkable(name)
	local def = minetest.registered_nodes[name]
	return def and def.walkable
end

creatura.register_mob("animalia:bat", {
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
	turn_rate = 12,
	-- Visuals
	mesh = "animalia_bat.b3d",
	hitbox = {
		width = 0.15,
		height = 0.3
	},
	visual_size = {x = 7, y = 7},
	textures = {
		"animalia_bat_1.png",
		"animalia_bat_2.png",
		"animalia_bat_3.png"
	},
	animations = {
		stand = {range = {x = 1, y = 40}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 50, y = 90}, speed = 30, frame_blend = 0.3, loop = true},
		fly = {range = {x = 100, y = 140}, speed = 80, frame_blend = 0.3, loop = true},
		cling = {range = {x = 150, y = 150}, speed = 1, frame_blend = 0, loop = false}
	},
	-- Misc
	sounds = {
		random = {
			name = "animalia_bat",
			gain = 0.5,
			distance = 16,
			variations = 2
		},
	},
	catch_with_net = true,
	catch_with_lasso = false,
	follow = {
		"butterflies:butterfly_red",
		"butterflies:butterfly_white",
		"butterflies:butterfly_violet"
	},
	-- Function
	roost_action = animalia.action_cling,
	utility_stack = {
		{
			utility = "animalia:wander",
			step_delay = 0.25,
			get_score = function(self)
				return 0.1, {self}
			end
		},
		{
			utility = "animalia:aerial_wander",
			step_delay = 0.25,
			get_score = function(self)
				local pos = self.object:get_pos()
				if not pos then return end
				local player = creatura.get_nearby_player(self)
				local plyr_pos = player and not player:get_player_control().sneak and player:get_pos()
				if plyr_pos then
					local trust = self.trust[player:get_player_name() or ""] or 0
					local dist = vec_dist(pos, plyr_pos)
					self._target = player
					self.is_landed = false
					return (12 - (dist + trust)) * 0.1, {self}
				end
				if self.in_liquid
				or not self.is_landed then
					return 0.2, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:fly_to_land",
			get_score = function(self)
				if self.is_landed
				and not self.touching_ground
				and not self.in_liquid
				and creatura.sensor_floor(self, 3, true) > 2 then
					return 0.3, {self}
				end
				return 0
			end
		},
		[4] = {
			utility = "animalia:fly_to_roost",
			get_score = function(self)
				local pos = self.object:get_pos()
				if not pos then return end
				local home = animalia.is_day and self.home_position
				if home
				and home.x
				and vec_dist(pos, home) < 8 then
					return 0.6, {self}
				end
				return 0
			end
		}
	},
	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
		self.home_position = self:recall("home_position") or nil
		self.is_landed = self:recall("is_landed") or false
		self.trust = self:recall("trust") or {}
		if not self.home_position then
			local roost = get_roost(self.object:get_pos(), 8)
			if roost then
				self.home_position = self:memorize("home_position", roost)
			end
		end
	end,
	step_func = function(self)
		animalia.step_timers(self)
		--animalia.head_tracking(self, 0.75, 0.75)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
		animalia.rotate_to_pitch(self)
		local pos = self.object:get_pos()
		if not pos then return end
		if self:timer(random(10,15)) then
			if random(4) < 2 then
				self.is_landed = not self.is_landed
			end
			if not self.home_position
			or creatura.get_node_def(self.home_position).walkable then
				local roost = get_roost(pos, 8)
				if roost then
					self.home_position = self:memorize("home_position", roost)
				end
			end
		end
		if self._anim == "fly" then
			local vel_y = vector.normalize(self.object:get_velocity()).y
			local rot = self.object:get_rotation()
			local n_rot = rot.x + (vel_y - rot.x) * 0.2
			self.object:set_rotation({
				x = clamp(n_rot, -0.75, 0.75),
				y = rot.y,
				z = rot.z
			})
		end
		if self:timer(random(3,4)) then
			self:play_sound("random")
			if guano_accumulation
			and random(16) < 2
			and self:get_utility() == "animalia:fly_to_roost" then
				pos = {
					x = floor(pos.x + 0.5),
					y = floor(pos.y + 0.5),
					z = floor(pos.z + 0.5)
				}
				if not is_node_walkable(minetest.get_node(vec_raise(pos, 1)).name) then
					return
				end
				local fail_safe = 1
				while not is_node_walkable(minetest.get_node(pos).name)
				and fail_safe < 16 do
					pos.y = pos.y - 1
				end
				if is_node_walkable(minetest.get_node(pos).name) then
					if minetest.get_node(vec_raise(pos, 1)).name ~= "animalia:guano" then
						minetest.set_node(vec_raise(pos, 1), {name = "animalia:guano"})
					else
						local nodes = minetest.find_nodes_in_area_under_air(
							vector.subtract(pos, 3),
							vec_add(pos, 3),
							animalia.walkable_nodes
						)
						if #nodes > 0 then
							pos = nodes[random(#nodes)]
							if minetest.get_node(vec_raise(pos, 1)).name ~= "animalia:guano" then
								minetest.set_node(vec_raise(pos, 1), {name = "animalia:guano"})
							end
						end
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
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
	end
})

creatura.register_spawn_egg("animalia:bat", "392517", "321b0b")