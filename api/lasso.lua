-----------
-- Lasso --
-----------

local abs = math.abs

function animalia.initialize_lasso(self)
    self.lasso_origin = self:recall("lasso_origin") or nil
    if self.lasso_origin then
        self.caught_with_lasso = true
        if type(self.lasso_origin) == "table"
        and minetest.get_item_group(minetest.get_node(self.lasso_origin).name, "fence") > 0 then
            local object = minetest.add_entity(self.lasso_origin, "animalia:lasso_fence_ent")
            object:get_luaentity().parent = self.object
        elseif type(self.lasso_origin) == "string"
        and minetest.get_player_by_name(self.lasso_origin) then
            self.lasso_origin = minetest.get_player_by_name(self.lasso_origin)
        else
            self:forget("lasso_origin")
        end
    end
end

function animalia.set_lasso_visual(self, target)
    if not creatura.is_alive(self)
    or (self.lasso_visual
    and self.lasso_visual:get_luaentity()) then return end
    local pos = self.object:get_pos()
    local object = minetest.add_entity(pos, "animalia:lasso_visual")
    local ent = object:get_luaentity()
    self.lasso_visual = object
    self.lasso_origin = target
    ent.parent = self.object
    ent.lasso_origin = target
    return object
end

function animalia.update_lasso_effects(self)
    if not creatura.is_alive(self) then return end
    if self.caught_with_lasso
    and self.lasso_origin then
        local pos = self.object:get_pos()
        pos.y = pos.y + (self:get_height() * 0.5)
        animalia.set_lasso_visual(self, self.lasso_origin)
        if type(self.lasso_origin) == "userdata"
        or type(self.lasso_origin) == "string" then
            if type(self.lasso_origin) == "string" then
                self.lasso_origin = minetest.get_player_by_name(self.lasso_origin)
                if not self.lasso_origin then
                    self.caught_with_lasso = nil
                    self.lasso_origin = nil
                    self:forget("lasso_origin")
                    if self.lasso_visual then
                        self.lasso_visual:remove()
                        self.lasso_visual = nil
                    end
                    return
                end
            end
            self:memorize("lasso_origin", self.lasso_origin:get_player_name())
            -- Get distance to lasso player
            local player = self.lasso_origin
            local lasso_origin = player:get_pos()
            lasso_origin.y = lasso_origin.y + 1
            local dist = vector.distance(pos, lasso_origin)
            if player:get_wielded_item():get_name() ~= "animalia:lasso"
            or vector.distance(pos, lasso_origin) > 16 then
                self.caught_with_lasso = nil
                self.lasso_origin = nil
                self:forget("lasso_origin")
                if self.lasso_visual then
                    self.lasso_visual:remove()
                    self.lasso_visual = nil
                end
            end
            -- Apply physics
            if dist > 6
            or abs(lasso_origin.y - pos.y) > 8 then
                local p_target = vector.add(pos, vector.multiply(vector.direction(pos, lasso_origin), dist * 0.8))
                local g = -0.18
                local v = vector.new(0, 0, 0)
                v.x = (1.0 + (0.005 * dist)) * (p_target.x - pos.x) / dist
                v.y = -((1.0 + (0.03 * dist)) * ((lasso_origin.y - 4) - pos.y) / (dist * (g * dist)))
                v.z = (1.0 + (0.005 * dist)) * (p_target.z - pos.z) / dist
                self.object:add_velocity(v)
            end
        elseif type(self.lasso_origin) == "table" then
            self:memorize("lasso_origin", self.lasso_origin)
            local lasso_origin = self.lasso_origin
            local dist = vector.distance(pos, lasso_origin)
            if dist > 6
            or abs(lasso_origin.y - pos.y) > 8 then
                local p_target = vector.add(pos, vector.multiply(vector.direction(pos, lasso_origin), dist * 0.8))
                local g = -0.18
                local v = vector.new(0, 0, 0)
                v.x = (1.0 + (0.005 * dist)) * (p_target.x - pos.x) / dist
                v.y = -((1.0 + (0.03 * dist)) * ((lasso_origin.y - 4) - pos.y) / (dist * (g * dist)))
                v.z = (1.0 + (0.005 * dist)) * (p_target.z - pos.z) / dist
                self.object:add_velocity(v)
            end
            local objects = minetest.get_objects_inside_radius(lasso_origin, 1)
            local is_lasso_attached = false
            for _, object in ipairs(objects) do
                if object
                and object:get_luaentity()
                and object:get_luaentity().name == "animalia:lasso_fence_ent" then
                    is_lasso_attached = true
                end
            end
            if not is_lasso_attached then
                self.caught_with_lasso = nil
                self.lasso_origin = nil
                self:forget("lasso_origin")
                if self.lasso_visual then
                    self.lasso_visual:remove()
                    self.lasso_visual = nil
                end
            end
        else
            local objects = minetest.get_objects_inside_radius(self.lasso_origin, 0.4)
            for _, object in ipairs(objects) do
                if object
                and object:get_luaentity()
                and object:get_luaentity().name == "animalia:lasso_fence_ent" then
                    minetest.add_item(object:get_pos(), "animalia:lasso")
                    object:remove()
                end
            end
            self.caught_with_lasso = nil
            self.lasso_origin = nil
            self:forget("lasso_origin")
            if self.lasso_visual then
                self.lasso_visual:remove()
                self.lasso_visual = nil
            end
        end
    end
end

local function is_lasso_in_use(player)
    for _, ent in pairs(minetest.luaentities) do
        if ent.name
        and ent.name:match("^animalia:") then
            if ent.lasso_origin
            and type(ent.lasso_origin) == "userdata"
            and ent.lasso_origin == player then
                return true
            end
        end
    end
    return false
end

local function update_lasso_rotation(self)
    if not self.parent
    or not self.lasso_origin then self.object:remove() return end
    local lasso_origin = self.lasso_origin
    if type(lasso_origin) == "userdata" then
        lasso_origin = lasso_origin:get_pos()
        lasso_origin.y = lasso_origin.y + 1
    end
    local object = self.parent
    if not object then return end
    local pos = object:get_pos()
    pos.y = pos.y + object:get_luaentity():get_height()
    local rot = vector.dir_to_rotation(vector.direction(lasso_origin, pos))
    self.object:set_pos(lasso_origin)
    self.object:set_rotation(rot)
    self.object:set_properties({
        visual_size = {x = 6, z = 10 * vector.distance(pos, lasso_origin), y = 6}
    })
end

minetest.register_entity("animalia:lasso_visual", {
    hp_max = 1,
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
        or not self.lasso_origin
        or (self.parent
        and (not creatura.is_alive(self.parent)
        or not self.parent:get_luaentity().caught_with_lasso)) then
            self.object:remove()
            return
        end
        update_lasso_rotation(self)
    end
})

minetest.register_entity("animalia:frog_tongue_visual", {
    hp_max = 1,
    physical = false,
    collisionbox = {0, 0, 0, 0, 0, 0},
    visual = "mesh",
    mesh = "animalia_lasso.b3d",
    visual_size = {x = 2, y = 2},
    textures = {"animalia_frog_tongue.png"},
    is_visible = true,
    makes_footstep_sound = false,
    on_step = function(self, dtime)
        self.object:set_armor_groups({immortal = 1})
        if not self.parent
        or not self.lasso_origin
        or (self.parent
        and (not creatura.is_alive(self.parent)
        or not self.parent:get_luaentity().caught_with_lasso)) then
            self.object:remove()
            return
        end
        update_lasso_rotation(self)
    end
})

minetest.register_entity("animalia:lasso_fence_ent", {
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
        or not self.parent:get_luaentity().lasso_origin then
            self.object:remove()
            return
        end
        local pos = self.object:get_pos()
        local node = minetest.get_node(pos)
        if not minetest.registered_nodes[node.name].walkable
        or minetest.get_item_group(node.name, "fence") < 1 then
            local ent = self.parent:get_luaentity()
            ent.lasso_origin = ent:memorize("lasso_origin", nil)
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
            ent.lasso_origin = ent:memorize("lasso_origin", nil)
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
            ent.lasso_origin = ent:memorize("lasso_origin", nil)
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
            if not ent.catch_with_lasso then return end
            if not ent.caught_with_lasso
            and not is_lasso_in_use(placer) then
                ent.caught_with_lasso = true
                ent.lasso_origin = placer
            elseif ent.lasso_origin
            and ent.lasso_origin == placer then
                ent.caught_with_lasso = nil
                ent.lasso_origin = nil
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
                    and obj:get_luaentity().lasso_origin
                    and obj:get_luaentity().lasso_visual
                    and type(obj:get_luaentity().lasso_origin) == "userdata"
                    and obj:get_luaentity().lasso_origin == placer then
                        obj:get_luaentity().lasso_visual:get_luaentity().lasso_origin = pos
                        obj:get_luaentity().lasso_origin = pos
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