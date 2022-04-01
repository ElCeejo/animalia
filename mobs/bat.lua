---------
-- Bat --
---------


local function get_ceiling_positions(pos, range)
    local walkable = minetest.find_nodes_in_area(
        {x = pos.x + range, y = pos.y + range, z = pos.z + range},
        {x = pos.x - range, y = pos.y, z = pos.z - range},
        animalia.walkable_nodes
    )
    if #walkable < 1 then return {} end
    local output = {}
    for i = 1, #walkable do
        local i_pos = walkable[i]
        local under = {
            x = i_pos.x,
            y = i_pos.y - 1,
            z = i_pos.z
        }
        if minetest.get_node(under).name == "air"
        and minetest.registered_nodes[minetest.get_node(i_pos).name].walkable then
            table.insert(output, i_pos)
        end
    end
    return output
end

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
        latch = {range = {x = 150, y = 150}, speed = 1, frame_blend = 0, loop = false}
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
	utility_stack = {
		[1] = {
			utility = "animalia:wander",
			get_score = function(self)
				if self.is_landed then
					return 0.1, {self}
				end
				return 0
			end
		},
		[2] = {
			utility = "animalia:aerial_swarm",
			get_score = function(self)
				if self:get_utility() == "animalia:return_to_home"
				or self:get_utility() == "animalia:wander" then
					local pos = self.object:get_pos()
					local player = creatura.get_nearby_player(self)
					if player
					and player:get_pos()
					and not player:get_player_control().sneak then
						local dist = vector.distance(pos, player:get_pos())
						self._nearby_player = player
						self.is_landed = false
						return (12 - dist) * 0.1, {self, 1}
					end
				end
				if self.in_liquid
				or not self.is_landed then
					return 0.11, {self, 1}
				end
				return 0
			end
		},
		[3] = {
			utility = "animalia:land",
			get_score = function(self)
				if not self.is_landed
				and not self.touching_ground then
					return 0.12, {self}
				end
				return 0
			end
		},
		[4] = {
			utility = "animalia:return_to_home",
			get_score = function(self)
				if not self.home_position then return 0 end
				local player = self._nearby_player
				if player
				and player:get_pos() then
					local pos = self.object:get_pos()
					local dist = vector.distance(pos, player:get_pos())
					if dist < 9 then
						return 0
					end
				end
				local time = (minetest.get_timeofday() * 24000) or 0
				local is_day = time < 19500 and time > 4500
				if is_day then
					return 0.6, {self}
				end
				return 0
			end
		},
		[5] = {
			utility = "animalia:find_home",
			get_score = function(self)
				if self.home_position then return 0 end
				local pos = self.object:get_pos()
				local range = self.tracking_range
				local ceiling = get_ceiling_positions(pos, range / 2)
				if not ceiling[1] then return 0 end
				return 1, {self}
			end
		}
	},
    activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
		self.home_position = self:recall("home_position") or nil
		self.is_landed = self:recall("is_landed") or false
		self.stamina = self:recall("stamina") or 30
    end,
    step_func = function(self)
		animalia.step_timers(self)
		--animalia.head_tracking(self, 0.75, 0.75)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
		if self.stamina > 0 then
			if not self.is_landed then
				self.stamina = self:memorize("stamina", self.stamina - self.dtime)
			else
				self.stamina = self:memorize("stamina", self.stamina + self.dtime)
			end
			if self.stamina > 25
			and self.is_landed then
				self.is_landed = self:memorize("is_landed", false)
			end
		else
			self.stamina = self:memorize("stamina", self.stamina + self.dtime)
			self.is_landed = self:memorize("is_landed", true)
		end
		if self._anim == "fly" then
			local vel_y = self.object:get_velocity().y
			local rot = self.object:get_rotation()
			self.object:set_rotation({
				x = clamp(vel_y * 0.25, -0.75, 0.75),
				y = rot.y,
				z = rot.z
			})
		end
		if self:timer(random(3,4)) then
			self:play_sound("random")
			if guano_accumulation
			and random(16) < 2
			and self:get_utility() == "animalia:return_to_home" then
				local pos = self.object:get_pos()
				pos = {
					x = floor(pos.x + 0.5),
					y = floor(pos.y + 0.5),
					z = floor(pos.z + 0.5)
				}
				if not is_node_walkable(minetest.get_node(vec_raise(pos, 1)).name) then
					return
				end
				local fail_safe = 1
				while not is_node_walkable(minetest.get_node(floor_pos).name)
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
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
		animalia.add_libri_page(self, clicker, {name = "bat", form = "pg_bat;Bats"})
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
	end
})

creatura.register_spawn_egg("animalia:bat", "392517", "321b0b")