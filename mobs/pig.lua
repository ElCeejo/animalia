---------
-- Pig --
---------

local follows = {}

minetest.register_on_mods_loaded(function()
	for name in pairs(minetest.registered_items) do
		if name:match(":carrot")
		and (minetest.get_item_group(name, "food") > 0
		or minetest.get_item_group(name, "food_carrot") > 0) then
			table.insert(follows, name)
		end
	end
end)

local destroyable_crops = {}

minetest.register_on_mods_loaded(function()
	for name in pairs(minetest.registered_nodes) do
		if name:match("^crops:")
		or name:match("^farming:") then
			table.insert(destroyable_crops, {name = name, replacement = "air"})
		end
	end
end)

creatura.register_mob("animalia:pig", {
	-- Stats
	max_health = 10,
	armor_groups = {fleshy = 100},
	damage = 0,
	speed = 3,
	tracking_range = 16,
	despawn_after = 1500,
	-- Entity Physics
	stepheight = 1.1,
	turn_rate = 6,
	-- Visuals
	mesh = "animalia_pig.b3d",
	hitbox = {
		width = 0.35,
		height = 0.7
	},
	visual_size = {x = 10, y = 10},
	female_textures = {
		"animalia_pig_1.png",
		"animalia_pig_2.png",
		"animalia_pig_3.png"
	},
	male_textures = {
		"animalia_pig_1.png^animalia_pig_tusks.png",
		"animalia_pig_2.png^animalia_pig_tusks.png",
		"animalia_pig_3.png^animalia_pig_tusks.png"
	},
	child_textures = {
		"animalia_pig_1.png",
		"animalia_pig_2.png",
		"animalia_pig_3.png"
	},
	animations = {
		stand = {range = {x = 30, y = 50}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 1, y = 20}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 1, y = 20}, speed = 45, frame_blend = 0.3, loop = true},
	},
	-- Misc
	makes_footstep_sound = true,
	consumable_nodes = destroyable_crops,
	birth_count = 2,
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = true,
	sounds = {
		random = {
			name = "animalia_pig_random",
			gain = 1.0,
			distance = 8
		},
		hurt = {
			name = "animalia_pig_hurt",
			gain = 1.0,
			distance = 8
		},
		death = {
			name = "animalia_pig_death",
			gain = 1.0,
			distance = 8
		}
	},
	drops = {
		{name = "animalia:porkchop_raw", min = 1, max = 3, chance = 1}
	},
	follow = follows,
	-- Function
	utility_stack = {
		{
			utility = "animalia:wander",
			step_delay = 0.25,
			get_score = function(self)
				return 0.1, {self, true}
			end
		},
		{
			utility = "animalia:eat_from_turf",
			step_delay = 0.25,
			get_score = function(self)
				if math.random(25) < 2 then
					return 0.2, {self}
				end
				return 0
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
		animalia.global_utils.basic_follow,
		{
			utility = "animalia:breed",
			step_delay = 0.25,
			get_score = function(self)
				if self.breeding
				and animalia.get_nearby_mate(self, self.name) then
					return 0.5, {self}
				end
				return 0
			end
		},
		animalia.global_utils.basic_flee
	},
	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
	end,
	step_func = function(self)
		animalia.step_timers(self)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
		animalia.random_sound(self)
	end,
	death_func = function(self)
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
	end,
	on_rightclick = function(self, clicker)
		if animalia.feed(self, clicker, false, true) then
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
	end,
	on_punch = animalia.punch
})

creatura.register_spawn_egg("animalia:pig", "e0b1a7" ,"cc9485")