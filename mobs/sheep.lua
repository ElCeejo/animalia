-----------
-- Sheep --
-----------

local random = math.random

local palette  = {
	black = {"Black", "#000000b0"},
	blue = {"Blue", "#015dbb70"},
	brown = {"Brown", "#663300a0"},
	cyan = {"Cyan", "#01ffd870"},
	dark_green = {"Dark Green", "#005b0770"},
	dark_grey = {"Dark Grey",  "#303030b0"},
	green = {"Green", "#61ff0170"},
	grey = {"Grey", "#5b5b5bb0"},
	magenta = {"Magenta", "#ff05bb70"},
	orange = {"Orange", "#ff840170"},
	pink = {"Pink", "#ff65b570"},
	red = {"Red", "#ff0000a0"},
	violet = {"Violet", "#2000c970"},
	white = {"White", "#ababab00"},
	yellow = {"Yellow", "#e3ff0070"},
}

creatura.register_mob("animalia:sheep", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_sheep.b3d",
	textures = {
		"animalia_sheep.png^animalia_sheep_wool.png"
	},
	child_textures = {
		"animalia_sheep.png"
	},
	makes_footstep_sound = true,

	-- Creatura Props
	max_health = 15,
	armor_groups = {fleshy = 100},
	damage = 0,
	speed = 3,
	tracking_range = 12,
	max_boids = 4,
	despawn_after = 500,
	stepheight = 1.1,
	sounds = {
		random = {
			name = "animalia_sheep",
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
	hitbox = {
		width = 0.4,
		height = 0.8
	},
	animations = {
		stand = {range = {x = 1, y = 59}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 89}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 100, y = 119}, speed = 40, frame_blend = 0.3, loop = true},
		eat = {range = {x = 130, y = 150}, speed = 20, frame_blend = 0.3, loop = false}
	},
	follow = animalia.food_wheat,
	drops = {
		{name = "animalia:mutton_raw", min = 1, max = 3, chance = 1},
		minetest.get_modpath("wool") and {name = "wool:white", min = 1, max = 3, chance = 2} or nil
	},

	-- Animalia Props
	group_wander = true,
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = true,
	consumable_nodes = {
		["default:dirt_with_grass"] = "default:dirt",
		["default:dry_dirt_with_dry_grass"] = "default:dry_dirt"
	},
	head_data = {
		offset = {x = 0, y = 0.41, z = 0},
		pitch_correction = -45,
		pivot_h = 0.75,
		pivot_v = 0.85
	},

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
		self.dye_color = self:recall("dye_color") or "white"
		if self.collected then
			self.object:set_properties({
				textures = {"animalia_sheep.png"},
			})
		elseif self.dye_color ~= "white" then
			self.object:set_properties({
				textures = {"animalia_sheep.png^(animalia_sheep_wool.png^[multiply:" .. palette[self.dye_color][2] .. ")"},
			})
		end
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
		animalia.random_sound(self)
	end,

	death_func = animalia.death_func,

	on_rightclick = function(self, clicker)
		if animalia.feed(self, clicker, false, true) then
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
		if self.collected
		or self.growth_scale < 1 then
			return
		end

		local tool = clicker:get_wielded_item()
		local tool_name = tool:get_name()
		local creative = minetest.is_creative_enabled(clicker)

		if tool_name == "animalia:shears" then
			if not minetest.get_modpath("wool") then
				return
			end

			minetest.add_item(
				self.object:get_pos(),
				ItemStack("wool:" .. self.dye_color .. " " .. random(1, 3))
			)

			self.collected = self:memorize("collected", true)
			self.dye_color = self:memorize("dye_color", "white")

			self.object:set_properties({
				textures = {"animalia_sheep.png"},
			})

			if not creative then
				tool:add_wear(650)
				clicker:set_wielded_item(tool)
			end
		end

		if tool_name:match("^dye:") then
			local dye_color = tool_name:split(":")[2]
			if palette[dye_color] then
				self.dye_color = self:memorize("dye_color", dye_color)
				self.drops = {
					{name = "animalia:mutton_raw", chance = 1, min = 1, max = 4},
					{name = "wool:" .. dye_color, chance = 2, min = 1, max = 2},
				}
				self.object:set_properties({
					textures = {"animalia_sheep.png^(animalia_sheep_wool.png^[multiply:" .. palette[dye_color][2] .. ")"},
				})
				if not creative then
					tool:take_item()
					clicker:set_wielded_item(tool)
				end
			end
		end
	end,

	on_punch = animalia.punch
})

creatura.register_spawn_item("animalia:sheep", {
	col1 = "f4e6cf",
	col2 = "e1ca9b"
})