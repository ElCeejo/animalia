---------
-- API --
---------

animalia.walkable_nodes = {}

minetest.register_on_mods_loaded(function()
    for name in pairs(minetest.registered_nodes) do
        if name ~= "air" and name ~= "ignore" then
            if minetest.registered_nodes[name].walkable then
                table.insert(animalia.walkable_nodes, name)
            end
        end
    end
end)

-- Math --

local pi = math.pi
local random = math.random
local abs = math.abs
local deg = math.deg

-- Vector Math --

local vec_dir = vector.direction
local vec_add = vector.add
local vec_sub = vector.subtract
local vec_multi = vector.multiply
local vec_divide = vector.divide
local vec_len = vector.length

local dir2yaw = minetest.dir_to_yaw
local yaw2dir = minetest.yaw_to_dir

--------------
-- Settings --
--------------

local creative = minetest.settings:get_bool("creative_mode")

---------------------
-- Local Utilities --
---------------------

function animalia.correct_name(str)
    if str then
        if str:match(":") then str = str:split(":")[2] end
        return (string.gsub(" " .. str, "%W%l", string.upper):sub(2):gsub("_", " "))
    end
end

local correct_name = animalia.correct_name

----------------------
-- Global Utilities --
----------------------

function animalia.particle_spawner(pos, texture, type, min_pos, max_pos)
    type = type or "float"
    min_pos = min_pos or {
        x = pos.x - 2,
        y = pos.y - 2,
        z = pos.z - 2,
    }
    max_pos = max_pos or {
        x = pos.x + 2,
        y = pos.y + 2,
        z = pos.z + 2,
    }
	if type == "float" then
		minetest.add_particlespawner({
			amount = 16,
			time = 0.25,
			minpos = min_pos,
			maxpos = max_pos,
			minvel = {x = 0, y = 0.2, z = 0},
			maxvel = {x = 0, y = 0.25, z = 0},
			minexptime = 0.75,
			maxexptime = 1,
			minsize = 4,
			maxsize = 4,
			texture = texture,
			glow = 1,
		})
	elseif type == "splash" then
		minetest.add_particlespawner({
			amount = 6,
			time = 0.25,
			minpos = {x = pos.x - 7/16, y = pos.y + 0.6, z = pos.z - 7/16},
			maxpos = {x = pos.x + 7/16, y = pos.y + 0.6, z = pos.z + 7/16},
			minvel = {x = -1, y = 2, z = -1},
			maxvel = {x = 1, y = 5, z = 1},
			minacc = {x = 0, y = -9.81, z = 0},
			maxacc = {x = 0, y = -9.81, z = 0},
			minsize = 2,
			maxsize = 4,
			collisiondetection = true,
			texture = texture,
		})
	end
end

function animalia.get_average_pos(vectors)
    local sum = {x = 0, y = 0, z = 0}
    for _, vec in pairs(vectors) do sum = vec_add(sum, vec) end
    return vec_divide(sum, #vectors)
end

----------------------
-- Entity Utilities --
----------------------

function animalia.get_group_positions(name, pos, radius)
    local objects = minetest.get_objects_in_area(vec_sub(pos, radius), vec_add(pos, radius))
    local group = {}
    for i = 1, #objects do
        local object = objects[i]
        if object
        and object:get_luaentity()
        and object:get_luaentity().name == name then
            table.insert(group, object:get_pos())
        end
    end
    return group
end

function animalia.get_group(self)
    local pos = self.object:get_pos()
    local radius = self.tracking_range
    local objects = minetest.get_objects_in_area(vec_sub(pos, radius), vec_add(pos, radius))
    local group = {}
    for i = 1, #objects do
        local object = objects[i]
        if object
        and object ~= self.object
        and object:get_luaentity()
        and object:get_luaentity().name == self.name then
            table.insert(group, object)
        end
    end
    return group
end


function animalia.get_nearby_mate(self, name)
    local objects = minetest.get_objects_inside_radius(self:get_center_pos(), self.tracking_range)
	for _, object in ipairs(objects) do
        if creatura.is_alive(object)
        and not object:is_player()
        and object:get_luaentity().name == name
        and object:get_luaentity().gender ~= self.gender
        and object:get_luaentity().breeding then
            return object
        end
	end
end

-------------------
-- Mob Functions --
-------------------

local function activate_nametag(self)
    self.nametag = self:recall("nametag") or nil
    if not self.nametag then return end
    self.object:set_properties({
        nametag = self.nametag,
        nametag_color = "#FFFFFF"
    })
end

function animalia.initialize_api(self)
    self.gender = self:recall("gender") or nil
    if not self.gender then
        local genders = {"male", "female"}
        self.gender = self:memorize("gender", genders[random(2)])
    end
    self.food = self:recall("food") or 0
    self.gotten = self:recall("gotten") or false
    self.breeding = false
    self.breeding_cooldown = self:recall("breeding_cooldown") or 0
    activate_nametag(self)
    if self.growth_scale then
        self:memorize("growth_scale", self.growth_scale) -- This is for spawning children
    end
    self.growth_scale = self:recall("growth_scale") or 1
    self:set_scale(self.growth_scale)
    if self.growth_scale < 0.8
    and self.child_textures then
        if not self.texture_no then
            self.texture_no = random(#self.child_textures)
        end
        self:set_texture(self.texture_no, self.child_textures)
        return
    elseif self.growth_scale > 0.7
    and self.male_textures
    and self.female_textures then
        if not self.texture_no then
            self.texture_no = random(#self[self.gender .. "_textures"])
        end
        self:set_texture(self.texture_no, self[self.gender .. "_textures"])
        return
    end
end

function animalia.step_timers(self)
    self.breeding_cooldown = (self.breeding_cooldown or 30) - self.dtime
    if self.breeding
    and self.breeding_cooldown <= 30 then
        self.breeding = false
    end
    self:memorize("breeding_cooldown", self.breeding_cooldown)
end

function animalia.do_growth(self, interval)
    if self.growth_scale
    and self.growth_scale < 0.9 then
        if self:timer(interval) then
            self.growth_scale = self.growth_scale + 0.1
            self:set_scale(self.growth_scale)
            if self.growth_scale < 0.8
            and self.child_textures then
                local tex_no = self.texture_no
                if not self.child_textures[tex_no] then
                    tex_no = 1
                end
                self:set_texture(tex_no, self.child_textures)
            elseif self.growth_scale == 0.8 then
                if self.male_textures
                and self.female_textures then
                    if #self.child_textures == 1 then
                        self.texture_no = random(#self[self.gender .. "_textures"])
                    end
                    self:set_texture(self.texture_no, self[self.gender .. "_textures"])
                else
                    if #self.child_textures == 1 then
                        self.texture_no = random(#self.textures)
                    end
                    self:set_texture(self.texture_no, self.textures)
                end
            end
            self:memorize("growth_scale", self.growth_scale)
        end
    end
end

function animalia.set_nametag(self, clicker)
    local item = clicker:get_wielded_item()
    if item
    and item:get_name() ~= "animalia:nametag" then
        return
    end
    local name = item:get_meta():get_string("name")
    if not name
    or name == "" then
        return
    end
    self.nametag = self:memorize("nametag", name)
    self.despawn_after = self:memorize("despawn_after", nil)
    activate_nametag(self)
    if not creative then
        item:take_item()
        clicker:set_wielded_item(item)
    end
    return true
end

-----------------------
-- Dynamic Animation --
-----------------------

local function clamp_bone_rot(n) -- Fixes issues with bones jittering when yaw clamps
    if n < -180 then
        n = n + 360
    elseif n > 180 then
        n = n - 360
    end
    if n < -60 then
        n = -60
    elseif n > 60 then
        n = 60
    end
    return n
end

local function interp_bone_rot(a, b, w) -- Smoothens bone movement
    if abs(a - b) > deg(pi) then
        if a < b then
            return ((a + (b - a) * w) + (deg(pi) * 2))
        elseif a > b then
            return ((a + (b - a) * w) - (deg(pi) * 2))
        end
    end
    return a + (b - a) * w
end

function animalia.move_head(self, tyaw, pitch)
    local data = self.head_data
    local _, rot = self.object:get_bone_position(data.bone or "Head.CTRL")
    local yaw = self.object:get_yaw()
    local look_yaw = clamp_bone_rot(deg(yaw - tyaw))
    local look_pitch = 0
    if pitch then
        look_pitch = clamp_bone_rot(deg(pitch))
    end
    if tyaw ~= yaw then
        look_yaw = look_yaw * 0.66
    end
    yaw = interp_bone_rot(rot.z, look_yaw, 0.1)
    local ptch = interp_bone_rot(rot.x, look_pitch + data.pitch_correction, 0.1)
    self.object:set_bone_position(data.bone or "Head.CTRL", data.offset, {x = ptch, y = yaw, z = yaw})
end

function animalia.head_tracking(self)
    if not self.head_data then return end
    local yaw = self.object:get_yaw()
    local pos = self.object:get_pos()
    local v = vec_add(pos, vec_multi(yaw2dir(yaw), self.head_data.pivot_h))
    pos.x = v.x
    pos.y = pos.y + self.head_data.pivot_v
    pos.z = v.z
    --[[minetest.add_particle({
        pos = pos,
        velocity = {x=0, y=0, z=0},
        acceleration = {x=0, y=0, z=0},
        expirationtime = 0.1,
        size = 8,
        collisiondetection = false,
        vertical = false,
        texture = "mob_core_green_particle.png",
        playername = "singleplayer"
    })]]
    local vel = self.object:get_velocity()
    if abs(yaw - self.last_yaw) < 0.1 then
        animalia.move_head(self, yaw)
    else
        animalia.move_head(self, self._tyaw)
    end
    if not self.head_tracking
    and self:timer(3)
    and random(4) < 2 then
        local objects = minetest.get_objects_inside_radius(pos, 6)
        for _, object in ipairs(objects) do
            if object:is_player() then
                self.head_tracking = object
                break
            end
        end
    else
        if not creatura.is_valid(self.head_tracking) then
            self.head_tracking = nil
            self.head_tracking_turn = nil
            return
        end
        local ppos = self.head_tracking:get_pos()
        ppos.y = ppos.y + 1.4
        local dir = vec_dir(pos, ppos)
        local tyaw = dir2yaw(dir)
        if self:timer(1)
        and abs(yaw - tyaw) > 1
        and abs(yaw - tyaw) < 5.3
        and self.head_tracking_turn then
            self.head_tracking = nil
            self.head_tracking_turn = nil
            dir.y = 0
            return
        elseif not self.head_tracking_turn then
            self.head_tracking_turn = tyaw
        end
        if self.head_tracking_turn
        and self._anim == "stand" then
            self:turn_to(self.head_tracking_turn, 2)
        end
        animalia.move_head(self, tyaw, dir.y)
    end
end

-----------------------
-- World Interaction --
-----------------------

function animalia.random_drop_item(item, chance)
    if random(chance) < 2 then
        local object = minetest.add_item(ItemStack(item))
        object:add_velocity({
            x = random(-2, 2),
            y = 1.5,
            z = random(-2, 2)
        })
    end
end

function animalia.protect_from_despawn(self)
    self._despawn = self:memorize("_despawn", false)
    self.despawn_after = self:memorize("despawn_after", false)
end

------------------------
-- Player Interaction --
------------------------

function animalia.feed(self, player, tame, breed)
    local item, item_name = self:follow_wielded_item(player)
    if item_name then
        if not creative then
            item:take_item()
            player:set_wielded_item(item)
        end
        if self.hp < self.max_health then
            self:heal(self.max_health / 5)
        end
        self.food = self.food + 1
        if self.food >= 5 then
            local pos = self:get_center_pos()
            local minp = vec_sub(pos, 1)
            local maxp = vec_add(pos, 1)
            self.food = 0
            local follow = self.follow
            if type(follow) == "table" then
                follow = follow[1]
            end
            if tame
            and not self.owner
            and (follow == item_name) then
                self.owner = self:memorize("owner", player:get_player_name())
                local name = correct_name(self.name)
                minetest.chat_send_player(player:get_player_name(), name .. " has been tamed!")
                if self.logic then
                    self:clear_task()
                end
                animalia.particle_spawner(pos, "creatura_particle_green.png", "float", minp, maxp)
                if not animalia.pets[self.owner][self.object] then
                    table.insert(animalia.pets[self.owner], self.object)
                end
            end
            if breed then
                if self.breeding then return false end
                if self.breeding_cooldown <= 0 then
                    self.breeding = true
                    self.breeding_cooldown = 60
                    animalia.particle_spawner(pos, "heart.png", "float", minp, maxp)
                end
            end
        end
        animalia.protect_from_despawn(self)
        return true
    end
    return false
end

local animate_player = {}

if minetest.get_modpath("default")
and minetest.get_modpath("player_api") then
    animate_player = player_api.set_animation
elseif minetest.get_modpath("mcl_player") then
    animate_player = mcl_player.set_animation
end

function animalia.mount(self, player, params)
    if not creatura.is_alive(player) then
        return
    end
    if (player:get_attach()
    and player:get_attach() == self.object)
    or not params then
        player:set_detach()
        player:set_properties({
            visual_size = {
                x = 1,
                y = 1
            }
        })
        player:set_eye_offset()
        if player_api then
            animate_player(player, "stand", 30)
            if player_api.player_attached then
                player_api.player_attached[player:get_player_name()] = false
            end
        end
        self.rider = nil
        return
    end
    if player_api then
        player_api.player_attached[player:get_player_name()] = true
    end
	minetest.after(0.2, function()
		if player
        and player:is_player()
        and player_api then
			animate_player(player, "sit", 30)
		end
	end)    self.rider = player
    local mob_size = self.object:get_properties().visual_size
    local player_size = player:get_properties().visual_size
    player:set_attach(self.object, "Torso", params.pos, params.rot)
    player:set_properties({
        visual_size = {
            x = player_size.x / mob_size.x,
            y = player_size.y / mob_size.y
        }
    })
    player:set_eye_offset({x = 0, y = 15, z = 0}, {x = 0, y = 15, z = 15})
end

-------------
-- Sensors --
-------------

function animalia.find_collision(self, dir)
    local pos = self.object:get_pos()
    local pos2 = vec_add(pos, vec_multi(dir, 16))
    local ray = minetest.raycast(pos, pos2, false, false)
    for pointed_thing in ray do
        if pointed_thing.type == "node" then
            return pointed_thing.under
        end
    end
    return nil
end

----------
-- Misc --
----------

function animalia.alias_mob(old_mob, new_mob)
    minetest.register_entity(":" .. old_mob, {
        on_activate = function(self)
            local pos = self.object:get_pos()
            minetest.add_entity(pos, new_mob)
            self.object:remove()
        end,
    })
end

--------------
-- Spawning --
--------------

animalia.registered_biome_groups = {}

function animalia.register_biome_group(name, def)
    animalia.registered_biome_groups[name] = def
    animalia.registered_biome_groups[name].biomes = {}
end

local function assign_biome_group(name)
    local def = minetest.registered_biomes[name]
    local turf = def.node_top
    local heat = def.heat_point or 0
    local humidity = def.humidity_point or 50
    local y_min = def.y_min
    local y_max = def.y_max
    for group, params in pairs(animalia.registered_biome_groups) do -- k, v in pairs
        if name:find(params.name_kw or "")
        and turf and turf:find(params.turf_kw or "")
        and heat >= params.min_heat
        and heat <= params.max_heat
        and humidity >= params.min_humidity
        and humidity <= params.max_humidity
        and (not params.min_height or y_min >= params.min_height)
        and (not params.max_height or y_max <= params.max_height) then
            table.insert(animalia.registered_biome_groups[group].biomes, name)
        end
    end
end

minetest.register_on_mods_loaded(function()
	for name in pairs(minetest.registered_biomes) do
        assign_biome_group(name)
	end
end)

local spawn_biomes = {
    ["animalia:bat"] = "cave",
    ["animalia:bird"] = "temperate",
    ["animalia:cat"] = "urban",
    ["animalia:chicken"] = "tropical",
    ["animalia:cow"] = "grassland",
    ["animalia:tropical_fish"] = "ocean",
    ["animalia:frog"] = "swamp",
    ["animalia:horse"] = "grassland",
    ["animalia:pig"] = "temperate",
    ["animalia:reindeer"] = "boreal",
    ["animalia:sheep"] = "grassland",
    ["animalia:turkey"] = "boreal",
    ["animalia:wolf"] = "boreal",
}

animalia.register_biome_group("temperate", {
    name_kw = "",
    turf_kw = "grass",
    min_heat = 45,
    max_heat = 70,
    min_humidity = 0,
    max_humidity = 50
})

animalia.register_biome_group("urban", {
    name_kw = "",
    turf_kw = "grass",
    min_heat = 0,
    max_heat = 100,
    min_humidity = 0,
    max_humidity = 100
})

animalia.register_biome_group("grassland", {
    name_kw = "",
    turf_kw = "grass",
    min_heat = 45,
    max_heat = 90,
    min_humidity = 0,
    max_humidity = 80
})

animalia.register_biome_group("boreal", {
    name_kw = "",
    turf_kw = "litter",
    min_heat = 10,
    max_heat = 55,
    min_humidity = 0,
    max_humidity = 80
})

animalia.register_biome_group("ocean", {
    name_kw = "ocean",
    turf_kw = "",
    min_heat = 0,
    max_heat = 100,
    min_humidity = 0,
    max_humidity = 100,
    max_height = 0
})

animalia.register_biome_group("swamp", {
    name_kw = "",
    turf_kw = "",
    min_heat = 55,
    max_heat = 90,
    min_humidity = 55,
    max_humidity = 90,
    max_height = 10,
    min_height = -20
})

animalia.register_biome_group("tropical", {
    name_kw = "",
    turf_kw = "litter",
    min_heat = 70,
    max_heat = 90,
    min_humidity = 65,
    max_humidity = 90
})

animalia.register_biome_group("cave", {
    name_kw = "under",
    turf_kw = "",
    min_heat = 0,
    max_heat = 100,
    min_humidity = 0,
    max_humidity = 100,
    max_height = 5
})

animalia.register_biome_group("common", {
    name_kw = "",
    turf_kw = "",
    min_heat = 25,
    max_heat = 75,
    min_humidity = 20,
    max_humidity = 80,
    min_height = 1
})

---------------
-- Libri API --
---------------

local function contains_item(inventory, item)
    return inventory and inventory:contains_item("main", ItemStack(item))
end

function animalia.get_libri(inventory)
    local list = inventory:get_list("main")
    for i = 1, inventory:get_size("main") do
        local stack = list[i]
        if stack:get_name()
        and stack:get_name() == "animalia:libri_animalia" then
            return stack, i
        end
    end
end

local get_libri = animalia.get_libri

function animalia.add_libri_page(self, player, page)
    local inv = minetest.get_inventory({type = "player", name = player:get_player_name()})
    if contains_item(inv, "animalia:libri_animalia") then
        local libri, list_i = get_libri(inv)
        local pages = minetest.deserialize(libri:get_meta():get_string("pages")) or {}
        if #pages > 0 then
            local add_page = true
            for i = 1, #pages do
                if pages[i].name == page.name then
                    add_page = false
                    break
                end
            end
            if add_page then
                table.insert(pages, page)
                libri:get_meta():set_string("pages", minetest.serialize(pages))
                inv:set_stack("main", list_i, libri)
                return true
            end
        else
            table.insert(pages, page)
            libri:get_meta():set_string("pages", minetest.serialize(pages))
            inv:set_stack("main", list_i, libri)
            return true
        end
    end
end

function animalia.get_item_list(list, offset_x, offset_y) -- Creates a visual list of items for Libri formspecs
    local size = 1 / #list
    if size < 0.45 then size = 0.45 end
    local spacing = 0.3
    local total_scale = size + spacing
    local max_horiz = 3
    local max_verti = 6
    local form = {}
    for i = 1, #list do
        local vert_multi = math.floor((i - 1) / max_horiz)
        local horz_multi = (total_scale * max_horiz) * vert_multi
        table.insert(form, "item_image[" .. offset_x + ((total_scale * i) - horz_multi) .. "," .. offset_y + (total_scale * vert_multi ).. ";" .. size .. "," .. size .. ";" .. list[i] .. "]")
    end
    return table.concat(form, "")
end

-- Libri should list: Spawn Biomes, Drops, Food, Taming Method, Catchability, and Lassoability


local function get_inventory_cube(name)
    local def = minetest.registered_nodes[name]
    local tiles
    if name:find(".png") then
        tiles = {
            name,
            name,
            name
        }
    elseif def then
        tiles = table.copy(def.tiles) or table.copy(def.textures)
    else
        return
    end
    if not tiles
    or type(tiles) ~= "table"
    or #tiles < 1 then
        return
    end
    for i = 1, #tiles do
        if type(tiles[i]) == "table" then
            tiles[i] = tiles[i].name
        end
    end
    local cube
    if #tiles < 3 then
        cube = minetest.inventorycube(tiles[1], tiles[1], tiles[1])
    else
        cube = minetest.inventorycube(tiles[1], tiles[3], tiles[3])
    end
    return cube
end

local function get_textures(name)
    local def = minetest.registered_entities[name]
    local textures = def.textures
    if not textures then
        if #def.female_textures < 2 then
            textures = {def.female_textures[1], def.male_textures[1]}
        else
            textures = {}
            local num = #def.female_textures
            for i = 1, num do
                if num + #def.male_textures < 7 then
                    textures = {unpack(def.male_textures), unpack(def.female_textures)}
                else
                    if i < num * 0.5 then
                        table.insert(textures, def.female_textures[i])
                    else
                        table.insert(textures, def.male_textures[i])
                    end
                end
            end
        end
    end
    return textures
end

local animalia_libri_info = {}

local libri_animal_info = {
    ["animalia:bat"] = {
        invcube = "default:stone",
        info = {
            domestication = {
                "While they can't be truly",
                "domesticated, Bats will begin ",
                "to trust you if you feed them ",
                "often. A Bat that trusts you will ",
                "not flee when you walk near it.",
                "This is useful as it allows ",
                "Players to keep them around ",
                "to harvest their guano, which ",
                "can be used as a powerful ",
                "fertilizer."
            },
            behavior = {
                "Bats are mostly harmless, and ",
                "can be found hanging from ",
                "trees and cliff ceilings during ",
                "the day. The only harm they ",
                "can cause it to property, with ",
                "guano accumulating ",
                "underneath them while they ",
                "rest. Being social creatures, it's ",
                "not uncommon to see a few ",
                "hanging from ceilings together ",
                "or swarming, which often ",
                "occurs at evening or when a ",
                "Player approaches."
            }
        }
    },
    ["animalia:bird"] = {
        info = {
            domestication = {
                "Cannot be tamed.",
            },
            behavior = {
                "Song Birds are found across ",
                "various biomes, except for ",
                "biomes too inhospitable like ",
                "deserts or tundras. They fly in ",
                "flocks that vary in size from 4 ",
                "or 5 individuals to large flocks ",
                "exceeding a dozen individuals. ",
                "Their calls vary between ",
                "species, making it easy to tell ",
                "what kind of birds are around."
            }
        }
    },
    ["animalia:cat"] = {
        info = {
            domestication = {
                "Unlike Wolves and Horses," ,
                "which are almost immediately ",
                "trusting upon being tamed, ",
                "Cats will remain untrusting ",
                "until you gain their trust. To do ",
                "so, you must feed and play ",
                "with it often. As trust builds ",
                "the cat will become more ",
                "comfortable in your presence, ",
                "and will be more receptive to ",
                "commands.",
            },
            behavior = {
                "Cats are very annoying ",
                "animals, to the point that ",
                "some may even call them a ",
                "pest. Their behavior in the ",
                "wild is somehow more tame ",
                "than their domesticated ",
                "behavior. They find immense ",
                "joy in running front of their ",
                "owner and even destroying ",
                "glass vessels. Despite this, ",
                "they are an incredibly popular ",
                "pet, especially for those who ",
                "don't often leave their home. ",
                "Like Wolves, a tamed Cat will ",
                "follow commands, but only if it ",
                "highly trusts it's owner."
            }
        }
    },
    ["animalia:chicken"] = {
        info = {
            domestication = {
                "Chickens are very valuable as a ",
                "livestock. They're a good ",
                "source of meat, but also lay ",
                "eggs. This, paired with their ",
                "small size, makes them great ",
                "for farming with limited space."
            },
            behavior = {
                "Chickens, or Jungle Fowl, are ",
                "most often found in groups. ",
                "They exhibit gender ",
                "dimorphism to a high degree, ",
                "with males having large tail ",
                "feathers. In the wild, they ",
                "dwell jungle floors, picking up ",
                "seeds and insects."
            }
        }
    },
    ["animalia:cow"] = {
        info = {
            domestication = {
                "Cows are commonplace on ",
                "farms because of their many ",
                "uses. They can be slaughtered ",
                "for beef and leather, and ",
                "females can be milked. Beef is ",
                "one of the most valuable ",
                "meats because of how much ",
                "satiation it provides, and ",
                "leather is valuable for crafting ",
                "various items."
            },
            behavior = {
                "Cows are always found in ",
                "groups of 3+ individuals. ",
                "Despite being capable of ",
                "inflicting damage, they will ",
                "always choose to flee, even ",
                "when in a large group. They ",
                "exhibit gender dimorphism, ",
                "with females having udders on ",
                "their belly."
            },
        }
    },
    ["animalia:frog"] = {
        info = {
            domestication = {
                "Cannot be tamed.",
            },
            behavior = {
                "Frogs are small creatures ",
                "almost exclusively found near ",
                "bodies of water. They will flee ",
                "to nearby water when a Player ",
                "approaches. They have quite ",
                "an affinity for water, moving ",
                "faster while in it and only ",
                "being able to breed when ",
                "submerged. They come to land ",
                "to search for food, which they ",
                "catch with their long tongue."
            },
        }
    },
    ["animalia:horse"] = {
        info = {
            domestication = {
                "Horses are one of the most ",
                "valuable animals to ",
                "domesticate because of their ",
                "ability carry Players and ",
                "maintain speed. They can ",
                "make traversing the world far ",
                "faster and easier, but aren't ",
                "easy to tame. To tame one, ",
                "you must keep your line of ",
                "sight lined up with the Horses ",
                "for a varying period of time. ",
                "This process is difficult but ",
                "well worth it."
            },
            behavior = {
                "Horses live in large groups, ",
                "wandering open grasslands. ",
                "They have a number of colors ",
                "and patterns, which are passed ",
                "down to their offspring, as ",
                "well as varying jumping and ",
                "running abilities."
            },
        }
    },
    ["animalia:reindeer"] = {
        info = {
            domestication = {
                "Cannot be tamed.",
            },
            behavior = {
                "Reindeer are found in large ",
                "groups in cold regions. They ",
                "stick tightly togther and move ",
                "in coordinated directions, even ",
                "while fleeing. They're also a ",
                "common food source for those ",
                "lost in taigas and tundras."
            }
        }
    },
    ["animalia:pig"] = {
        info = {
            domestication = {
                "Pigs are not quite as versatile ",
                "as other livestock like Cows or ",
                "Chickens, with their only ",
                "valuable resource being pork. ",
                "But they have a distinct ",
                "advantage by being able to ",
                "have more offspring at once ",
                "than Cows while also being ",
                "smaller."
            },
            behavior = {
                "Pigs in the wild can be very ",
                "destructive of ecosystems if ",
                "not controlled. Their ability to ",
                "reproduce quickly means ",
                "keeping populations under ",
                "control can be an issue. They ",
                "are known to destroy farmland ",
                "and will go as far as destroying ",
                "fences to do so."
            },
        }
    },
    ["animalia:sheep"] = {
        info = {
            domestication = {
                "Sheep are one of the most ",
                "useful animals to domesticate. ",
                "Their wool is a great resource ",
                "for crafting and building, and is ",
                "entirely renewable. Their wool ",
                "can also be dyed, though there ",
                "is little use for this."
            },
            behavior = {
                "Sheep are well known for ",
                "living in large groups. In the ",
                "wild these groups range from 4 ",
                "to 8 individuals, larger than ",
                "most other animals."
            }
        }
    },
    ["animalia:tropical_fish"] = {
        special_models = {
            [3] = "animalia_angelfish.b3d"
        },
        info = {
            domestication = {
                "Cannot be tamed."
            },
            behavior = {
                "All varieties of Tropical Fish ",
                "can be found in schools around ",
                "reefs. While they don't ",
                "provide food or any resources, ",
                "they are a beautiful sight to ",
                "see while traversing oceans."
            },
        }
    },
    ["animalia:turkey"] = {
        info = {
            domestication = {
                "Even though Turkeys take up ",
                "more space than Chickens, ",
                "they also produce more meat, ",
                "at the cost of laying less eggs. ",
                "This makes them a good option ",
                "for those who don't want to ",
                "build a farm large enough to ",
                "support Cows or other large ",
                "livestock but also don't need ",
                "many eggs."
            },
            behavior = {
                "Turkeys are similar ",
                "behaviorally to Chickens, but ",
                "spawn in colder biomes and ",
                "are slightly larger. They exhibit ",
                "gender dimorphism, with ",
                "males having a large fan of ",
                "feathers on their tail."
            }
        }
    },
    ["animalia:wolf"] = {
        info = {
            domestication = {
                "Their intelligence allows them ",
                "not only to form tight bonds ",
                "with players, but to also obey ",
                "orders. Once ordered to attack ",
                "a target, they will pursue it and ",
                "attack relentlessly, even if ",
                "death certain."
            },
            behavior = {
                "Wolves are found in packs of ",
                "up to 3. They hunt down Sheep ",
                "as a group and can quickly ",
                "overwhelm their target with ",
                "numbers. They're also ",
                "remarkebly intelligent, and ",
                "will remember players who ",
                "have harmed them and will ",
                "attack them on sight."
            }
        }
    }
}

-- Libri Utilities --

local function offset_info_text(offset_x, offset_y, tbl)
    local info_text = {}
    for i = 1, #tbl do
        local str = tbl[i]
        local center_offset = 0
        if string.len(str) < 30 then
            center_offset = (30 - string.len(str)) * 0.05
        end
        table.insert(info_text, "label[" .. offset_x + center_offset .. "," .. offset_y + i * 0.25 .. ";" .. minetest.colorize("#383329", tbl[i] .. "\n") .. "]")
    end
    return table.concat(info_text, "")
end

local function get_libri_page(mob_name, player_name)
    local def = minetest.registered_entities[mob_name]
    local animal_info = libri_animal_info[mob_name]
    -- Get Inventory Cube and Mob Texture
    local biome_group = spawn_biomes[mob_name]
    local spawn_biome = animalia.registered_biome_groups[biome_group].biomes[animalia_libri_info[player_name].biome_idx] or "grassland"
    local invcube
    if not minetest.registered_biomes[spawn_biome]
    or not minetest.registered_biomes[spawn_biome].node_top then
        invcube = get_inventory_cube("unknown_node.png")
    else
        invcube = get_inventory_cube(animal_info.invcube or minetest.registered_biomes[spawn_biome].node_top)
    end
    local texture = get_textures(mob_name)[animalia_libri_info[player_name].texture_idx]
    local mesh = def.mesh
    if libri_animal_info[mob_name].special_models
    and libri_animal_info[mob_name].special_models[animalia_libri_info[player_name].texture_idx] then
        mesh = libri_animal_info[mob_name].special_models[animalia_libri_info[player_name].texture_idx]
    end
    -- Create Formspec
    local form = {
        -- Background
        "formspec_version[3]",
        "size[16,10]",
        "background[-0.7,-0.5;17.5,11.5;animalia_libri_bg.png]",
        "image[-0.7,-0.5;17.5,11.5;animalia_libri_info_fg.png]",
        -- Mesh
        "model[1.5,1.5;5,5;libri_mesh;" .. mesh .. ";" .. texture .. ";-30,225;false;false;0,0;0]",
        -- Spawn Biome Group
        "image[0.825,8.15;1,1;" .. invcube .. "]",
        "tooltip[0.825,8.15;1,1;" .. correct_name(spawn_biome) .. "]",
        -- Health
        "image[2.535,8.15;1,1;animalia_libri_health_fg.png]",
        "label[3.25,9;x" .. def.max_health / 2 .. "]",
        -- Net
        "item_image[4.25,8.15;1,1;animalia:lasso]",
        "image[4.75,8.75;0.5,0.5;animalia_libri_" .. tostring(def.catch_with_lasso or false) .. "_icon.png]",
        -- Lasso
        "item_image[6,8.15;1,1;animalia:net]",
        "image[6.5,8.75;0.5,0.5;animalia_libri_" .. tostring(def.catch_with_net or false) .. "_icon.png]",
        -- Labels
        "label[9.5,7.25;" .. minetest.colorize("#383329", "Drops:") .. "]",
        "label[14,7.25;" .. minetest.colorize("#383329", "Eats:") .. "]",
        -- Info Text
        "label[9.25,1.5;" .. minetest.colorize("#000000", "Domestication:") .. "]",
        "label[13.5,1.5;" .. minetest.colorize("#000000", "Behavior:") .. "]",
    }
    -- Mob Info
    if libri_animal_info[mob_name] then
        if libri_animal_info[mob_name].info.domestication then
            table.insert(form, offset_info_text(8.5, 2, libri_animal_info[mob_name].info.domestication))
        end
        if libri_animal_info[mob_name].info.behavior then
            table.insert(form, offset_info_text(12.5, 2, libri_animal_info[mob_name].info.behavior))
        end
    end
    if def.follow then
        table.insert(form, animalia.get_item_list(def.follow, 12.35, 8.05))
    end
    if def.drops then
        local drops = {}
        for i = 1, #def.drops do
            table.insert(drops, def.drops[i].name)
        end
        table.insert(form, animalia.get_item_list(drops, 8, 8.05))
    end
    return table.concat(form, "")
end

local function update_libri(player_name, mob_name)
    if not animalia_libri_info[player_name]
    or animalia_libri_info[player_name].name ~= mob_name then
        return
    end
    local texture_idx = animalia_libri_info[player_name].texture_idx or 1
    local biome_idx = animalia_libri_info[player_name].biome_idx or 1
    if texture_idx >= #get_textures(mob_name) then
        texture_idx = 1
    else
        texture_idx = texture_idx + 1
    end
    local spawn_biomes = animalia.registered_biome_groups[spawn_biomes[mob_name]].biomes
    if biome_idx >= #spawn_biomes then
        biome_idx = 1
    else
        biome_idx = biome_idx + 1
    end
    animalia_libri_info[player_name] = {
        texture_idx = texture_idx,
        biome_idx = biome_idx,
        name = mob_name
    }
    minetest.show_formspec(player_name, "animalia:libri_" .. string.split(mob_name, ":")[2], get_libri_page(mob_name, player_name))
    minetest.after(4, function()
        update_libri(player_name, mob_name)
    end)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    local player_name = player:get_player_name()
	if formname == "animalia:libri_main" then
        animalia_libri_info[player_name] = {}
        for i = 1, #animalia.animals do
            local name = string.split(animalia.animals[i], ":")[2]
            if fields["pg_" .. name] then
                -- Get data for mob and biome visuals
                animalia_libri_info[player_name] = {
                    texture_idx = 1,
                    biome_idx = 1,
                    name = animalia.animals[i]
                }
                update_libri(player_name, animalia.animals[i])
                break
            end
        end
        if fields["btn_next"] then
            local pages = animalia.libri_pages[player_name]
            if pages
            and #pages > 1 then
                animalia.show_libri_main_form(player, pages, 2)
            end
        end
	end
    if formname:match("^animalia:libri_") then
        if fields.quit or fields.key_enter then
            animalia_libri_info[player_name] = nil
        end
    end
end)