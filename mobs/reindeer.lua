--------------
-- Reindeer --
--------------

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

local random = math.random

creatura.register_mob("animalia:reindeer", {
    -- Stats
    max_health = 20,
    armor_groups = {fleshy = 125},
    damage = 0,
    speed = 3,
	boid_seperation = 1,
	tracking_range = 16,
    despawn_after = 1500,
	-- Entity Physics
	stepheight = 1.1,
	turn_rate = 4,
    -- Visuals
    mesh = "animalia_reindeer.b3d",
	hitbox = {
		width = 0.45,
		height = 0.9
	},
    visual_size = {x = 10, y = 10},
	textures = {"animalia_reindeer.png"},
	child_textures = {"animalia_reindeer_calf.png"},
	animations = {
		stand = {range = {x = 1, y = 60}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 110}, speed = 40, frame_blend = 0.3, loop = true},
		run = {range = {x = 70, y = 110}, speed = 50, frame_blend = 0.3, loop = true},
	},
    -- Misc
	catch_with_net = true,
	catch_with_lasso = true,
    drops = {
        {name = "animalia:venison_raw", min = 1, max = 3, chance = 1},
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
		offset = {x = 0, y = 0.7, z = 0},
		pitch_correction = -45,
		pivot_h = 1,
		pivot_v = 1
	},
    -- Function
	utility_stack = {
		[1] = {
			utility = "animalia:boid_wander",
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
		animalia.add_libri_page(self, clicker, {name = "reindeer", form = "pg_reindeer;Reindeer"})
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		self:initiate_utility("animalia:boid_flee_from_player", self, puncher, true)
		self:set_utility_score(1)
	end
})

creatura.register_spawn_egg("animalia:reindeer", "cac3a1" ,"464438")