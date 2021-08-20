----------------
-- Craftitems --
----------------
---- Ver 0.1 ---

----------------
-- Animal Net -- Used to capture and store animals
----------------

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
            local ent_name = mob_core.get_name_proper(ent.name)
            local ent_gender = mob_core.get_name_proper(ent.gender)
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
                ent.object:remove()
                return itemstack
            else
                minetest.chat_send_player(placer:get_player_name(),
                                          "This Net already contains a " ..
                                              mob_core.get_name_proper(
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

minetest.register_craft({
    output = "animalia:net",
    recipe = {
        {"farming:string", "", "farming:string"},
        {"farming:string", "", "farming:string"},
        {"group:stick", "farming:string", ""}
    }
})

-----------
-- Lasso -- Used to pull animals around, and can be attached to fences
-----------

local function is_lasso_in_use(player)
    for _, ent in pairs(minetest.luaentities) do
        if ent.name
        and ent.name:match("^animalia:") then
            if ent.lasso_player
            and ent.lasso_player == player then
                return true
            end
        end
    end
    return false
end


minetest.register_entity("animalia:lasso_visual", {
    hp_max = 1,
    armor_groups = {immortal = 1},
    physical = false,
    collisionbox = {0, 0, 0, 0, 0, 0},
    visual = "mesh",
    mesh = "animalia_lasso.b3d",
    visual_size = {x = 2, y = 2},
    textures = {"animalia_lasso_cube.png"},
    is_visible = true,
    makes_footstep_sound = false,
    glow = 1,
    on_step = function(self, dtime)
        self.object:set_armor_groups({immortal = 1})
        if not self.parent
        or not self.anchor_pos
        or (self.parent
        and (not mobkit.is_alive(self.parent)
        or not self.parent:get_luaentity().caught_with_lasso)) then
            self.object:remove()
            return
        end
        local pos = mobkit.get_stand_pos(self.parent)
        pos.y = pos.y + (self.parent:get_luaentity().height * 0.5)
        self.object:set_pos(self.anchor_pos)
        local rot = vector.dir_to_rotation(vector.direction(self.anchor_pos, pos))
        self.object:set_rotation(rot)
        self.object:set_properties({
            visual_size = {x = 6, z = 10 * vector.distance(self.anchor_pos, pos), y = 6}
        })
    end
})

minetest.register_entity("animalia:lasso_fence_ent", {
    hp_max = 1,
    physical = false,
    collisionbox = {-0.25,-0.25,-0.25, 0.25,0.25,0.25},
    visual = "cube",
    visual_size = {x = 0.3, y = 0.3},
    mesh = "model",
    textures = {
        "animalia_lasso_cube.png",
        "animalia_lasso_cube.png",
        "animalia_lasso_cube.png",
        "animalia_lasso_cube.png",
        "animalia_lasso_cube.png",
        "animalia_lasso_cube.png",
    },
    makes_footstep_sound = false,
    on_step = function(self)
        if not self.parent
        or not self.parent:get_luaentity()
        or not self.parent:get_luaentity().lasso_pos then
            self.object:remove()
            return
        end
        local pos = self.object:get_pos()
        local node = minetest.get_node(pos)
        if not minetest.registered_nodes[node.name].walkable
        or minetest.get_item_group(node.name, "fence") < 1 then
            local ent = self.parent:get_luaentity()
            ent.lasso_pos = mobkit.remember(ent, "lasso_pos", nil)
            ent.caught_with_lasso = nil
            if ent.lasso_visual then
                ent.lasso_visual:remove()
                ent.lasso_visual = nil
            end
            minetest.add_item(self.object:get_pos(), "animalia:lasso")
            self.object:remove()
            return
        end
    end,
    on_rightclick = function(self)
        if self.parent then
            local ent = self.parent:get_luaentity()
            ent.lasso_pos = mobkit.remember(ent, "lasso_pos", nil)
            ent.caught_with_lasso = nil
            if ent.lasso_visual then
                ent.lasso_visual:remove()
                ent.lasso_visual = nil
            end
        end
        local dirs = {
            vector.new(1, 0, 0),
            vector.new(-1, 0, 0),
            vector.new(0, 1, 0),
            vector.new(0, -1, 0),
            vector.new(0, 0, 1),
            vector.new(0, 0, -1),
        }
        for i = 1, 6 do
            local pos = vector.add(self.object:get_pos(), dirs[i])
            local name = minetest.get_node(pos).name
            if not minetest.registered_nodes[name].walkable then
                minetest.add_item(pos, "animalia:lasso")
                break
            end
        end
        self.object:remove()
    end,
    on_punch = function(self)
        if self.parent then
            local ent = self.parent:get_luaentity()
            ent.lasso_pos = mobkit.remember(ent, "lasso_pos", nil)
            ent.caught_with_lasso = nil
            if ent.lasso_visual then
                ent.lasso_visual:remove()
                ent.lasso_visual = nil
            end
        end
        local dirs = {
            vector.new(1, 0, 0),
            vector.new(-1, 0, 0),
            vector.new(0, 1, 0),
            vector.new(0, -1, 0),
            vector.new(0, 0, 1),
            vector.new(0, 0, -1),
        }
        for i = 1, 6 do
            local pos = vector.add(self.object:get_pos(), dirs[i])
            local name = minetest.get_node(pos).name
            if not minetest.registered_nodes[name].walkable then
                minetest.add_item(pos, "animalia:lasso")
                break
            end
        end
        self.object:remove()
    end
})

minetest.register_craftitem("animalia:lasso", {
    description = "Lasso",
    inventory_image = "animalia_lasso.png",
    on_secondary_use = function(itemstack, placer, pointed_thing)
        if pointed_thing.type == "object" then
            if pointed_thing.ref:is_player() then return end
            local ent = pointed_thing.ref:get_luaentity()
            if not ent.name:match("^animalia:") or not ent.catch_with_net then
                return
            end
            if not ent.caught_with_lasso
            and not is_lasso_in_use(placer) then
                ent.caught_with_lasso = true
                ent.lasso_player = placer
            elseif ent.lasso_player
            and ent.lasso_player == placer then
                ent.caught_with_lasso = nil
                ent.lasso_player = nil
            end
        end
    end,
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type == "node" then
            local pos = minetest.get_pointed_thing_position(pointed_thing)
            if minetest.get_item_group(minetest.get_node(pos).name, "fence") > 0 then
                local objects = minetest.get_objects_inside_radius(placer:get_pos(), 21)
                for _, obj in ipairs(objects) do
                    if obj:get_luaentity()
                    and obj:get_luaentity().lasso_player
                    and obj:get_luaentity().lasso_player == placer then
                        obj:get_luaentity().lasso_pos = pos
                        obj:get_luaentity().lasso_player = nil
                        local object = minetest.add_entity(pos, "animalia:lasso_fence_ent")
                        object:get_luaentity().parent = obj
                        itemstack:take_item(1)
                        break
                    end
                end
            end
        end
        return itemstack
    end
})

minetest.register_craft({
    output = "animalia:lasso",
    recipe = {
        {"", "farming:string", "farming:string"},
        {"", "animalia:leather", "farming:string"},
        {"farming:string", "", ""}
    }
})

-------------
-- Cat Toy -- Used to quickly increase trust with Cats
-------------

minetest.register_craftitem("animalia:cat_toy", {
    description = "Cat Toy",
    inventory_image = "animalia_cat_toy.png",
    wield_image = "animalia_cat_toy.png^[transformFYR90",
})

minetest.register_craft({
    output = "animalia:cat_toy",
    recipe = {
        {"", "", "farming:string"},
        {"", "group:stick", "farming:string"},
        {"group:stick", "", "group:feather"}
    }
})

------------
-- Saddle -- Can be attached to a tamed Horse to make it ridable
------------

minetest.register_craftitem("animalia:saddle", {
    description = "Saddle",
    inventory_image = "animalia_saddle.png",
})

minetest.register_craft({
    output = "animalia:saddle",
    recipe = {
        {"animalia:leather", "animalia:leather", "animalia:leather"},
        {"animalia:leather", "default:steel_ingot", "animalia:leather"},
        {"farming:string", "", "farming:string"}
    }
})

------------
-- Shears -- Used to shear Sheep
------------

minetest.register_tool("animalia:shears", {
	description = "Shears",
	inventory_image = "animalia_shears.png",
	groups = {flammable = 2}
})

minetest.register_craft({
	output = "animalia:shears",
	recipe = {
		{"", "default:steel_ingot", ""},
		{"", "animalia:leather", "default:steel_ingot"}
	}
})