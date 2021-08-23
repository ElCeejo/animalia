-------------
---- API ----
-------------
-- Ver 0.2 --

local hitbox = mob_core.get_hitbox

local find_string = mob_core.find_val

local creative = minetest.settings:get_bool("creative_mode")

----------
-- Math --
----------

local random = math.random
local min = math.min
local pi = math.pi
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local function diff(a, b) -- Get difference between 2 angles
    return math.atan2(math.sin(b - a), math.cos(b - a))
end
local function round(x) -- Round to nearest multiple of 0.5
	return x + 0.5 - (x + 0.5) % 1
end

local function clamp(num, min, max)
	if num < min then
		num = min
	elseif num > max then
		num = max    
	end
	return num
end

local yaw2dir = minetest.yaw_to_dir
local dir2yaw = minetest.dir_to_yaw

local vec_dist = vector.distance
local vec_dir = vector.direction

local function dist_2d(pos1, pos2)
    local a = vector.new(pos1.x, 0, pos1.z)
    local b = vector.new(pos2.x, 0, pos2.z)
    return vec_dist(a, b)
end

local function get_average_pos(vectors)
    local sum = {x = 0, y = 0, z = 0}
    for _, vec in pairs(vectors) do sum = vector.add(sum, vec) end
    local avg = vector.divide(sum, #vectors)
    avg.x = math.floor(avg.x) + 0.5
    avg.y = math.floor(avg.y) + 0.5
    avg.z = math.floor(avg.z) + 0.5
    return avg
end

local function pos_to_neighbor(self, pos2)
    local pos = self.object:get_pos()
    local dir = vector.direction(pos, pos2)
    local neighbor = self._neighbors[mobkit.dir2neighbor(dir)]
    local vec = {
        x = neighbor.x,
        y = 0,
        z = neighbor.z
    }
    return vector.add(pos, vec)
end

local function get_random_offset(pos, range)
    if not pos then return nil end
    range = (range * 0.5) or 3
    local pos_x = pos.x + random(-range, range)
    local pos_z = pos.z + random(-range, range)
    local node = nil
    for i = -1, 1 do
        i_pos = vector.new(pos_x, pos.y + i, pos_z)
        if minetest.registered_nodes[minetest.get_node(vector.new(i_pos.x, i_pos.y - 1, i_pos.z)).name].walkable then
            node = i_pos
            break
        end
    end
    if not node then return nil end
    return node
end

local is_movable = mob_core.is_moveable

local function walkable(pos)
    return minetest.registered_nodes[minetest.get_node(pos).name].walkable
end

-------------------
-- API Functions --
-------------------

function animalia.is_prey(name1, name2)
	if name1 == name2 then return 0 end
	local def1 = minetest.registered_entities[name1]
	local def2 = minetest.registered_entities[name2]
	if find_string(paleotest.mobkit_mobs, name2)
	and def1.follow
	and def2.drops then
		for _, drop in ipairs(def2.drops) do
			if drop.name
			and find_string(def1.follow, drop.name)
			and def1.prey_params["height"] >= get_height(name2)
			and def1.prey_params["health"] >= def2.max_hp then
				-- Mob is prey
				return 2
			end
		end
		-- Mob can be attacked
		return 1
	end
	-- Not a mobkit mob
	return 0
end

function animalia.particle_spawner(pos, texture, type, min_pos, max_pos)
    type = type or "float"
    min_pos = min_pos or {
        x = pos.x - 2,
        y = pos.y - 2,
        z = pos.z - 2,
    }
    max_pos = max_pos or {
        x = pos.x + 2,
        y = pos.y + 2,
        z = pos.z + 2,
    }
	if type == "float" then
		minetest.add_particlespawner({
			amount = 16,
			time = 0.25,
			minpos = min_pos,
			maxpos = max_pos,
			minvel = {x = 0, y = 0.2, z = 0},
			maxvel = {x = 0, y = 0.25, z = 0},
			minexptime = 0.75,
			maxexptime = 1,
			minsize = 4,
			maxsize = 4,
			texture = texture,
			glow = 1,
		})
	elseif type == "splash" then
		minetest.add_particlespawner({
			amount = 6,
			time = 0.25,
			minpos = {x = pos.x - 7/16, y = pos.y + 0.6, z = pos.z - 7/16},
			maxpos = {x = pos.x + 7/16, y = pos.y + 0.6, z = pos.z + 7/16},
			minvel = vector.new(-1, 2, -1),
			maxvel = vector.new(1, 5, 1),
			minacc = vector.new(0, -9.81, 0),
			maxacc = vector.new(0, -9.81, 0),
			minsize = 2,
			maxsize = 4,
			collisiondetection = true,
			texture = texture,
		})
	end
end

function animalia.can_reach(self, pos2)
    if pos2 then
        local pos = mobkit.get_stand_pos(self)
        local box = hitbox(self)
        local path_data = mob_core.find_path(pos, pos2, box[4] - 0.1, self.height, 100)
        if path_data and #path_data > 2 then
            return true, path_data
        end
    end
    return false
end

function animalia.find_collision(self, dir)
    local pos = mobkit.get_stand_pos(self)
    local pos2 = vector.add(pos, vector.multiply(dir, 16))
    local ray = minetest.raycast(pos, pos2, false, false)
    for pointed_thing in ray do
        if pointed_thing.type == "node" then
            return pointed_thing.under
        end
    end
    return nil
end

function animalia.get_nearby_mate(self, name)
	for _, obj in ipairs(self.nearby_objects) do
        if mobkit.is_alive(obj)
        and not obj:is_player()
        and obj:get_luaentity().name == name
        and obj:get_luaentity().gender ~= self.gender
        and obj:get_luaentity().breeding then
            return obj
        end
	end
end

function animalia.feed_tame(self, clicker, feed_count, tame, breed)
	local item = clicker:get_wielded_item()
	local pos = self.object:get_pos()
	local mob_name = mob_core.get_name_proper(self.name)
	if mob_core.follow_holding(self, clicker) then
		if not creative then
			item:take_item()
			clicker:set_wielded_item(item)
		end
		mobkit.heal(self, self.max_hp/feed_count)
		if self.hp >= self.max_hp then
			self.hp = self.max_hp
		end
        self.food = mobkit.remember(self, "food", self.food + 1)

        local minppos = vector.add(pos, hitbox(self)[4])
        local maxppos = vector.subtract(pos, hitbox(self)[4])
        local def = minetest.registered_items[item:get_name()]
        local texture = def.inventory_image
        if not texture or texture == "" then
            texture = def.wield_image
            if def.tiles then
                texture = def.tiles[1]
            end
        end
        texture = texture .. "^[resize:8x8" -- Crops image
        minetest.add_particlespawner({
            amount = 12*self.height,
            time = 0.1,
            minpos = minppos,
            maxpos = maxppos,
            minvel = {x=-1, y=1, z=-1},
            maxvel = {x=1, y=2, z=1},
            minacc = {x=0, y=-5, z=0},
            maxacc = {x=0, y=-9, z=0},
            minexptime = 1,
            maxexptime = 1,
            minsize = 2*self.height,
            maxsize = 3*self.height,
            collisiondetection = true,
            vertical = false,
            texture = texture,
        })
        if self.food >= feed_count then
            self.food = mobkit.remember(self, "food", 0)
            if tame
            and not self.tamed
            and self.follow[1] == item:get_name() then
                mob_core.set_owner(self, clicker:get_player_name())
                minetest.chat_send_player(clicker:get_player_name(), mob_name.." has been tamed!")
                mobkit.clear_queue_high(self)
                animalia.particle_spawner(pos, "mob_core_green_particle.png", "float", minppos, maxppos)
            end
            if breed then
                if self.child then return false end
                if self.breeding then return false end
                if self.breeding_cooldown <= 0 then
                    self.breeding = true
                    animalia.particle_spawner(pos, "heart.png", "float", minppos, maxppos)
                end
            end
        end
	end
	return false
end

local function is_within_reach(self, target)
    local dist = vec_dist(mobkit.get_stand_pos(self), mobkit.get_stand_pos(target)) - (hitbox(self)[4] + hitbox(target)[4])
    if dist <= self.reach then
        return true
    end
    return false
end

local function is_on_ground(object)
    if object then
        local pos = object:get_pos()
        local sub = 1
        if not object:is_player() then
            sub = math.abs(hitbox(object)[2]) + 1
        end
        pos.y = pos.y - sub
        if minetest.registered_nodes[minetest.get_node(pos).name].walkable then
            return true
        end
        pos.y = pos.y - 1
        if minetest.registered_nodes[minetest.get_node(pos).name].walkable then
            return true
        end
    end
    return false
end

local function get_height(name)
	local def = minetest.registered_entities[name]
	return abs(def.collisionbox[2]) + abs(def.collisionbox[5])
end

------------------
-- LQ Functions --
------------------

function animalia.lq_follow_path(self, path_data, speed_factor, anim)
    speed_factor = speed_factor or 1
    anim = anim or "walk"
    local dest = nil
    local timer = #path_data -- failsafe
    local width = hitbox(self)[4]
    local init = false
	local func = function(self)
        local pos = mobkit.get_stand_pos(self)
		local yaw = self.object:get_yaw()
        local s_fctr = speed_factor
        if path_data and #path_data > 1 then
            if #path_data >= math.ceil(width) then
                dest = path_data[1]
            else
                return true
            end
        else
            return true
        end

        if not self.isonground then
            table.remove(path_data, 1)
            timer = timer - 1
            s_fctr = 0.25
        end

        timer = timer - self.dtime
        if timer < 0 then return true end

        local y = self.object:get_velocity().y

        local tyaw = minetest.dir_to_yaw(vector.direction(pos, dest))

        mobkit.turn2yaw(self, tyaw, self.turn_rate or 4)

        if vec_dist(pos, path_data[#path_data]) < math.ceil(width) then
            if not self.isonground and not self.isinliquid and
                mob_core.fall_check(self, pos, self.max_fall or self.jump_height) then
                self.object:set_velocity({x = 0, y = y, z = 0})
            end
            return true
        end

        if vec_dist(pos, path_data[1]) < 2.5
        and diff(yaw, tyaw) < 1.5 then
            table.remove(path_data, 1)
            timer = timer - 1
        end

        if mob_core.fall_check(self, pos, self.max_fall or self.jump_height) then
			self.object:set_velocity({x = 0, y = y, z = 0})
			return true
        end

        if self.isonground or self.isinliquid then
            local forward_dir = vector.normalize(minetest.yaw_to_dir(yaw))
            forward_dir = vector.multiply(forward_dir,
                                          self.max_speed * s_fctr)
            forward_dir.y = y
            self.object:set_velocity(forward_dir)
            if not init then
                mobkit.animate(self, anim)
                init = true
            end
        end
    end
    mobkit.queue_low(self, func)
end

function animalia.lq_dumb_follow_path(self, path_data, speed_factor, anim)
    speed_factor = speed_factor or 1
    anim = anim or "walk"
    local dest = nil
    local timer = 3 -- failsafe
    local width = hitbox(self)[4]
    local stop_thresh = 1
    local init = false
	local func = function(self)     
        local pos = mobkit.get_stand_pos(self)
		local yaw = self.object:get_yaw()
        if path_data and #path_data > 1 then
            dest = path_data[1]
        else
            return true
        end

        if not self.isonground then table.remove(path_data, 1) end

        timer = timer - self.dtime
        if timer < 0 then return true end

        local y = self.object:get_velocity().y

        local tyaw = minetest.dir_to_yaw(vector.direction(pos, dest))

        if #path_data > 2
        and ((dist_2d(pos, path_data[1]) < 1
        or abs(tyaw - yaw) < 3)
        or dist_2d(pos, path_data[1]) >= dist_2d(pos, path_data[2])) then
            table.remove(path_data, 1)
        end

        if abs(yaw - tyaw) > 0.5 then
            mobkit.turn2yaw(self, tyaw, 8)
        end

        if dist_2d(pos, path_data[#path_data]) < 0.6 then
            if not self.isonground and not self.isinliquid and
                mob_core.fall_check(self, pos, self.max_fall or self.jump_height) then
                self.object:set_velocity({x = 0, y = y, z = 0})
            end
            mobkit.animate(self, "stand")
            return true
        end

        if dist_2d(pos, path_data[#path_data]) < 0.6 then
            mobkit.animate(self, "stand")
            return true
        end

        if mob_core.fall_check(self, pos, self.max_fall or self.jump_height) then
			self.object:set_velocity({x = 0, y = y, z = 0})
			return true
        end

        if self.isonground or self.isinliquid then
            local forward_dir = vector.normalize(minetest.yaw_to_dir(yaw))
            forward_dir = vector.multiply(forward_dir,
                                          self.max_speed * speed_factor)
            forward_dir.y = y
            self.object:set_velocity(forward_dir)
            if not init then
                mobkit.animate(self, anim)
                init = true
            end
        end
    end
    mobkit.queue_low(self, func)
end

function animalia.lq_idle(self, duration, anim)
	anim = anim or 'stand'
    local random_yaw = nil
	local init = true
	local func = function(self)
		if init then 
			mobkit.animate(self, anim) 
			init = false
		end
		duration = duration - self.dtime
        if random(6) < 2
        and not random_yaw then
            random_yaw = self.object:get_yaw() + random(-2, 2)
        elseif random_yaw
        and abs(self.object:get_yaw() - random_yaw) > 0.1 then
            mobkit.turn2yaw(self, random_yaw, 3)
            self._tyaw = random_yaw
        end
		if duration <= 0 then return true end
	end
	mobkit.queue_low(self, func)
end

---------------------------
-- Mob Control Functions --
---------------------------

function animalia.go_to_pos(self, tpos, speed_factor, anim)
    speed_factor = speed_factor or 1
    local pos = self.object:get_pos()
    local dist = vec_dist(pos, tpos)
    if dist < 5
    and minetest.line_of_sight(pos, tpos) then
        local _, pos2 = mob_core.get_next_waypoint(self, tpos)
        if pos2 then
            mob_core.lq_dumbwalk(self, pos2, speed_factor, anim)
            return
        end
    else
        local box = hitbox(self)
        local path_data = mob_core.find_path(mobkit.get_stand_pos(self), tpos, box[4] - 0.1, self.height, 100)
        if path_data then
            mob_core.lq_follow_path(self, path_data, speed_factor, anim)
            return
        end
    end
    mob_core.lq_dumbwalk(self, tpos, speed_factor, anim)
end

function animalia.go_to_pos_lite(self, tpos, speed_factor)
    speed_factor = speed_factor or 1
    if mobkit.is_queue_empty_low(self) then
        local _, pos2 = mob_core.get_next_waypoint(self, tpos)
        if pos2 then
            mob_core.lq_dumbwalk(self, pos2, speed_factor)
            return true
        else
            local box = hitbox(self)
            local path_data = mob_core.find_path(mobkit.get_stand_pos(self), tpos, box[4] - 0.1, self.height, 100)
            if path_data and #path_data > 2 then
                mob_core.lq_follow_path(self, path_data, speed_factor, anim)
                return true
            end
        end
    end
    return false
end

---------------------------------
-- Entity Definition Functions --
---------------------------------

local function sensors()
	local timer = 2
	local pulse = 1
	return function(self)
		timer = timer - self.dtime
		if timer < 0 then
			pulse = pulse + 1
			local range = self.view_range
			if pulse > 2 then 
				pulse = 1
			else
				range = self.view_range * 0.5
			end
			
			local pos = self.object:get_pos()
            self.group = {}
			self.nearby_objects = minetest.get_objects_inside_radius(pos, range)
			for i, obj in ipairs(self.nearby_objects) do
                if obj ~= self.object
                and obj:get_luaentity()
                and obj:get_luaentity().name == self.name then
                    table.insert(self.group, obj)
				elseif obj == self.object then
					table.remove(self.nearby_objects, i)
					break
				end
			end
			timer = 2
		end
	end
end

function animalia.on_activate(self, staticdata, dtime_s)
    mob_core.on_activate(self, staticdata, dtime_s)
    self.sensefunc = sensors()
    self.order = mobkit.recall(self, "order") or "wander"
    self.gotten = mobkit.recall(self, "gotten") or false
    self.attention_span = mobkit.recall(self, "attention_span") or 0
    self.breeding = mobkit.recall(self, "breeding") or false
    self.breeding_time = mobkit.recall(self, "breeding_time") or 0
    self.breeding_cooldown = mobkit.recall(self, "breeding_cooldown") or 0
    self.lasso_pos = mobkit.recall(self, "lasso_pos") or nil
    self.liquid_recovery_cooldown = 0
    self.target_blacklist = {}
    if self.lasso_pos then
        self.caught_with_lasso = true
        if minetest.get_item_group(minetest.get_node(self.lasso_pos).name, "fence") > 0 then
            local object = minetest.add_entity(self.lasso_pos, "animalia:lasso_fence_ent")
            object:get_luaentity().parent = self.object
        end
    end
    for name in pairs(minetest.registered_entities) do
		if self.targets
		and self.prey_params then
			if animalia.is_prey(self.name, name) == 2 then
				table.insert(self.targets, name)
			end
		end
	end
end

local function lasso_effect(self, pos2)
    local pos = mobkit.get_stand_pos(self)
    pos.y = pos.y + (self.height * 0.5)
    local object = minetest.add_entity(pos2, "animalia:lasso_visual")
    local ent = object:get_luaentity()
    ent.parent = self.object
    ent.anchor_pos = pos2
    return object
end

local function is_under_solid(pos)
    local pos2 = vector.new(pos.x, pos.y + 1, pos.z)
    return (walkable(pos2) or ((mobkit.get_node_height(pos2) or 0) < 1.5))
end

local function vec_center(vec)
    return {x = floor(vec.x + 0.5), y = floor(vec.y + 0.5), z = floor(vec.z + 0.5)}
end

local function do_step(self, moveresult)
    local pos = mobkit.get_stand_pos(self)
    local width = hitbox(self)[4] - 0.1
    if not self._step then
        for _, data in ipairs(moveresult.collisions) do
            if data.type == "node" then
                local step_pos = data.node_pos
                local halfway = vector.add(pos, vector.multiply(vector.direction(pos, step_pos), 0.5))
                if step_pos.y + 0.5 > pos.y
                and (walkable({x = pos.x, y = pos.y - 1, z = pos.z})
                or self.isinliquid)
                and not vector.equals(vec_center(pos), step_pos)
                and not is_under_solid(step_pos)
                and is_movable({x = halfway.x, y = step_pos.y + 1, z = halfway.z}, width, self.height) then
                    local vel_yaw = self.object:get_yaw()
                    local dir_yaw = minetest.dir_to_yaw(vector.direction(pos, data.node_pos))
                    if diff(vel_yaw, dir_yaw) < width * 2 then
                        self._step = data.node_pos
                        break
                    end
                else
                    self._step = nil
                end
            end
        end
    else
        local vel = self.object:get_velocity()
        self.object:set_velocity(vector.new(vel.x, 7, vel.z))
        if self._step.y < pos.y - 0.5 then
            self.object:set_velocity(vector.new(vel.x, 0.5, vel.z))
            self._step = nil
        end
    end
end

function animalia.on_step(self, dtime, moveresult)
    mob_core.on_step(self, dtime, moveresult)
    mob_core.vitals(self)
    if mobkit.timer(self, 1) then
        if self.breeding_cooldown > 0 then
            self.breeding_cooldown = self.breeding_cooldown - 1
        end
        mobkit.remember(self, "breeding_cooldown", self.breeding_cooldown)
    end
    if mobkit.timer(self, 4)
    and #self.target_blacklist > 0 then
        table.remove(self.target_blacklist, 1)
    end
    if self.caught_with_lasso then
        if self.lasso_player
        and mobkit.is_alive(self) then
            local player = self.lasso_player
            local pos = mobkit.get_stand_pos(self)
            pos.y = pos.y + (self.height * 0.5)
            local ppos = player:get_pos()
            ppos.y = ppos.y + 1
            if not self.lasso_visual
            or not self.lasso_visual:get_luaentity() then
                self.lasso_visual = lasso_effect(self, ppos)
            else
                self.lasso_visual:get_luaentity().anchor_pos = ppos
            end
            local dist = vector.distance(pos, ppos)
            local dist = vector.distance(pos, ppos)
            if dist_2d(pos, ppos) > 6
            or abs(ppos.y - pos.y) > 8 then
                local p_target = vector.add(pos, vector.multiply(vector.direction(pos, ppos), dist * 0.8))
                local g = -0.18
                local v = vector.new(0, 0, 0)
                v.x = (1.0 + (0.005 * dist)) * (p_target.x - pos.x) / dist
                v.y = -((1.0 + (0.03 * dist)) * ((ppos.y - 4) - pos.y) / (dist * (g * dist)))
                v.z = (1.0 + (0.005 * dist)) * (p_target.z - pos.z) / dist
                self.object:add_velocity(v)
            end
            if player:get_wielded_item():get_name() ~= "animalia:lasso"
            or vector.distance(pos, ppos) > 20 then
                self.caught_with_lasso = nil
                self.lasso_player = nil
                if self.lasso_visual then
                    self.lasso_visual:remove()
                    self.lasso_visual = nil
                end
            end
        elseif self.lasso_pos
        and mobkit.is_alive(self) then
            mobkit.remember(self, "lasso_pos", self.lasso_pos)
            local pos = mobkit.get_stand_pos(self)
            pos.y = pos.y + (self.height * 0.5)
            local ppos = self.lasso_pos
            if not self.lasso_visual
            or not self.lasso_visual:get_luaentity() then
                self.lasso_visual = lasso_effect(self, ppos)
            else
                self.lasso_visual:get_luaentity().anchor_pos = ppos
            end
            local dist = vector.distance(pos, ppos)
            if dist_2d(pos, ppos) > 6
            or abs(ppos.y - pos.y) > 8 then
                local p_target = vector.add(pos, vector.multiply(vector.direction(pos, ppos), dist * 0.8))
                local g = -0.18
                local v = vector.new(0, 0, 0)
                v.x = (1.0 + (0.005 * dist)) * (p_target.x - pos.x) / dist
                v.y = -((1.0 + (0.03 * dist)) * ((ppos.y - 4) - pos.y) / (dist * (g * dist)))
                v.z = (1.0 + (0.005 * dist)) * (p_target.z - pos.z) / dist
                self.object:add_velocity(v)
            end
            local objects = minetest.get_objects_inside_radius(ppos, 1)
            local is_lasso_attached = false
            for _, object in ipairs(objects) do
                if object
                and object:get_luaentity()
                and object:get_luaentity().name == "animalia:lasso_fence_ent" then
                    is_lasso_attached = true
                end
            end
            if not is_lasso_attached then
                
                self.caught_with_lasso = nil
                self.lasso_pos = nil
                if self.lasso_visual then
                    self.lasso_visual:remove()
                    self.lasso_visual = nil
                end
            end
        else
            if self.lasso_pos then
                local objects = minetest.get_objects_inside_radius(self.lasso_pos, 0.4)
                for _, object in ipairs(objects) do
                    if object
                    and object:get_luaentity()
                    and object:get_luaentity().name == "animalia:lasso_fence_ent" then
                        minetest.add_item(object:get_pos(), "animalia:lasso")
                        object:remove()
                    end
                end
            end
            self.caught_with_lasso = nil
            self.lasso_pos = nil
            if self.lasso_visual then
                self.lasso_visual:remove()
                self.lasso_visual = nil
            end
        end
    end
    if mobkit.is_alive(self) then
        do_step(self, moveresult)
    end
end

-------------
-- Physics --
-------------

function animalia.lightweight_physics(self)
	local vel = self.object:get_velocity()
	if self.isonground and not self.isinliquid then
		self.object:set_velocity({x= vel.x> 0.2 and vel.x*mobkit.friction or 0,
								y=vel.y,
								z=vel.z > 0.2 and vel.z*mobkit.friction or 0})
	end
	if self.springiness and self.springiness > 0 then
		local vnew = vector.new(vel)
		
		if not self.collided then
			for _,k in ipairs({'y','z','x'}) do			
				if vel[k]==0 and abs(self.lastvelocity[k])> 0.1 then 
					vnew[k]=-self.lastvelocity[k]*self.springiness 
				end
			end
		end
		if not vector.equals(vel,vnew) then
			self.collided = true
		else
			if self.collided then
				vnew = vector.new(self.lastvelocity)
			end
			self.collided = false
		end
		
		self.object:set_velocity(vnew)
	end
	local surface = nil
	local surfnodename = nil
	local spos = mobkit.get_stand_pos(self)
	spos.y = spos.y+0.01
	local snodepos = mobkit.get_node_pos(spos)
	local surfnode = mobkit.nodeatpos(spos)
	while surfnode and surfnode.drawtype == 'liquid' do
		surfnodename = surfnode.name
		surface = snodepos.y+0.5
		if surface > spos.y+self.height then break end
		snodepos.y = snodepos.y+1
		surfnode = mobkit.nodeatpos(snodepos)
	end
	self.isinliquid = surfnodename
	if surface then
		local submergence = min(surface-spos.y,self.height)/self.height
		local buoyacc = mobkit.gravity*(self.buoyancy-submergence)
		mobkit.set_acceleration(self.object,
			{x=-vel.x*self.water_drag,y=buoyacc-vel.y*abs(vel.y)*0.4,z=-vel.z*self.water_drag})
	else
		self.object:set_acceleration({x=0,y=-2.8,z=0})
	end
end

------------------
-- HQ Functions --
------------------

function animalia.hq_eat(self, prty)
    local func = function(self)
        local pos = mobkit.get_stand_pos(self)
        local under = vector.new(pos.x, pos.y - 1, pos.z)
        for _, node in ipairs(self.consumable_nodes) do
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
                mobkit.remember(self, "gotten", self.gotten)
                return true
            else
                return true
            end
        end
    end
    mobkit.queue_high(self, func, prty)
end

-- Wandering --

function animalia.hq_go_to_land(self, prty)
    local init = false
    local tpos = nil
    local func = function(self)
        if self.liquid_recovery_cooldown > 0 then
            self.liquid_recovery_cooldown = self.liquid_recovery_cooldown - 1
            return true
        end
        if not init then
			for i = 1, 359, 15 do
				local yaw = math.rad(i)
				local dir = minetest.yaw_to_dir(yaw)
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
            local pos = mobkit.get_stand_pos(self)
            local yaw = self.object:get_yaw()
            local tyaw = minetest.dir_to_yaw(vec_dir(pos, tpos))
            if abs(tyaw - yaw) > 0.1 then
                mobkit.turn2yaw(self, tyaw)
            else
                mobkit.go_forward_horizontal(self, self.max_speed * 0.66)
                mobkit.animate(self, "walk")
            end
            if dist_2d(pos, tpos) < 1
            or (not self.isinliquid
            and self.isonground) then
                return true
            end
        else
            self.liquid_recovery_cooldown = 5
            return true
        end
    end
    mobkit.queue_high(self, func, prty)
end

function animalia.hq_wander_ranged(self, prty)
    local idle_time = 3
    local move_probability = 3
    local func = function(self)
        if mobkit.is_queue_empty_low(self) then
            local pos = self.object:get_pos()
            local random_goal = vector.new(
                pos.x + random(-1, 1),
                pos.y,
                pos.z + random(-1, 1)
            )
            local node = minetest.get_node(random_goal)
            if minetest.registered_nodes[node.name].drawtype == "liquid"
            or minetest.registered_nodes[node.name].walkable then
                random_goal = nil
            end
            if self.lasso_pos
            and vec_dist(pos, self.lasso_pos) > 10 then
                random_goal = self.lasso_pos
            end
            if random(move_probability) < 2
            and random_goal then
                local _, pos2 = mobkit.get_next_waypoint(self, random_goal)
                if pos2 then
                    random_goal = pos2
                end
                mob_core.lq_dumbwalk(self, random_goal, 0.5)
            else
                animalia.lq_idle(self, idle_time)
            end
        end
    end
    mobkit.queue_high(self, func, prty)
end

function animalia.hq_wander_group(self, prty, group_range)
    local idle_time = 3
    local move_probability = 3
    local group_tick = 0
    local func = function(self)
        if mobkit.is_queue_empty_low(self) then
            group_tick = group_tick - 1
            local pos = self.object:get_pos()
            local group_positions = {}
            local random_goal = vector.new(
                pos.x + random(-1, 1),
                pos.y,
                pos.z + random(-1, 1)
            )
            if group_tick <= 0
            and self.group
            and #self.group > 0 then
                for _, obj in ipairs(self.group) do
                    if obj
                    and mobkit.is_alive(obj)
                    and #group_positions < 4 then
                        table.insert(group_positions, obj:get_pos())
                    end
                end
                if #group_positions > 2 then
                    group_range = group_range + #group_positions
                    local center = get_average_pos(group_positions)
                    if center
                    and ((vec_dist(random_goal, center) > group_range)
                    or vec_dist(pos, center) > group_range) then
                        random_goal = pos_to_neighbor(self, center)
                    end
                end
                group_tick = 3
            end
            local node = minetest.get_node(random_goal)
            if minetest.registered_nodes[node.name].drawtype == "liquid"
            or minetest.registered_nodes[node.name].walkable then
                random_goal = nil
            end
            if self.lasso_pos
            and vec_dist(pos, self.lasso_pos) > 10 then
                random_goal = self.lasso_pos
            end
            if random(move_probability) < 2
            and random_goal then
                local _, pos2 = mobkit.get_next_waypoint(self, random_goal)
                if pos2 then
                    random_goal = pos2
                end
                mob_core.lq_dumbwalk(self, random_goal, 0.5)
            else
                animalia.lq_idle(self, idle_time)
            end
        end
    end
    mobkit.queue_high(self, func, prty)
end

-- Breeding --

function animalia.hq_breed(self, prty)
    local mate = animalia.get_nearby_mate(self, self.name)
    if not mate then return end
    local func = function(self)
        if not mobkit.is_alive(mate) then
            return true
        end
        local pos = mobkit.get_stand_pos(self)
        local tpos = mate:get_pos()
        local dist = vec_dist(pos, tpos) - math.abs(hitbox(self)[4])
        local speed_factor = clamp(dist, 0.1, 0.65)
        if dist < 1.75 then
            self.breeding_time = self.breeding_time + 1
        end
        if self.breeding_time >= 2
        or mate:get_luaentity().breeding_time >= 2 then
            if self.gender == "female" then
                mob_core.spawn_child(pos, self.name)
            end
            self.breeding = false
            self.breeding_time = 0
            self.breeding_cooldown = 300
            mobkit.remember(self, "breeding", self.breeding)
            mobkit.remember(self, "breeding_time", self.breeding_time)
            mobkit.remember(self, "breeding_cooldown", self.breeding_cooldown)
            return true
        end
        if mobkit.is_queue_empty_low(self) then
            animalia.go_to_pos(self, tpos, speed_factor)
        end
    end
    mobkit.queue_high(self, func, prty)
end

function animalia.hq_fowl_breed(self, prty)
    local mate = animalia.get_nearby_mate(self, self.name)
    if not mate then return end
    local speed_factor = 0.5
    local func = function(self)
        if mobkit.is_queue_empty_low(self) then
            local pos = mobkit.get_stand_pos(self)
            local tpos = mate:get_pos()
            local dist = vec_dist(pos, tpos) - math.abs(hitbox(self)[4])
            if dist > 1.5 then
                speed_factor = 0.5
            else
                speed_factor = 0.1
            end
            mob_core.goto_next_waypoint(self, tpos, speed_factor)
            if dist < 1.75 then
                self.breeding_time = self.breeding_time + 1
            end
            if self.breeding_time >= 2
            or mate:get_luaentity().breeding_time >= 2 then
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
                    mob_core.spawn_child(pos, self.name)
                end
                self.breeding = false
                self.breeding_time = 0
                self.breeding_cooldown = 300
                mobkit.remember(self, "breeding", self.breeding)
                mobkit.remember(self, "breeding_time", self.breeding_time)
                mobkit.remember(self, "breeding_cooldown", self.breeding_cooldown)
                return true
            end
        end
    end
    mobkit.queue_high(self, func, prty)
end

-- Player Interaction --


function animalia.hq_sporadic_flee(self, prty)
    local timer = 12
    local func = function(self)
        if mobkit.is_queue_empty_low(self) then
            local pos = self.object:get_pos()
            local random_goal = vector.new(
                pos.x + random(-6, 6),
                pos.y,
                pos.z + random(-6, 6)
            )
            local node = minetest.get_node({x = random_goal.x, y = random_goal.y + 1, z = random_goal.z})
            if minetest.registered_nodes[node.name].drawtype == "liquid" then
                random_goal = nil
            end
            if random_goal then
                local anim = "walk"
                if self.animation["run"] then
                    anim = "run"
                end
                animalia.go_to_pos_lite(self, random_goal, 1)
            else
                animalia.lq_idle(self, 0.1)
            end
        end
        timer = timer - self.dtime
        if timer <= 0 then
            animalia.lq_idle(self, 0.1, "stand")
            return true
        end
    end
    mobkit.queue_high(self, func, prty)
end

function animalia.hq_attack(self, prty, target)
    local func = function(self)
        if not mobkit.is_alive(target) then
            return true
        end
        mob_core.punch_timer(self)
        local pos = mobkit.get_stand_pos(self)
        local tpos = target:get_pos()
        if not is_on_ground(target) then
            table.insert(self.target_blacklist, target)
            return true
        end
        local can_punch = is_within_reach(self, target)
        if mobkit.is_queue_empty_low(self) then
            animalia.go_to_pos(self, tpos, 1, "run")
        end
        if self.punch_timer <= 0
        and can_punch then
            target:punch(self.object, 1.0, {
                full_punch_interval = 0.1,
                damage_groups = {fleshy = self.damage}
            }, nil)
            mob_core.knockback(self, target)
            mob_core.punch_timer(self, self.punch_cooldown or 1)
            return true
        end
    end
    mobkit.queue_high(self, func, prty)
end

function animalia.hq_follow_player(self, prty, player, force) -- Follow Player
	if not player then return end
    if not force
    and not mob_core.follow_holding(self, player) then return end
    local func = function(self)
		if not mobkit.is_alive(player) then
            return true
		end
        local pos = mobkit.get_stand_pos(self)
        local tpos = player:get_pos()
        if mob_core.follow_holding(self, player)
        or force then
            self.status = mobkit.remember(self, "status", "following")
            local dist = vec_dist(pos, tpos)
            local yaw = self.object:get_yaw()
            local tyaw = minetest.dir_to_yaw(vector.direction(pos, tpos))
            if dist > self.view_range then
                self.status = mobkit.remember(self, "status", "")
                return true
            end
            if mobkit.is_queue_empty_low(self) then
                if vec_dist(pos, tpos) > hitbox(self)[4] + 2 then
                    animalia.go_to_pos(self, tpos, 0.6)
                else
                    mobkit.lq_idle(self, 0.1, "stand")
                end
            end
        elseif mobkit.is_queue_empty_low(self) then
            self.status = mobkit.remember(self, "status", "")
            mobkit.lq_idle(self, 0.1, "stand")
            return true
        end
    end
    mobkit.queue_high(self, func, prty)
end

-------------------------------
-- Mob Specific HQ Functions --
-------------------------------

-- Cat --

function animalia.hq_find_and_break_glass(self, prty)
    local timer = 6
    local moving = false
    local pos2 = nil
    mobkit.clear_queue_low(self)
    local func = function(self)
        local pos = mobkit.get_stand_pos(self)
        if not pos2 then
            local nodes = minetest.find_nodes_in_area(
                vector.subtract(pos, 8),
                vector.add(pos, 8),
                {"vessels:glass_bottle", "vessels:drinking_glass"}
            )
            if #nodes > 0 then
                pos2 = nodes[1]
            end
        end
        if not pos2 then return true end
        timer = timer - self.dtime
        if mobkit.is_queue_empty_low(self) then
            if dist_2d(pos, pos2) > 0.5 then
                animalia.go_to_pos(self, pos2, 0.35)
            end
        end
        if dist_2d(pos, pos2) <= 0.5 then
            mobkit.lq_idle(self, 0.7, "smack")
            minetest.remove_node(pos2)
            minetest.add_item(pos2, "vessels:glass_fragments")
            if minetest.get_node(pos2).name == "air" then
                return true
            end
        end
        if timer < 0 then return true end
    end
    mobkit.queue_high(self, func, prty)
end

function animalia.hq_walk_in_front_of_player(self, prty, player)
    if not player then return end
    local can_reach = false
    local path_data = nil
    local timer = 8
    local func = function(self)
		if not mobkit.is_alive(player) then
            return true
		end
        local pos = mobkit.get_stand_pos(self)
        local tpos = player:get_pos()
        local dir = player:get_look_dir()
        tpos.x = tpos.x + dir.x
        tpos.z = tpos.z + dir.z
        self.status = mobkit.remember(self, "status", "following")
        local dist = vec_dist(pos, tpos)
        local yaw = self.object:get_yaw()
        local tyaw = minetest.dir_to_yaw(vector.direction(pos, tpos))
        if dist > self.view_range then
            self.status = mobkit.remember(self, "status", "")
            return true
        end
        if mobkit.is_queue_empty_low(self) then
            if vec_dist(pos, tpos) > hitbox(self)[4] + 0.5 then
                if not can_reach then
                    can_reach, path_data = animalia.can_reach(self, tpos)
                else
                    animalia.lq_dumb_follow_path(self, path_data, 1, "run")
                end
            else
                can_reach = false
                path_data = nil
                mobkit.lq_idle(self, 0.1, "stand")
            end
        else
            can_reach = false
            path_data = nil
        end
        timer = timer - self.dtime
        if timer < 0 then return true end
    end
    mobkit.queue_high(self, func, prty)
end

-- Horse --

function animalia.hq_mount_logic(self, prty)
    local tvel = 0
	local rearing = false
    local jumping = false
    local anim = "stand"
    local func = function(self)
        if not self.driver then return true end
        -- if horse is rearing, stop moving
		if rearing then
			if mobkit.timer(self, 1.5) then
				rearing = false
			end
			return
		end
        -- Controls
		local vel = self.object:get_velocity()
		local ctrl = self.driver:get_player_control()
		if ctrl.up then
			tvel = self.speed
			if ctrl.aux1 then
				tvel = self.speed * 2
			end
		elseif tvel < 0.25 or tvel == 0 then
			tvel = 0
			self.object:set_velocity({
				x = 0,
				y = vel.y,
				z = 0
			})
            anim = "stand"
		end
		if self.isonground then
			if ctrl.jump then
                jumping = true
				vel.y = self.jump_power + 4.405
            else
                jumping = false
            end
		end
		 -- Physics and Animation
		if not ctrl.up
        and self.isonground then
			tvel = tvel * 0.75
		elseif not self.isonground then
            if self.isinliquid then
			    tvel = tvel * 0.4
                vel.y = vel.y * 0.4
            else
                if jumping then
                    tvel = tvel * 0.4
                else
                    tvel = tvel * 0.6
                end
            end
		end
        if tvel > 0 then
            if jumping then
                anim = "rear_constant"
            else
                if ctrl.aux1 then
                    anim = "run"
                else
                    anim = "walk"
                end
            end
        end
        if random(1024) < 2 then
            tvel = 0
			anim = "rear"
			rearing = true
        end
        mobkit.animate(self, anim)
		local tyaw = self.driver:get_look_horizontal() or 0
        self._tyaw = tyaw
        self.object:set_yaw(tyaw)
		local nvel = vector.multiply(minetest.yaw_to_dir(self.object:get_yaw()), tvel)
        self.object:set_velocity({
			x = nvel.x,
			y = vel.y,
			z = nvel.z
		})
        if ctrl.sneak then
			mob_core.detach(self.driver, {x = 1, y = 0, z = 1})
			return true
        end
	end
	mobkit.queue_high(self, func, prty)
end

function animalia.hq_horse_breed(self, prty)
    local mate = animalia.get_nearby_mate(self, self.name)
    if not mate then return end
    local speed_factor = 0.5
    local func = function(self)
        if mobkit.is_queue_empty_low(self) then
            local pos = mobkit.get_stand_pos(self)
            local tpos = mate:get_pos()
            local dist = vec_dist(pos, tpos) - math.abs(hitbox(self)[4])
            if dist > 1.5 then
                speed_factor = 0.5
            else
                speed_factor = 0.1
            end
            mob_core.goto_next_waypoint(self, tpos, speed_factor)
            if dist < 1.75 then
                self.breeding_time = self.breeding_time + 1
            end
            if self.breeding_time >= 2
            or mate:get_luaentity().breeding_time >= 2 then
                if self.gender == "female" then
                    local obj = mob_core.spawn_child(pos, self.name)
                    local ent = obj:get_luaentity()
                    local tex_no = self.texture_no
                    if random(2) < 2 then
                        tex_no = mate:get_luaentity().texture_no
                    end
                    mobkit.remember(ent, "texture_no", self.texture_no)
                    mobkit.remember(ent, "speed", random(mate:get_luaentity().speed, self.speed))
                    mobkit.remember(ent, "jump_power", random(mate:get_luaentity().jump_power, self.jump_power))
                    mobkit.remember(ent, "max_hp", random(mate:get_luaentity().max_hp, self.max_hp))
                    ent.speed = mobkit.recall(ent, "speed")
                    ent.jump_power = mobkit.recall(ent, "jump_power")
                    ent.max_hp = mobkit.recall(ent, "max_hp")
                    ent.object:set_properties({
                        texture = ent.textures[ent.texture_no] .. "^" .. mobkit.recall(ent, "pattern")
                    })
                end
                self.breeding = false
                self.breeding_time = 0
                self.breeding_cooldown = 300
                mobkit.remember(self, "breeding", self.breeding)
                mobkit.remember(self, "breeding_time", self.breeding_time)
                mobkit.remember(self, "breeding_cooldown", self.breeding_cooldown)
                return true
            end
        end
    end
    mobkit.queue_high(self, func, prty)
end

-----------------------
-- Dynamic Animation --
-----------------------

local function clamp_bone_rot(n) -- Fixes issues with bones jittering when yaw clamps
    if n < -180 then
        n = n + 360
    elseif n > 180 then
        n = n - 360
    end
    if n < -60 then
        n = -60
    elseif n > 60 then
        n = 60
    end
    return n
end

local function interp(a, b, w) -- Smoothens bone movement
    local pi = math.pi
    if math.abs(a - b) > math.deg(pi) then
        if a < b then
            return ((a + (b - a) * w) + (math.deg(pi) * 2))
        elseif a > b then
            return ((a + (b - a) * w) - (math.deg(pi) * 2)) 
        end
    end
    return a + (b - a) * w
end

local function move_head(self, tyaw, pitch)
    local data = self.head_data
    local _, rot = self.object:get_bone_position(data.bone or "Head.CTRL")
    local yaw = self.object:get_yaw()
    local look_yaw = clamp_bone_rot(math.deg(yaw - tyaw))
    local look_pitch = 0
    if pitch then
        look_pitch = clamp_bone_rot(math.deg(pitch))
    end
    if tyaw ~= yaw then
        look_yaw = look_yaw * 0.66
    end
    local yaw = interp(rot.z, look_yaw, 0.1)
    local ptch = interp(rot.x, look_pitch + data.pitch_correction, 0.1)
    self.object:set_bone_position(data.bone or "Head.CTRL", data.offset, {x = ptch, y = yaw, z = yaw})
end

function animalia.head_tracking(self)
    if not self.head_data then return end
    local yaw = self.object:get_yaw()
    local pos = mobkit.get_stand_pos(self)
    local v = vector.add(pos, vector.multiply(yaw2dir(yaw), self.head_data.pivot_h))
    pos.x = v.x
    pos.y = pos.y + self.head_data.pivot_v
    pos.z = v.z
    --[[minetest.add_particle({
        pos = pos,
        velocity = {x=0, y=0, z=0},
        acceleration = {x=0, y=0, z=0},
        expirationtime = 0.1,
        size = 8,
        collisiondetection = false,
        vertical = false,
        texture = "mob_core_green_particle.png",
        playername = "singleplayer"
    })]]
    if not self.head_tracking then
        local objects = minetest.get_objects_inside_radius(pos, 6)
        for _, object in ipairs(objects) do
            if object:is_player() then
                local dir_2_plyr = vector.direction(pos, object:get_pos())
                local yaw_2_plyr = dir2yaw(dir_2_plyr)
                if abs(yaw - yaw_2_plyr) < 1
                or abs(yaw - yaw_2_plyr) > 5.3 then
                    self.head_tracking = object
                end
                break
            end
        end
        if self._anim == "stand" then
            move_head(self, yaw)
        else
            move_head(self, self._tyaw)
        end
    else
        if not mobkit.exists(self.head_tracking) then
            self.head_tracking = nil
            return
        end
        local ppos = self.head_tracking:get_pos()
        ppos.y = ppos.y + 1.4
        local dir = vector.direction(pos, ppos)
        local tyaw = minetest.dir_to_yaw(dir)
        if abs(yaw - tyaw) > 1
        and abs(yaw - tyaw) < 5.3 then
            self.head_tracking = nil
            dir.y = 0
            return
        end
        move_head(self, tyaw, dir.y)
    end
end