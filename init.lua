animalia = {}
better_fauna = animalia

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

local path = minetest.get_modpath("animalia")

dofile(path.."/api/api.lua")
dofile(path.."/api/behaviors.lua")
dofile(path.."/api/lasso.lua")
dofile(path.."/craftitems.lua")

animalia.animals = {
    "animalia:bat",
    "animalia:bird",
    "animalia:cat",
    "animalia:chicken",
    "animalia:cow",
    "animalia:tropical_fish",
    "animalia:frog",
    "animalia:horse",
    "animalia:pig",
    "animalia:reindeer",
    "animalia:sheep",
    "animalia:turkey",
    "animalia:wolf",
}

for i = 1, #animalia.animals do
    local name = string.split(animalia.animals[i], ":")[2]
    dofile(path.."/mobs/" .. name .. ".lua")
end

if minetest.settings:get_bool("spawn_mobs", true) then
    dofile(path.."/api/spawning.lua")
end

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
                if not pos then
                    return
                end
                if puncher:is_player()
                and animalia.pets[puncher:get_player_name()] then
                    local pets = animalia.pets[puncher:get_player_name()]
                    if #pets < 1 then return end
                    for i = 1, #pets do
                        local ent = pets[i]:get_luaentity()
                        if ent.assist_owner then
                            ent.owner_target = self
                        end
                    end
                end
            end
            def.on_punch = on_punch
            minetest.register_entity(":" .. name, def)
        end
	end
end)

minetest.log("action", "[MOD] Animalia [0.3] loaded")
