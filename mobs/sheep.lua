-----------
-- Sheep --
-----------

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

local clamp_bone_rot = animalia.clamp_bone_rot

local interp = animalia.interp

local min = math.min
local abs = math.abs
local random = math.random

local function sheep_logic(self)

	if self.hp <= 0 then
		mob_core.on_die(self)
		return
	end

	if self.status ~= "following" then
		if self.attention_span > 1 then
			self.attention_span = self.attention_span - self.dtime
			mobkit.remember(self, "attention_span", self.attention_span)
		end
	else
		self.attention_span = self.attention_span + self.dtime
		mobkit.remember(self, "attention_span", self.attention_span)
	end

	animalia.head_tracking(self, 0.5, 0.5)

	if mobkit.timer(self, 3) then 

		local pos = mobkit.get_stand_pos(self)
		local prty = mobkit.get_queue_priority(self)
		local player = mobkit.get_nearby_player(self)

		mob_core.random_sound(self, 14)
		mob_core.growth(self)

		if prty < 5
		and self.isinliquid then
			animalia.hq_go_to_land(self, 5)
		end

		if prty < 4
        and self.breeding then
            animalia.hq_breed(self, 4)
		end

		if prty < 3
		and self.gotten
		and math.random(1, 16) == 1 then
			animalia.hq_eat(self, 3)
		end

		if prty == 2
		and not self.lasso_player
		and (not player
		or not mob_core.follow_holding(self, player)) then
			mobkit.clear_queue_high(self)
		end

        if prty < 2 then
			if self.caught_with_lasso
			and self.lasso_player then
				animalia.hq_follow_player(self, 2, self.lasso_player, true)
			elseif player then
	        	if self.attention_span < 5 then
				    if mob_core.follow_holding(self, player) then
            	        animalia.hq_follow_player(self, 2, player)
            	        self.attention_span = self.attention_span + 3
            	    end
            	end
			end
        end

		if mobkit.is_queue_empty_high(self) then
			animalia.hq_wander_group(self, 0, 12)
		end
	end
end

animalia.register_mob("sheep", {
    -- Stats
    health = 20,
    fleshy = 100,
    view_range = 32,
    lung_capacity = 10,
    -- Visual
	collisionbox = {-0.4, 0, -0.4, 0.4, 0.8, 0.4},
	visual_size = {x = 10, y = 10},
	mesh = "animalia_sheep.b3d",
	textures = {"animalia_sheep.png^animalia_sheep_wool.png"},
	child_textures = {"animalia_sheep.png"},
	animations = {
		stand = {range = {x = 1, y = 60}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 110}, speed = 40, frame_blend = 0.3, loop = true},
		run = {range = {x = 70, y = 110}, speed = 50, frame_blend = 0.3, loop = true},
	},
    -- Physics
    speed = 4,
    max_fall = 3,
    -- Attributes
    sounds = {
        alter_child_pitch = true,
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
    -- Behavior
    defend_owner = false,
	follow = {
		"farming:wheat",
	},
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
	drops = {
		{name = "animalia:mutton_raw", chance = 1, min = 1, max = 4}
	},
    -- Functions
	head_data = {
		offset = {x = 0, y = 0.41, z = 0},
		pitch_correction = -45,
		pivot_h = 0.75,
		pivot_v = 0.85
	},
    logic = sheep_logic,
    get_staticdata = mobkit.statfunc,
	on_step = function(self, dtime, moveresult)
		animalia.on_step(self, dtime, moveresult)
		if mobkit.is_alive(self) then
			if self.object:get_properties().textures[1] == "animalia_sheep.png"
			and not self.gotten then
				self.object:set_properties({
					textures = {"animalia_sheep.png^animalia_sheep_wool.png"},
				})
			end
		end
	end,
	on_activate = function(self, staticdata, dtime_s)
		animalia.on_activate(self, staticdata, dtime_s)
		self.dye_color = mobkit.recall(self, "dye_color") or "white"
		self.dye_hex = mobkit.recall(self, "dye_hex") or ""
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
	end,
	on_rightclick = function(self, clicker)
		if animalia.feed_tame(self, clicker, 1, false, true) then return end
		mob_core.protect(self, clicker, true)
		mob_core.nametag(self, clicker, true)
		local item = clicker:get_wielded_item()
		local itemname = item:get_name()
		local name = clicker:get_player_name()
		if itemname == "animalia:shears"
		and not self.gotten
		and not self.child then
			if not minetest.get_modpath("wool") then
				return
			end

			local obj = minetest.add_item(
				self.object:get_pos(),
				ItemStack( "wool:" .. self.dye_color .. " " .. math.random(1, 3) )
			)

			self.gotten = mobkit.remember(self, "gotten", true)
			self.dye_color = mobkit.remember(self, "dye_color", "white")
			self.dye_hex = mobkit.remember(self, "dye_hex",  "#abababc000")

			item:add_wear(650) -- 100 uses

			clicker:set_wielded_item(item)

			self.object:set_properties({
				textures = {"animalia_sheep.png"},
			})
		end
		for _, color in ipairs(palette) do
			if itemname:find("dye:")
			and not self.gotten
			and not self.child then
				local dye = string.split(itemname, ":")[2]
				if color[1] == dye then

					self.dye_color = mobkit.remember(self, "dye_color", color[1])
					self.dye_hex = mobkit.remember(self, "dye_hex", color[3])

					self.drops = {
						{name = "animalia:mutton_raw", chance = 1, min = 1, max = 4},
						{name = "wool:"..self.dye_color, chance = 2, min = 1, max = 2},
					}

					self.object:set_properties({
						textures = {"animalia_sheep.png^(animalia_sheep_wool.png^[colorize:" .. color[3] .. ")"},
					})

					if not creative then
						item:take_item()
						clicker:set_wielded_item(item)
					end
					break
				end
			end
		end
	end,
	on_punch = function(self, puncher, _, tool_capabilities, dir)
		mob_core.on_punch_basic(self, puncher, tool_capabilities, dir)
		animalia.hq_sporadic_flee(self, 10)
	end
})

mob_core.register_spawn_egg("animalia:sheep", "f4e6cf", "e1ca9b")

minetest.register_craftitem("animalia:mutton_raw", {
	description = "Raw Mutton",
	inventory_image = "animalia_mutton_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:mutton_cooked", {
	description = "Cooked Mutton",
	inventory_image = "animalia_mutton_cooked.png",
	on_use = minetest.item_eat(6),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:mutton_raw",
	output = "animalia:mutton_cooked",
})