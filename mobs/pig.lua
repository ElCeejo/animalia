---------
-- Pig --
---------

local function pig_logic(self)
	
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

	if mobkit.timer(self, 3) then

		local prty = mobkit.get_queue_priority(self)
		local player = mobkit.get_nearby_player(self)

		mob_core.random_sound(self, 14)
		mob_core.growth(self)

		if prty < 4
		and self.isinliquid then
			animalia.hq_go_to_land(self, 4)
		end

		if prty < 3
        and self.breeding then
            animalia.hq_breed(self, 3)
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
            	        self.attention_span = self.attention_span + 3
            	    end
            	end
			end
        end

		if mobkit.is_queue_empty_high(self) then
			animalia.hq_wander_group(self, 0, 8)
		end
	end
end

animalia.register_mob("pig", {
    -- Stats
    health = 20,
    fleshy = 100,
    view_range = 32,
    lung_capacity = 10,
    -- Visual
	collisionbox = {-0.35, -0.45, -0.35, 0.35, 0.4, 0.35},
	visual_size = {x = 11, y = 11},
	mesh = "animalia_pig.b3d",
	female_textures = {
		"animalia_pig_1.png",
		"animalia_pig_2.png",
		"animalia_pig_3.png"
	},
	male_textures = {
		"animalia_pig_1.png^animalia_pig_tusks.png",
		"animalia_pig_2.png^animalia_pig_tusks.png",
		"animalia_pig_3.png^animalia_pig_tusks.png"
	},
	child_textures = {
		"animalia_pig_1.png",
		"animalia_pig_2.png",
		"animalia_pig_3.png"
	},
	animations = {
		stand = {range = {x = 30, y = 50}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 1, y = 20}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 1, y = 20}, speed = 45, frame_blend = 0.3, loop = true},
	},
    -- Physics
    speed = 4,
    max_fall = 3,
    -- Attributes
    sounds = {
        alter_child_pitch = true,
        random = {
            name = "animalia_pig_idle",
            gain = 1.0,
            distance = 8
        },
        hurt = {
            name = "animalia_pig_idle",
			gain = 1.0,
			pitch = 0.5,
            distance = 8
        },
        death = {
            name = "animalia_pig_death",
            gain = 1.0,
            distance = 8
        }
    },
    -- Behavior
    defend_owner = false,
	follow = {
		"farming:carrot"
	},
	drops = {
		{name = "animalia:porkchop_raw", chance = 1, min = 1, max = 4}
	},
    -- Functions
    logic = pig_logic,
    get_staticdata = mobkit.statfunc,
	on_step = animalia.on_step,
	on_activate = animalia.on_activate,
	on_rightclick = function(self, clicker)
		if animalia.feed_tame(self, clicker, 1, false, true) then return end
		mob_core.protect(self, clicker, true)
		mob_core.nametag(self, clicker, true)
	end,
	on_punch = function(self, puncher, _, tool_capabilities, dir)
		mob_core.on_punch_basic(self, puncher, tool_capabilities, dir)
		animalia.hq_sporadic_flee(self, 10)
	end
})

minetest.register_craftitem("animalia:porkchop_raw", {
	description = "Raw Porkchop",
	inventory_image = "animalia_porkchop_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:porkchop_cooked", {
	description = "Cooked Porkchop",
	inventory_image = "animalia_porkchop_cooked.png",
	on_use = minetest.item_eat(7),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:porkchop_raw",
	output = "animalia:porkchop_cooked",
})

mob_core.register_spawn_egg("animalia:pig", "e0b1a7" ,"cc9485")