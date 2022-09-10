---------
-- Cow --
---------

local random = math.random

local follows = {}

minetest.register_on_mods_loaded(function()
    for name in pairs(minetest.registered_items) do
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
		width = 0.65,
		height = 1.5
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
		stand = {range = {x = 1, y = 59}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 61, y = 79}, speed = 20, frame_blend = 0.3, loop = true},
		run = {range = {x = 61, y = 79}, speed = 30, frame_blend = 0.3, loop = true},
	},
    -- Misc
	step_delay = 0.25,
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
		["default:dirt_with_grass"] = "default:dirt",
		["default:dry_dirt_with_dry_grass"] = "default:dry_dirt",
		["hades_core:dirt_with_grass"] = "hades_core:dirt_with_grass_l3",
		["hades_core:dirt_with_grass_l3"] = "hades_core:dirt_with_grass_l1",
	},
	head_data = {
		offset = {x = 0, y = 0.7, z = 0.0},
		pitch_correction = -65,
		pivot_h = 0.75,
		pivot_v = 1
	},
    -- Function
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
		{
			utility = "animalia:follow_player",
			get_score = function(self)
				local lasso = type(self.lasso_origin or {}) == "userdata" and self.lasso_origin
				local force = lasso and lasso ~= false
				local player = (force and lasso) or creatura.get_nearby_player(self)
				if player
				and self:follow_wielded_item(player) then
					return 0.4, {self, player}
				end
				return 0
			end
		},
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
		{
			utility = "animalia:flee_from_target",
			get_score = function(self)
				local puncher = self._target
				if puncher
				and puncher:get_pos() then
					return 0.6, {self, puncher}
				end
				self._target = nil
				return 0
			end
		}
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
		animalia.add_libri_page(self, clicker, {name = "cow", form = "pg_cow;Cows"})
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		self._target = puncher
	end
})

creatura.register_spawn_egg("animalia:cow", "cac3a1" ,"464438")
