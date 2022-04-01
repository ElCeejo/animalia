---------
-- Cow --
---------

local follows = {}

minetest.register_on_mods_loaded(function()
    for name, def in pairs(minetest.registered_items) do
        if (name:match(":wheat")
		or minetest.get_item_group(name, "food_wheat") > 0)
		and not name:find("seed") then
			table.insert(follows, name)
        end
    end
end)

creatura.register_mob("animalia:cow", {
    -- Stats
    max_health = 20,
    armor_groups = {fleshy = 150},
    damage = 0,
    speed = 3,
	tracking_range = 16,
    despawn_after = 1500,
	-- Entity Physics
	stepheight = 1.1,
	turn_rate = 6,
    -- Visuals
    mesh = "animalia_cow.b3d",
	hitbox = {
		width = 0.45,
		height = 0.9
	},
    visual_size = {x = 10, y = 10},
	female_textures = {
		"animalia_cow_1.png^animalia_cow_udder.png",
		"animalia_cow_2.png^animalia_cow_udder.png",
		"animalia_cow_3.png^animalia_cow_udder.png",
		"animalia_cow_4.png^animalia_cow_udder.png"
	},
	male_textures = {
		"animalia_cow_1.png",
		"animalia_cow_2.png",
		"animalia_cow_3.png",
		"animalia_cow_4.png"
	},
	child_textures = {
		"animalia_cow_1.png",
		"animalia_cow_2.png",
		"animalia_cow_3.png",
		"animalia_cow_4.png"
	},
	animations = {
		stand = {range = {x = 1, y = 60}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 110}, speed = 40, frame_blend = 0.3, loop = true},
		run = {range = {x = 70, y = 110}, speed = 60, frame_blend = 0.3, loop = true},
	},
    -- Misc
	catch_with_net = true,
	catch_with_lasso = true,
	sounds = {
        random = {
            name = "animalia_cow_random",
            gain = 0.4,
            distance = 8,
			variations = 3
        },
        hurt = {
            name = "animalia_cow_hurt",
            gain = 0.4,
            distance = 8
        },
        death = {
            name = "animalia_cow_death",
            gain = 0.4,
            distance = 8
        }
    },
    drops = {
        {name = "animalia:beef_raw", min = 1, max = 3, chance = 1},
		{name = "animalia:leather", min = 1, max = 3, chance = 2}
    },
    follow = follows,
	consumable_nodes = {
		{
			name = "default:dirt_with_grass",
			replacement = "default:dirt"
		},
		{
			name = "default:dry_dirt_with_dry_grass",
			replacement = "default:dry_dirt"
		}
	},
	head_data = {
		offset = {x = 0, y = 0.5, z = 0},
		pitch_correction = -45,
		pivot_h = 0.75,
		pivot_v = 1
	},
    -- Function
	utility_stack = {
		[1] = {
			utility = "animalia:wander",
			get_score = function(self)
				return 0.1, {self, true}
			end
		},
		[2] = {
			utility = "animalia:eat_from_turf",
			get_score = function(self)
				if math.random(25) < 2 then
					return 0.1, {self}
				end
				return 0
			end
		},
		[3] = {
			utility = "animalia:swim_to_land",
			get_score = function(self)
				if self.in_liquid then
					return 1, {self}
				end
				return 0
			end
		},
		[4] = {
			utility = "animalia:follow_player",
			get_score = function(self)
				if self.lasso_origin
				and type(self.lasso_origin) == "userdata" then
					return 0.8, {self, self.lasso_origin, true}
				end
				local player = creatura.get_nearby_player(self)
				if player
				and self:follow_wielded_item(player) then
					return 0.8, {self, player}
				end
				return 0
			end
		},
		[5] = {
			utility = "animalia:mammal_breed",
			get_score = function(self)
				if self.breeding
				and animalia.get_nearby_mate(self, self.name) then
					return 0.9, {self}
				end
				return 0
			end
		}
	},
    activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
        self.gotten = self:recall("gotten") or false
    end,
    step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self, 0.75, 0.75)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
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
		local tool = clicker:get_wielded_item()
		local name = clicker:get_player_name()

		if tool:get_name() == "bucket:bucket_empty" then

			if self.growth_scale < 1 then
				return
			end

			if self.gotten then
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

			self.gotten = self:memorize("gotten", true)
			return
		end
		animalia.add_libri_page(self, clicker, {name = "cow", form = "pg_cow;Cows"})
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		self:initiate_utility("animalia:flee_from_player", self, puncher)
		self:set_utility_score(1)
	end
})

creatura.register_spawn_egg("animalia:cow", "cac3a1" ,"464438")