-----------
-- Horse --
-----------

local random = math.random

-- Horse Inventory

local form_obj = {}

local function create_horse_inventory(self)
	if not self.owner then return end
	local inv_name = "animalia:horse_" .. self.owner
	local inv = minetest.create_detached_inventory(inv_name, {
		allow_move = function(_, _, _, _, _, count)
			return count
		end,
		allow_put = function(_, _, _, stack)
			return stack:get_count()
		end,
		allow_take = function(_, _, _, stack)
			return stack:get_count()
		end
	})
	inv:set_size("main", 12)
	inv:set_width("main", 4)
	return inv
end

local function serialize_horse_inventory(self)
	if not self.owner then return end
	local inv_name = "animalia:horse_" .. self.owner
	local inv = minetest.get_inventory({type = "detached", name = inv_name})
	if not inv then return end
	local list = inv:get_list("main")
	local stored = {}
	for k, item in ipairs(list) do
		local itemstr = item:to_string()
		if itemstr ~= "" then
			stored[k] = itemstr
		end
	end
	self._inventory = self:memorize("_inventory", minetest.serialize(stored))
end

local function get_form(self, player_name)
	local inv = create_horse_inventory(self)
	if inv
	and self._inventory then
		inv:set_list("main", minetest.deserialize(self._inventory))
	end

	local frame_range = self.animations["stand"].range
	local frame_loop = frame_range.x .. "," ..  frame_range.y
	local texture = self:get_props().textures[1]
	local form = {
		"formspec_version[3]",
		"size[10.5,10]",
		"image[0,0;10.5,5.25;animalia_form_horse_bg.png]",
		"model[0,0.5;5,3.5;mob_mesh;animalia_horse.b3d;" .. texture .. ";-10,-130;false;false;" .. frame_loop .. ";15]",
		"list[detached:animalia:horse_" .. player_name .. ";main;5.4,0.5;4,3;]",
		"list[current_player;main;0.4,4.9;8,4;]",
		"listring[current_player;main]"
	}

	return table.concat(form, "")
end

local function close_form(player)
	local name = player:get_player_name()

	if form_obj[name] then
		form_obj[name] = nil
		minetest.remove_detached_inventory("animalia:horse_" .. name)
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if not form_obj[name] or not form_obj[name]:get_yaw() then
		return
	end
	local obj = form_obj[name]
	if formname == "animalia:horse_forms" then
		local ent = obj and obj:get_luaentity()
		if not ent then return end

		if fields.quit or fields.key_enter then
			form_obj[name] = nil
			serialize_horse_inventory(ent)
			minetest.remove_detached_inventory("animlaia:horse_" .. name)
		end
	end

	if formname == "animalia:horse_inv" then
		local ent = obj and obj:get_luaentity()
		if not ent then return end

		if fields.quit or fields.key_enter then
			form_obj[name] = nil
			serialize_horse_inventory(ent)
			minetest.remove_detached_inventory("animalia:horse_" .. name)
		end
	end
end)

minetest.register_on_leaveplayer(close_form)

-- Pattern

local patterns = {
	"animalia_horse_pattern_1.png",
	"animalia_horse_pattern_2.png",
	"animalia_horse_pattern_3.png"
}

local avlbl_colors = {
	[1] = {
		"animalia_horse_2.png",
		"animalia_horse_3.png",
		"animalia_horse_5.png"
	},
	[2] = {
		"animalia_horse_1.png",
		"animalia_horse_5.png"
	},
	[3] = {
		"animalia_horse_2.png",
		"animalia_horse_1.png"
	},
	[4] = {
		"animalia_horse_2.png",
		"animalia_horse_1.png"
	},
	[5] = {
		"animalia_horse_2.png",
		"animalia_horse_1.png"
	}
}

local function set_pattern(self)
	local pattern_no = self:recall("pattern_no")
	if pattern_no and pattern_no < 1 then return end
	if not pattern_no then
		if random(3) < 2 then
			pattern_no = self:memorize("pattern_no", random(#patterns))
		else
			self:memorize("pattern_no", 0)
			return
		end
	end
	local colors = avlbl_colors[self.texture_no]
	local color_no = self:recall("color_no") or self:memorize("color_no", random(#colors))
	if not colors[color_no] then return end
	local pattern = "(" .. patterns[pattern_no] .. "^[mask:" .. colors[color_no] .. ")"
	local texture = self.textures[self.texture_no]
	self.object:set_properties({
		textures = {texture .. "^" .. pattern}
	})
end

-- Definition

creatura.register_mob("animalia:horse", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_horse.b3d",
	textures = {
		"animalia_horse_1.png",
		"animalia_horse_2.png",
		"animalia_horse_3.png",
		"animalia_horse_4.png",
		"animalia_horse_5.png"
	},
	makes_footstep_sound = true,

	-- Creatura Props
	max_health = 40,
	armor_groups = {fleshy = 100},
	damage = 8,
	speed = 10,
	tracking_range = 16,
	max_boids = 7,
	despawn_after = 1000,
	max_fall = 4,
	stepheight = 1.2,
	sounds = {
		alter_child_pitch = true,
		random = {
			name = "animalia_horse_idle",
			gain = 1.0,
			distance = 8
		},
		hurt = {
			name = "animalia_horse_hurt",
			gain = 1.0,
			distance = 8
		},
		death = {
			name = "animalia_horse_death",
			gain = 1.0,
			distance = 8
		}
	},
	hitbox = {
		width = 0.65,
		height = 1.95
	},
	animations = {
		stand = {range = {x = 1, y = 59}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 89}, speed = 20, frame_blend = 0.3, loop = true},
		run = {range = {x = 101, y = 119}, speed = 40, frame_blend = 0.3, loop = true},
		punch_aoe = {range = {x = 170, y = 205}, speed = 30, frame_blend = 0.2, loop = false},
		rear = {range = {x = 130, y = 160}, speed = 20, frame_blend = 0.1, loop = false},
		eat = {range = {x = 210, y = 240}, speed = 30, frame_blend = 0.3, loop = false}
	},
	follow = animalia.food_wheat,
	drops = {
		{name = "animalia:leather", min = 1, max = 4, chance = 2}
	},
	fancy_collide = false,

	-- Behavior Parameters
	is_grazing_mob = true,
	is_herding_mob = true,

	-- Animalia Props
	catch_with_net = true,
	catch_with_lasso = true,
	consumable_nodes = {
		["default:dirt_with_grass"] = "default:dirt",
		["default:dry_dirt_with_dry_grass"] = "default:dry_dirt"
	},
	head_data = {
		bone = "Neck.CTRL",
		offset = {x = 0, y = 1.4, z = 0.0},
		pitch_correction = 15,
		pivot_h = 1,
		pivot_v = 1.75
	},
	utility_stack = {
		animalia.mob_ai.basic_wander,
		animalia.mob_ai.swim_seek_land,
		animalia.mob_ai.tamed_follow_owner,
		animalia.mob_ai.basic_breed,
		animalia.mob_ai.basic_flee,
		{
			utility = "animalia:horse_tame",
			get_score = function(self)
				local rider = not self.owner and self.rider
				if rider
				and rider:get_pos() then
					return 0.7, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:horse_ride",
			get_score = function(self)
				if not self.owner then return 0 end
				local owner = self.owner and minetest.get_player_by_name(self.owner)
				local rider = owner == self.rider and self.rider
				if rider
				and rider:get_pos() then
					return 0.8, {self, rider}
				end
				return 0
			end
		}
	},

	-- Functions
	set_saddle = function(self, saddle)
		if saddle then
			self.saddled = self:memorize("saddled", true)
			local texture = self.object:get_properties().textures[1]
			self.object:set_properties({
				textures = {texture .. "^animalia_horse_saddle.png"}
			})
			self.drops = {
				{name = "animalia:leather", chance = 2, min = 1, max = 4},
				{name = "animalia:saddle", chance = 1, min = 1, max = 1}
			}
		else
			local pos = self.object:get_pos()
			if not pos then return end
			self.saddled = self:memorize("saddled", false)
			set_pattern(self)
			self.drops = {
				{name = "animalia:leather", chance = 2, min = 1, max = 4}
			}
			minetest.add_item(pos, "animalia:saddle")
		end
	end,

	add_child = function(self, mate)
		local pos = self.object:get_pos()
		if not pos then return end
		local obj = minetest.add_entity(pos, self.name)
		local ent = obj and obj:get_luaentity()
		if not ent then return end
		ent.growth_scale = 0.7
		local tex_no = self.texture_no
		local mate_ent = mate and mate:get_luaentity()
		if mate_ent
		or not mate_ent.speed
		or not mate_ent.jump_power
		or not mate_ent.max_health then
			return
		end
		if random(2) < 2 then
			tex_no = mate_ent.texture_no
		end
		ent:memorize("texture_no", tex_no)
		ent:memorize("speed", random(mate_ent.speed, self.speed))
		ent:memorize("jump_power", random(mate_ent.jump_power, self.jump_power))
		ent:memorize("max_health", random(mate_ent.max_health, self.max_health))
		ent.speed = ent:recall("speed")
		ent.jump_power = ent:recall("jump_power")
		ent.max_health = ent:recall("max_health")
		animalia.initialize_api(ent)
		animalia.protect_from_despawn(ent)
	end,

	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
		set_pattern(self)

		self.owner = self:recall("owner") or nil

		if self.owner then
			self._inventory = self:recall("_inventory")
		end

		self.rider = nil
		self.saddled = self:recall("saddled") or false
		self.max_health = self:recall("max_health") or random(30, 45)
		self.speed = self:recall("speed") or random(5, 10)
		self.jump_power = self:recall("jump_power") or random(2, 5)
		self:memorize("max_health", self.max_health)
		self:memorize("speed", self.speed)
		self:memorize("jump_power", self.jump_power)
		if self.saddled then
			self:set_saddle(true)
		end
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
		animalia.random_sound(self)
	end,

	death_func = function(self)
		if self.rider then
			animalia.mount(self, self.rider)
		end
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
	end,

	on_rightclick = function(self, clicker)
		if animalia.feed(self, clicker, false, true) then
			return
		end

		local owner = self.owner
		local name = clicker and clicker:get_player_name()
		if owner and name ~= owner then return end

		if animalia.set_nametag(self, clicker) then
			return
		end

		local wielded_name = clicker:get_wielded_item():get_name()

		if wielded_name == "animalia:saddle" then
			self:set_saddle(true)
			return
		end

		if clicker:get_player_control().sneak
		and owner then
			minetest.show_formspec(name, "animalia:horse_forms", get_form(self, name))
			form_obj[name] = self.object
		elseif wielded_name == "" then
			animalia.mount(self, clicker, {rot = {x = -65, y = 180, z = 0}, pos = {x = 0, y = 0.75, z = 0.6}})
			if self.saddled then
				self:initiate_utility("animalia:mount", self, clicker)
			end
		end
	end,

	on_punch = function(self, puncher, ...)
		if self.rider and puncher == self.rider then return end
		local name = puncher:is_player() and puncher:get_player_name()
		if name
		and name == self.owner
		and puncher:get_player_control().sneak then
			self:set_saddle(false)
			return
		end
		animalia.punch(self, puncher, ...)
	end,

	on_detach_child = function(self, child)
		if child
		and self.rider == child then
			self.rider = nil
			child:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
			child:set_properties({visual_size = {x = 1, y = 1}})
			animalia.animate_player(child, "stand", 30)
		end
	end
})

creatura.register_spawn_item("animalia:horse", {
	col1 = "ebdfd8",
	col2 = "653818"
})
