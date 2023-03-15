-----------
-- Libri --
-----------

local libri = {}

local path = minetest.get_modpath(minetest.get_current_modname())

local color = minetest.colorize

local libri_bg = {
	"formspec_version[3]",
	"size[16,10]",
	"background[-0.7,-0.5;17.5,11.5;animalia_libri_bg.png]"
}

local libri_btn_next = "image_button[15,9;1,1;animalia_libri_icon_next.png;btn_next;;true;false]"

local libri_btn_last = "image_button[1,9;1,1;animalia_libri_icon_last.png;btn_last;;true;false]"

local libri_drp_font_scale = "dropdown[17,0;0.75,0.5;drp_font_scale;0.25,0.5,0.75,1;1]"

local function correct_string(str)
	if str then
		if str:match(":") then str = str:split(":")[2] end
		return (string.gsub(" " .. str, "%W%l", string.upper):sub(2):gsub("_", " "))
	end
end

local pages = {}

local generate_mobs = {
	["animalia:bat"] = "Bat",
	["animalia:cat"] = "Cat",
	["animalia:chicken"] = "Chicken",
	["animalia:cow"] = "Cow",
	["animalia:owl"] = "Owl",
	["animalia:tropical_fish"] = "Tropical Fish",
	["animalia:fox"] = "Fox",
	["animalia:frog"] = "Frog",
	["animalia:horse"] = "Horse",
	["animalia:pig"] = "Pig",
	["animalia:rat"] = "Rat",
	["animalia:reindeer"] = "Reindeer",
	["animalia:sheep"] = "Sheep",
	["animalia:song_bird"] = "Song Bird",
	["animalia:turkey"] = "Turkey",
	["animalia:wolf"] = "Wolf",
}


local spawn_biomes = {
	["animalia:bat"] = "cave",
	["animalia:cat"] = "urban",
	["animalia:chicken"] = "tropical",
	["animalia:cow"] = "grassland",
	["animalia:owl"] = "temperate",
	["animalia:tropical_fish"] = "ocean",
	["animalia:fox"] = "boreal",
	["animalia:frog"] = "swamp",
	["animalia:horse"] = "grassland",
	["animalia:pig"] = "temperate",
	["animalia:rat"] = "urban",
	["animalia:reindeer"] = "boreal",
	["animalia:sheep"] = "grassland",
	["animalia:song_bird"] = "temperate",
	["animalia:turkey"] = "boreal",
	["animalia:wolf"] = "boreal",
}

-----------
-- Pages --
-----------


local function get_spawn_biomes(name)
	local biome_group = spawn_biomes[name]
	local biomes = animalia.registered_biome_groups[biome_group].biomes
	return (#biomes > 0 and biomes) or {"grassland"}
end

local function can_lasso(name)
	return tostring(minetest.registered_entities[name].catch_with_lasso or false)
end

local function can_net(name)
	return tostring(minetest.registered_entities[name].catch_with_net or false)
end

local function max_health(name)
	return minetest.registered_entities[name].max_health or 20
end

local function mob_textures(name, mesh_no)
	local def = minetest.registered_entities[name]
	local textures = def.textures
	if def.male_textures
	or def.female_textures then
		textures = {unpack(def.male_textures), unpack(def.female_textures)}
	end
	if def.mesh_textures then
		textures = def.mesh_textures[mesh_no or 1]
	end
	return textures
end

local biome_cubes = {}

local function generate_page(mob)
	local name = mob:split(":")[2]
	local def = minetest.registered_entities[mob]
	local page = {
		{ -- Info
			element_type = "label",
			center_text = true,
			font_size = 20,
			offset = {x = 8, y = 1.5},
			file = "animalia_libri_" .. name .. ".txt"
		},
		{ -- Image
			element_type = "model",
			offset = {x = 1.5, y = 1.5},
			size = {x = 5, y = 5},
			mesh_iter = def.meshes and 1,
			texture_iter = 1,
			text = "mesh;" .. def.mesh .. ";" .. mob_textures(mob)[1] .. ";-30,225;false;false;0,0;0"
		},
		{ -- Spawn Biome
			element_type = "image",
			offset = {x = 0.825, y = 8.15},
			size = {x = 1, y = 1},
			biome_iter = 1,
			text = biome_cubes[get_spawn_biomes(mob)[1]]
		},
		{ -- Biome Label
			element_type = "tooltip",
			offset = {x = 0.825, y = 8.15},
			size = {x = 1, y = 1},
			biome_iter = 1,
			text = correct_string(get_spawn_biomes(mob)[1])
		},
		libri.render_element({ -- Health Icon
			element_type = "image",
			offset = {x = 2.535, y = 8.15},
			size = {x = 1, y = 1},
			text = "animalia_libri_health_fg.png"
		}),
		libri.render_element({ -- Health Amount
			element_type = "label",
			offset = {x = 3.25, y = 9},
			text = "x" .. max_health(mob) / 2
		}),
		libri.render_element({ -- Lasso Icon
			element_type = "item_image",
			offset = {x = 4.25, y = 8.15},
			size = {x = 1, y = 1},
			text = "animalia:lasso"
		}),
		libri.render_element({ -- Lasso Indication Icon
			element_type = "image",
			offset = {x = 4.75, y = 8.75},
			size = {x = 0.5, y = 0.5},
			text = "animalia_libri_" .. can_lasso(mob) .. "_icon.png"
		}),
		libri.render_element({ -- Net Icon
			element_type = "item_image",
			offset = {x = 6, y = 8.15},
			size = {x = 1, y = 1},
			text = "animalia:net"
		}),
		libri.render_element({ -- Net Indication Icon
			element_type = "image",
			offset = {x = 6.5, y = 8.75},
			size = {x = 0.5, y = 0.5},
			text = "animalia_libri_" .. can_net(mob) .. "_icon.png"
		}),
		libri.render_element({ -- Styling
			element_type = "image",
			offset = {x = -0.7, y = -0.5},
			size = {x = 17.5, y = 11.5},
			text = "animalia_libri_info_fg.png"
		})
	}
	pages[mob] = page
end

minetest.register_on_mods_loaded(function()
	-- Register Biome Cubes
	for name, def in pairs(minetest.registered_biomes) do
		if def.node_top then
			local tiles = {
				"unknown_node.png",
				"unknown_node.png",
				"unknown_node.png"
			}
			local n_def = minetest.registered_nodes[def.node_top]
			if n_def then
				local def_tiles = table.copy(n_def.tiles or n_def.textures)
				for i, tile in ipairs(def_tiles) do
					if tile.name then
						def_tiles[i] = tile.name
					end
				end
				tiles = (#def_tiles > 0 and def_tiles) or tiles
			end
			biome_cubes[name] = minetest.inventorycube(tiles[1], tiles[3], tiles[3])
		else
			biome_cubes[name] = minetest.inventorycube("unknown_node.png", "unknown_node.png", "unknown_node.png")
		end
	end
	pages = {
		["home_1"] = {
			{ -- Info
				element_type = "label",
				center_text = true,
				font_size = 24,
				offset = {x = 0, y = 1.5},
				file = "animalia_libri_home.txt"
			},
			{
				element_type = "mobs",
				start_iter = 0,
				offset = {x = 10.25, y = 1.5}
			}
		},
		["home_2"] = {
			{
				element_type = "mobs",
				start_iter = 4,
				offset = {x = 1.75, y = 1.5}
			}
		},
		["home_3"] = {
			{
				element_type = "mobs",
				start_iter = 12,
				offset = {x = 1.75, y = 1.5}
			}
		}
	}
	for mob in pairs(generate_mobs) do
		generate_page(mob)
	end
end)

---------
-- API --
---------

local function get_item_list(list, offset_x, offset_y) -- Creates a visual list of items for Libri formspecs
	local size = 1 / ((#list < 3 and #list) or 3)
	if size < 0.45 then size = 0.45 end
	local spacing = size * 0.5
	local total_scale = size + spacing
	local max_horiz = 3
	local form = ""
	for i, item in ipairs(list) do
		local vert_multi = math.floor((i - 1) / max_horiz)
		local horz_multi = (total_scale * max_horiz) * vert_multi
		local pos_x = offset_x + ((total_scale * i) - horz_multi)
		local pos_y = offset_y + (total_scale * vert_multi )
		form = form .. "item_image[" .. pos_x .. "," .. pos_y .. ";" .. size .. "," .. size .. ";" .. item .. "]"
	end
	return form
end

function libri.generate_list(meta, offset, start_iter)
	local chapters = minetest.deserialize(meta:get_string("chapters")) or {}
	local i = 0
	local elements = ""
	local offset_x = offset.x
	local offset_y = offset.y
	for mob in pairs(chapters) do
		if not mob then break end
		i = i + 1
		if i > start_iter then
			local mob_name = mob:split(":")[2]
			local offset_txt = offset_x .. "," .. offset_y
			local element = "button[" .. offset_txt .. ";4,1;btn_" .. mob_name .. ";" .. correct_string(mob_name) .. "]"
			elements = elements .. element
			offset_y = offset_y + 2
			if offset_y > 7.5 then
				offset_x = offset_x + 8.5
				if offset_x > 10.25 then
					return elements
				end
				offset_y = 1.5
			end
		end
	end
	return elements
end

function libri.render_element(def, meta, playername)
	local chapters = (meta and minetest.deserialize(meta:get_string("chapters"))) or {}
	local chap_no = 0
	for _ in pairs(chapters) do
		chap_no = chap_no + 1
	end
	local offset_x = def.offset.x
	local offset_y = def.offset.y
	local form = ""
	-- Add text
	if def.element_type == "label" then
		local font_size_x = (animalia.libri_font_size[playername] or 1)
		local font_size = (def.font_size or 16) * font_size_x
		if def.file then
			local filename = path .. "/libri/" .. def.file
			local file = io.open(filename)
			if file then
				local text = ""
				for line in file:lines() do
					text = text .. line .. "\n"
				end
				local total_offset = (offset_x + (0.35 - 0.35 * font_size_x)) .. "," .. offset_y
				form = form ..
					"hypertext[" ..	total_offset .. ";8,9;text;<global color=#000000 size="..
						font_size .. " halign=center>" .. text .. "]"
				file:close()
			end
		else
			form = form .. "style_type[label;font_size=" .. font_size .. "]"
			local line = def.text
			form = form .. "label[" .. offset_x .. "," .. offset_y .. ";" .. color("#000000", line .. "\n") .. "]"
		end
	elseif def.element_type == "mobs" then
		form = form .. libri.generate_list(meta, def.offset, def.start_iter)
		if chap_no > def.start_iter + 4 then form = form .. libri_btn_next end
		if def.start_iter > 3 then form = form .. libri_btn_last end
	else
		-- Add Images/Interaction
		local render_element = false
		if def.unlock_key
		and #chapters > 0 then
			for _, chapter in ipairs(chapters) do
				if chapter
				and chapter == def.unlock_key then
					render_element = true
					break
				end
			end
		elseif not def.unlock_key then
			render_element = true
		end
		if render_element then
			local offset = def.offset.x .. "," .. def.offset.y
			local size = def.size.x .. "," .. def.size.y
			form = form .. def.element_type .. "[" .. offset .. ";" .. size .. ";" .. def.text .. "]"
		end
	end
	return form
end

local function get_page(key, meta, playername)
	local form = table.copy(libri_bg)
	local chapters = minetest.deserialize(meta:get_string("chapters")) or {}
	local chap_no = 0
	for _ in pairs(chapters) do
		chap_no = chap_no + 1
	end
	local page = pages[key]
	for _, element in ipairs(page) do
		if type(element) == "table" then
			local element_rendered = libri.render_element(element, meta, playername)
			table.insert(form, element_rendered)
		else
			table.insert(form, element)
		end
	end
	table.insert(form, "style[drp_font_scale;noclip=true]")
	table.insert(form, libri_drp_font_scale)
	table.insert(form, "style[drp_font_scale;noclip=true]")
	local def = minetest.registered_entities[key]
	if def then
		if def.follow then
			table.insert(form, get_item_list(def.follow, 12.45, 8.05))
		end
		if def.drops then
			local drops = {}
			for i = 1, #def.drops do
				table.insert(drops, def.drops[i].name)
			end
			table.insert(form, get_item_list(drops, 8, 8.05))
		end
	end
	return table.concat(form, "")
end

-- Iterate through Animal textures and Biomes

local libri_players = {}

local function iterate_libri_images()
	for page, elements in pairs(pages) do
		if page ~= "home" then
			for _, info in ipairs(elements) do
				if info.texture_iter then
					local def = minetest.registered_entities[page]
					local textures = mob_textures(page, info.mesh_iter)

					local tex_i = info.texture_iter
					info.texture_iter = (textures[tex_i + 1] and tex_i + 1) or 1

					local mesh_i = info.mesh_iter
					if info.texture_iter < 2 then -- Only iterate mesh if all textures have been shown
						info.mesh_iter = def.meshes and ((def.meshes[mesh_i + 1] and mesh_i + 1) or 1)
						textures = mob_textures(page, info.mesh_iter)
					end

					local mesh = (info.mesh_iter and def.meshes[info.mesh_iter]) or def.mesh
					info.text = "mesh;" .. mesh .. ";" .. textures[info.texture_iter] .. ";-30,225;false;false;0,0;0]"
				end
				if info.biome_iter then
					local biome_group = spawn_biomes[page]
					local registered_groups = animalia.registered_biome_groups
					if registered_groups[biome_group].biomes[info.biome_iter + 1] then
						info.biome_iter = info.biome_iter + 1
					else
						info.biome_iter = 1
					end
					local spawn_biome = registered_groups[biome_group].biomes[info.biome_iter] or "grassland"
					if info.element_type == "image" then
						info.text = biome_cubes[spawn_biome]
					else
						info.text = correct_string(spawn_biome)
					end
				end
			end
		end
	end
	for name, page in pairs(libri_players) do
		local player = minetest.get_player_by_name(name)
		if player
		and spawn_biomes[page] then
			local meta = player:get_wielded_item():get_meta()
			minetest.show_formspec(name, "animalia:libri_" .. page:split(":")[2], get_page(page, meta, name))
		end
	end
	minetest.after(2, iterate_libri_images)
end

iterate_libri_images()

-- Craftitem

minetest.register_craftitem("animalia:libri_animalia", {
	description = "Libri Animalia",
	inventory_image = "animalia_libri_animalia.png",
	stack_max = 1,
	on_place = function(itemstack, player)
		local meta = itemstack:get_meta()
		if meta:get_string("pages") ~= "" then meta:set_string("pages", "") end
		local name = player:get_player_name()
		minetest.show_formspec(name, "animalia:libri_home_1", get_page("home_1", meta, name))
		libri_players[name] = "home_1"
	end,
	on_secondary_use = function(itemstack, player, pointed)
		local meta = itemstack:get_meta()
		if meta:get_string("pages") ~= "" then meta:set_string("pages", "") end
		local chapters = minetest.deserialize(meta:get_string("chapters")) or {}
		if pointed
		and pointed.type == "object" then
			local ent = pointed.ref and pointed.ref:get_luaentity()
			if ent
			and pages[ent.name]
			and not chapters[ent.name] then
				chapters[ent.name] = true
				itemstack:get_meta():set_string("chapters", minetest.serialize(chapters))
				player:set_wielded_item(itemstack)
			end
			return itemstack
		end
		local name = player:get_player_name()
		minetest.show_formspec(name, "animalia:libri_home_1", get_page("home_1", meta, name))
		libri_players[name] = "home_1"
	end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local plyr_name = player:get_player_name()
	local wielded_item = player:get_wielded_item()
	local meta = wielded_item:get_meta()
	if formname:match("animalia:libri_") then
		for page in pairs(pages) do
			if not page:match("^home") then
				local name = page:split(":")[2]
				if fields["btn_" .. name] then
					minetest.show_formspec(plyr_name, "animalia:libri_" .. name, get_page(page, meta, plyr_name))
					libri_players[plyr_name] = page
					return true
				end
			end
		end
		if fields.btn_next then
			local current_no = tonumber(formname:sub(-1))
			local page = "home_" .. current_no + 1
			if pages[page] then
				minetest.show_formspec(plyr_name, "animalia:libri_" .. page, get_page(page, meta, plyr_name))
				libri_players[plyr_name] = page
				return true
			end
		end
		if fields.btn_last then
			local current_no = tonumber(formname:sub(-1))
			local page = "home_" .. current_no - 1
			if pages[page] then
				minetest.show_formspec(plyr_name, "animalia:libri_" .. page, get_page(page, meta, plyr_name))
				libri_players[plyr_name] = page
				return true
			end
		end
		if fields.drp_font_scale then
			animalia.libri_font_size[plyr_name] = fields.drp_font_scale
			local page = libri_players[plyr_name]
			if not page then return end
			minetest.show_formspec(plyr_name, "animalia:libri_" .. page, get_page(page, meta, plyr_name))
		end
		if fields.quit or fields.key_enter then
			libri_players[plyr_name] = nil
		end
	end
end)