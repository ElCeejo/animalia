---------------
-- Behaviors --
---------------

-- Math --

local abs = math.abs
local random = math.random
local ceil = math.ceil
local floor = math.floor
local rad = math.rad

local function average(t)
    local sum = 0
    for _,v in pairs(t) do -- Get the sum of all numbers in t
      sum = sum + v
    end
    return sum / #t
end

local function clamp(val, min, max)
	if val < min then
		val = min
	elseif max < val then
		val = max
	end
	return val
end

-- Vector Math --

local vec_dist = vector.distance
local vec_dir = vector.direction
local vec_sub = vector.subtract
local vec_add = vector.add
local vec_multi = vector.multiply
local vec_normal = vector.normalize

local function vec_raise(v, n)
    return {x = v.x, y = v.y + n, z = v.z}
end

local yaw2dir = minetest.yaw_to_dir
local dir2yaw = minetest.dir_to_yaw

--------------
-- Settings --
--------------

------------
-- Tables --
------------

local is_flyable = {}
local is_liquid = {}
local is_solid = {}

minetest.register_on_mods_loaded(function()
    for name in pairs(minetest.registered_nodes) do
        if name ~= "air" and name ~= "ignore" then
            if minetest.registered_nodes[name].walkable
            or minetest.registered_nodes[name].drawtype == "liquid" then
                is_flyable[name] = true
                if minetest.registered_nodes[name].walkable then
                    is_solid[name] = true
                else
                    is_liquid[name] = true
                end
            end
        end
    end
end)

---------------------
-- Local Utilities --
---------------------

local moveable = creatura.is_pos_moveable
local fast_ray_sight = creatura.fast_ray_sight
local get_node_def = creatura.get_node_def

local function get_ground_level(pos2, max_height)
    local node = minetest.get_node(pos2)
    local node_under = minetest.get_node({
        x = pos2.x,
        y = pos2.y - 1,
        z = pos2.z
    })
    local height = 0
    local walkable = is_solid[node_under.name] and not is_solid[node.name]
    if walkable then
        return pos2
    elseif not walkable then
        if not is_solid[node_under.name] then
            while not is_solid[node_under.name]
            and height < max_height do
                pos2.y = pos2.y - 1
                node_under = minetest.get_node({
                    x = pos2.x,
                    y = pos2.y - 1,
                    z = pos2.z
                })
                height = height + 1
            end
        else
            while is_solid[node.name]
            and height < max_height do
                pos2.y = pos2.y + 1
                node = minetest.get_node(pos2)
                height = height + 1
            end
        end
        return pos2
    end
end

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
        and is_solid[minetest.get_node(i_pos).name] then
            table.insert(output, i_pos)
        end
    end
    return output
end

local function get_obstacle_avoidance(self, lift)
    local pos = self.object:get_pos()
    local yaw = self.object:get_yaw()
    pos.y = pos.y + self.stepheight
    local vel = self.object:get_velocity()
    local vel_len = abs(vector.length(vel))
    if vel_len < 1.5 then
        vel_len = 1.5
    end
    local dir = yaw2dir(yaw)
    dir.y = lift
    local outset = vec_add(pos, vec_multi(dir, vel_len))
    local pos2
    local obstacle = false
    if not fast_ray_sight(pos, outset) then
        pos2 = vec_add(pos, vec_multi(dir, -vel_len))
        obstacle = true
    end
    return pos2, obstacle
end

local function get_wander_pos_3d(self, range)
    local outset = random(range or 4)
    local pos = self.object:get_pos()
    local move_dir = {
        x = random(-10, 10) * 0.1,
        z = random(-10, 10) * 0.1,
        y = random(-10, 10) * 0.1
    }
    local pos2 = vec_add(pos, vec_multi(vec_normal(move_dir), random(1, outset)))
    local sight, dist = fast_ray_sight(pos, pos2, true)
    if not sight then
        pos2 = vec_add(pos, vec_multi(vec_normal(move_dir), dist - 0.5))
    end
    return pos2
end

local function get_boid_members(pos, radius, name, texture_no)
    local objects = minetest.get_objects_inside_radius(pos, radius)
    if #objects < 2 then return {} end
    local members = {}
    local max_boid = minetest.registered_entities[name].max_boids or 7
    for i = 1, #objects do
        if #members > max_boid then break end
        local object = objects[i]
        if object:get_luaentity()
        and object:get_luaentity().name == name 
        and object:get_luaentity().texture_no == texture_no  then
            object:get_luaentity().boid_heading = rad(random(360))
            table.insert(members, object)
        end
    end
    return members
end

----------------------
-- Movement Methods --
----------------------

local function movement_fly(self, pos2)
    -- Initial Properties
    local pos = self.object:get_pos()
    local turn_rate = self.turn_rate or 10
    local speed = self.speed or 2
    self:animate("fly")
    self:set_gravity(0)
    -- Collision Avoidance
    local temp_goal = self._movement_data.temp_goal
    local obstacle = self._movement_data.obstacle or false
    if not temp_goal
    or self:pos_in_box(temp_goal, self.width) then
        self._movement_data.temp_goal, self._movement_data.obstacle = get_obstacle_avoidance(self, vec_dir(pos, pos2).y)
    end
    local neighbor = self._movement_data.temp_goal
    -- Calculate Movement
    local dir = vector.direction(pos, pos2)
    local tyaw = minetest.dir_to_yaw(dir)
    if neighbor then
        local lift = dir.y
        dir = vector.direction(pos, neighbor)
        if not obstacle then
            dir.y = lift
        end
        tyaw = minetest.dir_to_yaw(dir)
    end
    if self._path
    and #self._path > 1 then
        neighbor = self._path[2]
        dir = vector.direction(pos, neighbor)
        tyaw = minetest.dir_to_yaw(dir)
        if self:pos_in_box(neighbor, self.width + 0.2) then
            table.remove(self._path, 1)
        end
    else
        self._path = creatura.find_path(self, pos, pos2, self.width, self.height, 300, false, true)
    end
    -- Apply Movement
    self:turn_to(tyaw, turn_rate)
    self:set_forward_velocity(speed)
    local v_speed = speed * dir.y
    local vel = self.object:get_velocity()
    vel.y = vel.y + (v_speed - vel.y) * 0.2
    self:set_vertical_velocity(vel.y)
    if self:pos_in_box(pos2) then
        self:halt()
    end
end

creatura.register_movement_method("animalia:fly_path", movement_fly)

local function movement_fly_waypoints(self, pos2, speed)
    -- Initial Properties
    local pos = self.object:get_pos()
    self:animate("fly")
    self:set_gravity(0)
    -- Collision Avoidance
    local temp_goal = self._movement_data.temp_goal
    local obstacle = self._movement_data.obstacle or false
    if not temp_goal
    or self:pos_in_box(temp_goal, 0.4) then
        self._movement_data.temp_goal, self._movement_data.obstacle = get_obstacle_avoidance(self, vec_dir(pos, pos2).y)
    end
    local neighbor = self._movement_data.temp_goal
    -- Calculate Movement
    local dir = vector.direction(pos, pos2)
    local tyaw = minetest.dir_to_yaw(dir)
    local turn_rate = self.turn_rate or 10
    local speed = self.speed or 2
    if neighbor then
        local lift = dir.y
        dir = vector.direction(pos, neighbor)
        if not obstacle then
            dir.y = lift
        end
        tyaw = minetest.dir_to_yaw(dir)
    end
    -- Apply Movement
    self:turn_to(boid_angle or tyaw, turn_rate)
    self:set_forward_velocity(speed)
    local v_speed = speed * dir.y
    local vel = self.object:get_velocity()
    vel.y = vel.y + (v_speed - vel.y) * 0.2
    self:set_vertical_velocity(vel.y)
    if self:pos_in_box(pos2) then
        self:halt()
    end
end

creatura.register_movement_method("animalia:fly_waypoints", movement_fly_waypoints)

-- Fly Obstacle Avoidance --

local function movement_fly_obstacle_avoidance(self, pos2, speed)
    -- Initial Properties
    local pos = self.object:get_pos()
    local turn_rate = self.turn_rate or 10
    local speed = self.speed or 2
    self:animate("fly")
    self:set_gravity(0)
    -- Collision Avoidance
    local temp_goal = self._movement_data.temp_goal
    local obstacle = self._movement_data.obstacle or false
    local timer = self._movement_data.timer
    if not temp_goal
    or self:pos_in_box(temp_goal, 0.4)
    or (timer
    and timer <= 0) then
        self._movement_data.temp_goal, self._movement_data.obstacle = get_obstacle_avoidance(self, vec_dir(pos, pos2).y)
        temp_goal = self._movement_data.temp_goal
        obstacle = self._movement_data.obstacle or false
        if temp_goal then
            self._movement_data.timer = 3
        end
    end
    if timer then
        self._movement_data.timer = self._movement_data.timer - self.dtime
    end
    -- Calculate Movement
    local dir = vector.direction(pos, pos2)
    local tyaw = minetest.dir_to_yaw(dir)
    if temp_goal
    and obstacle then
        dir = vector.direction(pos, temp_goal)
        dir.y = vec_dir(pos, pos2).y
        tyaw = minetest.dir_to_yaw(dir)
    end
    -- Apply Movement
    self:turn_to(tyaw, turn_rate)
    self:set_forward_velocity(speed)
    local v_speed = (speed) * dir.y
    local vel = self.object:get_velocity()
    vel.y = vel.y + (v_speed - vel.y) * 0.2
    self:set_vertical_velocity(vel.y)
    if self:pos_in_box(pos2, 0.5) then
        self:halt()
    end
end

creatura.register_movement_method("animalia:fly_obstacle_avoidance", movement_fly_obstacle_avoidance)

-- Swimming --

local function movement_swim_obstacle_avoidance(self, pos2, speed)
    -- Initial Properties
    local pos = self.object:get_pos()
    self:animate("swim")
    self:set_gravity(0)
    -- Collision Avoidance
    local temp_goal = self._movement_data.temp_goal
    local obstacle = self._movement_data.obstacle or false
    local timer = self._movement_data.timer
    if not temp_goal
    or self:pos_in_box(temp_goal, 0.4)
    or (timer
    and timer <= 0) then
        self._movement_data.temp_goal, self._movement_data.obstacle = get_obstacle_avoidance(self, vec_dir(pos, pos2).y)
        temp_goal = self._movement_data.temp_goal
        obstacle = self._movement_data.obstacle or false
        if temp_goal then
            self._movement_data.timer = vec_dist(pos, temp_goal) / self.speed
        end
    end
    if timer then
        self._movement_data.timer = self._movement_data.timer - self.dtime
    end
    -- Calculate Movement
    local dir = vector.direction(pos, pos2)
    local tyaw = minetest.dir_to_yaw(dir)
    if temp_goal
    and obstacle then
        dir = vector.direction(pos, temp_goal)
        tyaw = minetest.dir_to_yaw(dir)
    end
    -- Apply Movement
    self:turn_to(tyaw, turn_rate)
    self:set_forward_velocity(speed)
    local v_speed = speed * dir.y
    local vel = self.object:get_velocity()
    vel.y = vel.y + (v_speed - vel.y) * 0.2
    if not is_liquid[minetest.get_node(vec_raise(pos, 1)).name]
    and vel.y > 0 then
        vel.y = 0
    end
    self:set_vertical_velocity(vel.y)
    if self:pos_in_box(pos2) then
        self:halt()
    end
end

creatura.register_movement_method("animalia:swim_obstacle_avoidance", movement_swim_obstacle_avoidance)

-------------
-- Actions --
-------------

function animalia.action_fall(self)
    local function func(self)
        self:animate("fall")
        self:set_gravity(-1)
        local vel = self.object:get_velocity()
        if vel.y < -3.8 then
            self:set_vertical_velocity(-0.1)
        end
        self._fall_start = nil
        if self.touching_ground then
            return true
        end
    end
    self:set_action(func)
end

function animalia.action_punch(self, target)
    local function func(self)
        if not creatura.is_alive(target) then
            return true
        end
        local yaw = self.object:get_yaw()
        local pos = self.object:get_pos()
        local tpos = target:get_pos()
        local dir = vector.direction(pos, tpos)
        local tyaw = minetest.dir_to_yaw(dir)
        self:turn_to(tyaw)
        if self.touching_ground then
            self:animate("leap")
            local jump_vel = vec_multi(dir, self.speed)
            jump_vel.y = 3
            self.object:add_velocity(jump_vel)
        end
        if vec_dist(pos, tpos) < 2 then
            self:punch_target(target)
            return true
        end
    end
    self:set_action(func)
end

function animalia.action_latch_to_ceil(self, time, anim)
    local timer = time
    local function func(self)
        self:halt()
        self:set_forward_velocity(0)
        self:set_vertical_velocity(9)
        self:set_gravity(3)
        self:animate(anim or "latch")
        timer = timer - self.dtime
        if timer <= 0 then
            return true
        end
    end
    self:set_action(func)
end

function animalia.action_boid_move(self, pos2, timeout, method)
    local boids = get_boid_members(self.object:get_pos(), 6, self.name, self.texture_no)
    local timer = timeout
    local goal = pos2
    local function func(self)
        local pos = self.object:get_pos()
        timer = timer - self.dtime
        if #boids > 2 then
            local boid_angle, boid_lift = creatura.get_boid_angle(self, boids, 6)
            if boid_angle then
                local dir2goal = vec_dir(pos, goal)
                local yaw2goal = minetest.dir_to_yaw(dir2goal)
                boid_angle = boid_angle + (yaw2goal - boid_angle) * 0.25
                local boid_dir = minetest.yaw_to_dir(boid_angle)
                if boid_lift then
                    boid_dir.y = boid_lift + (vec_dir(pos, goal).y - boid_lift) * 0.25
                else
                    boid_dir.y = vec_dir(pos, goal).y
                end
                boid_dir = vector.normalize(boid_dir)
                goal = vec_add(pos, vec_multi(boid_dir, vec_dist(pos, goal)))
            end
        end
        if timer <= 0
        or self:pos_in_box(goal, 0.5) then
            self:halt()
            return true
        end
        self:move(goal, method or "animalia:fly_obstacle_avoidance", 1)
    end
    self:set_action(func)
end

function animalia.action_boid_walk(self, pos2, timeout, method, speed_factor, anim)
    local boids = creatura.get_boid_members(self.object:get_pos(), 12, self.name)
    local timer = timeout
    local move_init = false
    local goal = pos2
    local function func(self)
        local pos = self.object:get_pos()
        timer = timer - self.dtime
        if #boids > 2 then
            local boid_angle = creatura.get_boid_angle(self, boids, 12)
            if boid_angle then
                local dir2goal = vec_dir(pos, goal)
                local yaw2goal = minetest.dir_to_yaw(dir2goal)
                boid_angle = boid_angle + (yaw2goal - boid_angle) * 0.15
                local boid_dir = minetest.yaw_to_dir(boid_angle)
                pos2 = get_ground_level(vec_add(pos, vec_multi(boid_dir, 4)), 2)
            end
        end
        if not pos2
        or (move_init
        and not self._movement_data.goal) then
            return true
        end
        if timer <= 0
        or self:pos_in_box({x = goal.x, y = pos.y + 0.1, z = goal.z})
        or vec_dist(pos, goal) < 1 then
            self:halt()
            return true
        end
        self:move(pos2, method or "creatura:obstacle_avoidance", speed_factor or 1, anim or "walk")
        move_init = true
    end
    self:set_action(func)
end

function animalia.action_swim(self, pos, timeout, method, speed_factor, anim)
    local timer = timeout or 4
    local function func(self)
        timer = timer - self.dtime
        if timer <= 0
        or self:pos_in_box(pos) then
            self:halt()
            self:set_gravity(0)
            return true
        end
        self:move(pos, method or "animalia:swim_obstacle_avoidance", speed_factor or 0.5, anim)
        self:set_gravity(0)
    end
    self:set_action(func)
end

function animalia.action_horse_spin(self, speed, anim)
    local tyaw = random(math.pi * 2)
    local function func(self)
        self:set_gravity(-9.8)
        self:halt()
        self:animate(anim or "stand")
        self:turn_to(tyaw, speed)
        if abs(tyaw - self.object:get_yaw()) < 0.1 then
            return true
        end
    end
    self:set_action(func)
end

---------------
-- Behaviors --
---------------

------------------------
-- Register Utilities --
------------------------

-- Wander

creatura.register_utility("animalia:wander", function(self, group)
    local idle_time = 3
    local move_probability = 5
    local far_from_group = false
    local group_tick = 1
    local function func(self)
        local pos = self.object:get_pos()
        if not self:get_action() then
            local goal
            local move = random(move_probability) < 2
            if self.lasso_pos
            and vec_dist(pos, self.lasso_pos) > 10 then
                goal = self.lasso_pos
            end
            if not goal
            and move then
                goal = self:get_wander_pos(1, 2)
            end
            if group
            and goal
            and group_tick > 3 then
                local range = self.tracking_range * 0.5
                local group_positions = animalia.get_group_positions(self.name, pos, range + 1)
                if #group_positions > 2 then
                    local center = animalia.get_average_pos(group_positions)
                    if center
                    and vec_dist(pos, center) > range * 0.33
                    or vec_dist(goal, center) > range * 0.33 then
                        goal = center
                        far_from_group = true
                    else
                        far_from_group = false
                    end
                end
                group_tick = 0
            end
            if (move
            and goal)
            or far_from_group then
                creatura.action_walk(self, goal, 2, "creatura:neighbors")
            else
                creatura.action_idle(self, idle_time)
            end
            if group then
                group_tick = group_tick + 1
            end
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:skittish_wander", function(self)
    local idle_time = 3
    local move_probability = 3
    local force_move = false
    local avoid_tick = 1
    local function func(self)
        local pos = self.object:get_pos()
        if not self:get_action() then
            local goal
            local move = random(move_probability) < 2
            if avoid_tick > 3
            and move then
                local range = self.tracking_range * 0.5
                local player = creatura.get_nearby_player(self)
                if player then
                    local target_alive, line_of_sight, player_pos = self:get_target(player)
                    if target_alive
                    and line_of_sight
                    and vec_dist(pos, player_pos) < 8 then
                        force_move = true
                        local dir = vec_dir(player_pos, pos)
                        goal = self:get_wander_pos(2, 3, dir)
                    end
                end
                avoid_tick = 0
            end
            if self.lasso_pos
            and vec_dist(pos, self.lasso_pos) > 10 then
                goal = self.lasso_pos
            end
            if not goal
            and move then
                goal = self:get_wander_pos(4, 4)
            end
            if move
            and goal then
                creatura.action_walk(self, goal, 3, "creatura:neighbors", 0.35)
            else
                creatura.action_idle(self, idle_time)
            end
            avoid_tick = avoid_tick + 1
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:skittish_boid_wander", function(self)
    local idle_time = 3
    local move_probability = 3
    local group_tick = 0
    local force_move = false
    local function func(self)
        local pos = self.object:get_pos()
        local goal
        if self:timer(3) then
            local range = self.tracking_range * 0.5
            local group_positions = animalia.get_group_positions(self.name, pos, range + 1)
            if #group_positions > 2 then
                local center = animalia.get_average_pos(group_positions)
                if center
                and vec_dist(pos, center) > range then
                    goal = center
                    force_move = true
                else
                    force_move = false
                end
            else
                force_move = false
            end
            group_tick = 2
            local player = creatura.get_nearby_player(self)
            if player then
                local target_alive, line_of_sight, player_pos = self:get_target(player)
                if target_alive
                and line_of_sight
                and vec_dist(pos, player_pos) < 8 then
                    force_move = true
                    local dir = vec_dir(player_pos, pos)
                    goal = self:get_wander_pos(2, 3, dir)
                end
            end
        end
        if not self:get_action() then
            local move = random(move_probability) < 2
            if self.lasso_pos
            and vec_dist(pos, self.lasso_pos) > 10 then
                goal = self.lasso_pos
            end
            if not goal
            and move then
                goal = self:get_wander_pos(4, 4)
            end
            if move
            and goal then
                animalia.action_boid_walk(self, goal, 6, "creatura:neighbors", 0.35)
            else
                creatura.action_idle(self, idle_time)
            end
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:boid_wander", function(self, group)
    local idle_time = 3
    local move_probability = 5
    local group_tick = 1
    local function func(self)
        local pos = self.object:get_pos()
        if not self:get_action() then
            local goal
            local move = random(move_probability) < 2
            if self.lasso_pos
            and vec_dist(pos, self.lasso_pos) > 10 then
                goal = self.lasso_pos
            end
            if not goal
            and move then
                goal = self:get_wander_pos(1, 2)
            end
            if group
            and goal
            and group_tick > 3 then
                local range = self.tracking_range * 0.5
                local group_positions = animalia.get_group_positions(self.name, pos, range + 1)
                if #group_positions > 2 then
                    local center = animalia.get_average_pos(group_positions)
                    if center
                    and vec_dist(pos, center) > range * 0.33
                    or vec_dist(goal, center) > range * 0.33 then
                        goal = center
                        far_from_group = true
                    else
                        far_from_group = false
                    end
                end
                group_tick = 0
            end
            if (move
            or far_from_group)
            and goal then
                animalia.action_boid_walk(self, goal, 6, "creatura:neighbors", 0.35)
            else
                creatura.action_idle(self, idle_time)
            end
            group_tick = group_tick + 1
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:wander_water_surface", function(self)
    local idle_time = 3
    local move_probability = 3
    local function func(self)
        if not self.in_liquid then return true end
        local pos = self.object:get_pos()
        local random_goal = get_wander_pos_3d(self, 2)
        if not self:get_action() then
            if self.lasso_pos
            and vec_dist(pos, self.lasso_pos) > 10 then
                random_goal = self.lasso_pos
            end
            if random(move_probability) < 2
            and random_goal then
                animalia.action_swim(self, random_goal)
            else
                creatura.action_idle(self, idle_time, "float")
            end
        end
        self:set_gravity(0)
    end
    self:set_utility(func)
end)

-- "Eat" nodes

creatura.register_utility("animalia:eat_from_turf", function(self)
    local action_init = false
    local function func(self)
        local pos = self.object:get_pos()
        local look_dir = yaw2dir(self.object:get_yaw())
        local under = vec_add(pos, vec_multi(look_dir, self.width))
        under.y = pos.y - 0.5
        if not action_init then
            for i, node in ipairs(self.consumable_nodes) do
                if node.name == minetest.get_node(under).name then
                    minetest.set_node(under, {name = node.replacement})
                    local def = minetest.registered_nodes[node.name]
                    local texture = def.tiles[1]
                    texture = texture .. "^[resize:8x8"
                    minetest.add_particlespawner({
                        amount = 6,
                        time = 0.1,
                        minpos = vector.new(
                            pos.x - 0.5,
                            pos.y + 0.1,
                            pos.z - 0.5
                        ),
                        maxpos = vector.new(
                            pos.x + 0.5,
                            pos.y + 0.1,
                            pos.z + 0.5
                        ),
                        minvel = {x=-1, y=1, z=-1},
                        maxvel = {x=1, y=2, z=1},
                        minacc = {x=0, y=-5, z=0},
                        maxacc = {x=0, y=-9, z=0},
                        minexptime = 1,
                        maxexptime = 1,
                        minsize = 1,
                        maxsize = 2,
                        collisiondetection = true,
                        vertical = false,
                        texture = texture,
                    })
                    self.gotten = false
                    self:memorize("gotten", self.gotten)
                    if not self:get_action() then
                        creatura.action_idle(self, 1, "eat")
                        action_init = true
                    end
                    break
                elseif i == #self.consumable_nodes then
                    return true
                end
            end
        elseif not self:get_action() then
            return true
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:eat_bug_nodes", function(self)
    local timer = 0.2
    local pos = self.object:get_pos()
    local food = minetest.find_nodes_in_area(vec_sub(pos, 1.5), vec_add(pos, 1.5), self.follow)
    local function func(self)
        pos = self.object:get_pos()
        if food[1] then
            local dist = vector.distance(pos, food[1])
            local dir = vec_dir(pos, food[1])
			local frame = floor(dist * 10)
            self:turn_to(dir2yaw(dir))
			if frame < 15
			and frame > 1 then
                animalia.move_head(self, dir2yaw(dir), dir.y)
                creatura.action_idle(self, 0.1, "tongue_" .. frame)
                timer = timer - self.dtime
            elseif not self:get_action() then
                local pos2 = vec_add(food[1], vec_multi(vec_normal(vec_dir(food[1], pos)), 0.25))
                creatura.action_walk(self, pos2)
            end
        else
            return true
        end
        if timer <= 0
        and food[1] then
            minetest.remove_node(food[1])
            return true
        end
    end
    self:set_utility(func)
end)

-- Escape Water

creatura.register_utility("animalia:swim_to_land", function(self)
    local init = false
    local tpos = nil
    local function func(self)
        if not init then
			for i = 1, 359, 15 do
				local yaw = rad(i)
				local dir = yaw2dir(yaw)
				tpos = animalia.find_collision(self, dir)
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
            local pos = self.object:get_pos()
            local yaw = self.object:get_yaw()
            local tyaw = minetest.dir_to_yaw(vec_dir(pos, tpos))
            if abs(tyaw - yaw) > 0.1 then
                self:turn_to(tyaw, 12)
            end
            self:set_gravity(-9.8)
            self:set_forward_velocity(self.speed * 0.66)
            self:animate("walk")
            if vector.distance(pos, tpos) < 1
            or (not self.in_liquid
            and self.touching_ground) then
                return true
            end
        else
            self.liquid_recovery_cooldown = 5
            return true
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:flop", function(self)
    local function func(self)
        if self.in_liquid then
            return true
        end
        if not self:get_action() then
            creatura.action_idle(self, 0.1, "flop")
        end
        self:set_vertical_velocity(0)
        self:set_gravity(-9.8)
    end
    self:set_utility(func)
end)

-- Player Interaction

creatura.register_utility("animalia:flee_from_player", function(self, player, range)
    range = range or self.tracking_range
    local function func(self)
        local target_alive, line_of_sight, tpos = self:get_target(player)
        if not target_alive then return true end
        local pos = self.object:get_pos()
        local dir = vec_dir(pos, tpos)
        local escape_pos = vec_add(pos, vec_multi(vec_add(dir, {x = random(-10, 10) * 0.1, y = 0, z = random(-10, 10) * 0.1}), -3))
        if not self:get_action() then
            escape_pos = get_ground_level(escape_pos, 1)
            if self.lasso_pos
            and vec_dist(pos, self.lasso_pos) > 10 then
                escape_pos = self.lasso_pos
            end
            creatura.action_walk(self, escape_pos, 2, "creatura:obstacle_avoidance", 1, "run")
        end
        if vec_dist(pos, tpos) > range then
            return true
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:boid_flee_from_player", function(self, player, group)
    local mobs_in_group = animalia.get_group(self)
    if group then
        if #mobs_in_group > 0 then
            for i = 1, #mobs_in_group do
                local mob = mobs_in_group[i]
                mob:get_luaentity():initiate_utility("animalia:boid_flee_from_player", mob:get_luaentity(), player)
                mob:get_luaentity():set_utility_score(1)
            end
        end
    end
    local function func(self)
        local target_alive, line_of_sight, tpos = self:get_target(player)
        if not target_alive then return true end
        local pos = self.object:get_pos()
        local dir = vec_dir(pos, tpos)
        local escape_pos = vec_add(pos, vec_multi(vec_add(dir, {x = random(-10, 10) * 0.1, y = 0, z = random(-10, 10) * 0.1}), -3))
        if not self:get_action() then
            escape_pos = get_ground_level(escape_pos, 1)
            if self.lasso_pos
            and vec_dist(pos, self.lasso_pos) > 10 then
                escape_pos = self.lasso_pos
            end
            if escape_pos then
                animalia.action_boid_walk(self, escape_pos, 6, "creatura:obstacle_avoidance", 1, "run")
            end
        end
        if vec_dist(pos, tpos) > self.tracking_range + (#mobs_in_group or 0) then
            return true
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:flee_to_water", function(self)
    local function func(self)
        local pos = self.object:get_pos()
        local water = minetest.find_nodes_in_area_under_air(vec_sub(pos, 3), vec_add(pos, 3), {"default:water_source"})
        if water[1]
        and vec_dist(pos, water[1]) < 0.5 then
            return true
        end
        if water[1]
        and not self:get_action() then
            creatura.action_walk(self, water[1])
        else
            return true
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:follow_player", function(self, player, force)
    local function func(self)
        local player_alive, line_of_sight, tpos = self:get_target(player)
        -- Return if player is dead, not holding food, or behavior isn't forced
        if not player_alive
        or (not self:follow_wielded_item(player)
        and not force) then
            return true
        end
        local pos = self.object:get_pos()
        local dist = vec_dist(pos, tpos)
        if dist > self.tracking_range then
            return true
        end
        if not self:get_action() then
            if dist > self:get_hitbox(self)[4] + 1.5 then
                creatura.action_walk(self, tpos, 6, "creatura:pathfind")
            else
                creatura.action_idle(self, 0.1, "stand")
            end
        end
        self.head_tracking = player
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:sporadic_flee", function(self)
    local timer = 18
    self:clear_action()
    if group then
        local mobs_in_group = animalia.get_group(self)
        if #mobs_in_group > 0 then
            for i = 1, #mobs_in_group do
                local mob = mobs_in_group[i]
                animalia.bh_flee(mob:get_luaentity())
            end
        end
    end
    local function func(self)
        local pos = self.object:get_pos()
        local random_goal = {
            x = pos.x + random(-4, 4),
            y = pos.y,
            z = pos.z + random(-4, 4)
        }
        if not self:get_action() then
            random_goal = get_ground_level(random_goal, 1)
            local node = minetest.get_node(random_goal)
            if minetest.registered_nodes[node.name].drawtype == "liquid"
            or minetest.registered_nodes[node.name].walkable then
                return
            end
            if self.lasso_pos
            and vec_dist(pos, self.lasso_pos) > 10 then
                random_goal = self.lasso_pos
            end
            self._movement_data.speed = self.speed * 1.5
            creatura.action_walk(self, random_goal, 4, "creatura:obstacle_avoidance", 1.5)
        end
        timer = timer - self.dtime
        if timer <= 0 then
            return true
        end
    end
    self:set_utility(func)
end)

-- Mob Interaction

creatura.register_utility("animalia:mammal_breed", function(self)
    local mate = animalia.get_nearby_mate(self, self.name)
    if not mate then self.breeding = false return end
    local breeding_time = 0
    local function func(self)
        if not creatura.is_alive(mate) then
            return true
        end
        local pos = self:get_center_pos()
        local tpos = mate:get_pos()
        local dist = vec_dist(pos, tpos) - abs(self:get_hitbox(self)[4])
        if dist < 1.75 then
            breeding_time = breeding_time + self.dtime
        end
        if breeding_time >= 2 then
            if self.gender == "female" then
                for i = 1, self.birth_count or 1 do
                    local object = minetest.add_entity(pos, self.name)
                    local ent = object:get_luaentity()
                    ent.growth_scale = 0.7
                    animalia.initialize_api(ent)
                    animalia.protect_from_despawn(ent)
                end
            end
            self.breeding = false
            self.breeding_cooldown = 300
            self:memorize("breeding", self.breeding)
            self:memorize("breeding_time", self.breeding_time)
            self:memorize("breeding_cooldown", self.breeding_cooldown)
            local minp = vector.subtract(pos, 1)
            local maxp = vec_add(pos, 1)
            animalia.particle_spawner(pos, "heart.png", "float", minp, maxp)
            return true
        end
        if not self:get_action() then
            creatura.action_walk(self, tpos)
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:horse_breed", function(self)
    local mate = animalia.get_nearby_mate(self, self.name)
    if not mate then self.breeding = false return end
    local breeding_time = 0
    local function func(self)
        if not creatura.is_alive(mate) then
            return true
        end
        local pos = self:get_center_pos()
        local tpos = mate:get_pos()
        local dist = vec_dist(pos, tpos) - abs(self:get_hitbox(self)[4])
        if dist < 1.75 then
            breeding_time = breeding_time + self.dtime
        end
        if breeding_time >= 2 then
            if self.gender == "female" then
                local object = minetest.add_entity(pos, self.name)
                object:get_luaentity().growth_scale = 0.7
                local ent = object:get_luaentity()
                local tex_no = self.texture_no
                if random(2) < 2 then
                    tex_no = mate:get_luaentity().texture_no
                end
                ent:memorize("texture_no", tex_no)
                ent:memorize("speed", random(mate:get_luaentity().speed, self.speed))
                ent:memorize("jump_power", random(mate:get_luaentity().jump_power, self.jump_power))
                ent:memorize("max_hp", random(mate:get_luaentity().max_hp, self.max_hp))
                ent.speed = ent:recall("speed")
                ent.jump_power = ent:recall("jump_power")
                ent.max_hp = ent:recall("max_hp")
                animalia.initialize_api(ent)
                animalia.protect_from_despawn(ent)
            end
            self.breeding = false
            self.breeding_cooldown = 300
            self:memorize("breeding", self.breeding)
            self:memorize("breeding_time", self.breeding_time)
            self:memorize("breeding_cooldown", self.breeding_cooldown)
            local minp = vector.subtract(pos, 1)
            local maxp = vec_add(pos, 1)
            animalia.particle_spawner(pos, "heart.png", "float", minp, maxp)
            return true
        end
        if not self:get_action() then
            creatura.action_walk(self, tpos)
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:bird_breed", function(self)
    local mate = animalia.get_nearby_mate(self, self.name)
    if not mate then self.breeding = false return end
    local breeding_time = 0
    local function func(self)
        if not creatura.is_alive(mate) then
            return true
        end
        local pos = self:get_center_pos()
        local tpos = mate:get_pos()
        local dist = vec_dist(pos, tpos) - abs(self:get_hitbox(self)[4])
        if dist < 1.75 then
            breeding_time = breeding_time + self.dtime
        end
        if breeding_time >= 2 then
            if self.gender == "female" then
                minetest.add_particlespawner({
					amount = 6,
					time = 0.25,
					minpos = {x = pos.x - 7/16, y = pos.y - 5/16, z = pos.z - 7/16},
					maxpos = {x = pos.x + 7/16, y = pos.y - 5/16, z = pos.z + 7/16},
					minvel = vector.new(-1, 2, -1),
					maxvel = vector.new(1, 5, 1),
					minacc = vector.new(0, -9.81, 0),
					maxacc = vector.new(0, -9.81, 0),
					collisiondetection = true,
					texture = "animalia_egg_fragment.png",
				})
                for i = 1, self.birth_count or 1 do
                    local object = minetest.add_entity(pos, self.name)
                    local ent = object:get_luaentity()
                    ent.growth_scale = 0.7
                    animalia.initialize_api(ent)
                    animalia.protect_from_despawn(ent)
                end
            end
            self.breeding = false
            self.breeding_cooldown = 300
            self:memorize("breeding", self.breeding)
            self:memorize("breeding_time", self.breeding_time)
            self:memorize("breeding_cooldown", self.breeding_cooldown)
            local minp = vector.subtract(pos, 1)
            local maxp = vec_add(pos, 1)
            animalia.particle_spawner(pos, "heart.png", "float", minp, maxp)
            return true
        end
        if not self:get_action() then
            creatura.action_walk(self, tpos)
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:attack", function(self, target, group)
    local punch_init = false
    if group then
        local allies = creatura.get_nearby_entities(self, self.name)
        if #allies > 0 then
            for i = 1, #allies do
                allies[i]:get_luaentity():initiate_utility("animalia:attack", allies[i]:get_luaentity(), target)
                allies[i]:get_luaentity():set_utility_score(1)
            end
        end
    end
    local function func(self)
        local target_alive, line_of_sight, tpos = self:get_target(target)
        if not target_alive then
            return true
        end
        local pos = self.object:get_pos()
        local dist = vec_dist(pos, tpos)
        if not self:get_action() then
            if punch_init then return true end
            --if dist > self:get_hitbox(self)[4] then
                creatura.action_walk(self, tpos, 6, "creatura:theta_pathfind", 1)
            --end
        end
        if dist <= self:get_hitbox(self)[4] + 1
        and not punch_init then
            animalia.action_punch(self, target)
            punch_init = true
        end
    end
    self:set_utility(func)
end)

-- Flight

creatura.register_utility("animalia:aerial_flock", function(self, scale)
    local range = ceil(8 * scale)
    local function func(self)
        if self:timer(2)
        and self.stamina <= 0 then
            local boids = get_boid_members(self.object:get_pos(), 6, self.name, self.texture_no)
            if #boids > 1 then
                for i = 1, #boids do
                    local boid = boids[i]
                    local ent = boid:get_luaentity()
                    ent.stamina = ent:memorize("stamina", 0)
                    ent.is_landed = ent:memorize("is_landed", true)
                end
            end
        end
        local dist2floor = creatura.sensor_floor(self, 2, true)
        local dist2ceil = creatura.sensor_ceil(self, 2, true)
        if self.in_liquid then
            dist2floor = 0
            dist2ceil = 2
        end
        if dist2floor < 2
        and dist2ceil < 2 then
            self.is_landed = true
            return true
        end
        if not self:get_action()
        or (dist2floor < 2
        or dist2ceil < 2) then
            local pos = self.object:get_pos()
            local pos2 = self:get_wander_pos_3d(1, range)
            if dist2ceil < 2 then
                pos2.y = pos.y - 1
            end
            if dist2floor < 2 then
                pos2.y = pos.y + 1
            end
            if self.in_liquid then
                pos2.y = pos.y + 2
            end
            animalia.action_boid_move(self, pos2, 2)
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:aerial_swarm", function(self, scale)
    local function func(self)
        if self:timer(2)
        and self.stamina <= 0 then
            local boids = creatura.get_boid_members(self.object:get_pos(), 6, self.name)
            if #boids > 1 then
                for i = 1, #boids do
                    local boid = boids[i]
                    local ent = boid:get_luaentity()
                    ent.stamina = ent:memorize("stamina", 0)
                    ent.is_landed = ent:memorize("is_landed", true)
                end
            end
        end
        local dist2floor = creatura.sensor_floor(self, 2, true)
        local dist2ceil = creatura.sensor_ceil(self, 2, true)
        if self.in_liquid then
            dist2floor = 0
            dist2ceil = 2
        end
        if not self:get_action()
        or (dist2floor < 2
        or dist2ceil < 2) then
            local pos = self.object:get_pos()
            local pos2 = self:get_wander_pos_3d(1, 3)
            if dist2floor < 2 then
                pos2.y = pos.y + 1
            end
            if dist2ceil < 2 then
                pos2.y = pos.y - 1
            end
            animalia.action_boid_move(self, pos2, 2)
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:land", function(self, scale)
    scale = scale or 1
    local function func(self)
        if self.touching_ground then return true end
        local _, node = creatura.sensor_floor(self, 3, true)
        if node and get_node_def(node.name).drawtype == "liquid" then self.is_landed = false return true end
        if not self:get_action() then
            local pos = self.object:get_pos()
            local offset = random(2 * scale, 3 * scale)
            if random(2) < 2 then
                offset = offset * -1
            end
            local pos2 = {
                x = pos.x + offset,
                y = pos.y,
                z = pos.z + offset
            }
            pos2.y = pos2.y - (3 * scale)
            self:animate("fly")
            animalia.action_boid_move(self, pos2, 2, "animalia:fly_path", 1)
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:return_to_nest", function(self)
    local function func(self)
        if not self.home_position then return true end
        local pos = self.object:get_pos()
        local pos2 = self.home_position
        local dist = vec_dist(pos, {x = pos2.x, y = pos.y, z = pos2.z})
        if dist < 4
        and abs(pos.y - pos2.y) < 2 then
            if self.touching_ground then
                creatura.action_idle(self, 1)
            end
        end
        if not self:get_action() then
            creatura.action_walk(self, pos2, 6, "animalia:fly_path", 1)
        end
    end
    self:set_utility(func)
end)

-- Swimming

creatura.register_utility("animalia:schooling", function(self)
    local pos = self.object:get_pos()
    local water = minetest.find_nodes_in_area(vector.subtract(pos, 5), vector.add(pos, 5), {"group:water"})
    local function func(self)
        if not self:get_action() then
            if #water < 1 then return true end
            local iter = random(#water)
            local pos2 = water[iter]
            table.remove(water, iter)
            animalia.action_boid_move(self, pos2, 2, "animalia:swim_obstacle_avoidance")
        end
    end
    self:set_utility(func)
end)

-- Resist Fall

creatura.register_utility("animalia:resist_fall", function(self)
    local function func(self)
        if not self:get_action() then
            animalia.action_fall(self)
        end
        if self.touching_ground
        or self.in_liquid then
            creatura.action_idle(self, "stand")
            self:set_gravity(-9.8)
            return true
        end
    end
    self:set_utility(func)
end)

-- Die

creatura.register_utility("animalia:die", function(self)
	local timer = 1.5
	local init = false
	local function func(self)
		if not init then
            self:play_sound("death")
			creatura.action_fallover(self)
			init = true
		end
		timer = timer - self.dtime
		if timer <= 0 then
            local pos = self.object:get_pos()
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
            creatura.drop_items(self)
            self.object:remove()
        end
	end
    self:set_utility(func)
end)

-- Cat Exclusive Behaviors

creatura.register_utility("animalia:find_and_break_glass_vessels", function(self)
    local timer = 12
    local pos = self.object:get_pos()
    local pos2 = nil
    local nodes = minetest.find_nodes_in_area(
        vector.subtract(pos, 8),
        vec_add(pos, 8),
        {"vessels:glass_bottle", "vessels:drinking_glass"}
    )
    if #nodes > 0 then
        pos2 = nodes[1]
    end
    local func = function(self)
        if not pos2 then
            return
        end
        pos = self.object:get_pos()
        if not self:get_action() then
            creatura.action_walk(self, pos2, 6, "pathfind")
        end
        if vector.distance(pos, pos2) <= 0.5 then
            creatura.action_idle(self, 0.7, "smack")
            minetest.remove_node(pos2)
            minetest.add_item(pos2, "vessels:glass_fragments")
            if minetest.get_node(pos2).name == "air" then
                return true
            end
        end
        timer = timer - self.dtime
        if timer < 0 then return true end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:walk_ahead_of_player", function(self, player)
    if not player then return end
    local timer = 8
    local func = function(self)
		if not creatura.is_alive(player) then
            return true
		end
        local pos = self.object:get_pos()
        local tpos = player:get_pos()
        local dir = player:get_look_dir()
        tpos.x = tpos.x + dir.x
        tpos.z = tpos.z + dir.z
        self.status = self:memorize("status", "following")
        local dist = vec_dist(pos, tpos)
        if dist > self.view_range then
            self.status = self:memorize("status", "")
            return true
        end
        if not self:get_action() then
            if vec_dist(pos, tpos) > self.width + 0.5 then
                creatura.action_walk(self, tpos, 6, "pathfind", 0.75)
            else
                creatura.action_idle(self, 0.1, "stand")
            end
        end
        timer = timer - self.dtime
        if timer < 0 then self.status = self:memorize("status", "") return true end
    end
    self:set_utility(func)
end)

-- Bat Exclusive Behaviors

creatura.register_utility("animalia:return_to_home", function(self)
    local init = false
    local tpos = nil
    local function func(self)
        if not self.home_position then return true end
        local pos = self.object:get_pos()
        local pos2 = self.home_position
        local dist = vec_dist(pos, pos2)
        if dist < 2 then
            if is_solid[minetest.get_node(vec_raise(pos, 1)).name] then
                creatura.action_idle(self, 1, "latch")
                self:set_gravity(9.8)
                self.object:set_velocity({x = 0, y = 0, z = 0})
            end
        end
        if not self:get_action() then
            creatura.action_walk(self, vec_raise(pos2, -1), 6, "animalia:fly_path", 1)
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:find_home", function(self)
    local init = false
    local tpos = nil
    local pos = self.object:get_pos()
    local range = self.tracking_range
    local ceiling = get_ceiling_positions(pos, range / 2)
    local iter = 1
    local function func(self)
        if not ceiling[1] then
            return true
        else
            iter = random(#ceiling)
        end
        pos = self.object:get_pos()
        if not self:get_action() then
            local pos2 = get_wander_pos_3d(self, range)
            local dist2floor = creatura.sensor_floor(self, 5, true)
            local dist2ceil = creatura.sensor_ceil(self, 5, true)
            if dist2floor < 4 then
                pos2.y = pos.y + 2
            elseif dist2ceil < 4 then
                pos2.y = pos.y - 1
            end
            animalia.action_boid_move(self, pos2, 2)
        end
        if ceiling[iter] then
            local pos2 = {
                x = ceiling[iter].x,
                y = ceiling[iter].y - 1,
                z = ceiling[iter].z
            }
            local line_of_sight = fast_ray_sight(pos, pos2)
            if line_of_sight then
                self.home_position = self:memorize("home_position", ceiling[iter])
                return true
            end
        end
        if self:timer(1) then
            iter = iter + 1
            if iter > #ceiling then
                return true
            end
        end
    end
    self:set_utility(func)
end)

-- Horse Exclusive Behaviors

creatura.register_utility("animalia:horse_breaking", function(self)
    local timer = 18
    self:clear_action()
    local function func(self)
        if not self:get_action() then
            animalia.action_horse_spin(self, random(4, 6), "stand")
        end
        timer = timer - self.dtime
        if timer <= 0 then
            return true
        end
    end
    self:set_utility(func)
end)

-- Tamed Animal Orders

creatura.register_utility("animalia:sit", function(self)
    local function func(self)
        if self.order ~= "sit" then
            return true
        end
        if not self:get_action() then
            creatura.action_idle(self, 0.1, "sit")
        end
    end
    self:set_utility(func)
end)

creatura.register_utility("animalia:mount", function(self, player)
    local function func(self)
        if not creatura.is_alive(player) then
            return true
        end
        local anim = "stand"
        local control = player:get_player_control()
        local speed_factor = 0
        local vel = self.object:get_velocity()
        if control.up then
            speed_factor = 1
            if control.aux1 then
                speed_factor = 1.5
            end
        end
        if control.jump
        and self.touching_ground then
            self.object:add_velocity({
                x = 0,
                y = self.jump_power + (abs(self._movement_data.gravity) * 0.33),
                z = 0
            })
        elseif not self.touching_ground then
            speed_factor = speed_factor * 0.5
        end
        local total_speed = vector.length(vel)
        if total_speed > 0.2 then
            anim = "walk"
            if control.aux1 then
                anim = "run"
            end
            if not self.touching_ground
            and not self.in_liquid
            and vel.y > 0 then
                anim = "rear_constant"
            end
        end
        self:turn_to(player:get_look_horizontal())
        self:set_forward_velocity(self.speed * speed_factor)
        self:animate(anim)
        if control.sneak
        or not self.rider then
            animalia.mount(self, player)
            return true
        end
    end
    self:set_utility(func)
end)