------------
-- Turkey --
------------

local clamp_bone_rot = animalia.clamp_bone_rot

local interp = animalia.interp

local function turkey_logic(self)

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

	animalia.head_tracking(self, 0.45, 0.25)

	if mobkit.timer(self, 3) then

		local prty = mobkit.get_queue_priority(self)
		local player = mobkit.get_nearby_player(self)

		mob_core.random_sound(self, 14)

		if prty < 4
		and self.isinliquid then
			animalia.hq_go_to_land(self, 4)
		end

		if prty < 3
        and self.breeding then
            animalia.hq_fowl_breed(self, 3)
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

animalia.register_mob("turkey", {
	-- Stats
	health = 15,
	fleshy = 100,
	view_range = 26,
	lung_capacity = 10,
	-- Visual
	collisionbox = {-0.3, -0.2, -0.3, 0.3, 0.4, 0.3},
	visual_size = {x = 7, y = 7},
	mesh = "animalia_turkey.b3d",
	female_textures = {"animalia_turkey_hen.png"},
	male_textures = {"animalia_turkey_tom.png"},
	child_textures = {"animalia_turkey_chick.png"},
    animations = {
		stand = {range = {x = 0, y = 0}, speed = 1, frame_blend = 0.3, loop = true},
		walk = {range = {x = 10, y = 30}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 40, y = 60}, speed = 45, frame_blend = 0.3, loop = true},
        fall = {range = {x = 70, y = 90}, speed = 30, frame_blend = 0.3, loop = true},
	},
	-- Physics
	speed = 5,
	max_fall = 6,
	-- Attributes
    sounds = {
        alter_child_pitch = true,
        random = {
            name = "animalia_turkey_idle",
            gain = 1.0,
            distance = 8
        },
        hurt = {
            name = "animalia_turkey_hurt",
            gain = 1.0,
            distance = 8
        },
        death = {
            name = "animalia_turkey_death",
            gain = 1.0,
            distance = 8
        }
    },
	-- Behavior
	defend_owner = false,
	follow = {
		"farming:seed_cotton",
		"farming:seed_wheat"
	},
	drops = {
		{name = "animalia:feather", chance = 1, min = 1, max = 2},
		{name = "animalia:poultry_raw", chance = 1, min = 2, max = 5}
	},
	-- Functions
	head_data = {
		offset = {x = 0, y = 0.15, z = 0},
		pitch_correction = 45,
		pivot_h = 0.45,
		pivot_v = 0.65
	},
	physics = animalia.lightweight_physics,
	logic = turkey_logic,
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
	end,
})

mob_core.register_spawn_egg("animalia:turkey", "352b22", "2f2721")