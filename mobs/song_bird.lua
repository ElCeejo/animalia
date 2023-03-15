---------------
-- Song Bird --
---------------

local random = math.random

creatura.register_mob("animalia:song_bird", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	mesh = "animalia_bird.b3d",
	textures = {
		"animalia_cardinal.png",
		"animalia_bluebird.png",
		"animalia_goldfinch.png"
	},

	-- Creatura Props
	max_health = 2,
	speed = 4,
	tracking_range = 8,
	max_boids = 6,
	boid_seperation = 0.3,
	despawn_after = 200,
	max_fall = 0,
	stepheight = 1.1,
	sounds = {
		cardinal = {
			name = "animalia_cardinal",
			gain = 0.5,
			distance = 63
		},
		eastern_blue = {
			name = "animalia_bluebird",
			gain = 0.5,
			distance = 63
		},
		goldfinch = {
			name = "animalia_goldfinch",
			gain = 0.5,
			distance = 63
		},
	},
	hitbox = {
		width = 0.2,
		height = 0.4
	},
	animations = {
		stand = {range = {x = 1, y = 100}, speed = 30, frame_blend = 0.3, loop = true},
		walk = {range = {x = 110, y = 130}, speed = 40, frame_blend = 0.3, loop = true},
		fly = {range = {x = 140, y = 160}, speed = 40, frame_blend = 0.3, loop = true}
	},
	--follow = {},
	drops = {
		{name = "animalia:feather", min = 1, max = 1, chance = 2}
	},

	-- Animalia Props
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = false,
	wander_action = animalia.action_boid_move,
	--roost_action = animalia.action_roost,

	-- Functions
	utility_stack = {
		{
			utility = "animalia:wander",
			step_delay = 0.25,
			get_score = function(self)
				return 0.1, {self, true}
			end
		},
		{
			utility = "animalia:aerial_wander",
			get_score = function(self)
				if self.is_landed then
					local player = creatura.get_nearby_player(self)
					if player then
						self.is_landed = self:memorize("is_landed", false)
					end
				end
				if not self.is_landed
				or self.in_liquid then
					return 0.2, {self}
				end
				return 0
			end
		},
		{
			utility = "animalia:fly_to_land",
			get_score = function(self)
				if self.is_landed
				and not self.touching_ground
				and not self.in_liquid
				and creatura.sensor_floor(self, 3, true) > 2 then
					return 0.3, {self}
				end
				return 0
			end
		}
	},

	activate_func = function(self)
		if animalia.despawn_inactive_mob(self) then return end
		animalia.initialize_api(self)
		animalia.initialize_lasso(self)
		self.is_landed = (random(2) < 2 and true) or false
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.do_growth(self, 60)
		--animalia.update_lasso_effects(self)
		animalia.rotate_to_pitch(self)
		if self:timer(random(6, 12)) then
			if animalia.is_day then
				if self.texture_no == 1 then
					self:play_sound("cardinal")
				elseif self.texture_no == 2 then
					self:play_sound("eastern_blue")
				else
					self:play_sound("goldfinch")
				end
			end
		end
		if not self.is_landed
		or not self.touching_ground then
			self.speed = 4
		else
			self.speed = 3
		end
	end,

	death_func = animalia.death_func,

	on_rightclick = function(self, clicker)
		--[[if animalia.feed(self, clicker, false, false) then
			return
		end]]
		if animalia.set_nametag(self, clicker) then
			return
		end
	end,

	on_punch = animalia.punch
})

creatura.register_spawn_item("animalia:song_bird", {
	col1 = "ae2f2f",
	col2 = "f3ac1c"
})

minetest.register_entity("animalia:bird", {
	static_save = false,
	on_activate = function(self)
		self.object:remove()
	end
})

minetest.register_abm({
	label = "animalia:nest_cleanup",
	nodenames = "animalia:nest_song_bird",
	interval = 900,
	action = function(pos)
		minetest.remove_node(pos)
	end
})