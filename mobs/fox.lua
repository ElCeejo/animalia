---------
-- Fox --
---------

local vec_dir, vec_dist = vector.direction, vector.distance
local dir2yaw = minetest.dir_to_yaw

local function get_food_pos(self)
	local _, pos = animalia.get_dropped_food(self)

	return pos
end

local function eat_dropped_food(self)
	local pos = self.object:get_pos()
	if not pos then return end

	local food = animalia.get_dropped_food(self, nil, self.width + 1)

	local food_ent = food and food:get_luaentity()
	if food_ent then
		local food_pos = food:get_pos()

		local stack = ItemStack(food_ent.itemstring)
		if stack
		and stack:get_count() > 1 then
			stack:take_item()
			food_ent.itemstring = stack:to_string()
		else
			food:remove()
		end

		self.object:set_yaw(dir2yaw(vec_dir(pos, food_pos)))
		animalia.add_food_particle(self, stack:get_name())

		if self.on_eat_drop then
			self:on_eat_drop()
		end
		return true
	end
end


creatura.register_mob("animalia:fox", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_fox.b3d",
	textures = {
		"animalia_fox_1.png"
	},
	makes_footstep_sound = false,

	-- Creatura Props
	max_health = 10,
	armor_groups = {fleshy = 100},
	damage = 2,
	speed = 4,
	tracking_range = 16,
	max_boids = 0,
	despawn_after = 500,
	stepheight = 1.1,
	sound = {},
	hitbox = {
		width = 0.35,
		height = 0.5
	},
	animations = {
		stand = {range = {x = 1, y = 39}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 41, y = 59}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 41, y = 59}, speed = 45, frame_blend = 0.3, loop = true},
	},
	follow = {
		"animalia:rat_raw",
		"animalia:mutton_raw",
		"animalia:beef_raw",
		"animalia:porkchop_raw",
		"animalia:poultry_raw"
	},

	-- Animalia Props
	skittish_wander = true,
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = true,
	head_data = {
		offset = {x = 0, y = 0.18, z = 0},
		pitch_correction = -67,
		pivot_h = 0.65,
		pivot_v = 0.65
	},

	-- Functions
	utility_stack = {
		{
			utility = "animalia:wander",
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
					local dist = vec_dist(pos, tgt_pos)
					local score = (self.tracking_range - dist) / self.tracking_range
					self._puncher = target
					return score / 2, {self, target}
				end
				self._puncher = nil
				return 0
			end
		},
		{
			utility = "animalia:walk_to_pos_and_interact",
			get_score = function(self)
				if math.random(14) < 2 then
					return 0.7, {self, get_food_pos, eat_dropped_food, nil, 12}
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

	on_eat_drop = function(self)
		animalia.protect_from_despawn(self)
	end,

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

	death_func = animalia.death_func,

	on_rightclick = function(self, clicker)
		if animalia.feed(self, clicker, true, true) then
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
	end,

	on_punch = animalia.punch
})

creatura.register_spawn_item("animalia:fox", {
	col1 = "d0602d",
	col2 = "c9c9c9"
})