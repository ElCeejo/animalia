----------
-- Wolf --
----------

local vec_dist = vector.distance

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
    -- Stats
    max_health = 15,
    armor_groups = {fleshy = 100},
    damage = 4,
    speed = 5,
	tracking_range = 24,
    despawn_after = 2000,
	-- Entity Physics
	stepheight = 1.1,
    -- Visuals
    mesh = "animalia_wolf.b3d",
	hitbox = {
		width = 0.35,
		height = 0.7
	},
    visual_size = {x = 9, y = 9},
	textures = {"animalia_wolf.png"},
	animations = {
		stand = {range = {x = 30, y = 49}, speed = 10, frame_blend = 0.3, loop = true},
		sit = {range = {x = 60, y = 90}, speed = 20, frame_blend = 0.3, loop = true},
		walk = {range = {x = 1, y = 20}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 1, y = 20}, speed = 45, frame_blend = 0.3, loop = true},
		leap = {range = {x = 100, y = 100}, speed = 1, frame_blend = 0.15, loop = false}
	},
    -- Misc
	catch_with_net = true,
	catch_with_lasso = true,
	assist_owner = true,
    follow = follow,
	head_data = {
		offset = {x = 0, y = 0.22, z = 0},
		pitch_correction = -25,
		pivot_h = 0.65,
		pivot_v = 0.65
	},
    -- Function
	utility_stack = {
		[1] = {
			utility = "animalia:skittish_boid_wander",
			get_score = function(self)
				return 0.1, {self, true}
			end
		},
		[2] = {
			utility = "animalia:swim_to_land",
			get_score = function(self)
				if self.in_liquid then
					return 0.9, {self}
				end
				return 0
			end
		},
		[3] = {
			utility = "animalia:attack",
			get_score = function(self)
				local target = creatura.get_nearby_entity(self, "animalia:sheep")
				local player = self._nearby_player
				local is_attacking = self:get_utility() == "animalia:attack"
				if player
				and player:get_player_name() then
					if is_value_in_table(self.enemies, player:get_player_name()) then
						local nearby_players = creatura.get_nearby_players(self)
						local nearby_allies = creatura.get_nearby_entities(self, self.name)
						if #nearby_players < #nearby_allies then
							target = player
						end
					end
				end
				if target then
					if is_attacking
					and self._utility_data.args[2]
					and self._utility_data.args[2] == target then
						return 0
					end
					return 0.85, {self, target}
				end
				return 0
			end
		},
		[4] = {
			utility = "animalia:flee_from_player",
			get_score = function(self)
				local player = self._nearby_player
				if player
				and player:get_player_name() then
					if is_value_in_table(self.enemies, player:get_player_name()) then
						local nearby_players = creatura.get_nearby_players(self)
						local nearby_allies =  creatura.get_nearby_entities(self, self.name)
						if #nearby_players >= #nearby_allies then
							return 0.86, {self, player}
						end
					end
				end
				return 0
			end
		},
		[5] = {
			utility = "animalia:sit",
			get_score = function(self)
				if self.order == "sit" then
					return 0.8, {self}
				end
				return 0
			end
		},
		[6] = {
			utility = "animalia:follow_player",
			get_score = function(self)
				local trust = 0
				local player = self._nearby_player
				if self.lasso_origin
				and type(self.lasso_origin) == "userdata" then
					return 0.7, {self, self.lasso_origin, true}
				elseif player
				and self:follow_wielded_item(player) then
					return 0.7, {self, player}
				end
				if self.order == "follow"
				and self.owner
				and minetest.get_player_by_name(self.owner) then
					return 1, {self, minetest.get_player_by_name(self.owner), true}
				end
				return 0
			end
		},
		[7] = {
			utility = "animalia:mammal_breed",
			get_score = function(self)
				if self.breeding
				and animalia.get_nearby_mate(self, self.name) then
					return 0.7, {self}
				end
				return 0
			end
		}
	},
    activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
        self._path = {}
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
		animalia.head_tracking(self, 0.5, 0.75)
		animalia.do_growth(self, 60)
		animalia.update_lasso_effects(self)
    end,
    death_func = function(self)
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
    end,
	on_rightclick = function(self, clicker)
		if not clicker:is_player() then return end
		local passive = true
		if is_value_in_table(self.enemies, clicker:get_player_name()) then
			passive = false
		end
		if animalia.feed(self, clicker, passive, passive) then
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
		if self.owner
		and clicker:get_player_name() == self.owner
		and clicker:get_player_control().sneak then
			local order = self.order
			if order == "wander" then
				minetest.chat_send_player(clicker:get_player_name(), "Wolf is following")
				self.order = "follow"
				self:initiate_utility("animalia:follow_player", self, clicker, true)
				self:set_utility_score(1)
			elseif order == "follow" then
				minetest.chat_send_player(clicker:get_player_name(), "Wolf is sitting")
				self.order = "sit"
				self:initiate_utility("animalia:sit", self)
				self:set_utility_score(0.8)
			else
				minetest.chat_send_player(clicker:get_player_name(), "Wolf is wandering")
				self.order = "wander"
				self:set_utility_score(0)
			end
			self:memorize("order", self.order)
		end
		animalia.add_libri_page(self, clicker, {name = "wolf", form = "pg_wolf;Wolves"})
	end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		if puncher:is_player() then
			if self.owner
			and puncher:get_player_name() == self.owner then
				return
			elseif not is_value_in_table(self.enemies, puncher:get_player_name()) then
				table.insert(self.enemies, puncher:get_player_name())
				if #self.enemies > 15 then
					table.remove(self.enemies, 1)
				end
				self.enemies = self:memorize("enemies", self.enemies)
			else
				table.remove(self.enemies, 1)
				table.insert(self.enemies, puncher:get_player_name())
				self.enemies = self:memorize("enemies", self.enemies)
			end
		end
		self:initiate_utility("animalia:attack", self, puncher, true)
		self:set_utility_score(1)
	end,
	deactivate_func = function(self)
		if self.owner then
			for i = 1, #animalia.pets[self.owner] do
				if animalia.pets[self.owner][i] == self.object then
					animalia.pets[self.owner][i] = nil
				end
			end
		end
		if self.enemies
		and self.enemies[1] then
			self.enemies[1] = nil
			self.enemies = self:memorize("enemies", self.enemies)
		end
	end
})

creatura.register_spawn_egg("animalia:wolf", "a19678" ,"231b13")