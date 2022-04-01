----------------
-- Craftitems --
----------------

local random = math.random

local function vec_raise(v, n)
    return {x = v.x, y = v.y + n, z = v.z}
end

local walkable_nodes = {}

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

function register_egg(name, def)

	minetest.register_entity(def.mob .. "_egg_sprite", {
		hp_max = 1,
		physical = true,
		collisionbox = {0, 0, 0, 0, 0, 0},
		visual = "sprite",
		visual_size = {x = 0.5, y = 0.5},
		textures = {"animalia_egg.png"},
		initial_sprite_basepos = {x = 0, y = 0},
		is_visible = true,
		on_step = function(self, dtime)
			local pos = self.object:get_pos()
			local objects = minetest.get_objects_inside_radius(pos, 1.5)
			local cube = minetest.find_nodes_in_area(
				vector.new(pos.x - 0.5, pos.y - 0.5, pos.z - 0.5),
				vector.new(pos.x + 0.5, pos.y + 0.5, pos.z + 0.5),
				walkable_nodes)
			if #objects >= 2 then
				if objects[2]:get_armor_groups().fleshy then
					objects[2]:punch(self.object, 2.0, {full_punch_interval = 0.1, damage_groups = {fleshy = 1}}, nil)
				end
			end
			if #cube >= 1 then
				minetest.add_particlespawner({
					amount = 6,
					time = 0.25,
					minpos = {x = pos.x - 7/16, y = pos.y - 5/16, z = pos.z - 7/16},
					maxpos = {x = pos.x + 7/16, y = pos.y - 5/16, z = pos.z + 7/16},
					minvel = vector.new(-1, 2, -1),
					maxvel = vector.new(1, 5, 1),
					minacc = vector.new(0, -9.81, 0),
					maxacc = vector.new(0, -9.81, 0),
					collisiondetection = true,
					texture = "animalia_egg_fragment.png",
				})
				if random(1, 3) < 2 then
					local object = minetest.add_entity(pos, def.mob)
					local ent = object:get_luaentity()
					ent.growth_scale = 0.7
					animalia.initialize_api(ent)
					animalia.protect_from_despawn(ent)
					self.object:remove()
				else
					self.object:remove()
				end
			end
		end
	})

	local function mobs_shoot_egg(item, player, pointed_thing)
		local pos = player:get_pos()
	
		minetest.sound_play("default_place_node_hard", {
			pos = pos,
			gain = 1.0,
			max_hear_distance = 5,
		})
	
		local vel = 19
		local gravity = 9
	
		local obj = minetest.add_entity({
			x = pos.x,
			y = pos.y +1.5,
			z = pos.z
		}, def.mob .. "_egg_sprite")
	
		local ent = obj:get_luaentity()
		local dir = player:get_look_dir()
	
		ent.velocity = vel -- needed for api internal timing
		ent.switch = 1 -- needed so that egg doesn't despawn straight away
	
		obj:set_velocity({
			x = dir.x * vel,
			y = dir.y * vel,
			z = dir.z * vel
		})
	
		obj:set_acceleration({
			x = dir.x * -3,
			y = -gravity,
			z = dir.z * -3
		})
	
		-- pass player name to egg for chick ownership
		local ent2 = obj:get_luaentity()
		ent2.playername = player:get_player_name()
	
		item:take_item()
	
		return item
	end

	minetest.register_craftitem(name, {
		description = def.description,
		inventory_image = def.inventory_image .. ".png",
		on_use = mobs_shoot_egg,
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

-----------
-- Drops --
-----------

minetest.register_craftitem("animalia:leather", {
    description = "Leather",
    inventory_image = "animalia_leather.png",
	groups = {flammable = 2, leather = 1},
})

minetest.register_craftitem("animalia:feather", {
	description = "Feather",
	inventory_image = "animalia_feather.png",
	groups = {flammable = 2, feather = 1},
})

-- Meat --

minetest.register_craftitem("animalia:beef_raw", {
	description = "Raw Beef",
	inventory_image = "animalia_beef_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:beef_cooked", {
	description = "Steak",
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

minetest.register_craftitem("animalia:porkchop_raw", {
	description = "Raw Porkchop",
	inventory_image = "animalia_porkchop_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:porkchop_cooked", {
	description = "Cooked Porkchop",
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
	description = "Raw Poultry",
	inventory_image = "animalia_poultry_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:poultry_cooked", {
	description = "Cooked Poultry",
	inventory_image = "animalia_poultry_cooked.png",
	on_use = minetest.item_eat(6),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:poultry_raw",
	output = "animalia:poultry_cooked",
})

register_egg("animalia:chicken_egg", {
	description = "Chicken Egg",
	inventory_image = "animalia_egg",
	mob = "animalia:chicken"
})

----------
-- Misc --
----------

minetest.register_craftitem("animalia:bucket_milk", {
	description = "Bucket of Milk",
	inventory_image = "animalia_milk_bucket.png",
	stack_max = 1,
	on_use = minetest.item_eat(8, "bucket:bucket_empty"),
	groups = {food_milk = 1, flammable = 3},
})

function grow_crops(pos, nodename)
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
	description = "Bucket of Guano",
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
					local nodes = minetest.find_nodes_in_area_under_air(vector.subtract(pos, 5), vector.add(pos, 5), {"group:grass", "group:plant", "group:flora"})
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
	description = "Song Bird Nest",
	paramtype = "light",
	drawtype = "mesh",
	mesh = "animalia_nest.obj",
	tiles = {"animalia_nest.png"},
	sunlight_propagates = true,
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
    description = "Cat Toy",
    inventory_image = "animalia_cat_toy.png",
    wield_image = "animalia_cat_toy.png^[transformFYR90",
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
    description = "Nametag",
    inventory_image = "animalia_nametag.png",
	on_rightclick = nametag_rightclick,
	on_secondary_use = nametag_rightclick
})

minetest.register_craftitem("animalia:saddle", {
    description = "Saddle",
    inventory_image = "animalia_saddle.png",
})

minetest.register_tool("animalia:shears", {
	description = "Shears",
	inventory_image = "animalia_shears.png",
	groups = {flammable = 2}
})

minetest.register_craftitem("animalia:net", {
    description = "Animal Net",
    inventory_image = "animalia_net.png",
    stack_max = 1,
    on_secondary_use = function(itemstack, placer, pointed_thing)
        if pointed_thing.type == "object" then
            if pointed_thing.ref:is_player() then return end
            local ent = pointed_thing.ref:get_luaentity()
            if not ent.name:match("^animalia:") or not ent.catch_with_net then
                return
            end
            local ent_name = correct_name(ent.name)
            local ent_gender = correct_name(ent.gender)
            local meta = itemstack:get_meta()
            if not meta:get_string("mob") or meta:get_string("mob") == "" then
                if placer:get_wielded_item():get_count() > 1 then
                    if placer:get_inventory():room_for_item("main", {name = "animalia:net"}) then
                        itemstack:take_item(1)
                        placer:get_inventory():add_item("main", "animalia:net")
                        return itemstack
                    else
                        return
                    end
                end
                meta:set_string("mob", ent.name)
                meta:set_string("staticdata", ent:get_staticdata())
                local desc = "Animal Net \n" .. minetest.colorize("#a9a9a9", ent_name) .. "\n" .. minetest.colorize("#a9a9a9", ent_gender)
                if ent.name == "animalia:cat"
                and ent.trust
                and ent.trust[placer:get_player_name()] then
                    desc = desc .. "\n" .. minetest.colorize("#a9a9a9", ent.trust[placer:get_player_name()])
                end
                meta:set_string("description", desc)
                placer:set_wielded_item(itemstack)
				animalia.protect_from_despawn(ent)
                ent.object:remove()
                return itemstack
            else
                minetest.chat_send_player(placer:get_player_name(),
                                          "This Net already contains a " ..
                                              correct_name(
                                                  meta:get_string("mob")))
                return
            end
        end
    end,
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
	description = "Guano",
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
	groups = {crumbly = 3, falling_node = 1},
	on_punch = function(pos, _, player)
		local item = player:get_wielded_item()
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

-----------
-- Libri --
-----------

animalia.libri_pages = {}

function animalia.show_libri_main_form(player, pages, group)
	group = group or 1
    local basic_form = table.concat({
        "formspec_version[3]",
        "size[16,10]",
        "background[-0.7,-0.5;17.5,11.5;animalia_libri_bg.png]"
	}, "")
	if group == 1 then
		if pages[1] then
			basic_form = basic_form .. "button[1.75,1.5;4,1;".. pages[1].form .."]"
		end
		if pages[2] then
			basic_form = basic_form .. "button[1.75,3.5;4,1;".. pages[2].form .."]"
		end
		if pages[3] then
			basic_form = basic_form .. "button[1.75,5.5;4,1;".. pages[3].form .."]"
		end
		if pages[4] then
			basic_form = basic_form .. "button[1.75,7.5;4,1;".. pages[4].form .."]"
		end
		if pages[5] then
			basic_form = basic_form .. "button[10.25,1.5;4,1;".. pages[5].form .."]"
		end
		if pages[6] then
			basic_form = basic_form .. "button[10.25,3.5;4,1;".. pages[6].form .."]"
		end
		if pages[7] then
			basic_form = basic_form .. "button[10.25,5.5;4,1;".. pages[7].form .."]"
		end
		if pages[8] then
			basic_form = basic_form .. "button[10.25,7.5;4,1;".. pages[8].form .."]"
		end
		if pages[9] then
			basic_form = basic_form .. "button[12.25,9;1.5,1;btn_next;Next Page]"
		end
	elseif group == 2 then
		if pages[9] then
			basic_form = basic_form .. "button[1.75,1.5;4,1;".. pages[9].form .."]"
		end
		if pages[10] then
			basic_form = basic_form .. "button[1.75,3.5;4,1;".. pages[10].form .."]"
		end
		if pages[11] then
			basic_form = basic_form .. "button[1.75,5.5;4,1;".. pages[11].form .."]"
		end
		if pages[12] then
			basic_form = basic_form .. "button[1.75,7.5;4,1;".. pages[12].form .."]"
		end
		if pages[13] then
			basic_form = basic_form .. "button[10.25,1.5;4,1;".. pages[13].form .."]"
		end
		if pages[14] then
			basic_form = basic_form .. "button[10.25,3.5;4,1;".. pages[14].form .."]"
		end
		if pages[15] then
			basic_form = basic_form .. "button[10.25,5.5;4,1;".. pages[15].form .."]"
		end
		if pages[16] then
			basic_form = basic_form .. "button[10.25,7.5;4,1;".. pages[16].form .."]"
		end
	end
	animalia.libri_pages[player:get_player_name()] = pages
    minetest.show_formspec(player:get_player_name(), "animalia:libri_main", basic_form)
end

minetest.register_craftitem("animalia:libri_animalia", {
	description = "Libri Animalia",
	inventory_image = "animalia_libri_animalia.png",
	stack_max = 1,
	on_place = function(itemstack, player, pointed_thing)
		if pointed_thing and pointed_thing.type == "object" then return end
		local meta = itemstack:get_meta()
		local pages = minetest.deserialize(meta:get_string("pages"))
        local desc = meta:get_string("description")
		if not pages
		or #pages < 1 then return end
		animalia.show_libri_main_form(player, pages)
	end,
	on_secondary_use = function(itemstack, player, pointed_thing)
		if pointed_thing and pointed_thing.type == "object" then return end
		local meta = itemstack:get_meta()
		local pages = minetest.deserialize(meta:get_string("pages"))
        local desc = meta:get_string("description")
		if not pages
		or #pages < 1 then return end
		animalia.show_libri_main_form(player, pages)
	end
})

--------------
-- Crafting --
--------------

minetest.register_on_mods_loaded(function()
    for name, def in pairs(minetest.registered_items) do
        if string.find(name, "ingot")
		and string.find(name, "steel") then
            if not def.groups then
				def.groups = {}
			end
			def.groups["steel_ingot"] = 1
			minetest.register_item(":" .. name, def)
        elseif string.find(name, "string") then
            if not def.groups then
				def.groups = {}
			end
			def.groups["string"] = 1
			minetest.register_item(":" .. name, def)
        end
    end
end)

minetest.register_craft({
    output = "animalia:cat_toy",
    recipe = {
        {"", "", "group:string"},
        {"", "group:stick", "group:string"},
        {"group:stick", "", "group:feather"}
    }
})

minetest.register_craft({
    output = "animalia:lasso",
    recipe = {
        {"", "group:string", "group:string"},
        {"", "group:leather", "group:string"},
        {"group:string", "", ""}
    }
})

minetest.register_craft({
    output = "animalia:net",
    recipe = {
        {"group:string", "", "group:string"},
        {"group:string", "", "group:string"},
        {"group:stick", "group:string", ""}
    }
})


minetest.register_craft({
    output = "animalia:saddle",
    recipe = {
        {"group:leather", "group:leather", "group:leather"},
        {"group:leather", "group:steel_ingot", "group:leather"},
        {"group:string", "", "group:string"}
    }
})

minetest.register_craft({
	output = "animalia:shears",
	recipe = {
		{"", "group:steel_ingot", ""},
		{"", "group:leather", "group:steel_ingot"}
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

minetest.register_on_craft(function(itemstack, player, old_craft_grid)
	if itemstack:get_name() == "animalia:libri_animalia"
	and itemstack:get_count() > 1 then
		for _, old_libri in pairs(old_craft_grid) do
			if old_libri:get_meta():get_string("pages") then
				local pages = old_libri:get_meta():get_string("pages")
				itemstack:get_meta():set_string("pages", pages)
				return itemstack
			end
		end
	end
end)