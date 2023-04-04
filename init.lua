animalia = {}

local path = minetest.get_modpath("animalia")

local storage = dofile(path .. "/api/storage.lua")

animalia.spawn_points = storage.spawn_points
animalia.libri_font_size = storage.libri_font_size

animalia.pets = {}

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	animalia.pets[name] = {}
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	animalia.pets[name] = nil
end)

-- Daytime Tracking

animalia.is_day = true

local function is_day()
	local time = (minetest.get_timeofday() or 0) * 24000
	animalia.is_day = time < 19500 and time > 4500
	minetest.after(10, is_day)
end

is_day()

-- Player Effects

animalia.player_effects = {}

local function player_effect_step()
	for player, data in pairs(animalia.player_effects) do
		if player then
			local timer = data.timer - 1
			animalia.player_effects[player].timer = timer
			local func = data.func
			func(minetest.get_player_by_name(player))
			if timer <= 0 then
				animalia.player_effects[player] = nil
			end
		end
	end
	minetest.after(1, player_effect_step)
end

player_effect_step()

function animalia.set_player_effect(player_name, effect, timer)
	animalia.player_effects[player_name] = {
		func = effect,
		timer = timer or 5
	}
end

-- Create lists of items for reuse

animalia.food_wheat = {}
animalia.food_seeds = {}
animalia.food_crops = {}

minetest.register_on_mods_loaded(function()
	if minetest.get_modpath("farming")
	and farming.registered_plants then
		for _, def in pairs(farming.registered_plants) do
			if def.crop then
				table.insert(animalia.food_crops, def.crop)
			end
		end
	end
	for name in pairs(minetest.registered_items) do
		if (name:match(":wheat")
		or minetest.get_item_group(name, "food_wheat") > 0)
		and not name:find("seed") then
			table.insert(animalia.food_wheat, name)
			return
		end
		if name:match(":seed_")
		or name:match("_seed") then
			table.insert(animalia.food_seeds, name)
			return
		end
	end
end)

-- Load Files

dofile(path.."/api/api.lua")
dofile(path.."/api/behaviors.lua")
dofile(path.."/api/lasso.lua")
dofile(path.."/craftitems.lua")

animalia.animals = {
	"animalia:bat",
	"animalia:song_bird",
	"animalia:cat",
	"animalia:chicken",
	"animalia:cow",
	"animalia:fox",
	"animalia:frog",
	"animalia:horse",
	"animalia:owl",
	"animalia:pig",
	"animalia:rat",
	"animalia:reindeer",
	"animalia:sheep",
	"animalia:turkey",
	"animalia:tropical_fish",
	"animalia:wolf",
}

for i = 1, #animalia.animals do
	local name = animalia.animals[i]:split(":")[2]
	dofile(path.."/mobs/" .. name .. ".lua")
end

if minetest.settings:get_bool("spawn_mobs", true) then
	dofile(path.."/api/spawning.lua")
end

dofile(path.."/api/libri.lua")

minetest.register_on_mods_loaded(function()
	for name, def in pairs(minetest.registered_entities) do
		if def.logic
		or def.brainfunc
		or def.bh_tree
		or def._cmi_is_mob then
			local old_punch = def.on_punch
			if not old_punch then
				old_punch = function() end
			end
			local on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
				old_punch(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
				local pos = self.object:get_pos()
				if not pos then return end
				local plyr_name = puncher:is_player() and puncher:get_player_name()
				local pets = (plyr_name and animalia.pets[plyr_name]) or {}
				for _, obj in ipairs(pets) do
					local ent = obj and obj:get_luaentity()
					if ent
					and ent.assist_owner then
						ent.owner_target = self
					end
				end
			end
			def.on_punch = on_punch
			minetest.register_entity(":" .. name, def)
		end
	end
end)

local convert_mobs_redo = minetest.settings:get_bool("convert_redo_items", false)

if convert_mobs_redo then
	minetest.register_alias_force("mobs:leather", "animalia:leather")
	minetest.register_alias_force("mobs:meat_raw", "animalia:beef_raw")
	minetest.register_alias_force("mobs:meat", "animalia:beef_cooked")
	minetest.register_alias_force("mobs:lasso", "animalia:lasso")
	minetest.register_alias_force("mobs:net", "animalia:net")
	minetest.register_alias_force("mobs:shears", "animalia:shears")
	minetest.register_alias_force("mobs:saddles", "animalia:saddles")
	minetest.register_alias_force("mobs:nametag", "animalia:nametag")
end

minetest.log("action", "[MOD] Animalia [0.6] loaded")
