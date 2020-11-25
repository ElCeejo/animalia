------------
-- Turkey --
------------

local blend = better_fauna.frame_blend

local function turkey_logic(self)

	if self.hp <= 0 then
		mob_core.on_die(self)
		return
	end
	local prty = mobkit.get_queue_priority(self)
	local player = mobkit.get_nearby_player(self)

	if mobkit.timer(self,1) then

		mob_core.vitals(self)
		mob_core.random_sound(self, 12)

		if prty < 3
        and self.breeding then
            better_fauna.hq_fowl_breed(self, 3)
		end
		
        if prty < 2
        and player then
            if self.attention_span < 5 then
                if mob_core.follow_holding(self, player) then
                    better_fauna.hq_follow_player(self, 2, player)
                    self.attention_span = self.attention_span + 1
                end
            end
		end

		if mobkit.is_queue_empty_high(self) then
			mob_core.hq_roam(self, 0)
		end
	end
end

minetest.register_entity("better_fauna:turkey",{
	max_hp = 10,
	view_range = 16,
	armor_groups = {fleshy = 100},
	physical = true,
	collide_with_objects = true,
	collisionbox = {-0.3, -0.2, -0.3, 0.3, 0.4, 0.3},
	visual_size = {x = 7, y = 7},
	scale_stage1 = 0.25,
    scale_stage2 = 0.5,
    scale_stage3 = 0.75,
	visual = "mesh",
	mesh = "better_fauna_turkey.b3d",
	female_textures = {"better_fauna_turkey_hen.png"},
	male_textures = {"better_fauna_turkey_tom.png"},
	child_textures = {"better_fauna_turkey_chick.png"},
    animation = {
		stand = {range = {x = 0, y = 0}, speed = 1, frame_blend = blend, loop = true},
		walk = {range = {x = 10, y = 30}, speed = 30, frame_blend = blend, loop = true},
		run = {range = {x = 10, y = 30}, speed = 45, frame_blend = blend, loop = true},
        fall = {range = {x = 40, y = 60}, speed = 30, frame_blend = blend, loop = true},
	},
    sounds = {
        alter_child_pitch = true,
        random = {
            name = "better_fauna_turkey_idle",
            gain = 1.0,
            distance = 8
        },
        hurt = {
            name = "better_fauna_turkey_hurt",
            gain = 1.0,
            distance = 8
        },
        death = {
            name = "better_fauna_turkey_death",
            gain = 1.0,
            distance = 8
        }
    },
	max_speed = 4,
	stepheight = 1.1,
	jump_height = 1.1,
	buoyancy = 0.25,
	lung_capacity = 10,
    timeout = 1200,
    ignore_liquidflag = false,
    core_growth = false,
	push_on_collide = true,
	catch_with_net = true,
	follow = {
		"farming:seed_cotton",
		"farming:seed_wheat"
	},
	drops = {
		{name = "better_fauna:feather", chance = 1, min = 1, max = 2},
		{name = "better_fauna:turkey_raw", chance = 1, min = 3, max = 5}
	},
	on_step = better_fauna.on_step,
	on_activate = better_fauna.on_activate,
	get_staticdata = mobkit.statfunc,
	phsyics = better_fauna.lightweight_physics,
	logic = turkey_logic,
    on_rightclick = function(self, clicker)
		if better_fauna.feed_tame(self, clicker, 1, false, true) then return end
		mob_core.protect(self, clicker, false)
		mob_core.nametag(self, clicker, true)
	end,
	on_punch = function(self, puncher, _, tool_capabilities, dir)
		mobkit.clear_queue_high(self)
		mob_core.on_punch_basic(self, puncher, tool_capabilities, dir)
		better_fauna.hq_sporadic_flee(self, 10, puncher)
	end,
})

mob_core.register_spawn_egg("better_fauna:turkey", "352b22", "2f2721")

mob_core.register_spawn({
	name = "better_fauna:turkey",
	nodes = {"default:dry_dirt_with_dry_grass", "default:dirt_with_grass"},
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	min_rad = 24,
	max_rad = 256,
	group = 6,
	optional = {
		biomes = {
			"deciduous_forest",
			"taiga"
		}
	}
}, 16, 6)


minetest.register_craftitem("better_fauna:turkey_raw", {
	description = "Raw Turkey",
	inventory_image = "better_fauna_turkey_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2},
})

minetest.register_craftitem("better_fauna:turkey_cooked", {
	description = "Cooked Turkey",
	inventory_image = "better_fauna_turkey_cooked.png",
	on_use = minetest.item_eat(6),
	groups = {flammable = 2},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "better_fauna:turkey_raw",
	output = "better_fauna:turkey_cooked",
})