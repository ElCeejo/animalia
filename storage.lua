local mod_storage = minetest.get_mod_storage()

local data = {
    bound_horse = minetest.deserialize(mod_storage:get_string("bound_horse")) or {},
}

local function save()
    mod_storage:set_string("bound_horse", minetest.serialize(data.bound_horse))
end

minetest.register_on_shutdown(save)
minetest.register_on_leaveplayer(save)

local function periodic_save()
    save()
    minetest.after(120, periodic_save)
end
minetest.after(120, periodic_save)

return data