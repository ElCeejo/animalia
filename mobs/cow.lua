---------
-- Cow --
---------

local blend = better_fauna.frame_blend

local function cow_logic(self)
	
	if self.hp <= 0 then
		mob_core.on_die(self)
		return
	end

	local pos = mobkit.get_stand_pos(self)
	local prty = mobkit.get_queue_priority(self)
	local player = mobkit.get_nearby_player(self)

	mob_core.random_sound(self, 16/self.dtime)

	if mobkit.timer(self,1) then 

		mob_core.vitals(self)
		mob_core.growth(self)

		if math.random(1, 64) == 1 then
			self.gotten = mobkit.remember(self, "gotten", false)
		end

		if self.status ~= "following" then
            if self.attention_span > 1 then
                self.attention_span = self.attention_span - 1
                mobkit.remember(self, "attention_span", self.attention_span)
            end
		else
			self.attention_span = self.attention_span + 1
			mobkit.remember(self, "attention_span", self.attention_span)
		end

		if prty < 4
        and self.breeding then
            better_fauna.hq_breed(self, 4)
		end

		if prty < 3
		and self.gotten
		and math.random(1, 16) == 1 then
			better_fauna.hq_eat(self, 3)
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

local random = math.random

minetest.register_entity("better_fauna:cow",{
	max_hp = 20,
	view_range = 16,
	armor_groups = {fleshy = 100},
	physical = true,
	collide_with_objects = true,
	collisionbox = {-0.45, -0.55, -0.45, 0.45, 0.4, 0.45},
	visual_size = {x = 13, y = 13},
	scale_stage1 = 0.5,
    scale_stage2 = 0.65,
    scale_stage3 = 0.80,
	visual = "mesh",
	mesh = "better_fauna_cow.b3d",
	textures = {
		"better_fauna_cow_1.png",
		"better_fauna_cow_2.png",
		"better_fauna_cow_3.png",
		"better_fauna_cow_4.png"
	},
	animation = {
		stand = {range = {x = 30, y = 50}, speed = 10, frame_blend = blend, loop = true},
		walk = {range = {x = 1, y = 20}, speed = 20, frame_blend = blend, loop = true},
		run = {range = {x = 1, y = 20}, speed = 30, frame_blend = blend, loop = true},
	},
    sounds = {
        alter_child_pitch = true,
        random = {
            name = "better_fauna_cow_idle",
            gain = 1.0,
            distance = 8
        },
        hurt = {
            name = "better_fauna_cow_hurt",
            gain = 1.0,
            distance = 8
        },
        death = {
            name = "better_fauna_cow_death",
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
		"farming:wheat",
	},
	drops = {
		{name = "mobs:leather", chance = 1, min = 1, max = 2},
		{name = "better_fauna:beef_raw", chance = 1, min = 1, max = 4}
	},
	on_step = better_fauna.on_step,
	on_activate = better_fauna.on_activate,
	get_staticdata = mobkit.statfunc,
	logic = cow_logic,
	on_rightclick = function(self, clicker)
		if better_fauna.feed_tame(self, clicker, 1, false, true) then return end
		mob_core.protect(self, clicker, false)
		mob_core.nametag(self, clicker, true)

		local tool = clicker:get_wielded_item()
		local name = clicker:get_player_name()

		if tool:get_name() == "bucket:bucket_empty" then

			if self.child == true then
				return
			end

			if self.gotten == true then
				minetest.chat_send_player(name, "This Cow has already been milked.")
				return
			end

			local inv = clicker:get_inventory()

			tool:take_item()
			clicker:set_wielded_item(tool)

			if inv:room_for_item("main", {name = "better_fauna:bucket_milk"}) then
				clicker:get_inventory():add_item("main", "better_fauna:bucket_milk")
			else
				local pos = self.object:get_pos()
				pos.y = pos.y + 0.5
				minetest.add_item(pos, {name = "better_fauna:bucket_milk"})
			end

			self.gotten = mobkit.remember(self, "gotten", true)
			return
		end
	end,
	on_punch = function(self, puncher, _, tool_capabilities, dir)
		mobkit.clear_queue_high(self)
		mob_core.on_punch_basic(self, puncher, tool_capabilities, dir)
		better_fauna.hq_sporadic_flee(self, 20, puncher)
	end
})

minetest.register_craftitem("better_fauna:bucket_milk", {
	description = "Bucket of Milk",
	inventory_image = "better_fauna_milk_bucket.png",
	stack_max = 1,
	on_use = minetest.item_eat(8, "bucket:bucket_empty"),
	groups = {food_milk = 1, flammable = 3},
})

minetest.register_craftitem("better_fauna:beef_raw", {
	description = "Raw Beef",
	inventory_image = "better_fauna_beef_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2},
})

minetest.register_craftitem("better_fauna:beef_cooked", {
	description = "Steak",
	inventory_image = "better_fauna_beef_cooked.png",
	on_use = minetest.item_eat(8),
	groups = {flammable = 2},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "better_fauna:beef_raw",
	output = "better_fauna:beef_cooked",
})


mob_core.register_spawn_egg("better_fauna:cow", "cac3a1" ,"464438")

mob_core.register_spawn({
	name = "better_fauna:cow",
	nodes = {
		"default:dirt_with_grass",
		"default:dry_dirt_with_dry_grass"
	},
	min_light = 0,
	max_light = 15,
	min_height = -31000,
	max_height = 31000,
	group = 3,
	optional = {
		biomes = {
			"grassland",
			"savanna"
		}
	}
}, 4, 6)