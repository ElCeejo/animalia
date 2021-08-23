-----------
-- Horse --
-----------

local random = math.random

local function set_pattern(self)
	local types = {
		"spots",
		"patches"
	}
    if mobkit.recall(self, "pattern")
	and not mobkit.recall(self, "pattern"):find("better_fauna") then
        local pattern = mobkit.recall(self, "pattern")
        local texture = self.object:get_properties().textures[1]
        self.object:set_properties({
            textures = {texture .. "^" .. pattern}
        })
    else
		local type = types[random(#types)]
        local overlay = "(animalia_horse_".. type ..".png)"
		if type == "patches" then
			local colors = {
				"brown",
				"white"
			}
			if self.texture_no < 1 then
				table.insert(colors, "black")
			else
				table.remove(colors, 1)
			end
			overlay = "(animalia_horse_".. colors[random(#colors)] .."_patches.png)"
		end
        if random(100) > 50 then
            overlay = "transparency.png"
        end
        local texture = self.object:get_properties().textures[1]
        self.object:set_properties({
            textures = {texture .. "^" .. overlay}
        })
        mobkit.remember(self, "pattern", overlay)
    end
end

local function horse_logic(self)
	
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

	animalia.head_tracking(self)

	if mobkit.timer(self, 1) then

		local prty = mobkit.get_queue_priority(self)
		local player = mobkit.get_nearby_player(self)
		local pos = self.object:get_pos()

		mob_core.random_sound(self, 24)
		mob_core.growth(self)

		if self.breaking then
			if not minetest.get_player_by_name(self.breaker)
			or not self.driver then
				self.breaking = nil
				self.breaker = nil
			else
				local yaw = self.object:get_yaw()
				local yaw2 = minetest.get_player_by_name(self.breaker):get_look_horizontal()
				if math.abs(yaw - yaw2) > 5.8
				or math.abs(yaw - yaw2) < 0.5 then
					self.breaking_progress = self.breaking_progress + 1
				else
					self.breaking_progress = self.breaking_progress - 1
				end
				animalia.hq_sporadic_flee(self, 10)
				if self.breaking_progress < -5
				or minetest.get_player_by_name(self.breaker):get_player_control().sneak then
					mob_core.detach(self.driver, {x = 1, y = 0, z = 1})
					mobkit.lq_idle(self, 0.5, "rear")
					self.breaking = nil
					self.breaker = nil
					self.breaking_progress = nil
				elseif self.breaking_progress > 5 then
					mob_core.set_owner(self, self.breaker)
					self.breaking = nil
					self.breaker = nil
					self.breaking_progress = nil
					local prt_pos = vector.new(pos.x, pos.y + 2, pos.z)
					local minppos = vector.add(prt_pos, 1)
					local maxppos = vector.subtract(prt_pos, 1)
					animalia.particle_spawner(prt_pos, "mob_core_green_particle.png", "float", minppos, maxppos)
					mobkit.clear_queue_high(self)
				end
			end
			return
		end

		if prty < 20
		and self.driver
		and not self.breaking then
			animalia.hq_mount_logic(self, 20)
		end

		if prty < 5
		and self.isinliquid then
			animalia.hq_go_to_land(self, 5)
		end

		if prty < 4
        and self.breeding then
            animalia.hq_horse_breed(self, 4)
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
			animalia.hq_wander_group(self, 0, 12)
		end
	end
end

animalia.register_mob("horse", {
    -- Stats
    health = 40,
    fleshy = 100,
    view_range = 32,
    lung_capacity = 10,
    -- Visual
	collisionbox = {-0.65, 0, -0.65, 0.65, 1.95, 0.65},
	visual_size = {x = 10, y = 10},
	mesh = "animalia_horse.b3d",
	textures = {
		"animalia_horse_1.png",
		"animalia_horse_2.png",
		"animalia_horse_3.png",
		"animalia_horse_4.png",
		"animalia_horse_5.png",
		"animalia_horse_6.png"
	},
	animations = {
		stand = {range = {x = 1, y = 60}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 110}, speed = 25, frame_blend = 0.3, loop = true},
		run = {range = {x = 70, y = 110}, speed = 45, frame_blend = 0.3, loop = true},
		rear = {range = {x = 120, y = 150}, speed = 27, frame_blend = 0.2, loop = false},
		rear_constant = {range = {x = 130, y = 140}, speed = 20, frame_blend = 0.3, loop = true}
	},
    -- Physics
    speed = 10,
    max_fall = 8,
    -- Attributes
    sounds = {
        alter_child_pitch = true,
        random = {
            {
				name = "animalia_horse_idle_1",
				gain = 1.0,
				distance = 8
			},
			{
				name = "animalia_horse_idle_2",
				gain = 1.0,
				distance = 8
			},
			{
				name = "animalia_horse_idle_3",
				gain = 1.0,
				distance = 8
			}
        },
        hurt = {
            name = "animalia_horse_hurt",
            gain = 1.0,
            distance = 8
        },
        death = {
            name = "animalia_horse_death",
            gain = 1.0,
            distance = 8
        }
    },
    -- Behavior
    defend_owner = false,
	follow = {
		"farming:wheat",
	},
	drops = {
		{name = "animalia:leather", chance = 2, min = 1, max = 4},
	},
	player_rotation = {x = -60, y = 180, z = 0},
	driver_scale = {x = 0.1, y = 0.1},
    driver_attach_at = {x = 0, y = 1.1, z = 0.5},
	driver_attach_bone = "Torso",
    driver_eye_offset = {{x = 0, y = 15, z = 0}, {x = 0, y = 15, z = 15}},
    -- Functions
	head_data = {
		bone = "Neck.CTRL",
		offset = {x = 0, y = 1.98, z = 0},
		pitch_correction = 35,
		pivot_h = 1,
		pivot_v = 1.5
	},
    logic = horse_logic,
    get_staticdata = mobkit.statfunc,
	on_step = animalia.on_step,
	on_activate = function(self, staticdata, dtime_s)
		animalia.on_activate(self, staticdata, dtime_s)
		set_pattern(self)
		self.saddled = mobkit.recall(self, "saddled") or false
		self.max_hp = mobkit.recall(self, "max_hp") or random(30, 45)
		self.speed = mobkit.recall(self, "speed") or random(5, 10)
		self.jump_power = mobkit.recall(self, "speed") or random(2, 5)
		if self.saddled then
			local texture = self.object:get_properties().textures[1]
			self.object:set_properties({
				textures = {texture .. "^animalia_horse_saddle.png"}
			})
			self.drops = {
				{name = "animalia:leather", chance = 2, min = 1, max = 4},
				{name = "animalia:saddle", chance = 1, min = 1, max = 1}
			}
		end
	end,
	on_rightclick = function(self, clicker)
		if animalia.feed_tame(self, clicker, 1, false, true) then return end
		mob_core.protect(self, clicker, false)
		mob_core.nametag(self, clicker, true)
		local tool = clicker:get_wielded_item()
		if self.tamed
        and self.owner == clicker:get_player_name() then
			if self.saddled
			and tool:get_name() == "" then
            	mob_core.mount(self, clicker)
			elseif tool:get_name() == "animalia:saddle" then
				self.saddled = mobkit.remember(self, "saddled", true)
				local texture = self.object:get_properties().textures[1]
				self.object:set_properties({
					textures = {texture .. "^animalia_horse_saddle.png"}
				})
				tool:take_item()
				clicker:set_wielded_item(tool)
			end
        elseif not self.tamed
		and tool:get_name() == "" then
			mob_core.mount(self, clicker)
			self.breaking = true
			self.breaker = clicker:get_player_name()
			self.breaking_progress = 0
		end
	end,
	on_punch = function(self, puncher, _, tool_capabilities, dir)
		mob_core.on_punch_basic(self, puncher, tool_capabilities, dir)
		animalia.hq_sporadic_flee(self, 10)
	end
})

mob_core.register_spawn_egg("animalia:horse", "ebdfd8" ,"653818")