---------
-- Cow --
---------

local clamp_bone_rot = animalia.clamp_bone_rot

local interp = animalia.interp

local random = math.random
local blend = animalia.frame_blend

local function reindeer_logic(self)
	
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

animalia.register_mob("reindeer", {
    -- Stats
    health = 20,
    fleshy = 100,
    view_range = 32,
    lung_capacity = 10,
    -- Visual
	collisionbox = {-0.45, 0, -0.45, 0.45, 0.9, 0.45},
	visual_size = {x = 10, y = 10},
	mesh = "animalia_reindeer.b3d",
	textures = {
		"animalia_reindeer.png",
	},
	child_textures = {
		"animalia_reindeer_calf.png",
	},
	animations = {
		stand = {range = {x = 1, y = 60}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 110}, speed = 40, frame_blend = 0.3, loop = true},
		run = {range = {x = 70, y = 110}, speed = 50, frame_blend = 0.3, loop = true},
	},
    -- Physics
    speed = 4,
    max_fall = 3,
    -- Behavior
    defend_owner = false,
	follow = {
		"farming:wheat",
	},
	drops = {
		{name = "animalia:venison_raw", chance = 1, min = 1, max = 4}
	},
    -- Functions
	head_data = {
		offset = {x = 0, y = 0.7, z = 0},
		pitch_correction = -45,
		pivot_h = 1,
		pivot_v = 1
	},
    logic = reindeer_logic,
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

minetest.register_craftitem("animalia:venison_raw", {
	description = "Raw Venison",
	inventory_image = "animalia_venison_raw.png",
	on_use = minetest.item_eat(1),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craftitem("animalia:venison_cooked", {
	description = "Venison Steak",
	inventory_image = "animalia_venison_cooked.png",
	on_use = minetest.item_eat(6),
	groups = {flammable = 2, meat = 1, food_meat = 1},
})

minetest.register_craft({
	type  =  "cooking",
	recipe  = "animalia:venison_raw",
	output = "animalia:venison_cooked",
})


mob_core.register_spawn_egg("animalia:reindeer", "8c8174" ,"3d3732")