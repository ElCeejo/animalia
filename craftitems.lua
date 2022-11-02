----------------
-- Craftitems --
----------------

local S = minetest.get_translator(minetest.get_current_modname())

local random = math.random

local walkable_nodes = {}

local color = minetest.colorize

minetest.register_on_mods_loaded(function()
	for name in pairs(minetest.registered_nodes) do
		if name ~= "air" and name ~= "ignore" then
			if minetest.registered_nodes[name].walkable then
				table.insert(walkable_nodes, name)
			end
		end
	end
end)

local function correct_name(str)
	if str then
		if str:match(":") then str = str:split(":")[2] end
		return (string.gsub(" " .. str, "%W%l", string.upper):sub(2):gsub("_", " "))
	end
end

local function register_egg(name, def)

	minetest.register_entity(def.mob .. "_egg_entity", {
		hp_max = 1,
		physical = true,
		collisionbox = {0, 0, 0, 0, 0, 0},
		visual = "sprite",
		visual_size = {x = 0.5, y = 0.5},
		textures = {"animalia_egg.png"},
		initial_sprite_basepos = {x = 0, y = 0},
		is_visible = true,
		on_step = function(self, _, moveresult)
			local pos = self.object:get_pos()
			if not pos then return end
			if moveresult.collides then
				for _, collision in ipairs(moveresult.collision) do
					if collision.type == "nodes" then
						minetest.add_particlespawner({
							amount = 6,
							time = 0.1,
							minpos = {x = pos.x - 7/16, y = pos.y - 5/16, z = pos.z - 7/16},
							maxpos = {x = pos.x + 7/16, y = pos.y - 5/16, z = pos.z + 7/16},
							minvel = {x = -1, y = 2, z = -1},
							maxvel = {x = 1, y = 5, z = 1},
							minacc = {x = 0, y = -9.8, z = 0},
							maxacc = {x = 0, y = -9.8, z = 0},
							collisiondetection = true,
							collision_removal = true,
							texture = "animalia_egg_fragment.png"
						})
						break
					elseif collision.type == "object" then
						collision.object:punch(self.object, 2.0, {full_punch_interval = 0.1, damage_groups = {fleshy = 1}}, nil)
						break
					end
				end
				if random(1, 3) < 2 then
					local object = minetest.add_entity(pos, def.mob)
					local ent = object and object:get_luaentity()
					ent.growth_scale = 0.7
					animalia.initialize_api(ent)
					animalia.protect_from_despawn(ent)
				end
				self.object:remove()
			end
		end
	})

	minetest.register_craftitem(name, {
		description = def.description,
		inventory_image = def.inventory_image .. ".png",
		on_use = function(itemstack, player)
			local pos = player:get_pos()
			minetest.sound_play("default_place_node_hard", {
				pos = pos,
				gain = 1.0,
				max_hear_distance = 5,
			})
			local vel = 19
			local gravity = 9
			local object = minetest.add_entity({
				x = pos.x,
				y = pos.y + 1.5,
				z = pos.z
			}, def.mob .. "_egg_entity")
			local ent = object and object:get_luaentity()
			local dir = player:get_look_dir()
			object:set_velocity({
				x = dir.x * vel,
				y = dir.y * vel,
				z = dir.z * vel
			})
			object:set_acceleration({
				x = dir.x * -3,
				y = -gravity,
				z = dir.z * -3
			})
			itemstack:take_item()
			return itemstack
		end,
		groups = {food_egg = 1, flammable = 2},
	})

	minetest.register_craftitem(name .. "_fried", {
		description = "Fried " .. def.description,
		inventory_image = def.inventory_image .. "_fried.png",
		on_use = minetest.item_eat(4),
		groups = {food_egg = 1, flammable = 2},
	})

	minetest.register_craft({
		type  =  "cooking",
		recipe  = name,
		output = name .. "_fried",
	})
end

local function mob_storage_use(itemstack, player, pointed)
	local ent = pointed.ref and pointed.ref:get_luaentity()
	if ent
	and (ent.name:match("^animalia:")
	or ent.name:match("^monstrum:")) then
		local desc = itemstack:get_short_description()
		if itemstack:get_count() > 1 then
			local name = itemstack:get_name()
			local inv = player:get_inventory()
			if inv:room_for_item("main", {name = name}) then
				itemstack:take_item(1)
				inv:add_item("main", name)
			end
			return itemstack
		end
		local plyr_name = player:get_player_name()
		local meta = itemstack:get_meta()
		local mob = meta:get_string("mob") or ""
		local staticdata = meta:get_string("staticdata") or ""
		if mob == "" then
			animalia.protect_from_despawn(ent)
			meta:set_string("mob", ent.name)
			meta:set_string("staticdata", ent:get_staticdata())
			local ent_name = correct_name(ent.name)
			local ent_gender = correct_name(ent.gender)
			desc = desc .. " \n" .. color("#a9a9a9", ent_name) .. "\n" .. color("#a9a9a9", ent_gender)
			if ent.trust
			and ent.trust[plyr_name] then
				desc = desc .. "\n Trust: " .. color("#a9a9a9", ent.trust[plyr_name])
			end
			meta:set_string("description", desc)
			player:set_wielded_item(itemstack)
			ent.object:remove()
			return itemstack
		else
			minetest.chat_send_player(plyr_name,
				"This " .. desc .. " already contains a " .. correct_name(mob))
		end
	end
end

-----------
-- Drops --
-----------

minetest.register_craftitem("animalia:leather", {
	description = S("Leather"),
	inventory_image = "animalia_leather.png",
	groups = {flammable = 2, leather = 1},
})

minetest.register_craftitem("animalia:feather", {
	description = S("Feather"),
	inventory_image = "animalia_feather.png",
	groups = {flammable = 2, feather = 1},
})

-- Meat --

minetest.register_craftitem("animalia:beef_raw", {
	description = S("Raw Beef"),
	inventory_image = "animalia_beef_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:beef_cooked", {
	description = S("Steak"),
	inventory_image = "animalia_beef_cooked.png",
	on_use = minetest.item_eat(8),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:beef_raw",
	output = "animalia:beef_cooked",
})

minetest.register_craftitem("animalia:mutton_raw", {
	description = S("Raw Mutton"),
	inventory_image = "animalia_mutton_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:mutton_cooked", {
	description = S("Cooked Mutton"),
	inventory_image = "animalia_mutton_cooked.png",
	on_use = minetest.item_eat(6),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:mutton_raw",
	output = "animalia:mutton_cooked",
})

minetest.register_craftitem("animalia:rat_raw", {
	description = S("Raw Rat"),
	inventory_image = "animalia_rat_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:rat_cooked", {
	description = S("Cooked Rat"),
	inventory_image = "animalia_rat_cooked.png",
	on_use = minetest.item_eat(2),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:rat_raw",
	output = "animalia:rat_cooked",
})

minetest.register_craftitem("animalia:porkchop_raw", {
	description = S("Raw Porkchop"),
	inventory_image = "animalia_porkchop_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:porkchop_cooked", {
	description = S("Cooked Porkchop"),
	inventory_image = "animalia_porkchop_cooked.png",
	on_use = minetest.item_eat(7),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:porkchop_raw",
	output = "animalia:porkchop_cooked",
})

minetest.register_craftitem("animalia:poultry_raw", {
	description = S("Raw Poultry"),
	inventory_image = "animalia_poultry_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:poultry_cooked", {
	description = S("Cooked Poultry"),
	inventory_image = "animalia_poultry_cooked.png",
	on_use = minetest.item_eat(6),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:poultry_raw",
	output = "animalia:poultry_cooked",
})

minetest.register_craftitem("animalia:venison_raw", {
	description = S("Raw Venison"),
	inventory_image = "animalia_venison_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:venison_raw_cooked", {
	description = S("Venison Steak"),
	inventory_image = "animalia_venison_cooked.png",
	on_use = minetest.item_eat(10),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:venison_raw",
	output = "animalia:venison_cooked",
})

register_egg("animalia:chicken_egg", {
	description = S("Chicken Egg"),
	inventory_image = "animalia_egg",
	mob = "animalia:chicken"
})

register_egg("animalia:turkey_egg", {
	description = S("Turkey Egg"),
	inventory_image = "animalia_egg",
	mob = "animalia:turkey"
})

----------
-- Misc --
----------

minetest.register_craftitem("animalia:bucket_milk", {
	description = S("Bucket of Milk"),
	inventory_image = "animalia_milk_bucket.png",
	stack_max = 1,
	on_use = minetest.item_eat(8, "bucket:bucket_empty"),
	groups = {food_milk = 1, flammable = 3},
})

local function grow_crops(pos, nodename)
	local checkname = nodename:sub(1, string.len(nodename) - 1)
	if minetest.registered_nodes[checkname .. "1"]
	and minetest.registered_nodes[checkname .. "2"]
	and minetest.registered_nodes[checkname .. "2"].drawtype == "plantlike" then -- node is more than likely a plant
		local stage = tonumber(string.sub(nodename, -1)) or 0
		local newname = checkname .. (stage + 1)
		if minetest.registered_nodes[newname] then
			local def = minetest.registered_nodes[newname]
			def = def and def.place_param2 or 0
			minetest.set_node(pos, {name = newname, param2 = def})
			minetest.add_particlespawner({
				amount = 6,
				time = 0.1,
				minpos = vector.subtract(pos, 0.5),
				maxpos = vector.add(pos, 0.5),
				minvel = {
					x = -0.5,
					y = 0.5,
					z = -0.5
				},
				maxvel = {
					x = 0.5,
					y = 1,
					z = 0.5
				},
				minacc = {
					x = 0,
					y = 2,
					z = 0
				},
				maxacc = {
					x = 0,
					y = 4,
					z = 0
				},
				minexptime = 0.5,
				maxexptime = 1,
				minsize = 1,
				maxsize = 2,
				collisiondetection = false,
				vertical = false,
				use_texture_alpha = true,
				texture = "creatura_particle_green.png",
				glow = 6
			})
		end
	end
end

local guano_fert = minetest.settings:get_bool("guano_fertilization")

minetest.register_craftitem("animalia:bucket_guano", {
	description = S("Bucket of Guano"),
	inventory_image = "animalia_guano_bucket.png",
	stack_max = 1,
	groups = {flammable = 3},
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.above
		if pos then
			local under = minetest.get_node(pointed_thing.under)
			local node = minetest.registered_nodes[under.name]
			if node and node.on_rightclick then
				return node.on_rightclick(pointed_thing.under, under, placer,
										  itemstack)
			end
			if pos
			and not minetest.is_protected(pos, placer:get_player_name()) then
				if guano_fert then
					local nodes = minetest.find_nodes_in_area_under_air(
						vector.subtract(pos, 5),
						vector.add(pos, 5),
						{"group:grass", "group:plant", "group:flora"}
					)
					if #nodes > 0 then
						for n = 1, #nodes do
							grow_crops(nodes[n], minetest.get_node(nodes[n]).name)
						end
						local replace = itemstack:get_meta():get_string("original_item")
						if not replace
						or replace == "" then
							replace = "bucket:bucket_empty"
						end
						itemstack:set_name(replace)
					end
				else
					minetest.set_node(pos, {name = "animalia:guano"})
					local replace = itemstack:get_meta():get_string("original_item")
					if not replace
					or replace == "" then
						replace = "bucket:bucket_empty"
					end
					itemstack:set_name(replace)
				end
			end
		end
		return itemstack
	end
})

minetest.register_node("animalia:nest_song_bird", {
	description = S("Song Bird Nest"),
	paramtype = "light",
	drawtype = "mesh",
	mesh = "animalia_nest.obj",
	tiles = {"animalia_nest.png"},
	sunlight_propagates = true,
	walkable = false,
	stack_max = 1,
	groups = {snappy = 3, flammable = 3},
	selection_box = {
		type = "fixed",
		fixed = {-5 / 16, -0.5, -5 / 16, 5 / 16, -0.31, 5 / 16},
	},
	node_box = {
		type = "fixed",
		fixed = {-5 / 16, -0.5, -5 / 16, 5 / 16, -0.31, 5 / 16},
	},
	drops = "default:stick"
})

-----------
-- Tools --
-----------

minetest.register_craftitem("animalia:cat_toy", {
	description = S("Cat Toy"),
	inventory_image = "animalia_cat_toy.png",
	wield_image = "animalia_cat_toy.png^[transformFYR90",
	stack_max = 1
})

local nametag = {}

local function get_rename_formspec(meta)
	local tag = meta:get_string("name") or ""
	local form = {
		"size[8,4]",
		"field[0.5,1;7.5,0;name;" .. minetest.formspec_escape("Enter name:") .. ";" .. tag .. "]",
		"button_exit[2.5,3.5;3,1;set_name;" .. minetest.formspec_escape("Set Name") .. "]"
	}
	return table.concat(form, "")
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "animalia:set_name" and fields.name then
		local name = player:get_player_name()
		if not nametag[name] then
			return
		end
		local itemstack = nametag[name]
		if string.len(fields.name) > 64 then
			fields.name = string.sub(fields.name, 1, 64)
		end
		local meta = itemstack:get_meta()
		meta:set_string("name", fields.name)
		meta:set_string("description", fields.name)
		player:set_wielded_item(itemstack)
		if fields.quit or fields.key_enter then
			nametag[name] = nil
		end
	end
end)

local function nametag_rightclick(itemstack, player, pointed_thing)
	if pointed_thing
	and pointed_thing.type == "object" then
		return
	end
	local name = player:get_player_name()
	nametag[name] = itemstack
	local meta = itemstack:get_meta()
	minetest.show_formspec(name, "animalia:set_name", get_rename_formspec(meta))
end

minetest.register_craftitem("animalia:nametag", {
	description = S("Nametag"),
	inventory_image = "animalia_nametag.png",
	on_rightclick = nametag_rightclick,
	on_secondary_use = nametag_rightclick
})

minetest.register_craftitem("animalia:saddle", {
	description = S("Saddle"),
	inventory_image = "animalia_saddle.png",
})

minetest.register_tool("animalia:shears", {
	description = S("Shears"),
	inventory_image = "animalia_shears.png",
	groups = {flammable = 2}
})

minetest.register_craftitem("animalia:net", {
	description = S("Animal Net"),
	inventory_image = "animalia_net.png",
	stack_max = 1,
	on_secondary_use = mob_storage_use,
	on_place = function(itemstack, placer, pointed_thing)
		local pos = pointed_thing.above
		if pos then
			local under = minetest.get_node(pointed_thing.under)
			local node = minetest.registered_nodes[under.name]
			if node and node.on_rightclick then
				return node.on_rightclick(pointed_thing.under, under, placer,
										  itemstack)
			end
			if pos and not minetest.is_protected(pos, placer:get_player_name()) then
				local mob = itemstack:get_meta():get_string("mob")
				local staticdata = itemstack:get_meta():get_string("staticdata")
				if mob ~= "" then
					pos.y = pos.y +
								math.abs(
									minetest.registered_entities[mob]
										.collisionbox[2])
					minetest.add_entity(pos, mob, staticdata)
					itemstack:get_meta():set_string("mob", nil)
					itemstack:get_meta():set_string("staticdata", nil)
					itemstack:get_meta():set_string("description", "Animal Net")
				end
			end
		end
		return itemstack
	end
})

-----------
-- Nodes --
-----------

minetest.register_node("animalia:guano", {
	description = S("Guano"),
	tiles = {"animalia_guano.png"},
	paramtype = "light",
	buildable_to = true,
	floodable = true,
	walkable = false,
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -0.25, 0.5},
		},
	},
	groups = {crumbly = 3, falling_node = 1, not_in_creative_inventory = 1},
	on_punch = function(pos, _, player)
		local item_name = player:get_wielded_item():get_name()
		if item_name:find("bucket")
		and item_name:find("empty") then
			local stack = ItemStack("animalia:bucket_guano")
			stack:get_meta():set_string("original_item", item_name)
			player:set_wielded_item(stack)
			minetest.remove_node(pos)
		end
	end
})

minetest.register_node("animalia:crate", {
	description = S("Animal Crate"),
	tiles = {"animalia_crate.png", "animalia_crate.png", "animalia_crate_side.png"},
	groups = {choppy = 2},
	stack_max = 1,
	on_secondary_use = mob_storage_use,
	preserve_metadata = function(_, _, oldmeta, drops)
		for _, stack in pairs(drops) do
			if stack:get_name() == "animalia:crate" then
				local meta = stack:get_meta()
				meta:set_string("mob", oldmeta["mob"])
				meta:set_string("staticdata", oldmeta["staticdata"])
				meta:set_string("description", oldmeta["description"])
			end
		end
	end,
	after_place_node = function(pos, placer, itemstack)
		local meta = itemstack:get_meta()
		local mob = meta:get_string("mob")
		if mob ~= "" then
			local nmeta = minetest.get_meta(pos)
			nmeta:set_string("mob", mob)
			nmeta:set_string("infotext", "Contains a " .. correct_name((mob)))
			nmeta:set_string("staticdata", meta:get_string("staticdata"))
			nmeta:set_string("description", meta:get_string("description"))
			itemstack:take_item()
			placer:set_wielded_item(itemstack)
		end
	end,
	on_rightclick = function(pos, _, clicker)
		if minetest.is_protected(pos, clicker:get_player_name()) then
			return
		end
		local meta = minetest.get_meta(pos)
		local mob = meta:get_string("mob")
		local staticdata = meta:get_string("staticdata")
		if mob ~= "" then
			local above = {
				x = pos.x,
				y = pos.y + 1,
				z = pos.z
			}
			if creatura.get_node_def(above).walkable then
				return
			end
			minetest.add_entity(above, mob, staticdata)
			meta:set_string("mob", nil)
			meta:set_string("infotext", nil)
			meta:set_string("staticdata", nil)
			meta:set_string("description", "Animal Crate")
		end
	end
})

--------------
-- Crafting --
--------------

local steel_ingot = "default:steel_ingot"

minetest.register_on_mods_loaded(function()
	if minetest.registered_items[steel_ingot] then return end
	for name, def in pairs(minetest.registered_items) do
		if name:find("ingot")
		and (name:find("steel")
		or name:find("iron")) then
			steel_ingot = name
			break
		end
	end
end)

minetest.register_craft({
	output = "animalia:cat_toy",
	recipe = {
		{"", "", "group:thread"},
		{"", "group:stick", "group:thread"},
		{"group:stick", "", "group:feather"}
	}
})

minetest.register_craft({
	output = "animalia:cat_toy",
	recipe = {
		{"", "", "farming:string"},
		{"", "group:stick", "farming:string"},
		{"group:stick", "", "group:feather"}
	}
})

minetest.register_craft({
	output = "animalia:lasso",
	recipe = {
		{"", "group:thread", "group:thread"},
		{"", "group:leather", "group:thread"},
		{"group:thread", "", ""}
	}
})

minetest.register_craft({
	output = "animalia:lasso",
	recipe = {
		{"", "farming:string", "farming:string"},
		{"", "group:leather", "farming:string"},
		{"farming:string", "", ""}
	}
})

minetest.register_craft({
	output = "animalia:net",
	recipe = {
		{"group:thread", "", "group:thread"},
		{"group:thread", "", "group:thread"},
		{"group:stick", "group:thread", ""}
	}
})

minetest.register_craft({
	output = "animalia:net",
	recipe = {
		{"farming:string", "", "farming:string"},
		{"farming:string", "", "farming:string"},
		{"group:stick", "farming:string", ""}
	}
})

minetest.register_craft({
	output = "animalia:crate",
	recipe = {
		{"group:wood", "group:wood", "group:wood"},
		{"group:wood", "animalia:net", "group:wood"},
		{"group:wood", "group:wood", "group:wood"}
	}
})

minetest.register_craft({
	output = "animalia:saddle",
	recipe = {
		{"group:leather", "group:leather", "group:leather"},
		{"group:leather", steel_ingot, "group:leather"},
		{"group:thread", "", "group:thread"}
	}
})

minetest.register_craft({
	output = "animalia:saddle",
	recipe = {
		{"group:leather", "group:leather", "group:leather"},
		{"group:leather", steel_ingot, "group:leather"},
		{"farming:string", "", "farming:string"}
	}
})


minetest.register_craft({
	output = "animalia:shears",
	recipe = {
		{"", steel_ingot, ""},
		{"", "group:leather", steel_ingot}
	}
})

minetest.register_craft({
	output = "animalia:libri_animalia",
	recipe = {
		{"", "", ""},
		{"animalia:feather", "", ""},
		{"group:book", "group:color_green", ""}
	}
})

minetest.register_craft({
	output = "animalia:libri_animalia",
	recipe = {
		{"", "", ""},
		{"animalia:feather", "", ""},
		{"group:book", "group:unicolor_green", ""}
	}
})

minetest.register_craft({
	output = "animalia:libri_animalia 2",
	recipe = {
		{"", "", ""},
		{"animalia:libri_animalia", "group:book", ""},
		{"", "", ""}
	}
})

minetest.register_on_craft(function(itemstack, _, old_craft_grid)
	if itemstack:get_name() == "animalia:libri_animalia"
	and itemstack:get_count() > 1 then
		for _, old_libri in pairs(old_craft_grid) do
			if old_libri:get_meta():get_string("chapters") then
				local chapters = old_libri:get_meta():get_string("chapters")
				itemstack:get_meta():set_string("chapters", chapters)
				return itemstack
			end
		end
	end
end)
