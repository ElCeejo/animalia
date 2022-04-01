-----------
-- Horse --
-----------

local random = math.random

local follows = {}

minetest.register_on_mods_loaded(function()
    for name, def in pairs(minetest.registered_items) do
        if (name:match(":wheat")
		or minetest.get_item_group(name, "food_wheat") > 0)
		and not name:find("seed") then
			table.insert(follows, name)
        end
    end
end)

local function set_pattern(self)
	local types = {
		"spots",
		"patches"
	}
    if self:recall("pattern")
	and not self:recall("pattern"):find("better_fauna") then
        local pattern = self:recall("pattern")
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
        self:memorize("pattern", overlay)
    end
end

creatura.register_mob("animalia:horse", {
    -- Stats
    max_health = 40,
    armor_groups = {fleshy = 100},
    damage = 0,
    speed = 10,
	tracking_range = 24,
    despawn_after = 2000,
	-- Entity Physics
	stepheight = 1.1,
	turn_rate = 6,
	boid_seperation = 1.5,
    -- Visuals
    mesh = "animalia_horse.b3d",
	hitbox = {
		width = 0.65,
		height = 1.95
	},
    visual_size = {x = 10, y = 10},
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
		walk = {range = {x = 70, y = 110}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 120, y = 140}, speed = 30, frame_blend = 0.3, loop = true},
		rear = {range = {x = 150, y = 180}, speed = 27, frame_blend = 0.2, loop = false},
		rear_constant = {range = {x = 160, y = 170}, speed = 20, frame_blend = 0.3, loop = true},
		eat = {range = {x = 190, y = 220}, speed = 20, frame_blend = 0.3, loop = false}
	},
    -- Misc
	catch_with_net = true,
	catch_with_lasso = true,
    sounds = {
        alter_child_pitch = true,
        random = {
			name = "animalia_horse_idle",
			gain = 1.0,
			distance = 8,
			variations = 3,
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
    drops = {
		{name = "animalia:leather", min = 1, max = 4, chance = 2}
    },
    follow = follows,
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
	head_data = {
		bone = "Neck.CTRL",
		offset = {x = 0, y = 1.2, z = 0.15},
		pitch_correction = 45,
		pivot_h = 1,
		pivot_v = 1.5
	},
    -- Function
	utility_stack = {
		[1] = {
			utility = "animalia:boid_wander",
			get_score = function(self)
				return 0.1, {self, true}
			end
		},
		[2] = {
			utility = "animalia:eat_from_turf",
			get_score = function(self)
				return math.random(11) * 0.01, {self}
			end
		},
		[3] = {
			utility = "animalia:swim_to_land",
			get_score = function(self)
				if self.in_liquid then
					return 0.95, {self}
				end
				return 0
			end
		},
		[4] = {
			utility = "animalia:follow_player",
			get_score = function(self)
				if self.lasso_origin
				and type(self.lasso_origin) == "userdata" then
					return 0.8, {self, self.lasso_origin, true}
				end
				return 0
			end
		},
		[5] = {
			utility = "animalia:horse_breed",
			get_score = function(self)
				if self.breeding
				and animalia.get_nearby_mate(self, self.name) then
					return 0.9, {self}
				end
				return 0
			end
		},
		[6] = {
			utility = "animalia:mount",
			get_score = function(self)
				if self.rider
				and self.saddled then
					return 1, {self, self.rider}
				end
				return 0
			end
		}
	},
    activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
		set_pattern(self)
		self.owner = self:recall("owner") or nil
		if self.owner then
			self._despawn = nil
			self.despawn_after = nil
		end
		self.rider = nil
		self.saddled = self:recall("saddled") or false
		self.max_health = self:recall("max_health") or random(30, 45)
		self.speed = self:recall("speed") or random(5, 10)
		self.jump_power = self:recall("jump_power") or random(2, 5)
		self:memorize("max_health", self.max_health)
		self:memorize("speed", self.speed)
		self:memorize("jump_power", self.jump_power)
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
    step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
		if self.breaking
		and self:timer(1) then
			local pos = self:get_center_pos()
			if not minetest.get_player_by_name(self.breaker) then
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
				self:initiate_utility("animalia:horse_breaking", self)
				if self.breaking_progress < -5
				or minetest.get_player_by_name(self.breaker):get_player_control().sneak then
					animalia.mount(self, minetest.get_player_by_name(self.breaker))
					creatura.action_idle(self, 0.5, "rear")
					self.breaking = nil
					self.breaker = nil
					self.breaking_progress = nil
				elseif self.breaking_progress > 5 then
					animalia.mount(self, minetest.get_player_by_name(self.breaker))
					self.owner = self:memorize("owner", self.breaker)
					animalia.protect_from_despawn(self)
					self.breaking = nil
					self.breaker = nil
					self.breaking_progress = nil
					local prt_pos = vector.new(pos.x, pos.y + 2, pos.z)
					local minppos = vector.add(prt_pos, 1)
					local maxppos = vector.subtract(prt_pos, 1)
					animalia.particle_spawner(prt_pos, "creatura_particle_green.png", "float", minppos, maxppos)
				end
			end
		end
    end,
    death_func = function(self)
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
    end,
	on_rightclick = function(self, clicker)
		if animalia.feed(self, clicker, false, true) then
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
		local tool = clicker:get_wielded_item()
		local tool_name = clicker:get_wielded_item():get_name()
		if self.owner
        and self.owner == clicker:get_player_name() then
			if self.saddled
			and tool_name == "" then
				animalia.mount(self, clicker, {rot = {x = -60, y = 180, z = 0}, pos = {x = 0, y = 1.1, z = 0.5}})
				self:initiate_utility("animalia:mount", self, clicker)
			elseif tool_name == "animalia:saddle" then
				self.saddled = self:memorize("saddled", true)
				local texture = self.object:get_properties().textures[1]
				self.object:set_properties({
					textures = {texture .. "^animalia_horse_saddle.png"}
				})
				self.drops = {
					{name = "animalia:leather", chance = 2, min = 1, max = 4},
					{name = "animalia:saddle", chance = 1, min = 1, max = 1}
				}
				tool:take_item()
				clicker:set_wielded_item(tool)
			end
        elseif not self.owner
		and tool_name == "" then
			animalia.mount(self, clicker, {rot = {x = -60, y = 180, z = 0}, pos = {x = 0, y = 1.1, z = 0.5}})
			self.breaking = true
			self.breaker = clicker:get_player_name()
			self.breaking_progress = 0
		end
		animalia.add_libri_page(self, clicker, {name = "horse", form = "pg_horse;Horses"})
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		self:initiate_utility("animalia:boid_flee_from_player", self, puncher, true)
		self:set_utility_score(1)
	end
})

creatura.register_spawn_egg("animalia:horse", "ebdfd8" ,"653818")