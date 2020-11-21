----------------
-- Craftitems --
----------------
---- Ver 0.1 ---


minetest.register_craftitem("better_fauna:net", {
    description = "Animal Net",
    inventory_image = "better_fauna_net.png",
    on_secondary_use = function(itemstack, placer, pointed_thing)
		if pointed_thing.type == "object" then
            if pointed_thing.ref:is_player() then
                return
            end
			local ent = pointed_thing.ref:get_luaentity()
			if not ent.name:match("^better_fauna:")
			or not ent.catch_with_net then
				return
			end
            local ent_name = mob_core.get_name_proper(ent.name)
            local meta = itemstack:get_meta()
            if not meta:get_string("mob")
            or meta:get_string("mob") == "" then
                meta:set_string("mob", ent.name)
                meta:set_string("staticdata", ent:get_staticdata())
                local desc = "Animal Net \n" .. minetest.colorize("#a9a9a9", ent_name)
                meta:set_string("description", desc)
                placer:set_wielded_item(itemstack)
                ent.object:remove()
                return itemstack
            else
                minetest.chat_send_player(placer:get_player_name(), "This Net already contains a "..ent_name)
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
				return node.on_rightclick(pointed_thing.under, under, placer, itemstack)
			end
			if pos
			and not minetest.is_protected(pos, placer:get_player_name()) then
				local mob = itemstack:get_meta():get_string("mob")
				local staticdata = itemstack:get_meta():get_string("staticdata")
				if mob ~= "" then
					pos.y = pos.y + math.abs(minetest.registered_entities[mob].collisionbox[2])
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

minetest.register_craft({
	output = "better_fauna:net",
	recipe = {
		{"farming:string", "", "farming:string"},
		{"farming:string", "", "farming:string"},
		{"group:stick", "farming:string", ""}
	}
})