-----------
-- Sheep --
-----------

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

local wool_block = "wool:wool"

if not minetest.get_modpath("wool") then
	wool_block = nil
end

local creative = minetest.settings:get_bool("creative_mode")

local palette  = {
	{"black",      "Black",      "#000000b0"},
	{"blue",       "Blue",       "#015dbb70"},
	{"brown",      "Brown",      "#663300a0"},
	{"cyan",       "Cyan",       "#01ffd870"},
	{"dark_green", "Dark Green", "#005b0770"},
	{"dark_grey",  "Dark Grey",  "#303030b0"},
	{"green",      "Green",      "#61ff0170"},
	{"grey",       "Grey",       "#5b5b5bb0"},
	{"magenta",    "Magenta",    "#ff05bb70"},
	{"orange",     "Orange",     "#ff840170"},
	{"pink",       "Pink",       "#ff65b570"},
	{"red",        "Red",        "#ff0000a0"},
	{"violet",     "Violet",     "#2000c970"},
	{"white",      "White",      "#ababab00"},
	{"yellow",     "Yellow",     "#e3ff0070"},
}

creatura.register_mob("animalia:sheep", {
    -- Stats
    max_health = 15,
    armor_groups = {fleshy = 125},
    damage = 0,
    speed = 3,
	tracking_range = 16,
    despawn_after = 1500,
	-- Entity Physics
	stepheight = 1.1,
    -- Visuals
    mesh = "animalia_sheep.b3d",
	hitbox = {
		width = 0.4,
		height = 0.8
	},
	visual_size = {x = 10, y = 10},
	textures = {
		"animalia_sheep.png^animalia_sheep_wool.png"
	},
	child_textures = {
		"animalia_sheep.png"
	},
	animations = {
		stand = {range = {x = 1, y = 60}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 110}, speed = 40, frame_blend = 0.3, loop = true},
		run = {range = {x = 70, y = 110}, speed = 50, frame_blend = 0.3, loop = true},
	},
    -- Misc
	catch_with_net = true,
	catch_with_lasso = true,
	sounds = {
        random = {
            name = "animalia_sheep_idle",
            gain = 1.0,
            distance = 8
        },
        hurt = {
            name = "animalia_sheep_hurt",
			gain = 1.0,
            distance = 8
        },
        death = {
            name = "animalia_sheep_death",
			gain = 1.0,
            distance = 8
        }
    },
    drops = {
        {name = "animalia:mutton_raw", min = 1, max = 3, chance = 1},
		{name = wool_block, min = 1, max = 3, chance = 2}
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
		offset = {x = 0, y = 0.41, z = 0},
		pitch_correction = -45,
		pivot_h = 0.75,
		pivot_v = 0.85
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
        self.gotten = self:recall("gotten") or false
		self.dye_color = self:recall("dye_color") or "white"
		self.dye_hex = self:recall("dye_hex") or ""
		if self.dye_color ~= "white"
		and not self.gotten then
			self.object:set_properties({
				textures = {"animalia_sheep.png^(animalia_sheep_wool.png^[colorize:" .. self.dye_hex .. ")"},
			})
		end
		if self.gotten then
			self.object:set_properties({
				textures = {"animalia_sheep.png"},
			})
		end
        self.attention_span = 8
        self._path = {}
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
		local tool = clicker:get_wielded_item()
		local tool_name = tool:get_name()
		if tool_name == "animalia:shears"
		and not self.gotten
		and self.growth_scale > 0.9 then
			if not minetest.get_modpath("wool") then
				return
			end

			minetest.add_item(
				self.object:get_pos(),
				ItemStack( "wool:" .. self.dye_color .. " " .. math.random(1, 3) )
			)

			self.gotten = self:memorize("gotten", true)
			self.dye_color = self:memorize("dye_color", "white")
			self.dye_hex = self:memorize("dye_hex",  "#abababc000")

			tool:add_wear(650) -- 100 uses

			clicker:set_wielded_item(tool)

			self.object:set_properties({
				textures = {"animalia_sheep.png"},
			})
		end
		for _, color in ipairs(palette) do
			if tool_name:find("dye:")
			and not self.gotten
			and self.growth_scale > 0.9 then
				local dye = string.split(tool_name, ":")[2]
				if color[1] == dye then

					self.dye_color = self:memorize("dye_color", color[1])
					self.dye_hex = self:memorize("dye_hex", color[3])

					self.drops = {
						{name = "animalia:mutton_raw", chance = 1, min = 1, max = 4},
						{name = "wool:"..self.dye_color, chance = 2, min = 1, max = 2},
					}

					self.object:set_properties({
						textures = {"animalia_sheep.png^(animalia_sheep_wool.png^[colorize:" .. color[3] .. ")"},
					})

					if not creative then
						tool:take_item()
						clicker:set_wielded_item(tool)
					end
					break
				end
			end
		end
		animalia.add_libri_page(self, clicker, {name = "sheep", form = "pg_sheep;Sheep"})
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		self:initiate_utility("animalia:boid_flee_from_player", self, puncher, true)
		self:set_utility_score(1)
	end
})

creatura.register_spawn_egg("animalia:sheep", "f4e6cf", "e1ca9b")