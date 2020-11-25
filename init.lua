better_fauna = {}

better_fauna.walkable_nodes = {}

minetest.register_on_mods_loaded(function()
	for name in pairs(minetest.registered_nodes) do
		if name ~= "air" and name ~= "ignore" then
			if minetest.registered_nodes[name].walkable then
				table.insert(better_fauna.walkable_nodes, name)
			end
		end
	end
end)

better_fauna.frame_blend = 0

if minetest.has_feature("object_step_has_moveresult") then
	better_fauna.frame_blend = 0.3
end

local path = minetest.get_modpath("better_fauna")

dofile(path.."/api/api.lua")
dofile(path.."/craftitems.lua")
dofile(path.."/mobs/chicken.lua")
dofile(path.."/mobs/cow.lua")
dofile(path.."/mobs/pig.lua")
dofile(path.."/mobs/sheep.lua")
dofile(path.."/mobs/turkey.lua")


minetest.log("action", "[MOD] Better Fauna [0.1] loaded")
