-------------
-- Chicken --
-------------

local follows = {}

minetest.register_on_mods_loaded(function()
    for name, def in pairs(minetest.registered_items) do
        if name:match(":seed_")
		or name:match("_seed") then
			table.insert(follows, name)
        end
    end
end)

creatura.register_mob("animalia:chicken", {
    -- Stats
    max_health = 5,
    armor_groups = {fleshy = 150},
    damage = 0,
    speed = 4,
	tracking_range = 16,
    despawn_after = 1500,
	-- Entity Physics
	stepheight = 1.1,
	max_fall = 8,
	turn_rate = 7,
    -- Visuals
    mesh = "animalia_chicken.b3d",
	hitbox = {
		width = 0.15,
		height = 0.3
	},
    visual_size = {x = 7, y = 7},
	female_textures = {
		"animalia_chicken_1.png",
		"animalia_chicken_2.png",
		"animalia_chicken_3.png"
	},
	male_textures = {
		"animalia_rooster_1.png",
		"animalia_rooster_2.png",
		"animalia_rooster_3.png"
	},
	child_textures = {"animalia_chick.png"},
    animations = {
		stand = {range = {x = 0, y = 0}, speed = 1, frame_blend = 0.3, loop = true},
		walk = {range = {x = 10, y = 30}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 10, y = 30}, speed = 45, frame_blend = 0.3, loop = true},
        fall = {range = {x = 40, y = 60}, speed = 70, frame_blend = 0.3, loop = true},
	},
    -- Misc
	catch_with_net = true,
	catch_with_lasso = true,
    sounds = {
        random = {
            name = "animalia_chicken_idle",
            gain = 0.5,
            distance = 8
        },
        hurt = {
            name = "animalia_chicken_hurt",
            gain = 0.5,
            distance = 8
        },
        death = {
            name = "animalia_chicken_death",
            gain = 0.5,
            distance = 8
        }
    },
    drops = {
        {name = "animalia:poultry_raw", min = 1, max = 3, chance = 1},
		{name = "animalia:feather", min = 1, max = 3, chance = 2}
    },
    follow = follows,
	head_data = {
		offset = {x = 0, y = 0.15, z = 0},
		pitch_correction = 55,
		pivot_h = 0.25,
		pivot_v = 0.55
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
			utility = "animalia:resist_fall",
			get_score = function(self)
				if not self.touching_ground then
					return 0.11, {self}
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
			utility = "animalia:bird_breed",
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
		animalia.add_libri_page(self, clicker, {name = "chicken", form = "pg_chicken;Chickens"})
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		self:initiate_utility("animalia:flee_from_player", self, puncher)
		self:set_utility_score(1)
	end
})

creatura.register_spawn_egg("animalia:chicken", "c6c6c6", "d22222")