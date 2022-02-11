local mod_storage = minetest.get_mod_storage()

local data = {
    spawn_points = minetest.deserialize(mod_storage:get_string("spawn_points")) or {},
}

local function save()
    mod_storage:set_string("spawn_points", minetest.serialize(data.spawn_points))
end

minetest.register_on_shutdown(save)
minetest.register_on_leaveplayer(save)

local function periodic_save()
    save()
    minetest.after(120, periodic_save)
end
minetest.after(120, periodic_save)

return data