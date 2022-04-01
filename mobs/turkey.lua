------------
-- Turkey --
------------

local follows = {}

minetest.register_on_mods_loaded(function()
    for name, def in pairs(minetest.registered_items) do
        if name:match(":seed_")
		or name:match("_seed") then
			table.insert(follows, name)
        end
    end
end)

creatura.register_mob("animalia:turkey", {
    -- Stats
    max_health = 10,
    armor_groups = {fleshy = 150},
    damage = 0,
    speed = 4,
	tracking_range = 16,
    despawn_after = 1500,
	-- Entity Physics
	stepheight = 1.1,
	max_fall = 8,
    -- Visuals
    mesh = "animalia_turkey.b3d",
	hitbox = {
		width = 0.3,
		height = 0.6
	},
    visual_size = {x = 7, y = 7},
	female_textures = {"animalia_turkey_hen.png"},
	male_textures = {"animalia_turkey_tom.png"},
	child_textures = {"animalia_turkey_chick.png"},
    animations = {
		stand = {range = {x = 0, y = 0}, speed = 1, frame_blend = 0.3, loop = true},
		walk = {range = {x = 10, y = 30}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 40, y = 60}, speed = 45, frame_blend = 0.3, loop = true},
        fall = {range = {x = 70, y = 90}, speed = 30, frame_blend = 0.3, loop = true},
	},
    -- Misc
	catch_with_net = true,
	catch_with_lasso = true,
    sounds = {
        random = {
            name = "animalia_turkey_idle",
            gain = 1.0,
            distance = 8
        },
        hurt = {
            name = "animalia_turkey_hurt",
            gain = 1.0,
            distance = 8
        },
        death = {
            name = "animalia_turkey_death",
            gain = 1.0,
            distance = 8
        }
    },
    drops = {
        {name = "animalia:poultry_raw", min = 2, max = 4, chance = 1},
		{name = "animalia:feather", min = 2, max = 4, chance = 2}
    },
    follow = follows,
	head_data = {
		offset = {x = 0, y = 0.15, z = 0},
		pitch_correction = 45,
		pivot_h = 0.45,
		pivot_v = 0.65
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
		animalia.add_libri_page(self, clicker, {name = "turkey", form = "pg_turkey;Turkeys"})
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		self:initiate_utility("animalia:flee_from_player", self, puncher)
		self:set_utility_score(1)
	end
})

creatura.register_spawn_egg("animalia:turkey", "352b22", "2f2721")