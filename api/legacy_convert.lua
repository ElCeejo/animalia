--------------------------------------
-- Convert Better Fauna to Animalia --
--------------------------------------

for i = 1, #animalia.mobs do
    local new_mob = animalia.mobs[i]
    local old_mob = "better_fauna:" .. new_mob:split(":")[2]
    minetest.register_entity(":" .. old_mob, {
        on_activate = mob_core.on_activate
    })
    minetest.register_alias_force("better_fauna:spawn_" .. new_mob:split(":")[2],
		"animalia:spawn_" .. new_mob:split(":")[2])
end

minetest.register_globalstep(function(dtime)
    local mobs = minetest.luaentities
    for _, mob in pairs(mobs) do
        if mob
        and mob.name:match("better_fauna:") then
			local pos = mob.object:get_pos()
			if not pos then return end
            if mob.name:find("lasso_fence_ent") then
                if pos then
                    minetest.add_entity(pos, "animalia:lasso_fence_ent")
                end
                mob.object:remove()
            elseif mob.name:find("lasso_visual") then
                if pos then
                    minetest.add_entity(pos, "animalia:lasso_visual")
                end
                mob.object:remove()
            end
            for i = 1, #animalia.mobs do
                local ent = animalia.mobs[i]
                local new_name = ent:split(":")[2]
                local old_name = mob.name:split(":")[2]
                if new_name == old_name then
                    if pos then
                        local new_mob = minetest.add_entity(pos, ent)
                        local mem = nil
                        if mob.memory then
                            mem = mob.memory
                        end
                        minetest.after(0.1, function()
                            if mem then
                                new_mob:get_luaentity().memory = mem
                                new_mob:get_luaentity():on_activate(new_mob, nil, dtime)
                            end
                        end)
                    end
                    mob.object:remove()
                end
            end
        end
    end
end)


-- Tools

minetest.register_alias_force("better_fauna:net", "animalia:net")
minetest.register_alias_force("better_fauna:lasso", "animalia:lasso")
minetest.register_alias_force("better_fauna:cat_toy", "animalia:cat_toy")
minetest.register_alias_force("better_fauna:saddle", "animalia:saddle")
minetest.register_alias_force("better_fauna:shears", "animalia:shears")

-- Drops

minetest.register_alias_force("better_fauna:beef_raw", "animalia:beef_raw")
minetest.register_alias_force("better_fauna:beef_cooked", "animalia:beef_cooked")
minetest.register_alias_force("better_fauna:bucket_milk", "animalia:bucket_milk")
minetest.register_alias_force("better_fauna:leather", "animalia:leather")
minetest.register_alias_force("better_fauna:chicken_egg", "animalia:chicken_egg")
minetest.register_alias_force("better_fauna:chicken_raw", "animalia:poultry_raw")
minetest.register_alias_force("better_fauna:chicken_cooked", "animalia:poultry_cooked")
minetest.register_alias_force("better_fauna:feather", "animalia:feather")
minetest.register_alias_force("better_fauna:mutton_raw", "animalia:mutton_raw")
minetest.register_alias_force("better_fauna:mutton_cooked", "animalia:mutton_cooked")
minetest.register_alias_force("better_fauna:porkchop_raw", "animalia:porkchop_raw")
minetest.register_alias_force("better_fauna:porkchop_cooked", "animalia:porkchop_cooked")
minetest.register_alias_force("better_fauna:turkey_raw", "animalia:poultry_raw")
minetest.register_alias_force("better_fauna:turkey_cooked", "animalia:poultry_cooked")