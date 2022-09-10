-----------
-- Horse --
-----------

local random = math.random

local follows = {}

minetest.register_on_mods_loaded(function()
    for name in pairs(minetest.registered_items) do
        if (name:match(":wheat")
		or minetest.get_item_group(name, "food_wheat") > 0)
		and not name:find("seed") then
			table.insert(follows, name)
        end
    end
end)

local patterns = {
	"animalia_horse_pattern_1.png",
	"animalia_horse_pattern_2.png",
	"animalia_horse_pattern_3.png"
}

local avlbl_colors = {
	[1] = {
		"animalia_horse_2.png",
		"animalia_horse_3.png",
		"animalia_horse_6.png"
	},
	[2] = {
		"animalia_horse_1.png",
		"animalia_horse_6.png"
	},
	[3] = {
		"animalia_horse_2.png",
		"animalia_horse_1.png"
	},
	[4] = {
		"animalia_horse_2.png",
		"animalia_horse_1.png"
	},
	[5] = {
		"animalia_horse_2.png",
		"animalia_horse_1.png"
	},
	[6] = {
		"animalia_horse_2.png",
		"animalia_horse_1.png"
	}
}

local function set_pattern(self)
	local pattern_no = self:recall("pattern_no")
	if pattern_no and pattern_no < 1 then return end
	if not pattern_no then
		if random(3) < 2 then
			pattern_no = self:memorize("pattern_no", random(#patterns))
		else
			self:memorize("pattern_no", 0)
			return
		end
	end
	local colors = avlbl_colors[self.texture_no]
	local color_no = self:recall("color_no") or self:memorize("color_no", random(#colors))
	if not colors[color_no] then return end
	local pattern = "(" .. patterns[pattern_no] .. "^[mask:" .. colors[color_no] .. ")"
	local texture = self.object:get_properties().textures[1]
	self.object:set_properties({
		textures = {texture .. "^" .. pattern}
	})
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
		stand = {range = {x = 1, y = 59}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 61, y = 79}, speed = 20, frame_blend = 0.3, loop = true},
		run = {range = {x = 81, y = 99}, speed = 30, frame_blend = 0.3, loop = true},
		punch_aoe = {range = {x = 101, y = 119}, speed = 30, frame_blend = 0.2, loop = false},
		rear = {range = {x = 121, y = 140}, speed = 20, frame_blend = 0.2, loop = false},
		rear_constant = {range = {x = 121, y = 140}, speed = 20, frame_blend = 0.3, loop = false},
		eat = {range = {x = 141, y = 160}, speed = 20, frame_blend = 0.3, loop = false}
	},
    -- Misc
	step_delay = 0.25,
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
		["default:dirt_with_grass"] = "default:dirt",
		["default:dry_dirt_with_dry_grass"] = "default:dry_dirt",
		["hades_core:dirt_with_grass"] = "hades_core:dirt_with_grass_l3",
		["hades_core:dirt_with_grass_l3"] = "hades_core:dirt_with_grass_l1",
	},
	head_data = {
		bone = "Neck.CTRL",
		offset = {x = 0, y = 1.45, z = 0.0},
		pitch_correction = 25,
		pivot_h = 1,
		pivot_v = 1.5
	},
    -- Function
	wander_action = animalia.action_move_flock,
	utility_stack = {
		{
			utility = "animalia:wander_group",
			step_delay = 0.25,
			get_score = function(self)
				return 0.1, {self}
			end
		},
		{
			utility = "animalia:eat_turf",
			step_delay = 0.25,
			get_score = function(self)
				if random(64) < 2 then
					return 0.2, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:swim_to_land",
			step_delay = 0.25,
			get_score = function(self)
				if self.in_liquid then
					return 0.3, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:follow_player",
			get_score = function(self)
				local lasso = type(self.lasso_origin or {}) == "userdata" and self.lasso_origin
				local force = lasso and lasso ~= false
				local player = (force and lasso) or creatura.get_nearby_player(self)
				if player
				and self:follow_wielded_item(player) then
					return 0.4, {self, player}
				end
				return 0
			end
		},
		{
			utility = "animalia:breed",
			step_delay = 0.25,
			get_score = function(self)
				if self.breeding
				and animalia.get_nearby_mate(self, self.name) then
					return 0.5, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:flee_from_target_defend",
			get_score = function(self)
				local puncher = self._puncher
				if puncher
				and puncher:get_pos() then
					return 0.6, {self, puncher}
				end
				self._puncher = nil
				return 0
			end
		},
		{
			utility = "animalia:tame_horse",
			get_score = function(self)
				local rider = not self.owner and self.rider
				if rider
				and rider:get_pos() then
					return 0.7, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:mount_horse",
			get_score = function(self)
				local owner = self.owner and minetest.get_player_by_name(self.owner)
				local rider = owner == self.rider and self.rider
				if rider
				and rider:get_pos() then
					return 0.8, {self, rider}
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
				animalia.mount(self, clicker, {rot = {x = -75, y = 180, z = 0}, pos = {x = 0, y = 0.6, z = 0.5}})
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
		end
		animalia.add_libri_page(self, clicker, {name = "horse", form = "pg_horse;Horses"})
	end,
	on_punch = function(self, puncher, ...)
		if self.rider and puncher == self.rider then return end
		creatura.basic_punch_func(self, puncher, ...)
		if self.hp < 0 then return end
		self._puncher = puncher
	end
})

creatura.register_spawn_egg("animalia:horse", "ebdfd8" ,"653818")
