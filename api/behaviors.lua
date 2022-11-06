---------------
-- Behaviors --
---------------

-- Math --

local abs = math.abs
local atan2 = math.atan2
local cos = math.cos
local floor = math.floor
local pi = math.pi
local sin = math.sin
local rad = math.rad
local random = math.random

local function interp_rad(a, b, w)
	local cs = (1 - w) * cos(a) + w * cos(b)
	local sn = (1 - w) * sin(a) + w * sin(b)
	return atan2(sn, cs)
end

local function diff(a, b) -- Get difference between 2 angles
	return atan2(sin(b - a), cos(b - a))
end

local function clamp(val, min, max)
	if val < min then
		val = min
	elseif max < val then
		val = max
	end
	return val
end

-- Vector --

local vec_dir = vector.direction
local vec_dist = vector.distance
local vec_divide = vector.divide
local vec_len = vector.length
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
			if farming.registered_plants[item_string]
			or farming.registered_plants[item_name] then
				def.groups.crop = 2
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
	animate_player = mcl_player.set_animation
end

local get_collision = creatura.get_collision

local function get_avoidance_dir(self)
	local pos = self.object:get_pos()
	if not pos then return end
	local collide, col_pos = get_collision(self)
	if collide then
		local vel = self.object:get_velocity()
		local ahead = vec_add(pos, vec_normal(self.object:get_velocity()))
		local avoidance_force = vector.subtract(ahead, col_pos)
		avoidance_force.y = 0
		local vel_len = vec_len(vel)
		avoidance_force = vec_multi(vec_normal(avoidance_force), (vel_len > 1 and vel_len) or 1)
		return vec_dir(pos, vec_add(ahead, avoidance_force))
	end
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

local function add_eat_particle(self, item_name)
	local pos, yaw = self.object:get_pos(), self.object:get_yaw()
	if not pos then return end
	local head = self.head_data
	local offset_h = (head and head.pivot_h) or self.width
	local offset_v = (head and head.pivot_v) or self.height
	local head_pos = {
		x = pos.x + sin(yaw) * -offset_h,
		y = pos.y + offset_v,
		z = pos.z + cos(yaw) * offset_h
	}
	local def = minetest.registered_items[item_name]
	local image = def.inventory_image
	if def.tiles then
		image = def.tiles[1].name or def.tiles[1]
	end
	if image then
		local crop = "^[sheet:4x4:" .. random(4) .. "," .. random(4)
		minetest.add_particlespawner({
			pos = head_pos,
			time = 0.5,
			amount = 12,
			collisiondetection = true,
			collision_removal = true,
			vel = {min = {x = -1, y = 1, z = -1}, max = {x = 1, y = 2, z = 1}},
			acc = {x = 0, y = -9.8, z = 0},
			size = {min = 1, max = 2},
			texture = image .. crop
		})
	end
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

local function reset_attack_vals(self)
	self.punch_cooldown = 0
	self.target = nil
end

--------------
-- Movement --
--------------

creatura.register_movement_method("animalia:fly_simple", function(self)
	local box = clamp(self.width, 0.5, 1.5)
	self:set_gravity(0)
	local function func(_self, goal, speed_factor)
		local pos = _self.object:get_pos()
		if not pos then return end
		-- Return true when goal is reached
		if vec_dist(pos, goal) < box * 1.33 then
			_self:halt()
			return true
		end
		-- Get movement direction
		local goal_dir = vec_dir(pos, goal)
		local yaw = _self.object:get_yaw()
		local goal_yaw = dir2yaw(goal_dir)
		local speed = abs(_self.speed or 2) * speed_factor or 0.5
		local turn_rate = abs(_self.turn_rate or 5)
		-- Movement
		local yaw_diff = abs(diff(yaw, goal_yaw))
		if yaw_diff < pi * 0.25 then
			_self:set_forward_velocity(speed)
		else
			_self:set_forward_velocity(speed * 0.33)
		end
		self:set_vertical_velocity(speed * goal_dir.y)
		_self:turn_to(goal_yaw, turn_rate)
		if _self.touching_ground
		or _self.in_liquid then
			_self.object:add_velocity({x = 0, y = 2, z = 0})
		end
	end
	return func
end)

creatura.register_movement_method("animalia:fly_obstacle_avoidance", function(self)
	local steer_to
	local steer_timer = 0.25
	local init_dist
	self:set_gravity(0)
	local function func(_self, goal, speed_factor)
		local pos = _self.object:get_pos()
		if not pos then return end
		local dist = vec_dist(pos, goal)
		init_dist = dist
		if dist < clamp(self.width, 0.5, 1) + 1.5 then
			_self:halt()
			return true
		end
		-- Calculate Movement
		steer_timer = (steer_timer > 0 and steer_timer - self.dtime) or 0.25
		steer_to = (steer_timer <= 0 and creatura.get_context_steering(self, goal, 4, true)) or steer_to
		local speed = abs(_self.speed or 2) * speed_factor or 0.5
		local turn_rate = abs(_self.turn_rate or 5)
		local dist_weight = (init_dist - dist) / init_dist
		-- Apply Movement
		local dir = (steer_to or vec_dir(pos, goal))
		speed = speed - (speed * 0.75) * dist_weight
		turn_rate = turn_rate + turn_rate * dist_weight
		_self:set_forward_velocity(speed)
		_self:set_vertical_velocity(speed * dir.y)
		_self:turn_to(dir2yaw(dir), turn_rate)
	end
	return func
end)

creatura.register_movement_method("animalia:swim_simple", function(self)
	local box = clamp(self.width, 0.5, 1.5)
	self:set_gravity(0)
	local function func(_self, goal, speed_factor)
		local pos = _self.object:get_pos()
		if not pos then return end
		-- Return true when goal is reached
		if vec_dist(pos, goal) < box * 1.33 then
			_self:halt()
			return true
		end
		-- Get movement direction
		local goal_dir = vec_dir(pos, goal)
		local yaw = _self.object:get_yaw()
		local goal_yaw = dir2yaw(goal_dir)
		local speed = abs(_self.speed or 2) * speed_factor or 0.5
		local turn_rate = abs(_self.turn_rate or 5)
		-- Movement
		local yaw_diff = abs(diff(yaw, goal_yaw))
		if yaw_diff < pi * 0.25 then
			_self:set_forward_velocity(speed)
		else
			_self:set_forward_velocity(speed * 0.66)
		end
		self:set_vertical_velocity(speed * goal_dir.y)
		_self:turn_to(goal_yaw, turn_rate)
	end
	return func
end)

creatura.register_movement_method("animalia:swim_obstacle_avoidance", function(self)
	local box = clamp(self.width, 0.5, 1.5)
	local steer_to
	local steer_timer = 0.25
	self:set_gravity(0)
	local function func(_self, goal, speed_factor)
		local pos = _self.object:get_pos()
		if not pos then return end
		-- Return true when goal is reached
		if vec_dist(pos, goal) < box * 1.33 then
			_self:halt()
			return true
		end
		steer_timer = steer_timer - self.dtime
		if steer_timer <= 0 then
			steer_to = get_avoidance_dir(_self)
		end
		-- Get movement direction
		local goal_dir = vec_dir(pos, goal)
		if steer_to then
			steer_to.y = goal_dir.y
			goal_dir = steer_to
		end
		local yaw = _self.object:get_yaw()
		local goal_yaw = dir2yaw(goal_dir)
		local speed = abs(_self.speed or 2) * speed_factor or 0.5
		local turn_rate = abs(_self.turn_rate or 5)
		-- Movement
		local yaw_diff = abs(diff(yaw, goal_yaw))
		if yaw_diff < pi * 0.25
		or steer_to then
			_self:set_forward_velocity(speed)
		else
			_self:set_forward_velocity(speed * 0.33)
		end
		self:set_vertical_velocity(speed * goal_dir.y)
		_self:turn_to(goal_yaw, turn_rate)
	end
	return func
end)

-------------
-- Actions --
-------------

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
		or _self:move_to(goal, method or "animalia:fly_obstacle_avoidance", speed_x) then
			return true
		end
	end
	self:set_action(func)
end

function animalia.action_flight_attack(self, target, timeout)
	local anim = self.animations["fly_punch"]
	local anim_len = (anim.range.y - anim.range.x) / anim.speed
	local anim_time = 0
	local timer = timeout or 12
	local cooldown = 0
	local speed_x = 0.5
	local goal
	local function func(_self)
		local pos = _self.stand_pos
		if timer <= 0 then return true end
		local target_alive, los, tgt_pos = _self:get_target(target)
		if not target_alive then return true end
		local dist = vec_dist(pos, tgt_pos)

		if dist > 32 then return true end

		local vel = self.object:get_velocity()
		if vel.y < 0 and speed_x < 1 then speed_x = speed_x + self.dtime * 0.5 end
		if vel.y >= 0 and speed_x > 0.5 then speed_x = speed_x - self.dtime end

		if anim_time > 0 then
			_self:animate("fly_punch")
			anim_time = anim_time - _self.dtime
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
		and _self:move_to(goal, "animalia:fly_obstacle_avoidance", speed_x) then
			goal = nil
		end
		
		if not goal
		and _self:move_to(tgt_pos, "animalia:fly_obstacle_avoidance", speed_x) then
			if dist < _self.width + 1 then
				_self:punch_target(target)
				cooldown = timeout / 3
				anim_time = anim_len
			end
		end

		timer = timer - _self.dtime
	end
	self:set_action(func)
end

function animalia.action_move_flock(self, pos2, timeout, method, speed_factor, anim, boid_steer)
	local old_boids = (self._movement_data and self._movement_data.boids) or {}
	local boids = (#old_boids > 2 and old_boids) or creatura.get_boid_members(self.object:get_pos(), 12, self.name)
	local timer = timeout or 4
	local boid_pos2
	local function func(_self)
		local pos = self.object:get_pos()
		if not pos then return end
		-- Tick down timer
		timer = timer - _self.dtime
		-- Check if goal is safe
		local safe = true
		local max_fall = (_self.max_fall or 0) > 0 and _self.max_fall
		if max_fall then
			safe = _self:is_pos_safe(pos2)
		end
		-- Boid calculation
		if #boids > 2 then
			local boid_yaw, boid_pitch = creatura.get_boid_angle(self, boids, 12)
			if boid_yaw then
				local dir2pos = vec_dir(pos, pos2)
				local yaw2pos = minetest.dir_to_yaw(dir2pos)
				boid_yaw = interp_rad(boid_yaw, yaw2pos, 0.3)
				local boid_dir = minetest.yaw_to_dir(boid_yaw)
				boid_dir.y = boid_pitch
				boid_pos2 = vec_add(pos, vec_multi(boid_dir, 4))
				if max_fall then
					boid_pos2 = creatura.get_ground_level(boid_pos2, 2)
				end
			end
		end
		local steer_to = boid_steer and get_avoidance_dir(self)
		if steer_to then
			boid_pos2 = {
				x = pos.x + steer_to.x * 2,
				y = pos2.y,
				z = pos.z + steer_to.z * 2
			}
		end
		-- Main movement
		if timer <= 0
		or not safe
		or _self:move_to(boid_pos2 or pos2, method or "creatura:obstacle_avoidance", speed_factor or 0.5) then
			return true
		end
		self:animate(anim or "walk")
	end
	self:set_action(func)
end

function animalia.action_move_boid(self, pos2, timeout, method, speed_factor, anim, water)
	local timer = timeout or 4
	local goal
	local function func(_self)
		local pos, vel = self.object:get_pos(), self.object:get_velocity()
		if not pos then return end
		local move_data = self._movement_data or {}
		-- Tick down timer
		timer = timer - _self.dtime
		-- Check if goal is safe
		local safe = true
		local max_fall = (_self.max_fall or 0) > 0 and _self.max_fall
		if max_fall then
			safe = _self:is_pos_safe(pos2)
		end
		-- Boid calculation
		local boid_dir, boids = move_data.boid_dir or creatura.get_boid_dir(self)
		if boid_dir then
			local heading = vec_dir(pos, pos2)
			boid_dir.y = boid_dir.y + heading.y / 2
			goal = vec_add(pos, vec_multi(boid_dir, self.width + 1))
			if max_fall then
				goal = creatura.get_ground_level(goal, 2)
			end
			if boids then
				for _, obj in ipairs(boids) do
					local ent = obj and obj:get_luaentity()
					if ent then
						ent._movement_data.boid_dir = boid_dir
					end
				end
			end
		else
			goal = pos2
		end
		local steer_dir = creatura.get_context_steering(self, goal, 1, water)
		goal = (steer_dir and vec_add(pos, steer_dir)) or goal
		-- Main movement
		if timer <= 0
		or not safe
		or _self:move_to(goal, method or "creatura:obstacle_avoidance", speed_factor or 0.5) then
			return true
		end
		self:animate(anim or "walk")
		self._movement_data.boid_dir = nil
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
	local timeout = 2
	local function func(_self)
		local tgt_alive, _, tgt_pos = _self:get_target(target)
		if not tgt_alive then return true end
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
		if dist < _self.width + 1 then
			_self:punch_target(target)
			local knockback = minetest.calculate_knockback(
				target, self.object, 1.0,
				{damage_groups = {fleshy = self.damage}},
				dir, 2.0, self.damage
			)
			target:add_velocity({x = dir.x * knockback, y = dir.y * knockback, z = dir.z * knockback})
			return true
		end
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

---------------
-- Utilities --
---------------

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

-- Wandering

creatura.register_utility("animalia:wander", function(self)
	local move_chance = self.move_chance or 5
	local idle_duration = self.idle_time or 4
	local center = self.object:get_pos()
	if not center then return end
	local move = self.wander_action or creatura.action_move
	local function func(_self)
		if not _self:get_action() then
			local pos2 = _self:get_wander_pos(2, 3)
			if random(move_chance) < 2
			and vec_dist(pos2, center) < _self.tracking_range * 0.5 then
				move(_self, pos2, 2)
			else
				creatura.action_idle(_self, random(idle_duration), "stand")
			end
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:wander_group", function(self)
	local move_chance = self.move_chance or 3
	local idle_duration = self.idle_time or 3
	local center = self.object:get_pos()
	if not center then return end
	local cntr_timer = 30
	local move = self.wander_action or animalia.action_move_boid
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		cntr_timer = cntr_timer - _self.dtime
		if cntr_timer <= 0 then
			local grp_pos = get_group_positions(_self)
			center = animalia.get_average_pos(grp_pos) or pos
			cntr_timer = 30
		end
		if not _self:get_action() then
			if random(move_chance) < 2 then
				local move_dir
				if vec_dist(pos, center) > _self.tracking_range * 0.25 then
					move_dir = vec_dir(pos, center)
				end
				local pos2 = _self:get_wander_pos(2, 3, move_dir)
				move(_self, pos2, 2)
			else
				creatura.action_idle(_self, random(idle_duration))
			end
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:wander_skittish", function(self)
	local move_chance = self.move_chance or 3
	local idle_duration = self.idle_time or 3
	local center = self.object:get_pos()
	if not center then return end
	local plyr_tick = 500
	local move_dir
	local move = self.wander_action or creatura.action_move
	local function func(_self)
		plyr_tick = plyr_tick - 1
		if plyr_tick <= 0 then
			local pos = _self.object:get_pos()
			if not pos then return true end
			local plyr = creatura.get_nearby_player(_self)
			local plyr_alive, los, plyr_pos = _self:get_target(plyr)
			if plyr_alive
			and los then
				move_dir = vec_dir(plyr_pos, pos)
			end
			plyr_tick = 500
		end
		if not _self:get_action() then
			local pos2 = _self:get_wander_pos(2, 3, move_dir)
			if random(move_chance) < 2
			and vec_dist(pos2, center) < _self.tracking_range * 0.5 then
				move(_self, pos2, 2)
				move_dir = nil
			else
				creatura.action_idle(_self, random(idle_duration))
			end
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:aerial_wander", function(self)
	local center = self.object:get_pos()
	if not center then return end
	local height_tick = 0
	local move = self.wander_action or creatura.action_move
	local function func(_self)
		local pos = self.object:get_pos()
		if not pos then return end
		height_tick = height_tick - 1
		if height_tick <= 0 then
			local dist2floor = creatura.sensor_floor(self, 2, true)
			center.y = center.y + (2 - dist2floor)
			height_tick = 30
		end
		if not _self:get_action() then
			local move_dir = (vec_dist(pos, center) > 8 and vec_dir(pos, center)) or nil
			local pos2 = _self:get_wander_pos_3d(2, 5, move_dir)
			move(_self, pos2, 3, "animalia:fly_simple", 1, "fly", true)
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
			creatura.action_move(_self, home, 3, "animalia:fly_obstacle_avoidance", 1, "fly")
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
					creatura.action_move(_self, pos2, 3, "animalia:fly_simple", 0.6, "fly")
				end
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
	local function func(_self)
		if #water_nodes < 1 then return true end
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
			animalia.action_move_boid(_self, water_nodes[random(#water_nodes)], 3, "animalia:swim_simple", 1, "swim")
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
		if #water_nodes < 1 then return true end
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
			if random(move_chance) < 2 then
				creatura.action_move(_self, water_nodes[random(#water_nodes)], 3, "animalia:swim_obstacle_avoidance", 0.5, "swim")
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

creatura.register_utility("animalia:eat_bug", function(self, bug)
	local timer = 0.2
	local action_init = false
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		if not bug then return true end
		local dist = vec_dist(pos, bug)
		local dir = vec_dir(pos, bug)
		local frame = floor(dist * 10)
		if not _self:get_action() then
			if dist > 1 then
				local pos2 = vec_add(bug, vec_multi(vec_normal(vec_dir(bug, pos)), 0.25))
				creatura.action_move(_self, pos2, 1)
			else
				animalia.move_head(_self, dir2yaw(dir), dir.y)
				creatura.action_idle(_self, 0.1, "tongue_" .. frame)
				action_init = true
			end
		end
		if action_init then
			timer = timer - _self.dtime
			if timer <= 0 then
				minetest.remove_node(bug)
				return true
			end
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
			creatura.action_move(_self, pos2, 2, "creatura:obstacle_avoidance", 1, anim)
		end
		timeout = timeout - _self.dtime
		if timeout <= 0 then
			return true
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
		local plyr_alive, _, plyr_pos = _self:get_target(player)
		if not plyr_alive
		or (not _self:follow_wielded_item(player)
		and not force) then return true end
		local dist = vec_dist(pos, plyr_pos)
		if not _self:get_action() then
			if dist > width + 1 then
				animalia.action_pursue(_self, player, 3, "creatura:context_based_steering", 0.75)
			else
				creatura.action_idle(_self, 1)
			end
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:flee_from_target", function(self, target)
	local los_timeout = 3
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		local tgt_alive, los, tgt_pos = _self:get_target(target)
		if not tgt_alive then self._puncher = nil return true end
		if not los then
			los_timeout = los_timeout - _self.dtime
		else
			los_timeout = 3
		end
		if los_timeout <= 0 then self._puncher = nil return true end
		local dist = vec_dist(pos, tgt_pos)
		if dist > _self.tracking_range then self._puncher = nil return true end
		if not _self:get_action() then
			local flee_dir = vec_dir(tgt_pos, pos)
			local pos2 = _self:get_wander_pos(2, 3, flee_dir)
			local anim = (_self.animations["run"] and "run") or "walk"
			creatura.action_move(_self, pos2, 2, "creatura:context_based_steering", 1, anim)
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:flee_from_target_defend", function(self, target)
	local los_timeout = 3
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		local tgt_alive, los, tgt_pos = _self:get_target(target)
		if not tgt_alive then self._puncher = nil return true end
		if not los then
			los_timeout = los_timeout - _self.dtime
		else
			los_timeout = 3
		end
		if los_timeout <= 0 then self._puncher = nil return true end
		local dist = vec_dist(pos, tgt_pos)
		if dist > _self.tracking_range then self._puncher = nil return true end
		if not _self:get_action() then
			local flee_dir = vec_dir(tgt_pos, pos)
			local pos2 = _self:get_wander_pos(2, 3, flee_dir)
			local anim = (_self.animations["run"] and "run") or "walk"
			if dist > _self.width + 0.5 then
				creatura.action_move(_self, pos2, 2, "creatura:obstacle_avoidance", 1, anim)
			else
				animalia.action_punch_aoe(self, target)
			end
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:tame_horse", function(self)
	local center = self.object:get_pos()
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
		if not _self.rider
		or not creatura.is_alive(_self.rider) then return true end
		player = _self.rider
		animate_player(player, "sit", 30)
		if _self:timer(1) then
			player_props = player and player:get_properties()
			if player_props.visual_size.x ~= adj_size.x then
				player:set_properties({
					visual_size = adj_size
				})
			end
		end
		if not _self:get_action() then
			if random(6) < 2 then
				creatura.action_idle(_self, 0.5, "punch_aoe")
			else
				local dir = vec_dist(pos, center) > 8 and vec_dir(pos, center)
				local pos2 = _self:get_wander_pos(2, 4, dir)
				creatura.action_move(_self, pos2, 3, "creatura:obstacle_avoidance", 1, "run")
			end
		end
		local yaw = _self.object:get_yaw()
		local plyr_yaw = player:get_look_horizontal()
		if abs(diff(yaw, plyr_yaw)) < pi * 0.25 then
			trust = trust + _self.dtime
		else
			trust = trust - _self.dtime * 0.5
		end
		local min_pos = {x = pos.x, y = pos.y + 2, z = pos.z}
		local max_pos = {x = pos.x, y = pos.y + 2, z = pos.z}
		if trust <= 0 then
			animalia.mount(_self, player)
			animalia.particle_spawner(pos, "creatura_particle_red.png", "float", min_pos, max_pos)
			return true
		end
		if trust >= 10 then
			_self.owner = self:memorize("owner", player:get_player_name())
			animalia.protect_from_despawn(_self)
			animalia.mount(_self, player)
			animalia.particle_spawner(pos, "creatura_particle_green.png", "float", min_pos, max_pos)
			return true
		end
		if not player
		or player:get_player_control().sneak then
			animalia.mount(_self, player)
			return true
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:attack_target", function(self, target)
	local width = self.width
	local punch_init = false
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		local tgt_alive, _, tgt_pos = _self:get_target(target)
		if not tgt_alive then reset_attack_vals(self) return true end
		local dist = vec_dist(pos, tgt_pos)
		if dist > self.tracking_range then reset_attack_vals(self) return true end
		local punch_cooldown = self.punch_cooldown or 0
		if punch_cooldown > 0 then
			punch_cooldown = punch_cooldown - self.dtime
		end
		self.punch_cooldown = punch_cooldown
		if punch_cooldown <= 0
		and dist < width + 1
		and not punch_init then
			punch_init = true
			animalia.action_punch(_self, target)
			self.punch_cooldown = 1.5
		end
		if not _self:get_action() then
			if punch_init then reset_attack_vals(self) return true end
			animalia.action_pursue(_self, target, 3, "creatura:pathfind", 0.75)
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:glide_attack_target", function(self, target)
	local hidden_timer = 1
	local attack_init = false
	local function func(_self)
		local pos, yaw = _self.object:get_pos(), _self.object:get_yaw()
		if not pos then return end
		local target_alive, los, tgt_pos = _self:get_target(target)
		if not target_alive then
			_self._target = nil
			return true
		end
		if not _self:get_action() then
			if attack_init then return true end
			local dist = vec_dist(pos, tgt_pos)
			if dist > 14 then
				creatura.action_move(_self, tgt_pos, 3, "animalia:fly_obstacle_avoidance", 0.5, "fly")
			else
				animalia.action_flight_attack(_self, target, 12)
			end
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:breed", function(self)
	local mate = animalia.get_nearby_mate(self, self.name)
	if not mate then self.breeding = false return end
	local breeding_time = 0
	local function func(_self)
		if not _self.breeding then return true end
		local pos = _self.object:get_pos()
		if not pos then return end
		local tgt_pos = mate:get_pos()
		if not tgt_pos then return end
		local dist = vec_dist(pos, tgt_pos)
		if dist < _self.width + 0.5 then
			breeding_time = breeding_time + _self.dtime
		end
		if breeding_time > 2 then
			local mate_ent = mate:get_luaentity()
			_self.breeding = self:memorize("breeding", false)
			_self.breeding_cooldown = _self:memorize("breeding_cooldown", 300)
			mate_ent.breeding = mate_ent:memorize("breeding", false)
			mate_ent.breeding_cooldown = mate_ent:memorize("breeding_cooldown", 300)
			local minp = vector.subtract(pos, 1)
			local maxp = vec_add(pos, 1)
			animalia.particle_spawner(pos, "heart.png", "float", minp, maxp)
			for _ = 1, _self.birth_count or 1 do
				if _self.add_child then
					_self:add_child(mate)
				else
					local object = minetest.add_entity(pos, _self.name)
					local ent = object:get_luaentity()
					ent.growth_scale = 0.7
					animalia.initialize_api(ent)
					animalia.protect_from_despawn(ent)
				end
			end
			return true
		end
		if not _self:get_action() then
			creatura.action_move(_self, tgt_pos)
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:fly_to_food", function(self, food_item)
	local eat_init = false
	local function func(_self)
		local pos, tgt_pos = _self.object:get_pos(), food_item and food_item:get_pos()
		if not pos then return end
		if not tgt_pos and not eat_init then return true end
		local dist = vec_dist(pos, tgt_pos or pos)
		if dist < 1
		and not eat_init then
			eat_init = true
			local food_ent = food_item:get_luaentity()
			local stack = ItemStack(food_ent.itemstring)
			if stack
			and stack:get_count() > 1 then
				stack:take_item()
				food_ent.itemstring = stack:to_string()
			else
				food_item:remove()
			end
			self.object:get_yaw(dir2yaw(vec_dir(pos, tgt_pos)))
			add_eat_particle(self, "animalia:rat_raw")
			creatura.action_idle(_self, 1, "eat")
			self.eat_cooldown = 60
			if self.on_eat_drop then
				self:on_eat_drop()
			end
		end
		if not _self:get_action() then
			if eat_init then return true end
			creatura.action_move(_self, tgt_pos, 3, "animalia:fly_simple", 1, "fly")
		end
	end
	self:set_utility(func)
end)

creatura.register_utility("animalia:walk_to_food", function(self, food_item)
	local eat_init = false
	local function func(_self)
		local pos, tgt_pos = _self.object:get_pos(), food_item and food_item:get_pos()
		if not pos then return end
		if not tgt_pos and not eat_init then return true end
		local dist = vec_dist(pos, tgt_pos or pos)
		if dist < 1
		and not eat_init then
			eat_init = true
			local food_ent = food_item:get_luaentity()
			local stack = ItemStack(food_ent.itemstring)
			if stack
			and stack:get_count() > 1 then
				stack:take_item()
				food_ent.itemstring = stack:to_string()
			else
				food_item:remove()
			end
			self.object:get_yaw(dir2yaw(vec_dir(pos, tgt_pos)))
			add_eat_particle(self, "animalia:rat_raw")
			local anim = (self.animations["eat"] and "eat") or "stand"
			creatura.action_idle(_self, 1, anim)
			self.eat_cooldown = 60
			if self.on_eat_drop then
				self:on_eat_drop()
			end
		end
		if not _self:get_action() then
			if eat_init then return true end
			creatura.action_move(_self, tgt_pos, 3, "creatura:context_based_steering", 0.5, "walk")
		end
	end
	self:set_utility(func)
end)

-- Pest Behavior

creatura.register_utility("animalia:eat_crop", function(self)
	local center = self.object:get_pos()
	if not center then return end
	local width = self.width
	local timeout = 8
	local nodes = minetest.find_nodes_in_area(vec_sub(center, 6), vec_add(center, 6), "group:crop") or {}
	local pos2
	local anim_init = false
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		if #nodes < 1 then return true end
		if not _self:get_action() then
			if anim_init then return true end
			pos2 = pos2 or nodes[random(#nodes)]
			local node_name = minetest.get_node(pos2).name
			local dist = vec_dist(pos, pos2)
			if dist < width + 0.5 then
				local new_name = node_name:sub(1, #node_name - 1) .. (tonumber(node_name:sub(-1)) or 2) - 1
				local new_def = minetest.registered_nodes[new_name]
				if not new_def then return true end
				local p2 = new_def.place_param2 or 1
				minetest.set_node(pos2, {name = new_name, param2 = p2})
				add_eat_particle(self, new_name)
				anim_init = true
				creatura.action_idle(_self, 0.5, "eat")
			else
				creatura.action_move(_self, pos2, 4, "creatura:context_based_steering")
			end
		end
		timeout = timeout - _self.dtime
		if timeout <= 0 then return true end
	end
	self:set_utility(func)
end)

local function take_food_from_chest(self, pos)
	local inv = minetest.get_inventory({type = "node", pos = pos})
	if inv
	and inv:get_list("main") then
		for i, stack in ipairs(inv:get_list("main")) do
			local item_name = stack:get_name()
			local def = minetest.registered_items[item_name]
			for group in pairs(def.groups) do
				if group:match("food_") then
					stack:take_item()
					inv:set_stack("main", i, stack)
					add_eat_particle(self, item_name)
					return true
				end
			end
		end
	end
end

creatura.register_utility("animalia:steal_from_chest", function(self)
	local center = self.object:get_pos()
	if not center then return end
	local width = self.width
	local timeout = 8
	local nodes = minetest.find_nodes_with_meta(vec_sub(center, 6), vec_add(center, 6)) or {}
	local pos2
	for _, node_pos in ipairs(nodes) do
		local meta = minetest.get_meta(node_pos)
		if meta:get_string("owner") == "" then
			local inv = minetest.get_inventory({type = "node", pos = node_pos})
			if inv
			and inv:get_list("main") then
				pos2 = node_pos
			end
		end
	end
	local anim_init = false
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		if not pos2 then return true end
		if not _self:get_action() then
			if anim_init then return true end
			local dist = vec_dist(pos, pos2)
			if dist < width + 1.1 then
				anim_init = true
				if take_food_from_chest(self, pos2) then
					creatura.action_idle(_self, 0.5, "eat")
				end
			else
				creatura.action_move(_self, pos2, 2, "creatura:context_based_steering")
			end
		end
		timeout = timeout - _self.dtime
		if timeout <= 0 then return true end
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

creatura.register_utility("animalia:destroy_nearby_vessel", function(self)
	local width = self.width
	local timeout = 8
	local nodes
	local glass_vessels = {"vessels:glass_bottle", "vessels:drinking_glass"}
	local pos2
	local function func(_self)
		local pos = _self.object:get_pos()
		if not pos then return end
		nodes = nodes or minetest.find_nodes_in_area(vec_sub(pos, 6), vec_add(pos, 6), glass_vessels) or {}
		if #nodes < 1 then return true end
		if not _self:get_action() then
			pos2 = pos2 or nodes[random(#nodes)]
			local dist = vec_dist(pos, pos2)
			if dist < width + 0.5 then
				creatura.action_idle(_self, 0.7, "smack")
				minetest.remove_node(pos2)
				minetest.add_item(pos2, "vessels:glass_fragments")
				return true
			else
				creatura.action_move(_self, pos2, 4, "creatura:pathfind")
			end
		end
		timeout = timeout - self.dtime
		if timeout <= 0 then return true end
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
		if control.jump
		and _self.touching_ground
		and vel.y < 1 then
			_self.object:add_velocity({
				x = 0,
				y = _self.jump_power,
				z = 0
			})
		elseif not _self.touching_ground then
			speed_x = speed_x * 0.75
		end
		if not _self.touching_ground
		and not _self.in_liquid
		and vel.y > 0 then
			anim = "rear"
		end
		local yaw = self.object:get_yaw()
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