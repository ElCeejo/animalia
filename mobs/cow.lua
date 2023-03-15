---------
-- Cow --
---------

local random = math.random


creatura.register_mob("animalia:cow", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_cow.b3d",
	female_textures = {
		"animalia_cow_1.png^animalia_cow_udder.png",
		"animalia_cow_2.png^animalia_cow_udder.png",
		"animalia_cow_3.png^animalia_cow_udder.png",
		"animalia_cow_4.png^animalia_cow_udder.png",
		"animalia_cow_5.png^animalia_cow_udder.png"
	},
	male_textures = {
		"animalia_cow_1.png",
		"animalia_cow_2.png",
		"animalia_cow_3.png",
		"animalia_cow_4.png",
		"animalia_cow_5.png"
	},
	child_textures = {
		"animalia_cow_1.png",
		"animalia_cow_2.png",
		"animalia_cow_3.png",
		"animalia_cow_4.png",
		"animalia_cow_5.png"
	},
	makes_footstep_sound = true,

	-- Creatura Props
	max_health = 20,
	armor_groups = {fleshy = 100},
	damage = 0,
	speed = 2,
	tracking_range = 10,
	max_boids = 0,
	despawn_after = 500,
	max_fall = 3,
	stepheight = 1.1,
	sounds = {
		random = {
			name = "animalia_cow",
			gain = 0.5,
			distance = 8
		},
		hurt = {
			name = "animalia_cow_hurt",
			gain = 0.5,
			distance = 8
		},
		death = {
			name = "animalia_cow_death",
			gain = 0.5,
			distance = 8
		}
	},
	hitbox = {
		width = 0.5,
		height = 1
	},
	animations = {
		stand = {range = {x = 1, y = 59}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 71, y = 89}, speed = 20, frame_blend = 0.3, loop = true},
		run = {range = {x = 71, y = 89}, speed = 30, frame_blend = 0.3, loop = true},
	},
	follow = animalia.food_wheat,
	drops = {
		{name = "animalia:beef_raw", min = 1, max = 3, chance = 1},
		{name = "animalia:leather", min = 1, max = 3, chance = 2}
	},
	fancy_collide = false,

	-- Animalia Props
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = true,
	consumable_nodes = {
		["default:dirt_with_grass"] = "default:dirt",
		["default:dry_dirt_with_dry_grass"] = "default:dry_dirt"
	},
	head_data = {
		offset = {x = 0, y = 0.5, z = 0.0},
		pitch_correction = -40,
		pivot_h = 0.75,
		pivot_v = 1
	},
	wander_action = animalia.action_boid_move,

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
			utility = "animalia:eat_turf",
			step_delay = 0.25,
			get_score = function(self)
				if random(64) < 2 then
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
		self.collected = self:recall("collected") or false
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self, 0.75, 0.75)
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
		if animalia.feed(self, clicker, false, true)
		or animalia.set_nametag(self, clicker) then
			return
		end

		local tool = clicker:get_wielded_item()
		local name = clicker:get_player_name()

		if tool:get_name() == "bucket:bucket_empty" then

			if self.growth_scale < 1 then
				return
			end

			if self.collected then
				minetest.chat_send_player(name, "This Cow has already been milked.")
				return
			end

			local inv = clicker:get_inventory()

			tool:take_item()
			clicker:set_wielded_item(tool)

			if inv:room_for_item("main", {name = "animalia:bucket_milk"}) then
				clicker:get_inventory():add_item("main", "animalia:bucket_milk")
			else
				local pos = self:get_pos("floor")
				pos.y = pos.y + 0.5
				minetest.add_item(pos, {name = "animalia:bucket_milk"})
			end

			self.collected = self:memorize("collected", true)
			return
		end
	end,

	on_punch = animalia.punch
})

creatura.register_spawn_item("animalia:cow", {
	col1 = "cac3a1",
	col2 = "464438"
})
