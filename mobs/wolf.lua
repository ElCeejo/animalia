----------
-- Wolf --
----------



local follow = {
	"animalia:mutton_raw",
	"animalia:beef_raw",
	"animalia:porkchop_raw",
	"animalia:poultry_raw"
}

if minetest.registered_items["bonemeal:bone"] then
	follow = {
		"bonemeal:bone",
		"animalia:beef_raw",
		"animalia:porkchop_raw",
		"animalia:mutton_raw",
		"animalia:poultry_raw"
	}
end

local function is_value_in_table(tbl, val)
	for _, v in pairs(tbl) do
		if v == val then
			return true
		end
	end
	return false
end

creatura.register_mob("animalia:wolf", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_wolf.b3d",
	textures = {
		"animalia_wolf_1.png",
		"animalia_wolf_2.png",
		"animalia_wolf_3.png",
		"animalia_wolf_4.png"
	},
	makes_footstep_sound = true,

	-- Creatura Props
	max_health = 20,
	damage = 4,
	speed = 4,
	tracking_range = 24,
	despawn_after = 500,
	stepheight = 1.1,
	sound = {},
	hitbox = {
		width = 0.35,
		height = 0.7
	},
	animations = {
		stand = {range = {x = 1, y = 60}, speed = 20, frame_blend = 0.3, loop = true},
		walk = {range = {x = 70, y = 89}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 100, y = 119}, speed = 40, frame_blend = 0.3, loop = true},
		sit = {range = {x = 130, y = 139}, speed = 10, frame_blend = 0.3, loop = true},
	},
	follow = follow,

	-- Behavior Parameters
	is_skittish_mob = true,
	is_herding_mob = true,

	-- Animalia Props
	assist_owner = true,
	flee_puncher = false,
	catch_with_net = true,
	catch_with_lasso = true,
	consumable_nodes = {},
	head_data = {
		offset = {x = 0, y = 0.22, z = 0},
		pitch_correction = -35,
		pivot_h = 0.45,
		pivot_v = 0.45
	},

	-- Functions
	utility_stack = {
		animalia.mob_ai.basic_wander,
		animalia.mob_ai.swim_seek_land,
		animalia.mob_ai.tamed_stay,
		animalia.mob_ai.tamed_follow_owner,
		animalia.mob_ai.basic_attack,
		animalia.mob_ai.basic_breed
	},

	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
		self.order = self:recall("order") or "wander"
		self.owner = self:recall("owner") or nil
		self.enemies = self:recall("enemies") or {}
		if self.owner
		and minetest.get_player_by_name(self.owner) then
			if not is_value_in_table(animalia.pets[self.owner], self.object) then
				table.insert(animalia.pets[self.owner], self.object)
			end
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

	deactivate_func = function(self)
		if self.owner then
			for i, object in ipairs(animalia.pets[self.owner] or {}) do
				if object == self.object then
					animalia.pets[self.owner][i] = nil
				end
			end
		end
		if self.enemies
		and self.enemies[1]
		and self.memorize then
			self.enemies[1] = nil
			self.enemies = self:memorize("enemies", self.enemies)
		end
	end,

	on_rightclick = function(self, clicker)
		if not clicker:is_player() then return end
		local name = clicker:get_player_name()
		local passive = true
		if is_value_in_table(self.enemies, name) then passive = false end
		if animalia.feed(self, clicker, passive, passive) then
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
		if self.owner
		and name == self.owner
		and clicker:get_player_control().sneak then
			local order = self.order
			if order == "wander" then
				minetest.chat_send_player(name, "Wolf is following")
				self.order = "follow"
				self:initiate_utility("animalia:follow_player", self, clicker, true)
				self:set_utility_score(0.7)
			elseif order == "follow" then
				minetest.chat_send_player(name, "Wolf is sitting")
				self.order = "sit"
				self:initiate_utility("animalia:stay", self)
				self:set_utility_score(0.5)
			else
				minetest.chat_send_player(name, "Wolf is wandering")
				self.order = "wander"
				self:set_utility_score(0)
			end
			self:memorize("order", self.order)
		end
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		local name = puncher:is_player() and puncher:get_player_name()
		if name then
			if self.owner
			and name == self.owner then
				return
			elseif not is_value_in_table(self.enemies, name) then
				table.insert(self.enemies, name)
				if #self.enemies > 15 then
					table.remove(self.enemies, 1)
				end
				self.enemies = self:memorize("enemies", self.enemies)
			else
				table.remove(self.enemies, 1)
				table.insert(self.enemies, name)
				self.enemies = self:memorize("enemies", self.enemies)
			end
		end
		self._target = puncher
	end,
})

creatura.register_spawn_item("animalia:wolf", {
	col1 = "a19678",
	col2 = "231b13"
})
