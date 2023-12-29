---------------
-- Behaviors --
---------------

-- Math --

local abs = math.abs
local atan2 = math.atan2
local ceil = math.ceil
local cos = math.cos
local min = math.min
local max = math.max
local pi = math.pi
local pi2 = pi * 2
local sin = math.sin
local rad = math.rad
local random = math.random

local function diff(a, b) -- Get difference between 2 angles
	return atan2(sin(b - a), cos(b - a))
end

local function clamp(val, minn, maxn)
	if val < minn then
		val = minn
	elseif maxn < val then
		val = maxn
	end
	return val
end

-- Vector --

local vec_dir = vector.direction
local vec_dist = vector.distance
local vec_dot = vector.dot
local vec_divide = vector.divide
local vec_normal = vector.normalize
local vec_round = vector.round
local vec_sub = vector.subtract
local vec_add = vector.add
local vec_multi = vector.multiply

local dir2yaw = minetest.dir_to_yaw
local yaw2dir = minetest.yaw_to_dir

-----------------
-- Local Tools --
-----------------

local farming_enabled = minetest.get_modpath("farming") and farming.registered_plants

if farming_enabled then
	minetest.register_on_mods_loaded(function()
		for name, def in pairs(minetest.registered_nodes) do
			local item_string = name:sub(1, #name - 2)
			local item_name = item_string:split(":")[2]
			local growth_stage = tonumber(name:sub(-1)) or 1
			if farming.registered_plants[item_string]
			or farming.registered_plants[item_name] then
				def.groups.crop = growth_stage
			end
			minetest.register_node(":" .. name, def)
		end
	end)
end

local animate_player = {}

if minetest.get_modpath("default")
and minetest.get_modpath("player_api") then
	animate_player = player_api.set_animation
elseif minetest.get_modpath("mcl_player") then
	animate_player = mcl_player.player_set_animation
end

local function add_break_particle(pos)
	pos = vec_round(pos)
	local def = creatura.get_node_def(pos)
	local texture = (def.tiles and def.tiles[1]) or def.inventory_image
	texture = texture .. "^[resize:8x8"
	minetest.add_particlespawner({
		amount = 6,
		time = 0.1,
		minpos = {
			x = pos.x,
			y = pos.y - 0.49,
			z = pos.z
		},
		maxpos = {
			x = pos.x,
			y = pos.y - 0.49,
			z = pos.z
		},
		minvel = {x=-1, y=1, z=-1},
		maxvel = {x=1, y=2, z=1},
		minacc = {x=0, y=-5, z=0},
		maxacc = {x=0, y=-9, z=0},
		minexptime = 1,
		maxexptime = 1.5,
		minsize = 1,
		maxsize = 2,
		collisiondetection = true,
		vertical = false,
		texture = texture,
	})
end

local function get_group_positions(self)
	local objects = creatura.get_nearby_objects(self, self.name)
	local group = {}
	for _, object in ipairs(objects) do
		local obj_pos = object and object:get_pos()
		if obj_pos then table.insert(group, obj_pos) end
	end
	return group
end

local function calc_altitude(self, pos2)
	local height_half = self.height * 0.5
	local center_y = pos2.y + height_half
	local calc_pos = {x = pos2.x, y = center_y, z = pos2.z}
	local range = (height_half + 2)
	local offset = {x = 0, y = range, z = 0}
	local ceil_pos, floor_pos = vec_add(calc_pos, offset), vec_sub(calc_pos, offset)
	local ray_up = minetest.raycast(calc_pos, ceil_pos, false, true):next()
	local ray_down = minetest.raycast(calc_pos, floor_pos, false, true):next()
	ceil_pos = (ray_up and ray_up.above) or ceil_pos
	floor_pos = (ray_down and ray_down.above) or floor_pos

	local dist_up = ceil_pos.y - center_y
	local dist_down = floor_pos.y - center_y

	local altitude = (dist_up + dist_down) / 2

	return ((calc_pos.y + altitude) - center_y) / range * 2
end

local function calc_steering_and_lift(self, pos, pos2, dir, steer_method)
	local steer_to = creatura.calc_steering(self, pos2, steer_method or creatura.get_context_small)
	pos2 = vector.add(pos, steer_to)
	local lift = creatura.get_avoidance_lift(self, pos2, 2)
	steer_to.y = (lift ~= 0 and lift) or dir.y
	return steer_to
end

local function calc_steering_and_lift_aquatic(self, pos, pos2, dir, steer_method)
	local steer_to = creatura.calc_steering(self, pos2, steer_method or creatura.get_context_small_aquatic)
	local lift = creatura.get_avoidance_lift_aquatic(self, vector.add(pos, steer_to), 2)
	steer_to.y = (lift ~= 0 and lift) or dir.y
	return steer_to
end

local function get_obstacle(pos, water)
	local pos2 = {x = pos.x, y = pos.y, z = pos.z}
	local n_def = creatura.get_node_def(pos2)
	if n_def.walkable
	or (water and (n_def.groups.liquid or 0) > 0) then
		pos2.y = pos.y + 1
		n_def = creatura.get_node_def(pos2)
		local col_max = n_def.walkable or (water and (n_def.groups.liquid or 0) > 0)
		pos2.y = pos.y - 1
		local col_min = col_max and (n_def.walkable or (water and (n_def.groups.liquid or 0) > 0))
		if col_min then
			return pos
		else
			pos2.y = pos.y + 1
			return pos2
		end
	end
end

function animalia.get_steering_context(self, goal, steer_dir, interest, danger, range)
	local pos = self.object:get_pos()
	if not pos then return end
	pos = vector.round(pos)
	local width = self.width or 0.5

	local check_pos = vec_add(pos, steer_dir)
	local collision = get_obstacle(check_pos)
	local unsafe_pos = not collision and not self:is_pos_safe(check_pos) and check_pos

	if collision
	or unsafe_pos then
		local dir2goal = vec_normal(vec_dir(pos, goal))
		local dir2col = vec_normal(vec_dir(pos, collision or unsafe_pos))
		local dist2col = vec_dist(pos, collision or unsafe_pos) - width
		local dot_score = vec_dot(dir2col, dir2goal)
		local dist_score = (range - dist2col) / range
		interest = interest - dot_score
		danger = dist_score
	end
	return interest, danger
end

--------------
-- Movement --
--------------

-- Obstacle Avoidance

function animalia.obstacle_avoidance(self, goal, water)
	local steer_method = water and creatura.get_context_small_aquatic or animalia.get_steering_context
	local dir = creatura.calc_steering(self, goal, steer_method)

	local lift_method = water and creatura.get_avoidance_lift_aquatic or creatura.get_avoidance_lift
	local lift = lift_method(self, vec_add(self.stand_pos, dir), 2)
	dir.y = (lift ~= 0 and lift) or dir.y

	return dir
end

-- Methods

creatura.register_movement_method("animalia:fly_wide", function(self)
	local steer_to
	local steer_int = 0
	self:set_gravity(0)
	local function func(_self, goal, speed_factor)
		local pos = _self.object:get_pos()
		if not pos or not goal then return end
		if vec_dist(pos, goal) < clamp(self.width, 0.5, 1) then
			_self:halt()
			return true
		end
		-- Calculate Movement
		local turn_rate = 2.5
		local speed = abs(_self.speed or 2) * speed_factor or 0.5
		steer_int = (steer_int > 0 and steer_int - _self.dtime) or 1 / math.max(speed, 1)
		steer_to = (steer_int <= 0 and creatura.calc_steering(_self, goal)) or steer_to
		local dir = steer_to or vec_dir(pos, goal)
		local altitude = calc_altitude(self, vec_add(pos, dir))
		dir.y = (altitude ~= 0 and altitude) or dir.y

		if vector.dot(dir, yaw2dir(_self.object:get_yaw())) > 0.2 then -- Steer faster for major obstacles
			turn_rate = 5
		end
		-- Apply Movement
		_self:turn_to(dir2yaw(dir), turn_rate)
		_self:set_forward_velocity(speed)
		_self:set_vertical_velocity(speed * dir.y)
	end
	return func
end)

-- Steering Methods

creatura.register_movement_method("animalia:steer", function(self)
	local steer_to
	local steer_int = 0

	local radius = 2 -- Arrival Radius

	self:set_gravity(-9.8)
	local function func(_self, goal, speed_factor)
		-- Vectors
		local pos = self.object:get_pos()
		if not pos or not goal then return end

		local dist = vector.distance(pos, goal)
		local dir = vector.direction(pos, goal)

		-- Movement Params
		local vel = self.speed * speed_factor
		local turn_rate = self.turn_rate
		local mag = math.min(radius - ((radius - dist) / 1), 1)
		vel = vel * mag

		-- Steering
		steer_int = (steer_int > 0 and steer_int - _self.dtime) or 1 / math.max(vel, 1)
		steer_to = steer_int <= 0 and animalia.obstacle_avoidance(_self, goal) or steer_to

		-- Apply Movement
		_self:turn_to(minetest.dir_to_yaw(steer_to or dir), turn_rate)
		_self:set_forward_velocity(vel)
	end
	return func
end)

creatura.register_movement_method("animalia:steer_no_gravity", function(self)
	local steer_to
	local steer_int = 0

	local radius = 2 -- Arrival Radius

	self:set_gravity(0)
	local function func(_self, goal, speed_factor)
		-- Vectors
		local pos = self.object:get_pos()
		if not pos or not goal then return end

		local dist = vector.distance(pos, goal)
		local dir = vector.direction(pos, goal)

		-- Movement Params
		local vel = self.speed * speed_factor
		local turn_rate = self.turn_rate
		local mag = min(radius - ((radius - dist) / 1), 1)
		vel = vel * mag

		-- Steering
		steer_int = (steer_int > 0 and steer_int - _self.dtime) or 1 / max(vel, 1)
		steer_to = steer_int <= 0 and animalia.obstacle_avoidance(_self, goal, _self.max_breath == 0) or steer_to

		-- Apply Movement
		_self:turn_to(minetest.dir_to_yaw(steer_to or dir), turn_rate)
		_self:set_forward_velocity(vel)
		_self:set_vertical_velocity(dir.y * vel)
	end
	return func
end)

-- Simple Methods

creatura.register_movement_method("animalia:move", function(self)
	local radius = 2 -- Arrival Radius

	self:set_gravity(-9.8)
	local function func(_self, goal, speed_factor)
		-- Vectors
		local pos = self.object:get_pos()
		if not pos or not goal then return end

		local dist = vector.distance(pos, goal)
		local dir = vector.direction(pos, goal)

		-- Movement Params
		local vel = self.speed * speed_factor
		local turn_rate = self.turn_rate
		local mag = math.min(radius - ((radius - dist) / 1), 1)
		vel = vel * mag

		-- Apply Movement
		_self:turn_to(minetest.dir_to_yaw(dir), turn_rate)
		_self:set_forward_velocity(vel)
	end
	return func
end)

creatura.register_movement_method("animalia:move_no_gravity", function(self)
	local radius = 2 -- Arrival Radius

	self:set_gravity(0)
	local function func(_self, goal, speed_factor)
		-- Vectors
		local pos = self.object:get_pos()
		if not pos or not goal then return end

		local dist = vector.distance(pos, goal)
		local dir = vector.direction(pos, goal)

		-- Movement Params
		local vel = self.speed * speed_factor
		local turn_rate = self.turn_rate
		local mag = math.min(radius - ((radius - dist) / 1), 1)
		vel = vel * mag

		-- Apply Movement
		_self:turn_to(minetest.dir_to_yaw(dir), turn_rate)
		_self:set_forward_velocity(vel)
		_self:set_vertical_velocity(vel * dir.y)
	end
	return func
end)

-------------
-- Actions --
-------------

function animalia.action_walk(self, time, speed, animation, pos2)
	local timeout = time or 3
	local speed_factor = speed or 0.5
	local anim = animation or "walk"

	local wander_radius = 2

	local dir = pos2 and vec_dir(self.stand_pos, pos2)
	local function func(mob)
		local pos, yaw = mob.object:get_pos(), mob.object:get_yaw()
		if not pos or not yaw then return true end

		dir = pos2 and vec_dir(pos, pos2) or minetest.yaw_to_dir(yaw)

		local wander_point = vec_add(pos, vec_multi(dir, wander_radius + 0.5))
		local goal = vec_add(wander_point, vec_multi(minetest.yaw_to_dir(random(pi2)), wander_radius))

		local safe = true

		if mob.max_fall then
			safe = mob:is_pos_safe(goal)
		end

		if timeout <= 0
		or not safe
		or mob:move_to(goal, "animalia:steer", speed_factor) then
			mob:halt()
			return true
		end

		timeout = timeout - mob.dtime
		if timeout <= 0 then return true end

		mob:animate(anim)
	end
	self:set_action(func)
end

function animalia.action_soar(self, pos2, timeout, speed_factor)
	local timer = timeout or 4
	local center = pos2
	local function func(_self)
		local pos, vel = _self.object:get_pos(), _self.object:get_velocity()
		if not pos then return end

		timer = timer - _self.dtime
		if timer <= 0 then return true end

		if abs(pos.y - pos2.y) < 2 then
			center.y = center.y - self.dtime * 0.5
		else
			center.y = pos2.y
		end

		_self:move_to(center, "animalia:fly_wide", speed_factor or 0.5)

		local anim
		if vel.y > 0 then
			anim = "fly"
		else
			anim = "glide"
		end
		_self:animate(anim)
	end
	self:set_action(func)
end

function animalia.action_pursue(self, target, timeout, method, speed_factor, anim)
	local timer = timeout or 4
	local goal
	local function func(_self)
		local target_alive, line_of_sight, tgt_pos = _self:get_target(target)
		if not target_alive then
			return true
		end
		goal = goal or tgt_pos
		timer = timer - _self.dtime
		self:animate(anim or "walk")
		local safe = true
		if _self.max_fall
		and _self.max_fall > 0 then
			local pos = self.object:get_pos()
			if not pos then return end
			safe = _self:is_pos_safe(goal)
		end
		if line_of_sight
		and vec_dist(goal, tgt_pos) > 3 then
			goal = tgt_pos
		end
		if timer <= 0
		or not safe
		or _self:move_to(goal, method or "creatura:obstacle_avoidance", speed_factor or 0.5) then
			return true
		end
	end
	self:set_action(func)
end

function animalia.action_pursue_glide(self, target, timeout, method, speed_factor, anim)
	local timer = timeout or 4
	local goal
	local speed_x = speed_factor
	local function func(_self)
		local target_alive, line_of_sight, tgt_pos = _self:get_target(target)
		if not target_alive then
			return true
		end
		goal = goal or tgt_pos
		timer = timer - _self.dtime
		self:animate(anim or "walk")
		if line_of_sight
		and vec_dist(goal, tgt_pos) > 3 then
			goal = tgt_pos
		end
		local vel = self.object:get_velocity()
		if vel.y < 0 and speed_x < speed_factor + 0.5 then speed_x = speed_x + self.dtime * 0.5 end
		if vel.y >= 0 and speed_x > speed_factor then speed_x = speed_x - self.dtime * 0.25 end
		if timer <= 0
		or _self:move_to(goal, method or "animalia:steer_no_gravity", speed_x) then
			return true
		end
	end
	self:set_action(func)
end

function animalia.action_flight_attack(self, target, timeout)
	timeout = timeout or 12
	local punch_init = false
	local timer = timeout
	local sight_timeout = timeout * 0.5
	local cooldown = 0
	local speed_x = 0.5
	local goal
	local function func(_self)
		local pos = _self.stand_pos
		if timer <= 0 then return true end
		local target_alive, los, tgt_pos = _self:get_target(target)
		if not target_alive then return true end
		if not los then
			sight_timeout = sight_timeout - self._dtime
			if sight_timeout <= 0 then
				return true
			end
		else
			sight_timeout = timeout * 0.5
		end
		local dist = vec_dist(pos, tgt_pos)

		if dist > 32 then return true end

		local vel = self.object:get_velocity()
		if vel.y < 0 and speed_x < 1 then speed_x = speed_x + self.dtime * 0.5 end
		if vel.y >= 0 and speed_x > 0.5 then speed_x = speed_x - self.dtime end

		if punch_init then
			local anim = _self:animate("fly_punch", "fly")
			if anim == "fly" then
				punch_init = false
			end
		else
			if speed_x > 0.6 then
				_self:animate("glide")
			else
				_self:animate("fly")
			end
		end

		if cooldown > 0 then
			goal = goal or _self:get_wander_pos_3d(3, 6, nil, 1)
			cooldown = cooldown - _self.dtime
		else
			goal = nil
			cooldown = 0
		end

		if goal
		and _self:move_to(goal, "animalia:steer_no_gravity", speed_x) then
			goal = nil
		end

		if not goal
		and _self:move_to(tgt_pos, "animalia:steer_no_gravity", speed_x) then
			if dist < _self.width + 1 then
				_self:punch_target(target)
				cooldown = timeout / 3
				punch_init = true
			end
		end

		timer = timer - _self.dtime
	end
	self:set_action(func)
end

function animalia.action_dive_attack(self, target, timeout)
	timeout = timeout or 12
	local timer = timeout
	local width = self.width or 0.5
	local punch_init = false
	local anim
	local function func(_self)
		-- Tick down timers
		timer = timer - _self.dtime
		if timer <= 0 then return true end

		-- Get positions
		local pos = _self.stand_pos
		local tgt_pos = target and target:get_pos()
		if not tgt_pos then return true end
		local dist = vec_dist(pos, tgt_pos)

		if punch_init then
			anim = _self:animate("fly_punch", "fly")
			if anim == "fly" then return true end
		else
			anim = _self:animate("fly")
		end

		if dist > width + 1 then
			local method = "animalia:move_no_gravity"
			if dist > 4 then
				method = "animalia:steer_no_gravity"
			end
			_self:move_to(tgt_pos, method, 1)
		elseif not punch_init then
			_self:punch_target(target)
			punch_init = true
		end
	end
	self:set_action(func)
end

function animalia.action_wander_fly(self, timer, pos2)
	local pos = self.object:get_pos()
	if not pos then return end
	local goal
	local steer_to
	local width = ceil(self.width or 1) * 2
	local check_timer = 0.25
	timer = timer or 2
	pos2 = pos2 or {
		x = pos.x + random(width, -width),
		y = pos.y + random(width, -width),
		z = pos.z + random(width, -width)
	}
	local function func(_self)
		pos = _self.object:get_pos()
		if not pos then return end
		local dir = vec_dir(pos, pos2)
		goal = goal or vector.add(pos, dir)

		-- Tick down timers
		timer = timer - _self.dtime
		check_timer = (check_timer <= 0 and 0.25) or check_timer - _self.dtime

		-- Calculate movement
		steer_to = (check_timer > 0 and steer_to) or calc_steering_and_lift(_self, pos, goal, dir)
		goal = vec_add(pos, vec_multi(steer_to, self.width + 1))

		if timer <= 0
		or _self:move_to(goal, "animalia:move_no_gravity", 0.5) then
			_self:halt()
			return true
		end
		_self:animate("fly")
	end
	self:set_action(func)
end

function animalia.action_move_boid(self, pos2, timeout, method, speed_factor, anim, steer_method)
	steer_method = steer_method or calc_steering_and_lift
	timeout = timeout or 2
	local timer = timeout
	local check_timer = timeout / 6
	local max_fall = (self.max_fall or 0) > 0 and self.max_fall
	local steer_to
	local goal
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		local dir = vec_dir(pos, pos2)
		goal = goal or vector.add(pos, dir)

		-- Tick down timers
		timer = timer - _self.dtime
		check_timer = (check_timer <= 0 and timeout / 6) or check_timer - _self.dtime

		-- Check if goal is safe
		local safe = true

		if max_fall then
			safe = _self:is_pos_safe(goal)
		end

		-- Calculate movement
		local boid_dir = creatura.get_boid_dir(_self)
		if boid_dir then
			boid_dir.y = boid_dir.y + dir.y / 2
			goal = vec_add(pos, vec_multi(boid_dir, self.width + 1))
			if max_fall then
				goal = creatura.get_ground_level(goal, 2)
			end
		end

		local median_dir = boid_dir and steer_to and vec_divide(vec_add(boid_dir, steer_to), 2)
		steer_to = (check_timer > 0 and median_dir) or steer_method(_self, pos, goal, boid_dir or dir)
		goal = vec_add(pos, vec_multi(steer_to, self.width + 1))

		-- Apply movement/end function when goal is met
		if timer <= 0
		or not safe
		or _self:move_to(goal or pos2, method or "creatura:obstacle_avoidance", speed_factor or 0.5) then
			return true
		end
		_self:animate(anim or "walk")
	end
	self:set_action(func)
end

function animalia.action_float(self, time, anim)
	local timer = time
	local function func(_self)
		_self:set_gravity(-0.14)
		_self:halt()
		_self:animate(anim or "foat")
		timer = timer - _self.dtime
		if timer <= 0 then
			return true
		end
	end
	self:set_action(func)
end

function animalia.action_cling(self, time)
	local timer = time
	local pos = self.object:get_pos()
	if not pos then return end
	pos.y = pos.y + 1
	if not creatura.get_node_def(pos).walkable then
		self:forget("home_position")
		self.home_position = nil
		return
	end
	local function func(_self)
		_self:set_gravity(0)
		_self:halt()
		_self:set_vertical_velocity(1)
		_self:set_forward_velocity(0)
		_self:animate("cling")
		timer = timer - _self.dtime
		if timer <= 0 then
			return true
		end
	end
	self:set_action(func)
end

function animalia.action_punch(self, target)
	local jump_init = false
	local punch_init = false
	local timeout = 2
	local is_animated = self.animations["punch"] ~= nil
	local function func(_self)
		local tgt_alive, _, tgt_pos = _self:get_target(target)
		if not tgt_alive and (not punch_init or not is_animated) then return true end
		local pos = _self.object:get_pos()
		if not pos then return end
		local dir = vec_dir(pos, tgt_pos)
		if not jump_init
		and _self.touching_ground then
			_self.object:add_velocity({x = dir.x * 3, y = 2, z = dir.z * 3})
			jump_init = true
		end
		timeout = timeout - _self.dtime
		if timeout <= 0 then return true end
		local dist = vec_dist(pos, tgt_pos)
		if dist < _self.width + 1
		and not punch_init then
			_self:punch_target(target)
			local knockback = minetest.calculate_knockback(
				target, self.object, 1.0,
				{damage_groups = {fleshy = self.damage}},
				dir, 2.0, self.damage
			)
			target:add_velocity({x = dir.x * knockback, y = dir.y * knockback, z = dir.z * knockback})
			if not is_animated then return true end
			punch_init = true
		end
		if is_animated then
			if _self:animate("punch", "stand") == "stand" then return true end
		end
	end
	self:set_action(func)
end

function animalia.action_melee(self, target)
	local stage = 1
	local is_animated = self.animations["punch"] ~= nil
	local timeout = 1

	local function func(mob)
		local target_pos = target and target:get_pos()
		if not target_pos then return true end

		local pos = mob.stand_pos
		local dist = vec_dist(pos, target_pos)
		local dir = vec_dir(pos, target_pos)

		local anim = is_animated and mob:animate("punch", "stand")

		if stage == 1 then
			mob.object:add_velocity({x = dir.x * 3, y = 2, z = dir.z * 3})

			stage = 2
		end

		if stage == 2
		and dist < mob.width + 1 then
			mob:punch_target(target)
			local knockback = minetest.calculate_knockback(
				target, mob.object, 1.0,
				{damage_groups = {fleshy = mob.damage}},
				dir, 2.0, mob.damage
			)
			target:add_velocity({x = dir.x * knockback, y = dir.y * knockback, z = dir.z * knockback})

			stage = 3
		end

		if stage == 3
		and (not is_animated
		or anim == "stand") then
			return true
		end

		timeout = timeout - mob.dtime
		if timeout <= 0 then return true end
	end
	self:set_action(func)
end

function animalia.action_punch_aoe(self, target)
	local punch_init = false
	local anim = self.animations["punch_aoe"]
	local anim_len = (anim.range.y - anim.range.x) / anim.speed
	local timeout = anim_len
	local function func(_self)
		local tgt_alive, _, tgt_pos = _self:get_target(target)
		if not tgt_alive then return true end
		local pos = _self.object:get_pos()
		if not pos then return end
		_self:halt()
		_self:animate("punch_aoe")
		local dist = vec_dist(pos, tgt_pos)
		timeout = timeout - _self.dtime
		if not punch_init
		and dist < _self.width + 1
		and timeout < anim_len * 0.5 then
			_self:punch_target(target)
			punch_init = true
		end
		if timeout <= 0 then _self:animate("stand") return true end
	end
	self:set_action(func)
end

local cling_offsets = {
	{x = 0, y = 1, z = 0}, -- Ceiling is prioritized
	{x = 1, y = 0, z = 0},
	{x = 0, y = 0, z = 1},
	{x = -1, y = 0, z = 0},
	{x = 0, y = 0, z = -1}
}

function animalia.action_idle(self, var, dur, anim)
	var = var or "stand"
	dur = dur or 1
	anim = anim or "stand"

	if var == "stand" then
		self:set_gravity(-9.8)
	else
		self:set_gravity(0)
	end

	local pos = self.object:get_pos()
	if not pos then return end

	local cling_pos

	if var == "cling" then -- Cling to wall or ceiling
		for _, v in ipairs(cling_offsets) do
			cling_pos = vector.add(pos, vector.multiply(v, self.width + 0.5))

			if not creatura.get_node_def(cling_pos).walkable then
				cling_pos = nil
			else
				break
			end
		end
	end

	local function func(ent)
		if cling_pos then
			ent.object:set_velocity(vector.direction(pos, cling_pos))
		end

		if ent.in_liquid
		and var == "float" then
			ent:set_vertical_velocity(0.5)
		end

		dur = dur - ent.dtime
		if dur <= 0 then return true end

		ent:animate(anim)
	end
	self:set_action(func)
end

-- Experimental

function animalia.action_swim(self, time, speed, animation, pos2)
	local timeout = time or 3
	local speed_factor = speed or 0.5
	local anim = animation or "swim"

	local wander_radius = 2

	local dir = pos2 and vec_dir(self.stand_pos, pos2)
	local function func(mob)
		local pos, yaw = mob.object:get_pos(), mob.object:get_yaw()
		if not pos or not yaw then return true end

		dir = pos2 and vec_dir(pos, pos2) or minetest.yaw_to_dir(yaw)
		dir.y = random(-10, 10) * 0.1

		local wander_point = vec_add(pos, vec_multi(dir, wander_radius + 0.5))
		local goal = vec_add(wander_point, vec_multi(minetest.yaw_to_dir(random(pi2)), wander_radius))

		if timeout <= 0
		or mob:move_to(goal, "animalia:steer_no_gravity", speed_factor) then
			mob:halt()
			return true
		end

		timeout = timeout - mob.dtime
		if timeout <= 0 then return true end

		mob:animate(anim)
	end
	self:set_action(func)
end

---------------
-- Utilities --
---------------

creatura.register_utility("animalia:idle", function(self, timeout, anim)
	local timer = timeout or 1
	local init = false
	local function func(_self)
		if not init then
			creatura.action_idle(_self, timeout, anim)
		end
		timer = timer - _self.dtime
		if timer <= 0 then
			return true
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:die", function(self)
	local timer = 1.5
	local init = false
	local function func(_self)
		if not init then
			_self:play_sound("death")
			creatura.action_fallover(_self)
			init = true
		end
		timer = timer - _self.dtime
		if timer <= 0 then
			local pos = _self.object:get_pos()
			if not pos then return end
			minetest.add_particlespawner({
				amount = 8,
				time = 0.25,
				minpos = {x = pos.x - 0.1, y = pos.y, z = pos.z - 0.1},
				maxpos = {x = pos.x + 0.1, y = pos.y + 0.1, z = pos.z + 0.1},
				minacc = {x = 0, y = 2, z = 0},
				maxacc = {x = 0, y = 3, z = 0},
				minvel = {x = random(-1, 1), y = -0.25, z = random(-1, 1)},
				maxvel = {x = random(-2, 2), y = -0.25, z = random(-2, 2)},
				minexptime = 0.75,
				maxexptime = 1,
				minsize = 4,
				maxsize = 4,
				texture = "creatura_smoke_particle.png",
				animation = {
					type = 'vertical_frames',
					aspect_w = 4,
					aspect_h = 4,
					length = 1,
				},
				glow = 1
			})
			creatura.drop_items(_self)
			_self.object:remove()
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:swim_to_land", function(self)
	local init = false
	local tpos = nil
	local function func(_self)
		if not init then
			for i = 1, 359, 15 do
				local yaw = rad(i)
				local dir = yaw2dir(yaw)
				tpos = animalia.find_collision(_self, dir)
				if tpos then
					local node = minetest.get_node({x = tpos.x, y = tpos.y + 1, z = tpos.z})
					 if node.name == "air" then
						break
					 else
						 tpos = nil
					 end
				end
			end
			init = true
		end
		if tpos then
			local pos = _self.object:get_pos()
			if not pos then return end
			local yaw = _self.object:get_yaw()
			local tyaw = minetest.dir_to_yaw(vec_dir(pos, tpos))
			if abs(tyaw - yaw) > 0.1 then
				_self:turn_to(tyaw, 12)
			end
			_self:set_gravity(-9.8)
			_self:set_forward_velocity(_self.speed * 0.66)
			_self:animate("walk")
			if vec_dist(pos, tpos) < 1
			or (not _self.in_liquid
			and _self.touching_ground) then
				return true
			end
		else
			_self.liquid_recovery_cooldown = 5
			return true
		end
	end
	self:set_utility(func)
end)

-- WIP

-- Wandering

creatura.register_utility("animalia:wander", function(self)
	local idle_max = 4
	local move_chance = 3
	local graze_chance = 16

	--local iter = 1
	local range = self.tracking_range

	local center
	local function func(mob)
		local pos = mob.stand_pos

		if mob:timer(2) then
			--iter = iter < 3 and iter + 1 or 1 -- Iterate to 3, then reset to 1

			-- Grazing Behavior
			if mob.is_grazing_mob
			and random(graze_chance) < 2 then
				local yaw = mob.object:get_yaw()
				if not yaw then return true end

				local turf_pos = {
					x = pos.x + -sin(yaw) * mob.width,
					y = pos.y - 0.5,
					z = pos.z + cos(yaw) * mob.width
				}

				if animalia.eat_turf(mob, turf_pos) then
					add_break_particle(turf_pos)
					creatura.action_idle(mob, 1, "eat")
				end
			end

			-- Herding Behavior
			if mob.is_herding_mob then
				center = animalia.get_average_pos(get_group_positions(mob)) or pos

				if vec_dist(pos, center) < range / 4 then
					center = false
				end
			end

			-- Skittish Behavior
			if mob.is_skittish_mob then
				local plyr = creatura.get_nearby_player(mob)
				local plyr_alive, los, plyr_pos = mob:get_target(plyr)
				if plyr_alive
				and los then
					center = vec_add(pos, vec_dir(plyr_pos, pos))
				end
			end
		end

		if not mob:get_action() then
			if random(move_chance) < 2 then
				animalia.action_walk(mob, 3, 0.2, "walk", center)
				center = false
			else
				creatura.action_idle(mob, random(idle_max), "stand")
			end
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:aerial_wander", function(self)
	local function func(_self)
		if not _self:get_action() then
			local max_boids = self.max_boids or 0
			if max_boids > 0 then
				local pos2 = _self:get_wander_pos(1, 2)
				animalia.action_move_boid(_self, pos2, 4, "animalia:move_no_gravity", 1, "fly")
			else
				animalia.action_wander_fly(_self, 2)
			end
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:aquatic_wander_school", function(self)
	local center = self.object:get_pos()
	if not center then return end
	local center_tick = 0
	local water_nodes = minetest.find_nodes_in_area(vec_sub(center, 4), vec_add(center, 4), {"group:water"})
	local steer_method = calc_steering_and_lift_aquatic
	local function func(_self)
		if #water_nodes < 1 then
			if _self.is_aquatic_mob then
				creatura.action_idle(_self, 1, "flop")
			else
				return true
			end
		end

		if #water_nodes < 10 then
			center_tick = center_tick - 1
			if center_tick <= 0 then
				center_tick = 30
			end
			center = self.object:get_pos()
			if not center then return end
			water_nodes = minetest.find_nodes_in_area(vec_sub(center, 4), vec_add(center, 4), {"group:water"})
		end

		if not _self:get_action() then
			if _self.is_aquatic_mob
			and not _self.in_liquid then
				creatura.action_idle(_self, 1, "flop")
				return
			end

			local pos2 = water_nodes[random(#water_nodes)]
			animalia.action_move_boid(_self, pos2, 3, "animalia:move_no_gravity", 1, "swim", steer_method)
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:aquatic_wander", function(self)
	local center = self.object:get_pos()
	if not center then return end
	local center_tick = 0
	local move_chance = 3
	local idle_duration = 3
	local water_nodes = minetest.find_nodes_in_area(vec_sub(center, 4), vec_add(center, 4), {"group:water"})
	local function func(_self)
		if #water_nodes < 1 then
			if _self.is_aquatic_mob then
				creatura.action_idle(_self, 1, "flop")
			else
				return true
			end
		end

		if #water_nodes < 10 then
			center_tick = center_tick - 1
			if center_tick <= 0 then
				center_tick = 30
			end
			center = self.object:get_pos()
			if not center then return end
			water_nodes = minetest.find_nodes_in_area(vec_sub(center, 4), vec_add(center, 4), {"group:water"})
		end

		if not _self:get_action() then
			if _self.is_aquatic_mob
			and not _self.in_liquid then
				creatura.action_idle(_self, 1, "flop")
				return
			end

			if random(move_chance) < 2 then
				creatura.action_move(_self, water_nodes[random(#water_nodes)], 3, "animalia:steer_no_gravity", 0.5, "swim")
			else
				animalia.action_float(_self, random(idle_duration), "float")
			end
		end
	end
	self:set_utility(func)
end)

-- Environment Interaction

creatura.register_utility("animalia:eat_turf", function(self)
	local action_init = false
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		local yaw = _self.object:get_yaw()
		local dir = vec_normal(yaw2dir(yaw))
		local turf_pos = {
			x = pos.x + dir.x * _self.width,
			y = pos.y - 0.5,
			z = pos.z + dir.z * _self.width
		}
		if not _self:get_action() then
			if action_init then return true end
			for name, sub_name in pairs(_self.consumable_nodes) do
				if minetest.get_node(turf_pos).name == name then
					add_break_particle(turf_pos)
					minetest.set_node(turf_pos, {name = sub_name})
					_self.collected = _self:memorize("collected", false)
					creatura.action_idle(_self, 1, "eat")
					action_init = true
					break
				end
			end
			if not action_init then return true end
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:run_to_pos", function(self, pos2, timeout)
	timeout = timeout or 3
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		if not pos2 then return true end
		if not _self:get_action() then
			local anim = (_self.animations["run"] and "run") or "walk"
			animalia.action_walk(_self, 1, 1, anim, pos2)
		end
		timeout = timeout - _self.dtime
		if timeout <= 0 then
			return true
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:fly_to_roost", function(self)
	local home = self.home_position
	local roost = self.roost_action or creatura.action_idle
	local is_home = self.is_roost or function(pos, home_pos)
		if abs(pos.x - home_pos.x) < 0.5
		and abs(pos.z - home_pos.z) < 0.5
		and abs(pos.y - home_pos.y) < 0.75 then
			return true
		end
		return false
	end
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		if not home then return true end
		if not _self:get_action() then
			if is_home(pos, home) then
				roost(_self, 1, "stand")
				return
			end
			creatura.action_move(_self, home, 3, "animalia:steer_no_gravity", 1, "fly")
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:fly_to_land", function(self)
	local landed = false
	local function func(_self)
		if not _self:get_action() then
			if landed then return true end
			if _self.touching_ground then
				creatura.action_idle(_self, 0.5, "stand")
				landed = true
			else
				local pos2 = _self:get_wander_pos_3d(3, 6)
				if pos2 then
					local dist2floor = creatura.sensor_floor(_self, 10, true)
					pos2.y = pos2.y - dist2floor
					creatura.action_move(_self, pos2, 3, "animalia:move_no_gravity", 0.6, "fly")
				end
			end
		end
	end
	self:set_utility(func)
end)

-- Object Interaction

creatura.register_utility("animalia:follow_player", function(self, player, force)
	local width = self.width
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		local plyr_alive, line_of_sight, plyr_pos = _self:get_target(player)
		if not plyr_alive
		or (not _self:follow_wielded_item(player)
		and not force) then return true end
		local dist = vec_dist(pos, plyr_pos)
		if not _self:get_action() then
			local anim = "walk"
			local speed = 0.5
			if dist > self.tracking_range * 0.5 then
				anim = "run"
				speed = 1
			end
			if dist > width + 2
			and _self:is_pos_safe(plyr_pos) then
				if dist > self.tracking_range * 0.5
				or not line_of_sight then
					creatura.action_move(_self, plyr_pos, 4, "creatura:pathfind", speed, anim)
				else
					animalia.action_pursue(_self, player, 1, "animalia:steer", speed, anim)
				end
			else
				creatura.action_idle(_self, 1)
			end
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:flee_from_target", function(self, target, defend)
	local attention = 5
	local defend_cooldown = defend and 0

	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end

		local tgt_alive, los, tgt_pos = _self:get_target(target)
		if not tgt_alive then self._puncher = nil return true end

		attention = not los and attention - _self.dtime or 5
		if attention <= 0 then self._puncher = nil return true end

		local dist = vec_dist(pos, tgt_pos)
		if dist > _self.tracking_range then self._puncher = nil return true end

		defend_cooldown = defend and ((defend_cooldown > 0 and defend_cooldown - _self.dtime) or 0)

		if defend
		and defend_cooldown <= 0
		and dist < _self.width + 1 then
			animalia.action_punch_aoe(self, target)
			defend_cooldown = 5
		end

		if not _self:get_action() then
			local flee_dir = vec_dir(tgt_pos, pos)
			local pos2 = _self:get_wander_pos(1, 2, flee_dir)
			local anim = (_self.animations["run"] and "run") or "walk"
			animalia.action_walk(_self, 1, 1, anim, pos2)
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:horse_taming", function(self)
	local trust = 5
	local player = self.rider
	local player_props = player and player:get_properties()
	if not player_props then return end
	local player_size = player_props.visual_size
	local mob_size = self.visual_size
	local adj_size = {
		x = player_size.x / mob_size.x,
		y = player_size.y / mob_size.y
	}
	if player_size.x ~= adj_size.x then
		player:set_properties({
			visual_size = adj_size
		})
	end
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		if not player or not creatura.is_alive(player) then return true end

		-- Increase Taming progress while Players view is aligned with the Horses
		local yaw, plyr_yaw = _self.object:get_yaw(), player:get_look_horizontal()
		local yaw_diff = abs(diff(yaw, plyr_yaw))

		trust = yaw_diff < pi / 3 and trust + _self.dtime or trust - _self.dtime * 0.5

		if trust >= 10 then -- Tame
			_self.owner = _self:memorize("owner", player:get_player_name())
			animalia.protect_from_despawn(_self)
			animalia.mount(_self, player)
			animalia.particle_spawner(pos, "creatura_particle_green.png", "float")
		elseif trust <= 0 then -- Fail
			animalia.mount(_self, player)
			animalia.particle_spawner(pos, "creatura_particle_red.png", "float")
		end

		-- Actions
		if not _self:get_action() then
			if random(3) < 2 then
				creatura.action_idle(_self, 0.5, "punch_aoe")
			else
				animalia.action_walk(_self, 2, 0.75, "run")
			end
		end

		-- Dismount
		if not player
		or player:get_player_control().sneak then
			animalia.mount(_self, player)
			return true
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:attack_target", function(self, target)
	local has_attacked = false
	local has_warned = not self.warn_before_attack
	local function func(mob)
		local target_alive, _, target_pos = mob:get_target(target)
		if not target_alive then return true end

		local pos = mob.object:get_pos()
		if not pos then return true end

		if not mob:get_action() then
			if has_attacked then return true, 2 end

			local dist = vec_dist(pos, target_pos)

			if dist > mob.width + 1 then
				if not has_warned
				and dist > mob.width + 2 then
					local yaw = mob.object:get_yaw()
					local yaw_to_target = minetest.dir_to_yaw(vec_dir(pos, target_pos))

					if abs(diff(yaw, yaw_to_target)) > pi / 2 then
						animalia.action_pursue(mob, target)
					else
						creatura.action_idle(mob, 0.5, "warn")
					end
					return
				else
					animalia.action_pursue(mob, target, 0.5)
				end
			else
				animalia.action_melee(mob, target)
				has_attacked = true
			end
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:breed", function(self)
	local mate

	local timer = 0
	local function func(mob)
		mate = mate or animalia.get_nearby_mate(mob, mob.name)
		if not mate then return true end

		local pos, target_pos = mob.object:get_pos(), mate and mate:get_pos()
		if not pos or not target_pos then return true end

		local dist = vec_dist(pos, target_pos)
		timer = dist < mob.width + 0.5 and timer + mob.dtime or timer

		if timer > 2 then
			local mate_entity = mate:get_luaentity()

			mob.breeding = mob:memorize("breeding", false)
			mob.breeding_cooldown = mob:memorize("breeding_cooldown", 300)
			mate_entity.breeding = mate:memorize("breeding", false)
			mate_entity.breeding_cooldown = mate:memorize("breeding_cooldown", 300)

			animalia.particle_spawner(pos, "heart.png", "float")

			for _ = 1, mob.birth_count or 1 do
				if mob.add_child then
					mob:add_child(mate_entity)
				else
					local object = minetest.add_entity(pos, mob.name)
					local ent = object:get_luaentity()
					ent.growth_scale = 0.7
					animalia.initialize_api(ent)
					animalia.protect_from_despawn(ent)
				end
			end
		end

		if not mob:get_action() then
			animalia.action_pursue(mob, mate)
		end
	end
	self:set_utility(func)
end)

-- Move to/Interact

creatura.register_utility("animalia:fly_to_pos_and_interact", function(self, find_node,
																		interact, anim, cooldown)
	local interact_complete = false
	local timeout = 8
	local pos2
	local function func(_self)
		if not find_node or not interact then return true, cooldown end

		local pos = _self.object:get_pos()
		pos2 = pos2 or find_node(_self)
		if not pos or not pos2 then return true, cooldown end

		if not _self:get_action() then
			if interact_complete then return true, cooldown end
			local dist = vec_dist(pos, pos2)

			if dist > max(_self.width, 0.5) + 1 then
				creatura.action_move(_self, pos2, 3, "animalia:move_no_gravity", 1, "fly")
			else
				if interact(_self, pos2) then
					if not _self:get_action() then
						creatura.action_idle(_self, 1, anim)
					end
					interact_complete = true
				else
					return true, cooldown
				end
			end
		end

		timeout = timeout - _self.dtime
		if timeout <= 0 then return true, cooldown end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:walk_to_pos_and_interact", function(self, find_node,
																		interact, anim, cooldown)
	local interact_complete = false
	local timeout = 8
	local pos2
	local function func(_self)
		if not find_node or not interact then return true, cooldown end

		local pos = _self.object:get_pos()
		pos2 = pos2 or find_node(_self)
		if not pos or not pos2 then return true, cooldown end

		if not _self:get_action() then
			if interact_complete then return true, cooldown end
			local dist = vec_dist(pos, pos2)

			if dist > max(_self.width, 0.5) + 1 then
				creatura.action_move(_self, pos2, 4, "creatura:pathfind")
			else
				if interact(_self, pos2) then
					if not _self:get_action() then
						creatura.action_idle(_self, 1, anim)
					end
					interact_complete = true
				else
					return true, cooldown
				end
			end
		end

		timeout = timeout - _self.dtime
		if timeout <= 0 then return true, cooldown end
	end
	self:set_utility(func)
end)

-- Hunting Behavior

creatura.register_utility("animalia:raptor_hunt", function(self, target)
	local attack_cooldown = 0
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		local tgt_alive, los, tgt_pos = _self:get_target(target)
		if not tgt_alive then return end

		attack_cooldown = (attack_cooldown > 0 and attack_cooldown - _self.dtime) or 0

		if not _self:get_action() then
			local tgt_overhead = {
				x = tgt_pos.x,
				y =  tgt_pos.y + 6,
				z = tgt_pos.z
			}
			local dist = vec_dist(pos, tgt_overhead)

			if dist > 8 then
				creatura.action_move(_self, tgt_overhead, 2, "animalia:steer_no_gravity", 0.75, "fly")
			elseif not los
			or attack_cooldown > 0 then
				animalia.action_soar(_self, tgt_overhead, 3, 0.5)
			else
				animalia.action_dive_attack(_self, target, 6)
				attack_cooldown = 12
			end
		end
	end
	self:set_utility(func)
end)

-- Domesticated Behavior

creatura.register_utility("animalia:stay", function(self)
	local function func(_self)
		local order = _self.order or "wander"
		if order ~= "sit" then return true end
		if not _self:get_action() then
			creatura.action_idle(_self, 1, "sit")
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:play_with_player", function(self, player)
	local play_init = false
	local width = self.width
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		local plyr_alive, _, plyr_pos = _self:get_target(player)
		if not plyr_alive
		or _self.trust_cooldown > 0 then return true end
		local dist = vec_dist(pos, plyr_pos)
		if dist < width + 0.5
		and not play_init then
			creatura.action_idle(_self, 0.5, "play")
			_self.object:add_velocity({x = 0, y = 2, z = 0})
			animalia.particle_spawner(pos, "heart.png", "float")
			animalia.add_trust(_self, player, 1)
			play_init = true
		end
		if not _self:get_action() then
			if play_init then return true end
			animalia.action_pursue(_self, player, 1, "creatura:obstacle_avoidance")
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:bother_player", function(self, player)
	local width = self.width
	local play_init = false
	local timeout = 5
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		local plyr_alive, _, plyr_pos = _self:get_target(player)
		if not plyr_alive then return true end
		local dist = vec_dist(pos, plyr_pos)
		if not _self:get_action() then
			if play_init then return true end
			if dist > width then
				animalia.action_pursue(_self, player, 3, "creatura:pathfind", 0.75)
			else
				creatura.action_idle(_self, 0.5, "play")
				play_init = true
			end
		end
		timeout = timeout - _self.dtime
		if timeout <= 0 then return true end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:mount_horse", function(self, player)
	local player_props = player and player:get_properties()
	if not player_props then return end
	local player_size = player_props.visual_size
	local mob_size = self.visual_size
	local adj_size = {
		x = player_size.x / mob_size.x,
		y = player_size.y / mob_size.y
	}
	if player_size.x ~= adj_size.x then
		player:set_properties({
			visual_size = adj_size
		})
	end

	local function func(_self)
		if not creatura.is_alive(player) then
			return true
		end
		local anim = "stand"
		local speed_x = 0
		local tyaw = player:get_look_horizontal()
		local control = player:get_player_control()
		local vel = _self.object:get_velocity()
		if not tyaw then return end

		animate_player(player, "sit", 30)

		if _self:timer(1) then
			player_props = player and player:get_properties()
			if player_props.visual_size.x ~= adj_size.x then
				player:set_properties({
					visual_size = adj_size
				})
			end
		end

		if control.up then
			speed_x = 1
			anim = "walk"
			if control.aux1 then
				speed_x = 1.5
				anim = "run"
			end
		end

		-- Jump Control
		if control.jump
		and _self.touching_ground
		and vel.y < 1 then
			_self.object:add_velocity({
				x = 0,
				y = _self.jump_power * 2,
				z = 0
			})
		elseif not _self.touching_ground then
			speed_x = speed_x * 0.75
		end

		-- Rear Animation when jumping
		if not _self.touching_ground
		and not _self.in_liquid
		and vel.y > 0 then
			anim = "rear"
		end

		-- Steering
		local yaw = _self.object:get_yaw()

		_self.head_tracking = nil
		animalia.move_head(_self, tyaw, 0)

		if speed_x > 0 and control.left then tyaw = tyaw + pi * 0.25 end
		if speed_x > 0 and control.right then tyaw = tyaw - pi * 0.25 end
		if abs(yaw - tyaw) > 0.1 then
			_self:turn_to(tyaw, _self.turn_rate)
		end

		_self:set_forward_velocity(_self.speed * speed_x)
		_self:animate(anim)

		if control.sneak
		or not _self.rider then
			animalia.mount(_self, player)
			return true
		end
	end
	self:set_utility(func)
end)

-- Misc

creatura.register_utility("animalia:flop", function(self)
	local function func(_self)
		if _self.in_liquid then
			return true
		end
		if not _self:get_action() then
			creatura.action_idle(_self, 0.1, "flop")
		end
		_self:set_vertical_velocity(0)
		_self:set_gravity(-9.8)
	end
	self:set_utility(func)
end)

-- Global Utilities

animalia.global_utils = {
	["basic_follow"] = {
		utility = "animalia:follow_player",
		get_score = function(self)
			local lasso_tgt = self._lassod_to
			local lasso = type(lasso_tgt) == "string" and minetest.get_player_by_name(lasso_tgt)
			local force = lasso and lasso ~= false
			local player = (force and lasso) or creatura.get_nearby_player(self)
			if player
			and (self:follow_wielded_item(player)
			or force) then
				return 0.4, {self, player, force}
			end
			return 0
		end
	},
	["basic_flee"] = {
		utility = "animalia:flee_from_target",
		get_score = function(self)
			local puncher = self._puncher
			if puncher
			and puncher:get_pos() then
				return 0.6, {self, puncher}
			end
			self._puncher = nil
			return 0
		end
	}
}
