----------
-- Mice --
----------

local vec_add, vec_sub = vector.add, vector.subtract

local function find_chest(self)
	local pos = self.object:get_pos()
	if not pos then return end

	local nodes = minetest.find_nodes_with_meta(vec_sub(pos, 6), vec_add(pos, 6)) or {}
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
	return pos2
end


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
					animalia.add_food_particle(self, item_name)
					return true
				end
			end
		end
	end
end

creatura.register_mob("animalia:rat", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_rat.b3d",
	textures = {
		"animalia_rat_1.png",
		"animalia_rat_2.png",
		"animalia_rat_3.png"
	},

	-- Creatura Props
	max_health = 5,
	damage = 0,
	speed = 1,
	tracking_range = 8,
	despawn_after = 200,
	stepheight = 1.1,
	--sound = {},
	hitbox = {
		width = 0.15,
		height = 0.3
	},
	animations = {
		stand = {range = {x = 1, y = 39}, speed = 20, frame_blend = 0.3, loop = true},
		walk = {range = {x = 51, y = 69}, speed = 20, frame_blend = 0.3, loop = true},
		run = {range = {x = 81, y = 99}, speed = 45, frame_blend = 0.3, loop = true},
		eat = {range = {x = 111, y = 119}, speed = 20, frame_blend = 0.1, loop = false}
	},
	drops = {
		{name = "animalia:rat_raw", min = 1, max = 1, chance = 1}
	},

	-- Animalia Props
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = false,

	-- Functions
	utility_stack = {
		{
			utility = "animalia:wander",
			step_delay = 0.25,
			get_score = function(self)
				return 0.1, {self}
			end
		},
		{
			utility = "animalia:swim_to_land",
			step_delay = 0.25,
			get_score = function(self)
				if self.in_liquid then
					return 0.3, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:walk_to_pos_and_interact",
			get_score = function(self)
				-- Eat Crops
				if math.random(6) < 2
				or self:get_utility() == "animalia:walk_to_pos_and_interact" then
					return 0.2, {self, animalia.find_crop, animalia.eat_crop, "eat"}
				end
				-- Steal From Chest
				if math.random(12) < 2
				or self:get_utility() == "animalia:walk_to_pos_and_interact" then
					return 0.3, {self, find_chest, take_food_from_chest, "eat"}
				end
				return 0
			end
		},
		{
			utility = "animalia:flee_from_target",
			get_score = function(self)
				local target = creatura.get_nearby_object(self, {"animalia:fox", "animalia:cat"})
				if not target then
					target = creatura.get_nearby_player(self)
				end
				if target
				and target:get_pos() then
					return 0.6, {self, target}
				end
				return 0
			end
		}
	},

	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.do_growth(self, 60)
	end,

	death_func = function(self)
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
	end,

	on_rightclick = function(self, clicker)
		if animalia.set_nametag(self, clicker) then
			return
		end
	end,

	on_punch = animalia.punch
})

creatura.register_spawn_item("animalia:rat", {
	col1 = "605a55",
	col2 = "ff936f"
})