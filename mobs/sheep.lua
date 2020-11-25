-----------
-- Sheep --
-----------

local blend = better_fauna.frame_blend

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

local min = math.min
local abs = math.abs
local random = math.random

local function sheep_logic(self)

	if self.hp <= 0 then
		mob_core.on_die(self)
		return
	end

	local pos = mobkit.get_stand_pos(self)
	local prty = mobkit.get_queue_priority(self)
	local player = mobkit.get_nearby_player(self)

	mob_core.random_sound(self, 16/self.dtime)

	if mobkit.timer(self,1) then 

		mob_core.vitals(self)
		mob_core.growth(self)

		if self.status ~= "following" then
            if self.attention_span > 1 then
                self.attention_span = self.attention_span - 1
                mobkit.remember(self, "attention_span", self.attention_span)
            end
		else
			self.attention_span = self.attention_span + 1
			mobkit.remember(self, "attention_span", self.attention_span)
		end

		if prty < 4
        and self.breeding then
            better_fauna.hq_breed(self, 4)
		end

		if prty < 3
		and self.gotten
		and math.random(1, 16) == 1 then
			better_fauna.hq_eat(self, 3)
		end
		
        if prty < 2
        and player then
            if self.attention_span < 5 then
                if mob_core.follow_holding(self, player) then
                    better_fauna.hq_follow_player(self, 2, player)
                    self.attention_span = self.attention_span + 1
                end
            end
        end

		if mobkit.is_queue_empty_high(self) then
			mob_core.hq_roam(self, 0)
		end
	end
end

minetest.register_entity("better_fauna:sheep",{
	max_hp = 20,
	view_range = 16,
	armor_groups = {fleshy = 100},
	physical = true,
	collide_with_objects = true,
	collisionbox = {-0.4, -0.4, -0.4, 0.4, 0.4, 0.4},
	visual_size = {x = 10, y = 10},
	scale_stage1 = 0.5,
    scale_stage2 = 0.65,
    scale_stage3 = 0.80,
	visual = "mesh",
	mesh = "better_fauna_sheep.b3d",
	textures = {"better_fauna_sheep.png^better_fauna_sheep_wool.png"},
	child_textures = {"better_fauna_sheep.png"},
	animation = {
		stand = {range = {x = 30, y = 50}, speed = 10, frame_blend = blend, loop = true},
		walk = {range = {x = 1, y = 20}, speed = 30, frame_blend = blend, loop = true},
		run = {range = {x = 1, y = 20}, speed = 45, frame_blend = blend, loop = true},
	},
    sounds = {
        alter_child_pitch = true,
        random = {
            name = "better_fauna_sheep_idle",
            gain = 1.0,
            distance = 8
        },
        hurt = {
            name = "better_fauna_sheep_idle",
			gain = 1.0,
			pitch = 0.5,
            distance = 8
        },
        death = {
            name = "better_fauna_sheep_idle",
			gain = 1.0,
			pitch = 0.25,
            distance = 8
        }
    },
	max_speed = 4,
	stepheight = 1.1,
	jump_height = 1.1,
	buoyancy = 0.25,
	lung_capacity = 10,
    timeout = 1200,
    ignore_liquidflag = false,
    core_growth = false,
	push_on_collide = true,
	catch_with_net = true,
	follow = {
		"farming:wheat"
	},
	drops = {
		{name = "better_fauna:mutton_raw", chance = 1, min = 1, max = 4}
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
	get_staticdata = mobkit.statfunc,
	logic = sheep_logic,
	on_step = function(self, dtime, moveresult)
		better_fauna.on_step(self, dtime, moveresult)
		if mobkit.is_alive(self) then
			if self.object:get_properties().textures[1] == "better_fauna_sheep.png"
			and not self.gotten then
				self.object:set_properties({
					textures = {"better_fauna_sheep.png^better_fauna_sheep_wool.png"},
				})
			end
		end
	end,
	on_activate = function(self, staticdata, dtime_s)
		better_fauna.on_activate(self, staticdata, dtime_s)
		self.dye_color = mobkit.recall(self, "dye_color") or "white"
		self.dye_hex = mobkit.recall(self, "dye_hex") or ""
		if self.dye_color ~= "white"
		and not self.gotten then
			self.object:set_properties({
				textures = {"better_fauna_sheep.png^(better_fauna_sheep_wool.png^[colorize:" .. self.dye_hex .. ")"},
			})
		end
		if self.gotten then
			self.object:set_properties({
				textures = {"better_fauna_sheep.png"},
			})
		end
	end,
	on_rightclick = function(self, clicker)
		if better_fauna.feed_tame(self, clicker, 1, false, true) then return end
		mob_core.protect(self, clicker, false)
		mob_core.nametag(self, clicker, true)
		local item = clicker:get_wielded_item()
		local itemname = item:get_name()
		local name = clicker:get_player_name()
		if itemname == "mobs:shears"
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
				textures = {"better_fauna_sheep.png"},
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
						{name = "better_fauna:mutton_raw", chance = 1, min = 1, max = 4},
						{name = "wool:"..self.dye_color, chance = 2, min = 1, max = 2},
					}

					self.object:set_properties({
						textures = {"better_fauna_sheep.png^(better_fauna_sheep_wool.png^[colorize:" .. color[3] .. ")"},
					})

					if not mobs.is_creative(clicker:get_player_name()) then
						item:take_item()
						clicker:set_wielded_item(item)
					end
					break
				end
			end
		end
	end,

	on_punch = function(self, puncher, _, tool_capabilities, dir)
		mobkit.clear_queue_high(self)
		mob_core.on_punch_basic(self, puncher, tool_capabilities, dir)
		better_fauna.hq_sporadic_flee(self, 10, puncher)
	end,
})

mob_core.register_spawn_egg("better_fauna:sheep", "f4e6cf", "e1ca9b")

mob_core.register_spawn({
	name = "better_fauna:sheep",
	nodes = {"default:dirt_with_grass"},
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	min_rad = 24,
	max_rad = 256,
	group = 6
}, 2, 8)

minetest.register_craftitem("better_fauna:mutton_raw", {
	description = "Raw Mutton",
	inventory_image = "better_fauna_mutton_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2},
})

minetest.register_craftitem("better_fauna:mutton_cooked", {
	description = "Cooked Mutton",
	inventory_image = "better_fauna_mutton_cooked.png",
	on_use = minetest.item_eat(6),
	groups = {flammable = 2},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "better_fauna:mutton_raw",
	output = "better_fauna:mutton_cooked",
})