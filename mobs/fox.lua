----------
-- Wolf --
----------

creatura.register_mob("animalia:fox", {
	-- Stats
	max_health = 15,
	armor_groups = {fleshy = 100},
	damage = 4,
	speed = 5,
	tracking_range = 24,
	despawn_after = 2000,
	-- Entity Physics
	stepheight = 1.1,
	max_fall = 3,
	-- Visuals
	mesh = "animalia_fox.b3d",
	hitbox = {
		width = 0.35,
		height = 0.7
	},
	visual_size = {x = 10, y = 10},
	textures = {
		"animalia_fox_1.png",
	},
	animations = {
		stand = {range = {x = 1, y = 39}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 41, y = 59}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 41, y = 59}, speed = 45, frame_blend = 0.3, loop = true},
	},
	-- Misc
	makes_footstep_sound = true,
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = true,
	follow = {
		"animalia:rat_raw",
		"animalia:mutton_raw",
		"animalia:beef_raw",
		"animalia:porkchop_raw",
		"animalia:poultry_raw"
	},
	head_data = {
		offset = {x = 0, y = 0.18, z = 0},
		pitch_correction = -67,
		pivot_h = 0.65,
		pivot_v = 0.65
	},
	-- Function
	on_eat_drop = function(self)
		animalia.protect_from_despawn(self)
	end,
	utility_stack = {
		{
			utility = "animalia:wander_skittish",
			step_delay = 0.25,
			get_score = function(self)
				return 0.1, {self}
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
			utility = "animalia:attack_target",
			get_score = function(self)
				local target = self._target or creatura.get_nearby_object(self, {"animalia:rat", "animalia:chicken"})
				local tgt_pos = target and target:get_pos()
				if tgt_pos
				and self:is_pos_safe(tgt_pos) then
					return 0.4, {self, target}
				end
				return 0
			end
		},
		{
			utility = "animalia:flee_from_target",
			get_score = function(self)
				local target = self._puncher or creatura.get_nearby_player(self)
				local pos, tgt_pos = self.object:get_pos(), target and target:get_pos()
				if not pos then return end
				if not tgt_pos then self._puncher = nil return 0 end
				local sneaking = target:get_player_control().sneak
				if not sneaking then
					local dist = vector.distance(pos, tgt_pos)
					local score = (self.tracking_range - dist) / self.tracking_range
					self._puncher = target
					return score / 2, {self, target}
				end
				self._puncher = nil
				return 0
			end
		},
		{
			utility = "animalia:walk_to_food",
			get_score = function(self)
				local cooldown = self.eat_cooldown or 0
				if cooldown > 0 then
					self.eat_cooldown = cooldown - 1
					return 0
				end
				local food_item = animalia.get_dropped_food(self)
				if food_item then
					return 0.7, {self, food_item}
				end
				return 0
			end
		},
		{
			utility = "animalia:follow_player",
			get_score = function(self)
				local lasso_tgt = self._lassod_to
				local lasso = type(lasso_tgt) == "string" and minetest.get_player_by_name(lasso_tgt)
				if lasso
				and lasso:get_pos() then
					return 0.6, {self, lasso, true}
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
					return 0.7, {self}
				end
				return 0
			end
		}
	},
	activate_func = function(self)
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
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
		local name = clicker:get_player_name()
		local passive = true
		if animalia.feed(self, clicker, passive, passive) then
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
	end,
	on_punch = animalia.punch
})

creatura.register_spawn_egg("animalia:fox", "d0602d" ,"c9c9c9")