---------
-- API --
---------

-- Math --

local abs = math.abs
local atan2 = math.atan2
local cos = math.cos
local deg = math.deg
local min = math.min
local pi = math.pi
local pi2 = pi * 2
local rad = math.rad
local random = math.random
local sin = math.sin
local sqrt = math.sqrt


local function diff(a, b) -- Get difference between 2 angles
	return atan2(sin(b - a), cos(b - a))
end

local function interp_angle(a, b, w)
	local cs = (1 - w) * cos(a) + w * cos(b)
	local sn = (1 - w) * sin(a) + w * sin(b)
	return atan2(sn, cs)
end

local function lerp_step(a, b, dtime, rate)
	return min(dtime * rate, abs(diff(a, b)) % (pi2))
end

local function clamp(val, _min, _max)
	if val < _min then
		val = _min
	elseif _max < val then
		val = _max
	end
	return val
end

-- Vector Math --

local vec_dir = vector.direction
local vec_add = vector.add
local vec_sub = vector.subtract
local vec_multi = vector.multiply
local vec_normal = vector.normalize
local vec_divide = vector.divide
local vec_len = vector.length

local dir2yaw = minetest.dir_to_yaw
local yaw2dir = minetest.yaw_to_dir

------------
-- Common --
------------

function animalia.get_average_pos(vectors)
	local sum = {x = 0, y = 0, z = 0}
	for _, vec in pairs(vectors) do sum = vec_add(sum, vec) end
	return vec_divide(sum, #vectors)
end

function animalia.correct_name(str)
	if str then
		if str:match(":") then str = str:split(":")[2] end
		return (string.gsub(" " .. str, "%W%l", string.upper):sub(2):gsub("_", " "))
	end
end

---------------------
-- Local Utilities --
---------------------

local function activate_nametag(self)
	self.nametag = self:recall("nametag") or nil
	if not self.nametag then return end
	self.object:set_properties({
		nametag = self.nametag,
		nametag_color = "#FFFFFF"
	})
end

local animate_player = {}

if minetest.get_modpath("default")
and minetest.get_modpath("player_api") then
	animate_player = player_api.set_animation
elseif minetest.get_modpath("mcl_player") then
	animate_player = mcl_player.player_set_animation
end

-----------------------
-- Dynamic Animation --
-----------------------

function animalia.rotate_to_pitch(self)
	local rot = self.object:get_rotation()
	if self._anim == "fly" then
		local vel = vec_normal(self.object:get_velocity())
		local step = math.min(self.dtime * 5, abs(diff(rot.x, vel.y)) % (pi2))
		local n_rot = interp_angle(rot.x, vel.y, step)
		self.object:set_rotation({
			x = clamp(n_rot, -0.75, 0.75),
			y = rot.y,
			z = rot.z
		})
	elseif rot.x ~= 0 then
		self.object:set_rotation({
			x = 0,
			y = rot.y,
			z = rot.z
		})
	end
end

function animalia.move_head(self, tyaw, pitch)
	local data = self.head_data
	if not data then return end
	local yaw = self.object:get_yaw()
	local pitch_offset = data.pitch_correction or 0
	local bone = data.bone or "Head.CTRL"
	local _, rot = self.object:get_bone_position(bone)
	if not rot then return end
	local n_yaw = (tyaw ~= yaw and diff(tyaw, yaw) / 2) or 0
	if abs(deg(n_yaw)) > 45 then n_yaw = 0 end
	local dir = yaw2dir(n_yaw)
	dir.y = pitch or 0
	local n_pitch = (sqrt(dir.x^2 + dir.y^2) / dir.z)
	if abs(deg(n_pitch)) > 45 then n_pitch = 0 end
	if self.dtime then
		local yaw_w = lerp_step(rad(rot.z), tyaw, self.dtime, 3)
		n_yaw = interp_angle(rad(rot.z), n_yaw, yaw_w)
		local rad_offset = rad(pitch_offset)
		local pitch_w = lerp_step(rad(rot.x), n_pitch + rad_offset, self.dtime, 3)
		n_pitch = interp_angle(rad(rot.x), n_pitch + rad_offset, pitch_w)
	end
	local pitch_max = pitch_offset + 45
	local pitch_min = pitch_offset - 45
	self.object:set_bone_position(bone, data.offset,
		{x = clamp(deg(n_pitch), pitch_min, pitch_max), y = 0, z = clamp(deg(n_yaw), -45, 45)})
end

function animalia.head_tracking(self)
	if not self.head_data then return end
	-- Calculate Head Position
	local yaw = self.object:get_yaw()
	local pos = self.object:get_pos()
	if not pos then return end
	local y_dir = yaw2dir(yaw)
	local offset_h = self.head_data.pivot_h
	local offset_v = self.head_data.pivot_v
	pos = {
		x = pos.x + y_dir.x * offset_h,
		y = pos.y + offset_v,
		z = pos.z + y_dir.z * offset_h
	}
	local vel = self.object:get_velocity()
	if vec_len(vel) > 2 then
		self.head_tracking = nil
		animalia.move_head(self, yaw, 0)
		return
	end
	local player = self.head_tracking
	local plyr_pos = player and player:get_pos()
	if plyr_pos then
		plyr_pos.y = plyr_pos.y + 1.4
		local dir = vec_dir(pos, plyr_pos)
		local tyaw = dir2yaw(dir)
		if abs(diff(yaw, tyaw)) > pi / 10
		and self._anim == "stand" then
			self:turn_to(tyaw, 1)
		end
		animalia.move_head(self, tyaw, dir.y)
		return
	elseif self:timer(6)
	and random(4) < 2 then

		local players = creatura.get_nearby_players(self, 6)
		self.head_tracking = #players > 0 and players[random(#players)]
	end
	animalia.move_head(self, yaw, 0)

end

---------------
-- Utilities --
---------------

function animalia.alias_mob(old_mob, new_mob)
	minetest.register_entity(":" .. old_mob, {
		on_activate = function(self)
			local pos = self.object:get_pos()
			minetest.add_entity(pos, new_mob)
			self.object:remove()
		end,
	})
end

------------------------
-- Environment Access --
------------------------

function animalia.get_nearby_mate(self)
	local pos = self.object:get_pos()
	if not pos then return end
	local objects = creatura.get_nearby_objects(self, self.name)
	for _, object in ipairs(objects) do
		local obj_pos = object and object:get_pos()
		local ent = obj_pos and object:get_luaentity()
		if obj_pos
		and ent.gender ~= self.gender
		and ent.breeding then
			return object
		end
	end
end

function animalia.find_collision(self, dir)
	local pos = self.object:get_pos()
	local pos2 = vec_add(pos, vec_multi(dir, 16))
	local ray = minetest.raycast(pos, pos2, false, false)
	for pointed_thing in ray do
		if pointed_thing.type == "node" then
			return pointed_thing.under
		end
	end
	return nil
end

function animalia.random_drop_item(self, item, chance)
	local pos = self.object:get_pos()
	if not pos then return end
	if random(chance) < 2 then
		local object = minetest.add_item(pos, ItemStack(item))
		object:add_velocity({
			x = random(-2, 2),
			y = 1.5,
			z = random(-2, 2)
		})
	end
end

---------------
-- Particles --
---------------

function animalia.particle_spawner(pos, texture, type, min_pos, max_pos)
	type = type or "float"
	min_pos = min_pos or vec_sub(pos, 2)
	max_pos = max_pos or vec_add(pos, 2)
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
			minvel = {x = -1, y = 2, z = -1},
			maxvel = {x = 1, y = 5, z = 1},
			minacc = {x = 0, y = -9.81, z = 0},
			maxacc = {x = 0, y = -9.81, z = 0},
			minsize = 2,
			maxsize = 4,
			collisiondetection = true,
			texture = texture,
		})
	end
end

function animalia.add_food_particle(self, item_name)
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

----------
-- Mobs --
----------

function animalia.death_func(self)
	if self:get_utility() ~= "animalia:die" then
		self:initiate_utility("animalia:die", self)
	end
end

function animalia.get_dropped_food(self, item, radius)
	local pos = self.object:get_pos()
	if not pos then return end
	local objects = minetest.get_objects_inside_radius(pos, radius or self.tracking_range)
	for _, object in ipairs(objects) do
		local ent = object:get_luaentity()
		if ent
		and ent.name == "__builtin:item"
		and ent.itemstring
		and ((item and ent.itemstring:match(item))
		or self:follow_item(ItemStack(ent.itemstring))) then
			return object, object:get_pos()
		end
	end
end

function animalia.protect_from_despawn(self)
	self._despawn = self:memorize("_despawn", false)
	self.despawn_after = self:memorize("despawn_after", false)
end

function animalia.despawn_inactive_mob(self)
	local os_time = os.time()
	self._last_active = self:recall("_last_active")
	if self._last_active
	and self.despawn_after then
		local last_active = self._last_active
		if os_time - last_active > self.despawn_after then
			self.object:remove()
			return true
		end
	end
end

function animalia.set_nametag(self, clicker)
	local plyr_name = clicker and clicker:get_player_name()
	if not plyr_name then return end
	local item = clicker:get_wielded_item()
	if item
	and item:get_name() ~= "animalia:nametag" then
		return
	end
	local name = item:get_meta():get_string("name")
	if not name
	or name == "" then
		return
	end
	self.nametag = self:memorize("nametag", name)
	self.despawn_after = self:memorize("despawn_after", false)
	activate_nametag(self)
	if not minetest.is_creative_enabled(plyr_name) then
		item:take_item()
		clicker:set_wielded_item(item)
	end
	return true
end

function animalia.initialize_api(self)
	self.gender = self:recall("gender") or nil
	if not self.gender then
		local genders = {"male", "female"}
		self.gender = self:memorize("gender", genders[random(2)])
		-- Reset Texture ID
		self.texture_no = nil
	end
	self.food = self:recall("food") or 0
	self.gotten = self:recall("gotten") or false
	self.breeding = false
	self.breeding_cooldown = self:recall("breeding_cooldown") or 0
	activate_nametag(self)
	if self.growth_scale then
		self:memorize("growth_scale", self.growth_scale) -- This is for spawning children
	end
	self.growth_scale = self:recall("growth_scale") or 1
	self:set_scale(self.growth_scale)
	local child_textures = self.growth_scale < 0.8 and self.child_textures
	local textures = (not child_textures and self[self.gender .. "_textures"]) or self.textures
	if child_textures then
		if not self.texture_no
		or self.texture_no > #child_textures then
			self.texture_no = random(#child_textures)
		end
		self:set_texture(self.texture_no, child_textures)
	elseif textures then
		if not self.texture_no then
			self.texture_no = random(#textures)
		end
		self:set_texture(self.texture_no, textures)
	end
	if self.growth_scale < 0.8
	and self.child_mesh then
		self.object:set_properties({
			mesh = self.child_mesh
		})
	end
end

function animalia.step_timers(self)
	local breed_cd = self.breeding_cooldown or 30
	local trust_cd = self.trust_cooldown or 0
	self.breeding_cooldown = (breed_cd > 0 and breed_cd - self.dtime) or 0
	self.trust_cooldown = (trust_cd > 0 and trust_cd - self.dtime) or 0
	if self.breeding
	and self.breeding_cooldown <= 30 then
		self.breeding = false
	end
	self:memorize("breeding_cooldown", self.breeding_cooldown)
	self:memorize("trust_cooldown", self.trust_cooldown)
	self:memorize("_last_active", os.time())
end

function animalia.do_growth(self, interval)
	if self.growth_scale
	and self.growth_scale < 0.9 then
		if self:timer(interval) then
			self.growth_scale = self.growth_scale + 0.1
			self:set_scale(self.growth_scale)
			if self.growth_scale < 0.8
			and self.child_textures then
				local tex_no = self.texture_no
				if not self.child_textures[tex_no] then
					tex_no = 1
				end
				self:set_texture(tex_no, self.child_textures)
			elseif self.growth_scale == 0.8 then
				if self.child_mesh then self:set_mesh() end
				if self.male_textures
				and self.female_textures then
					if #self.child_textures == 1 then
						self.texture_no = random(#self[self.gender .. "_textures"])
					end
					self:set_texture(self.texture_no, self[self.gender .. "_textures"])
				else
					if #self.child_textures == 1 then
						self.texture_no = random(#self.textures)
					end
					self:set_texture(self.texture_no, self.textures)
				end
				if self.on_grown then
					self:on_grown()
				end
			end
			self:memorize("growth_scale", self.growth_scale)
		end
	end
end

function animalia.random_sound(self)
	if self:timer(8)
	and random(4) < 2 then
		self:play_sound("random")
	end
end

function animalia.add_trust(self, player, amount)
	if self.trust_cooldown > 0 then return end
	self.trust_cooldown = 60
	local plyr_name = player:get_player_name()
	local trust = self.trust[plyr_name] or 0
	if trust > 4 then return end
	self.trust[plyr_name] = trust + (amount or 1)
	self:memorize("trust", self.trust)
end

function animalia.feed(self, clicker, tame, breed)
	local yaw = self.object:get_yaw()
	local pos = self.object:get_pos()
	if not pos then return end
	local name = clicker:is_player() and clicker:get_player_name()
	local item, item_name = self:follow_wielded_item(clicker)
	if item_name then
		-- Eat Animation
		local head = self.head_data
		local offset_h = (head and head.pivot_h) or 0.5
		local offset_v = (head and head.pivot_v) or 0.5
		local head_pos = {
			x = pos.x + sin(yaw) * -offset_h,
			y = pos.y + offset_v,
			z = pos.z + cos(yaw) * offset_h
		}
		local def = minetest.registered_items[item_name]
		if def.inventory_image then
			minetest.add_particlespawner({
				pos = head_pos,
				time = 0.1,
				amount = 3,
				collisiondetection = true,
				collision_removal = true,
				vel = {min = {x = -1, y = 3, z = -1}, max = {x = 1, y = 4, z = 1}},
				acc = {x = 0, y = -9.8, z = 0},
				size = {min = 2, max = 4},
				texture = def.inventory_image
			})
		end
		-- Increase Health
		local feed_no = (self.feed_no or 0) + 1
		local max_hp = self.max_health
		local hp = self.hp
		hp = hp + (max_hp / 5)
		if hp > max_hp then hp = max_hp end
		self.hp = hp
		-- Tame/Breed
		if feed_no >= 5 then
			feed_no = 0
			if tame then
				self.owner = self:memorize("owner", name)
				minetest.add_particlespawner({
					pos = {min = vec_sub(pos, self.width), max = vec_add(pos, self.width)},
					time = 0.1,
					amount = 12,
					vel = {min = {x = 0, y = 3, z = 0}, max = {x = 0, y = 4, z = 0}},
					size = {min = 4, max = 6},
					glow = 16,
					texture = "creatura_particle_green.png"
				})
			end
			if breed then
				if self.breeding then return false end
                if self.breeding_cooldown <= 0 then
                    self.breeding = true
                    self.breeding_cooldown = 60
                    animalia.particle_spawner(pos, "heart.png", "float")
                end
			end
			self._despawn = self:memorize("_despawn", false)
			self.despawn_after = self:memorize("despawn_after", false)
		end
		self.feed_no = feed_no
		-- Take item
		if not minetest.is_creative_enabled(name) then
			item:take_item()
			clicker:set_wielded_item(item)
		end
		return true
	end
end

function animalia.mount(self, player, params)
	if not creatura.is_alive(player) then
		return
	end
	local plyr_name = player:get_player_name()
	if (player:get_attach()
	and player:get_attach() == self.object)
	or not params then
		player:set_detach()
		player:set_properties({
			visual_size = {
				x = 1,
				y = 1
			}
		})
		player:set_eye_offset()
		if minetest.get_modpath("player_api") then
			animate_player(player, "stand", 30)
			if player_api.player_attached then
				player_api.player_attached[plyr_name] = false
			end
		end
		self.rider = nil
		return
	end
	if minetest.get_modpath("player_api") then
		player_api.player_attached[plyr_name] = true
	end
	self.rider = player
	player:set_attach(self.object, "Torso", params.pos, params.rot)
	player:set_eye_offset({x = 0, y = 25, z = 0}, {x = 0, y = 15, z = 15})
	self:clear_utility()
	minetest.after(0.4, function()
		animate_player(player, "sit" , 30)
	end)
end

function animalia.punch(self, puncher, ...)
	if self.hp <= 0 then return end
	creatura.basic_punch_func(self, puncher, ...)
	self._puncher = puncher
	if self.flee_puncher
	and (self:get_utility() or "") ~= "animalia:flee_from_target" then
		self:clear_utility()
	end
end

function animalia.find_crop(self)
	local pos = self.object:get_pos()
	if not pos then return end

	local nodes = minetest.find_nodes_in_area(vec_sub(pos, 6), vec_add(pos, 6), "group:crop") or {}
	if #nodes < 1 then return end
	return nodes[math.random(#nodes)]
end

function animalia.eat_crop(self, pos)
	local node_name = minetest.get_node(pos).name
	local new_name = node_name:sub(1, #node_name - 1) .. (tonumber(node_name:sub(-1)) or 2) - 1
	local new_def = minetest.registered_nodes[new_name]
	if not new_def then return false end
	local p2 = new_def.place_param2 or 1
	minetest.set_node(pos, {name = new_name, param2 = p2})
	animalia.add_food_particle(self, new_name)
	return true
end

--------------
-- Spawning --
--------------

animalia.registered_biome_groups = {}

function animalia.register_biome_group(name, def)
	animalia.registered_biome_groups[name] = def
	animalia.registered_biome_groups[name].biomes = {}
end

local function assign_biome_group(name)
	local def = minetest.registered_biomes[name]
	local turf = def.node_top
	local heat = def.heat_point or 0
	local humidity = def.humidity_point or 50
	local y_min = def.y_min
	local y_max = def.y_max
	for group, params in pairs(animalia.registered_biome_groups) do -- k, v in pairs
		if name:find(params.name_kw or "")
		and turf and turf:find(params.turf_kw or "")
		and heat >= params.min_heat
		and heat <= params.max_heat
		and humidity >= params.min_humidity
		and humidity <= params.max_humidity
		and (not params.min_height or y_min >= params.min_height)
		and (not params.max_height or y_max <= params.max_height) then
			table.insert(animalia.registered_biome_groups[group].biomes, name)
		end
	end
end

minetest.register_on_mods_loaded(function()
	for name in pairs(minetest.registered_biomes) do
		assign_biome_group(name)
	end
end)

animalia.register_biome_group("temperate", {
	name_kw = "",
	turf_kw = "grass",
	min_heat = 45,
	max_heat = 70,
	min_humidity = 0,
	max_humidity = 50
})

animalia.register_biome_group("urban", {
	name_kw = "",
	turf_kw = "grass",
	min_heat = 0,
	max_heat = 100,
	min_humidity = 0,
	max_humidity = 100
})

animalia.register_biome_group("grassland", {
	name_kw = "",
	turf_kw = "grass",
	min_heat = 45,
	max_heat = 90,
	min_humidity = 0,
	max_humidity = 80
})

animalia.register_biome_group("boreal", {
	name_kw = "",
	turf_kw = "litter",
	min_heat = 10,
	max_heat = 55,
	min_humidity = 0,
	max_humidity = 80
})

animalia.register_biome_group("ocean", {
	name_kw = "ocean",
	turf_kw = "",
	min_heat = 0,
	max_heat = 100,
	min_humidity = 0,
	max_humidity = 100,
	max_height = 0
})

animalia.register_biome_group("swamp", {
	name_kw = "",
	turf_kw = "",
	min_heat = 55,
	max_heat = 90,
	min_humidity = 55,
	max_humidity = 90,
	max_height = 10,
	min_height = -20
})

animalia.register_biome_group("tropical", {
	name_kw = "",
	turf_kw = "litter",
	min_heat = 70,
	max_heat = 90,
	min_humidity = 65,
	max_humidity = 90
})

animalia.register_biome_group("cave", {
	name_kw = "under",
	turf_kw = "",
	min_heat = 0,
	max_heat = 100,
	min_humidity = 0,
	max_humidity = 100,
	max_height = 5
})

animalia.register_biome_group("common", {
	name_kw = "",
	turf_kw = "",
	min_heat = 25,
	max_heat = 75,
	min_humidity = 20,
	max_humidity = 80,
	min_height = 1
})
