----------
-- Frog --
----------

local random = math.random

local function poison_effect(object)
	object:punch(object, 1.0, {
		full_punch_interval = 1.0,
		damage_groups = {fleshy = 1},
	})
end

local hitboxes = {
	{-0.25, 0, -0.25, 0.2, 0.4, 0.25},
	{-0.4, 0, -0.4, 0.4, 0.5, 0.4},
	{-0.15, 0, -0.15, 0.15, 0.3, 0.15}
}

local animations = {
	{
		stand = {range = {x = 1, y = 40}, speed = 10, frame_blend = 0.3, loop = true},
		float = {range = {x = 90, y = 90}, speed = 1, frame_blend = 0.3, loop = true},
		swim = {range = {x = 90, y = 110}, speed = 50, frame_blend = 0.3, loop = true},
		walk = {range = {x = 50, y = 80}, speed = 50, frame_blend = 0.3, loop = true},
		run = {range = {x = 50, y = 80}, speed = 60, frame_blend = 0.3, loop = true}
	},
	{
		stand = {range = {x = 1, y = 40}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 50, y = 79}, speed = 20, frame_blend = 0.3, loop = true},
		run = {range = {x = 50, y = 79}, speed = 30, frame_blend = 0.3, loop = true},
		warn = {range = {x = 90, y = 129}, speed = 30, frame_blend = 0.3, loop = true},
		punch = {range = {x = 140, y = 160}, speed = 30, frame_blend = 0.1, loop = false},
		float = {range = {x = 170, y = 209}, speed = 10, frame_blend = 0.3, loop = true},
		swim = {range = {x = 220, y = 239}, speed = 20, frame_blend = 0.3, loop = true}
	},
	{
		stand = {range = {x = 1, y = 40}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 50, y = 69}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 50, y = 69}, speed = 40, frame_blend = 0.3, loop = true},
		float = {range = {x = 80, y = 119}, speed = 10, frame_blend = 0.3, loop = true},
		swim = {range = {x = 130, y = 149}, speed = 20, frame_blend = 0.3, loop = true}
	}
}

local utility_stacks = {
	{ -- Tree Frog
		animalia.mob_ai.basic_wander,
		animalia.mob_ai.swim_wander,
		animalia.mob_ai.frog_seek_bug,
		animalia.mob_ai.frog_breed,
		animalia.mob_ai.basic_flee,
		animalia.mob_ai.frog_flop,
		animalia.mob_ai.frog_seek_water
	},
	{ -- Bull Frog
		animalia.mob_ai.basic_wander,
		animalia.mob_ai.swim_wander,
		animalia.mob_ai.basic_seek_food,
		animalia.mob_ai.basic_attack,
		animalia.mob_ai.frog_breed,
		animalia.mob_ai.frog_flop,
		animalia.mob_ai.frog_seek_water
	},
	{ -- Poison Dart Frog
		animalia.mob_ai.basic_wander,
		animalia.mob_ai.swim_wander,
		animalia.mob_ai.frog_breed,
		animalia.mob_ai.basic_flee,
		animalia.mob_ai.frog_flop,
		animalia.mob_ai.frog_seek_water
	}
}

local head_data = {
	{
		offset = {x = 0, y = 0.43, z = 0},
		pitch_correction = -15,
		pivot_h = 0.3,
		pivot_v = 0.3
	},
	{
		offset = {x = 0, y = 0.50, z = 0},
		pitch_correction = -20,
		pivot_h = 0.3,
		pivot_v = 0.3
	},
	{
		offset = {x = 0, y = 0.25, z = 0},
		pitch_correction = -20,
		pivot_h = 0.3,
		pivot_v = 0.3
	}
}

local follow = {
	{
		"butterflies:butterfly_white",
		"butterflies:butterfly_violet",
		"butterflies:butterfly_red"
	},
	{
		"animalia:rat_raw"
	},
	{}
}

creatura.register_mob("animalia:frog", {
	-- Engine Props
	visual_size = {x = 10, y = 10},
	meshes = {
		"animalia_frog.b3d",
		"animalia_bull_frog.b3d",
		"animalia_dart_frog.b3d"
	},
	child_mesh = "animalia_tadpole.b3d",
	mesh_textures = {
		{
			"animalia_tree_frog.png"
		},
		{
			"animalia_bull_frog.png"
		},
		{
			"animalia_dart_frog_1.png",
			"animalia_dart_frog_2.png",
			"animalia_dart_frog_3.png"
		}
	},
	child_textures = {
		"animalia_tadpole.png"
	},
	makes_footstep_sound = true,

	-- Creatura Props
	max_health = 5,
	armor_groups = {fleshy = 100},
	damage = 2,
	max_breath = 0,
	speed = 2,
	tracking_range = 8,
	max_boids = 0,
	despawn_after = 300,
	max_fall = 0,
	stepheight = 1.1,
	sound = {},
	hitbox = {
		width = 0.15,
		height = 0.3
	},
	animations = {},
	follow = {},
	drops = {},
	fancy_collide = false,
	bouyancy_multiplier = 0,
	hydrodynamics_multiplier = 0.3,

	-- Animalia Props
	flee_puncher = true,
	catch_with_net = true,
	catch_with_lasso = false,
	head_data = {},

	-- Functions
	utility_stack = {},

	on_grown = function(self)
		local mesh_no = self.mesh_no
		self.animations = animations[mesh_no]
		self.utility_stack = utility_stacks[mesh_no]
		self.head_data = head_data[mesh_no]
		self.object:set_properties({
			collisionbox = hitboxes[mesh_no]
		})
	end,

	activate_func = function(self)
		animalia.initialize_api(self)
		self.trust = self:recall("trust") or {}

		local mesh_no = self.mesh_no

		-- Set Species Properties
		if self.growth_scale >= 0.8 then
			self.animations = animations[mesh_no]
			self.utility_stack = utility_stacks[mesh_no]
			self.object:set_properties({
				collisionbox = hitboxes[mesh_no]
			})
		else
			self.animations = {
				swim = {range = {x = 1, y = 19}, speed = 20, frame_blend = 0.1, loop = true}
			}
			self.utility_stack = utility_stacks[1]
		end

		self.head_data = head_data[mesh_no]

		if mesh_no == 1 then
			for i = 1, 15 do
				local frame = 120 + i
				local anim = {range = {x = frame, y = frame}, speed = 1, frame_blend = 0.3, loop = false}
				self.animations["tongue_" .. i] = anim
			end
		elseif mesh_no == 2 then
			self.object:set_armor_groups({fleshy = 50})
			self.warn_before_attack = true
		end
	end,

	step_func = function(self)
		animalia.step_timers(self)
		animalia.head_tracking(self, 0.2, 0.2)
		animalia.do_growth(self, 60)
		if self:timer(random(5, 15)) then
			self:play_sound("random")
		end

		if not self.mesh_vars_set then
			self.follow = follow[self.mesh_no]
		end
	end,

	death_func = function(self)
		if self:get_utility() ~= "animalia:die" then
			self:initiate_utility("animalia:die", self)
		end
	end,

	on_rightclick = function(self, clicker)
		if self.mesh_no ~= 2 then return end
		if animalia.feed(self, clicker, false, true) then
			animalia.add_trust(self, clicker, 1)
			return
		end
		if animalia.set_nametag(self, clicker) then
			return
		end
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		creatura.basic_punch_func(self, puncher, time_from_last_punch, tool_capabilities, direction, damage)
		local name = puncher:is_player() and puncher:get_player_name()
		if name then
			self.trust[name] = 0
			self:memorize("trust", self.trust)
			if self.mesh_no == 3 then
				animalia.set_player_effect(name, poison_effect, 3)
			end
		end
	end
})

creatura.register_spawn_item("animalia:frog", {
	col1 = "67942e",
	col2 = "294811"
})