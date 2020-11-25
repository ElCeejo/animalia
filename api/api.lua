-------------
---- API ----
-------------
-- Ver 0.1 --

local random = math.random
local pi = math.pi
local abs = math.abs
local ceil = math.ceil

local vec_dist = vector.distance

local abr = minetest.get_mapgen_setting('active_block_range')

local function hitbox(self) return self.object:get_properties().collisionbox end

local walkable_nodes = {}

minetest.register_on_mods_loaded(function()
	for name in pairs(minetest.registered_nodes) do
		if name ~= "air" and name ~= "ignore" then
			if minetest.registered_nodes[name].walkable then
				table.insert(walkable_nodes,name)
			end
		end
	end
end)

function better_fauna.particle_spawner(pos, texture, type, min_pos, max_pos)
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

---------------------------
-- Mob Control Functions --
---------------------------

local function can_fit(pos, width)
    local pos1 = vector.new(pos.x - width, pos.y, pos.z - width)
    local pos2 = vector.new(pos.x + width, pos.y, pos.z + width)
    for x = pos1.x, pos2.x do
        for y = pos1.y, pos2.y do
            for z = pos1.z, pos2.z do
                local p2 = vector.new(x, y, z)
                local node = minetest.get_node(p2)
                if minetest.registered_nodes[node.name].walkable then
                    local p3 = vector.new(p2.x, p2.y + 1, p2.z)
                    local node2 = minetest.get_node(p3)
                    if minetest.registered_nodes[node2.name].walkable then
                        return false
                    end
                end
            end
        end
    end
    return true
end

local function move_from_wall(pos, width)
    local pos1 = vector.new(pos.x - width, pos.y, pos.z - width)
    local pos2 = vector.new(pos.x + width, pos.y, pos.z + width)
    for x = pos1.x, pos2.x do
        for y = pos1.y, pos2.y do
            for z = pos1.z, pos2.z do
                local p2 = vector.new(x, y, z)
                if can_fit(p2, width) then
                    return p2
                end
            end
        end
    end
    return pos
end

function better_fauna.find_path(pos, tpos, width)

    local endpos = tpos

    if not minetest.registered_nodes[minetest.get_node(
        vector.new(endpos.x, endpos.y - 1, endpos.z))
        .name].walkable then
        local min = vector.subtract(endpos, 1)
        local max = vector.add(endpos, 1)

        local index_table = minetest.find_nodes_in_area_under_air( min, max, better_fauna.walkable_nodes)
        for _, i_pos in pairs(index_table) do
            if minetest.registered_nodes[minetest.get_node(i_pos)
                .name].walkable then
                endpos = vector.new(i_pos.x, i_pos.y + 1, i_pos.z)
                break
            end
        end
    end

    local path = minetest.find_path(pos, endpos, 32, 1, 1, "A*_noprefetch")

    if not path
    or #path < 2 then return end
	
    table.remove(path, 1)
    table.remove(path, #path)
	
    for i = #path, 1, -1 do
        if not path then return end
        if not can_fit(path[i], width + 1) then
            local clear = move_from_wall(path[i], width + 1)
            if clear and can_fit(clear, width) then
                path[i] = clear
            end
		end
        if #path > 3 then
            local pos1 = path[i - 2]
			local pos2 = path[i]
			-- Handle Diagonals
            if pos1
            and pos2
            and pos1.x ~= pos2.x
            and pos1.z ~= pos2.z then
				if minetest.line_of_sight(pos1, pos2) then
					local pos3 = vector.divide(vector.add(pos1, pos2), 2)
					if can_fit(pos, width) then
						table.remove(path, i - 1)
					end
                end
			end
			-- Reduce Straight Lines
			if pos1
            and pos2
            and pos1.x == pos2.x
			and pos1.z ~= pos2.z
			and pos1.y == pos2.y then
                if minetest.line_of_sight(pos1, pos2) then
					local pos3 = vector.divide(vector.add(pos1, pos2), 2)
					if can_fit(pos, width) then
						table.remove(path, i - 1)
					end
                end
            elseif pos1
			and pos2
			and pos1.x ~= pos2.x
			and pos1.z == pos2.z
			and pos1.y == pos2.y then
				if minetest.line_of_sight(pos1, pos2) then
					local pos3 = vector.divide(vector.add(pos1, pos2), 2)
					if can_fit(pos, width) then
						table.remove(path, i - 1)
					end
				end
			end
		end
    end

    if #path > 2 then
        if vector.distance(pos, path[2]) <= width + 1 then
            for i = 3, #path do
                path[i - 1] = path[i]
            end
        end
    end

    return path
end

function better_fauna.path_to_next_waypoint(self, tpos, speed_factor)
    speed_factor = speed_factor or 1
    local pos = self.object:get_pos()
	local path_data = better_fauna.find_path(pos, tpos, 1)
	if not path_data
	or #path_data < 2 then
        return true
    end
    local pos2 = path_data[2]
	if pos2 then
		local yaw = self.object:get_yaw()
        local tyaw = minetest.dir_to_yaw(vector.direction(pos, pos2))
        if abs(tyaw - yaw) > 0.1 then
            mobkit.lq_turn2pos(self, pos2)
        end
        mobkit.lq_dumbwalk(self, pos2, speed_factor)
        return true
    end
end

function better_fauna.feed_tame(self, clicker, feed_count, tame, breed)
	local item = clicker:get_wielded_item()
	local pos = self.object:get_pos()
	local mob_name = mob_core.get_name_proper(self.name)
	if mob_core.follow_holding(self, clicker) then
		if creative == false then
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
            if tame and not self.tamed then
                mob_core.set_owner(self, clicker:get_player_name())
                minetest.chat_send_player(clicker:get_player_name(), mob_name.." has been tamed!")
                mobkit.clear_queue_high(self)
                paleotest.particle_spawner(pos, "mob_core_green_particle.png", "float", min, max)
            end
            if breed then
                if self.child then return false end
                if self.breeding then return false end
                if self.breeding_cooldown <= 0 then
                    self.breeding = true
                    local min = vector.subtract(pos, 0.5)
                    local max = vector.add(pos, 0.5)
                    better_fauna.particle_spawner(pos, "heart.png", "float", min, max)
                end
            end
        end
	end
	return false
end

------------------
-- HQ Functions --
------------------

function better_fauna.hq_sporadic_flee(self, prty, player)
    local tyaw = 0
    local init = true
	local timer = 1
	if not player then return true end
	local func = function(self)
		if not mobkit.is_alive(player) then return true end
		if not mobkit.is_alive(self) then return true end
		local pos = mobkit.get_stand_pos(self)
		local yaw = self.object:get_yaw()
		local tpos = vector.add(pos, vector.multiply(minetest.yaw_to_dir(yaw), 4))

		if init then
			tyaw = minetest.dir_to_yaw(vector.direction(pos, tpos))
		end
		if self._anim ~= "run" then
			mobkit.animate(self, "run")
		end

        if mobkit.is_queue_empty_low(self) then
            timer = timer - self.dtime
            if timer < 0 then
				tyaw = yaw - random(1.6, 3.2)
				timer = 1
            end
            if abs(tyaw - yaw) > 0.1 then
                mobkit.turn2yaw(self, tyaw)
            end
            mobkit.go_forward_horizontal(self, self.max_speed)
            if timer <= 0 then return true end
        end
	end
    mobkit.queue_high(self, func, prty)
end

function better_fauna.hq_follow_player(self, prty, player) -- Follow Player
	if not player then return end
    if not mob_core.follow_holding(self, player) then return end
    local func = function(self)
		if not mobkit.is_alive(player) then
            mobkit.clear_queue_high(self)
            return true
		end
		if mobkit.is_queue_empty_low(self) then
			local pos = mobkit.get_stand_pos(self)
			local tpos = player:get_pos()
			if mob_core.follow_holding(self, player) then
				self.status = mobkit.remember(self, "status", "following")
				local dist = vec_dist(pos, tpos)
				local yaw = self.object:get_yaw()
				local tyaw = minetest.dir_to_yaw(vector.direction(pos, tpos))
				if dist > self.view_range then
					self.status = mobkit.remember(self, "status", "")
					return true
				end
				better_fauna.path_to_next_waypoint(self, tpos, 0.85)
				if vec_dist(pos, tpos) < hitbox(self)[4] + 2 then
					mobkit.lq_idle(self, 0.1, "stand")
				end
			else
				self.status = mobkit.remember(self, "status", "")
				mobkit.lq_idle(self, 0.1, "stand")
				return true
			end
		end
    end
    mobkit.queue_high(self, func, prty)
end

function better_fauna.get_nearby_mate(self, name)
	for _,obj in ipairs(self.nearby_objects) do
        if mobkit.is_alive(obj)
        and not obj:is_player()
        and obj:get_luaentity().name == name
        and obj:get_luaentity().gender ~= self.gender
        and obj:get_luaentity().breeding then
            return obj
        end
	end
	return
end

function better_fauna.hq_breed(self, prty)
    local mate = better_fauna.get_nearby_mate(self, self.name)
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

function better_fauna.hq_fowl_breed(self, prty)
    local mate = better_fauna.get_nearby_mate(self, self.name)
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
                        texture = "better_fauna_egg_fragment.png",
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

function better_fauna.hq_eat(self, prty)
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

---------------------------------
-- Entity Definition Functions --
---------------------------------

function better_fauna.on_step(self, dtime, moveresult)
    mob_core.on_step(self, dtime, moveresult)
    if mobkit.timer(self, 1) then
        if self.breeding_cooldown > 0 then
            self.breeding_cooldown = self.breeding_cooldown - 1
        end
        mobkit.remember(self, "breeding_cooldown", self.breeding_cooldown)
    end
end

function better_fauna.on_activate(self, staticdata, dtime_s)
    mob_core.on_activate(self, staticdata, dtime_s)
    self.gotten = mobkit.recall(self, "gotten") or false
    self.attention_span = mobkit.recall(self, "attention_span") or 0
    self.breeding = mobkit.recall(self, "breeding") or false
    self.breeding_time = mobkit.recall(self, "breeding_time") or 0
    self.breeding_cooldown = mobkit.recall(self, "breeding_cooldown") or 0
end

-------------
-- Physics --
-------------

function better_fauna.lightweight_physics(self)
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
