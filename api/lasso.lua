-----------
-- Lasso --
-----------

local abs = math.abs

local vec_add, vec_dir, vec_dist, vec_len = vector.add, vector.direction, vector.distance, vector.length
local dir2rot = vector.dir_to_rotation

-- Entities --

local using_lasso = {}

minetest.register_entity("animalia:lasso_entity", {
	visual = "mesh",
	mesh = "animalia_lasso_entity.b3d",
	textures = {"animalia_lasso_entity.png"},
	pointable = false,
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
	_scale = 1,
	on_step = function(self)
		local pos, parent = self.object:get_pos(), (self.object:get_attach() or self._attached)
		local pointed_ent = self._point_to and self._point_to:get_luaentity()
		local point_to = self._point_to and self._point_to:get_pos()
		if not pos or not parent or not point_to then self.object:remove() return end
		if type(parent) == "string" then
			parent = minetest.get_player_by_name(parent)
			if not parent then self.object:remove() return end
			local tgt_pos = parent:get_pos()
			tgt_pos.y = tgt_pos.y + 1
			point_to.y = point_to.y + pointed_ent.height * 0.5
			local dist = vec_dist(pos, tgt_pos)
			if dist > 0.5 then
				self.object:set_pos(tgt_pos)
			else
				self.object:move_to(tgt_pos)
			end
			self.object:set_rotation(dir2rot(vec_dir(tgt_pos, point_to)))
		elseif parent.x then
			point_to.y = point_to.y + pointed_ent.height * 0.5
			self.object:set_rotation(dir2rot(vec_dir(pos, point_to)))
		else
			self.object:remove()
			return
		end
		local size = vec_dist(pos, point_to)
		if abs(size - self._scale) > 0.1 then
			self.object:set_properties({
				visual_size = {x = 1, y = 1, z = size}
			})
			self._scale = size
		end
	end
})

local function remove_from_fence(self)
	local pos = self.object:get_pos()
	local mob = self._mob and self._mob:get_luaentity()
	if not mob then
		self.object:remove()
		return
	end
	mob._lassod_to = nil
	mob:forget("_lassod_to")
	mob._lasso_ent:remove()
	local dirs = {
		{x = 0.5, y = 0, z = 0},
		{x = -0.5, y = 0, z = 0},
		{x = 0, y = 0.5, z = 0},
		{x = 0, y = -0.5, z = 0},
		{x = 0, y = 0, z = 0.5},
		{x = 0, y = 0, z = -0.5}
	}
	for i = 1, 6 do
		local i_pos = vec_add(pos, dirs[i])
		if not creatura.get_node_def(i_pos).walkable then
			minetest.add_item(i_pos, "animalia:lasso")
			break
		end
	end
	self.object:remove()
end

minetest.register_entity("animalia:tied_lasso_entity", {
	collisionbox = {-0.25,-0.25,-0.25, 0.25,0.25,0.25},
	visual = "cube",
	visual_size = {x = 0.3, y = 0.3},
	mesh = "model",
	textures = {
		"animalia_tied_lasso_entity.png",
		"animalia_tied_lasso_entity.png",
		"animalia_tied_lasso_entity.png",
		"animalia_tied_lasso_entity.png",
		"animalia_tied_lasso_entity.png",
		"animalia_tied_lasso_entity.png",
	},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
	on_step = function(self)
		local mob = self._mob and self._mob:get_luaentity()
		if not mob then remove_from_fence(self) return end
	end,
	on_rightclick = remove_from_fence,
	on_punch = remove_from_fence
})

-- API --

local function add_lasso(self, origin)
	local pos = self.object:get_pos()
	if not pos then return end
	local object = minetest.add_entity(pos, "animalia:lasso_entity")
	local ent = object and object:get_luaentity()
	if not ent then return end
	-- Attachment point of entity
	ent._attached = origin
	if type(origin) ~= "string" then
		--local player = minetest.get_player_by_name(origin)
		--object:set_attach(player)
	--else
		object:set_pos(origin)
	end
	self._lassod_to = origin
	ent._point_to = self.object
	self:memorize("_lassod_to", origin)
	return object
end

local function get_rope_velocity(pos1, pos2, dist)
	local force = dist / 10
	local vel = vector.new((pos2.x - pos1.x) * force, ((pos2.y - pos1.y) / (24 + dist)), (pos2.z - pos1.z) * force)
	return vel
end

function animalia.initialize_lasso(self)
	self._lassod_to = self:recall("_lassod_to") or self:recall("lasso_origin")
	if self._lassod_to then
		local origin = self._lassod_to
		if type(origin) == "table"
		and minetest.get_item_group(minetest.get_node(origin).name, "fence") > 0 then
			local object = minetest.add_entity(origin, "animalia:tied_lasso_entity")
			object:get_luaentity()._mob = self.object
			self._lasso_ent = add_lasso(self, origin)
		elseif type(origin) == "string" then
			self._lassod_to = origin
			self._lasso_ent = add_lasso(self, origin)
		else
			self:forget("_lassod_to")
		end
	end
end

function animalia.update_lasso_effects(self)
	local pos = self.object:get_pos()
	if not creatura.is_alive(self) then return end
	if self._lassod_to then
		local lasso = self._lassod_to
		self._lasso_ent = self._lasso_ent or add_lasso(self, lasso)
		if type(lasso) == "string" then
			using_lasso[lasso] = self
			local name = lasso
			lasso = minetest.get_player_by_name(lasso)
			if lasso then
				if lasso:get_wielded_item():get_name() ~= "animalia:lasso" then
					using_lasso[name] = nil
					self._lasso_ent:remove()
					self._lasso_ent = nil
					self._lassod_to = nil
					self:forget("_lassod_to")
					return
				end
				local lasso_pos = lasso:get_pos()
				local dist = vec_dist(pos, lasso_pos)
				local vel = self.object:get_velocity()
				if not vel or dist < 8 and self.touching_ground then return end
				if vec_len(vel) < 8 then
					self.object:add_velocity(get_rope_velocity(pos, lasso_pos, dist))
				end
				return
			end
		elseif type(lasso) == "table" then
			local dist = vec_dist(pos, lasso)
			local vel = self.object:get_velocity()
			if not vel or dist < 8 and self.touching_ground then return end
			if vec_len(vel) < 8 then
				self.object:add_velocity(get_rope_velocity(pos, lasso, dist))
			end
			return
		end
	end
	if self._lasso_ent then
		self._lasso_ent:remove()
		self._lasso_ent = nil
		self._lassod_to = nil
		self:forget("_lassod_to")
	end
end

-- Item

minetest.register_craftitem("animalia:lasso", {
	description = "Lasso",
	inventory_image = "animalia_lasso.png",
	on_secondary_use = function(_, placer, pointed)
		local ent = pointed.ref and pointed.ref:get_luaentity()
		if ent
		and (ent.name:match("^animalia:")
		or ent.name:match("^monstrum:")) then
			if not ent.catch_with_lasso then return end
			local name = placer:get_player_name()
			if not ent._lassod_to
			and not using_lasso[name] then
				using_lasso[name] = ent
				ent._lassod_to = name
				ent:memorize("_lassod_to", name)
			elseif ent._lassod_to
			and ent._lassod_to == name then
				using_lasso[name] = nil
				ent._lassod_to = nil
				ent:forget("_lassod_to")
			end
		end
	end,
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type == "node" then
			local pos = minetest.get_pointed_thing_position(pointed_thing)
			if minetest.get_item_group(minetest.get_node(pos).name, "fence") > 0 then
				local name = placer:get_player_name()
				local ent = using_lasso[name]
				if ent
				and ent._lassod_to
				and ent._lassod_to == name then
					using_lasso[name] = nil
					ent._lasso_ent:set_detach()
					ent._lasso_ent:set_pos(pos)
					ent._lasso_ent:get_luaentity()._attached = pos
					ent._lassod_to = pos
					ent:memorize("_lassod_to", pos)
					local fence_obj = minetest.add_entity(pos, "animalia:tied_lasso_entity")
					fence_obj:get_luaentity()._mob = ent.object
					fence_obj:get_luaentity()._lasso_obj = ent._lasso_ent
					itemstack:take_item(1)
				end
			end
		end
		return itemstack
	end
})
