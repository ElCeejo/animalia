---------
-- Cow --
---------

local clamp_bone_rot = animalia.clamp_bone_rot

local interp = animalia.interp

local random = math.random
local blend = animalia.frame_blend

local function cow_logic(self)
	
	if self.hp <= 0 then
		mob_core.on_die(self)
		return
	end

	if self.status ~= "following" then
		if self.attention_span > 1 then
			self.attention_span = self.attention_span - self.dtime
			mobkit.remember(self, "attention_span", self.attention_span)
		end
	else
		self.attention_span = self.attention_span + self.dtime
		mobkit.remember(self, "attention_span", self.attention_span)
	end

	animalia.head_tracking(self, 0.75, 0.75)

	if mobkit.timer(self, 3) then

		local prty = mobkit.get_queue_priority(self)
		local player = mobkit.get_nearby_player(self)

		mob_core.random_sound(self, 14)
		mob_core.growth(self)

		if random(1, 64) < 2 then
			self.gotten = mobkit.remember(self, "gotten", false)
		end

		if prty < 5
		and self.isinliquid then
			animalia.hq_go_to_land(self, 5)
		end

		if prty < 4
        and self.breeding then
            animalia.hq_breed(self, 4)
		end

		if prty < 3
		and self.gotten
		and random(1, 16) < 2 then
			animalia.hq_eat(self, 3)
		end

		if prty == 2
		and not self.lasso_player
		and (not player
		or not mob_core.follow_holding(self, player)) then
			mobkit.clear_queue_high(self)
		end

        if prty < 2 then
			if self.caught_with_lasso
			and self.lasso_player then
				animalia.hq_follow_player(self, 2, self.lasso_player, true)
			elseif player then
				if self.attention_span < 5 then
					if mob_core.follow_holding(self, player) then
						animalia.hq_follow_player(self, 2, player)
						self.attention_span = self.attention_span + 1
					end
				end
			end
        end

		if mobkit.is_queue_empty_high(self) then
			animalia.hq_wander_group(self, 0, 10)
		end
	end
end

animalia.register_mob("cow", {
    -- Stats
    health = 20,
    fleshy = 100,
    view_range = 32,
    lung_capacity = 10,
    -- Visual
	collisionbox = {-0.45, 0, -0.45, 0.45, 0.9, 0.45},
	visual_size = {x = 10, y = 10},
	mesh = "animalia_cow.b3d",
	female_textures = {
		"animalia_cow_1.png^animalia_cow_udder.png",
		"animalia_cow_2.png^animalia_cow_udder.png",
		"animalia_cow_3.png^animalia_cow_udder.png",
		"animalia_cow_4.png^animalia_cow_udder.png"
	},
	male_textures = {
		"animalia_cow_1.png",
		"animalia_cow_2.png",
		"animalia_cow_3.png",
		"animalia_cow_4.png"
	},
	child_textures = {
		"animalia_cow_1.png",
		"animalia_cow_2.png",
		"animalia_cow_3.png",
		"animalia_cow_4.png"
	},
	animations = {
		stand = {range = {x = 1, y = 60}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 110}, speed = 40, frame_blend = 0.3, loop = true},
		run = {range = {x = 70, y = 110}, speed = 50, frame_blend = 0.3, loop = true},
	},
    -- Physics
    speed = 4,
    max_fall = 3,
    -- Attributes
    sounds = {
        alter_child_pitch = true,
        random = {
            name = "animalia_cow_idle",
            gain = 1.0,
            distance = 8
        },
        hurt = {
            name = "animalia_cow_hurt",
            gain = 1.0,
            distance = 8
        },
        death = {
            name = "animalia_cow_death",
            gain = 1.0,
            distance = 8
        }
    },
    -- Behavior
    defend_owner = false,
	follow = {
		"farming:wheat",
	},
	consumable_nodes = {
		{
			name = "default:dirt_with_grass",
			replacement = "default:dirt"
		},
		{
			name = "default:dry_dirt_with_dry_grass",
			replacement = "default:dry_dirt"
		}
	},
	drops = {
		{name = "animalia:leather", chance = 2, min = 1, max = 2},
		{name = "animalia:beef_raw", chance = 1, min = 1, max = 4}
	},
    -- Functions
	head_data = {
		offset = {x = 0, y = 0.5, z = 0},
		pitch_correction = -45,
		pivot_h = 0.75,
		pivot_v = 1
	},
    logic = cow_logic,
    get_staticdata = mobkit.statfunc,
	on_step = animalia.on_step,
	on_activate = animalia.on_activate,
	on_rightclick = function(self, clicker)
		if animalia.feed_tame(self, clicker, 1, false, true) then return end
		mob_core.protect(self, clicker, true)
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

			if inv:room_for_item("main", {name = "animalia:bucket_milk"}) then
				clicker:get_inventory():add_item("main", "animalia:bucket_milk")
			else
				local pos = self.object:get_pos()
				pos.y = pos.y + 0.5
				minetest.add_item(pos, {name = "animalia:bucket_milk"})
			end

			self.gotten = mobkit.remember(self, "gotten", true)
			return
		end
	end,
	on_punch = function(self, puncher, _, tool_capabilities, dir)
		mob_core.on_punch_basic(self, puncher, tool_capabilities, dir)
		animalia.hq_sporadic_flee(self, 10)
	end
})

minetest.register_craftitem("animalia:leather", {
    description = "Leather",
    inventory_image = "animalia_leather.png"
})

minetest.register_craftitem("animalia:bucket_milk", {
	description = "Bucket of Milk",
	inventory_image = "animalia_milk_bucket.png",
	stack_max = 1,
	on_use = minetest.item_eat(8, "bucket:bucket_empty"),
	groups = {food_milk = 1, flammable = 3},
})

minetest.register_craftitem("animalia:beef_raw", {
	description = "Raw Beef",
	inventory_image = "animalia_beef_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:beef_cooked", {
	description = "Steak",
	inventory_image = "animalia_beef_cooked.png",
	on_use = minetest.item_eat(8),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:beef_raw",
	output = "animalia:beef_cooked",
})


mob_core.register_spawn_egg("animalia:cow", "cac3a1" ,"464438")