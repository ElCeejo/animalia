---------
-- Cat --
---------

local clamp_bone_rot = animalia.clamp_bone_rot

local interp = animalia.interp

local follow = {
	"animalia:poultry_raw"
}

if minetest.registered_items["ethereal:fish_raw"] then
	follow = {
		"ethereal:fish_raw",
		"animalia:poultry_raw"
	}
end

local function cat_logic(self)
	
	if self.hp <= 0 then	
		mob_core.on_die(self)
		return
	end

	if self._anim == "run" then
		local pos = self.object:get_pos()
		minetest.add_particlespawner({
			amount = 1,
			time = 0.25,
			minpos = pos,
			maxpos = pos,
			minvel = vector.new(-1, 1, -1),
			maxvel = vector.new(1, 2, 1),
			minacc = vector.new(0, -9.81, 0),
			maxacc = vector.new(0, -9.81, 0),
			minsize = 0.25,
			maxsize = 0.5,
			collisiondetection = true,
			texture = "default_dirt.png",
		})
	end

	animalia.head_tracking(self, 0.25, 0.25)

	if mobkit.timer(self, 1) then

		local prty = mobkit.get_queue_priority(self)
		local player = mobkit.get_nearby_player(self)
		local trust = 0

		mob_core.random_sound(self, 30)
		mob_core.growth(self)

		if player then
			if not self.trust[player:get_player_name()] then
				self.trust[player:get_player_name()] = 0
				mobkit.remember(self, "trust", self.trust)
			else
				trust = self.trust[player:get_player_name()]
			end
		end

		if self.trust_cooldown > 0 then
			self.trust_cooldown = mobkit.remember(self, "trust_cooldown", self.trust_cooldown - 1)
		end

		if self.interact_sound_cooldown > 0 then
			self.interact_sound_cooldown = self.interact_sound_cooldown - 1
		end

		if self.owner
		and self.trust[self.owner] > 7 then
			if prty < 22
			and self.order == "sit" then
				if not mobkit.is_queue_empty_high(self) then
					mobkit.clear_queue_high(self)
				end
				mobkit.animate(self, "sit")
				return
			end
	
			if prty < 21
			and self.owner_target then
				if not mob_core.shared_owner(self, self.owner_target) then
					animalia.hq_attack(self, 21, self.owner_target)
				end
			end
	
			if prty < 20
			and self.order == "follow"
			and minetest.get_player_by_name(self.owner) then
				local owner = minetest.get_player_by_name(self.owner)
				animalia.hq_follow_player(self, 20, owner, true)
			end

			if prty < 4
			and self.breeding then
				animalia.hq_breed(self, 3)
			end
		end

		if prty < 5
		and self.isinliquid then
			animalia.hq_go_to_land(self, 5)
		end

		if prty < 3
		and player then
			if player:get_velocity()
			and vector.length(player:get_velocity()) < 2 then
				if mob_core.follow_holding(self, player)
				and trust >= 4 then
					animalia.hq_follow_player(self, 3, player)
				end
			elseif player:get_wielded_item():get_name() == "animalia:cat_toy" then
				animalia.hq_follow_player(self, 3, player, true)
				return
			end
		end
		
		if player
		and prty == 3
		and not mob_core.follow_holding(self, player)
		and player:get_wielded_item():get_name() ~= "animalia:cat_toy" then
			mobkit.clear_queue_high(self)
		end

		if prty < 2
		and player
		and trust > 4 then
			local r = math.random(48)
			if r < 2 then
				animalia.hq_walk_in_front_of_player(self, 2, player)
			elseif r < 3 then
				animalia.hq_find_and_break_glass(self, 2)
			end
		end

		if mobkit.is_queue_empty_high(self) then
			animalia.hq_wander_ranged(self, 0)
		end
	end
end

animalia.register_mob("cat", {
    -- Stats
    health = 10,
    fleshy = 100,
    view_range = 32,
    lung_capacity = 10,
    -- Visual
	collisionbox = {-0.2, 0, -0.2, 0.2, 0.4, 0.2},
	visual_size = {x = 6, y = 6},
	scale_stage1 = 0.5,
    scale_stage2 = 0.65,
    scale_stage3 = 0.80,
	mesh = "animalia_cat.b3d",
	textures = {
		"animalia_cat_1.png",
		"animalia_cat_2.png",
		"animalia_cat_3.png",
		"animalia_cat_4.png"
	},
	animations = {
		stand = {range = {x = 1, y = 39}, speed = 10, frame_blend = 0.3, loop = true},
		walk = {range = {x = 50, y = 90}, speed = 45, frame_blend = 0.3, loop = true},
		run = {range = {x = 100, y = 130}, speed = 50, frame_blend = 0.3, loop = true},
		sit = {range = {x = 140, y = 180}, speed = 10, frame_blend = 0.3, loop = true},
		smack = {range = {x = 190, y = 210}, speed = 40, frame_blend = 0.1, loop = true},
	},
    -- Physics
    speed = 8,
    max_fall = 4,
    -- Attributes
    sounds = {
        alter_child_pitch = true,
        random = {
            name = "animalia_cat_idle",
            gain = 0.25,
            distance = 8
        },
		purr = {
            name = "animalia_cat_purr",
            gain = 0.6,
            distance = 8
        },
        hurt = {
            name = "animalia_cat_hurt",
            gain = 0.25,
            distance = 8
        },
        death = {
            name = "animalia_cat_hurt",
            gain = 0.25,
            distance = 8
        }
	},
	reach = 2,
    damage = 3,
    knockback = 2,
    punch_cooldown = 1,
    -- Behavior
    defend_owner = true,
	follow = follow,
    -- Functions
	head_data = {
		offset = {x = 0, y = 0.17, z = 0},
		pitch_correction = -20,
		pivot_h = 0.35,
		pivot_v = 0.2
	},
    logic = cat_logic,
    get_staticdata = mobkit.statfunc,
	on_step = animalia.on_step,
	on_activate = function(self, staticdata, dtime_s)
		animalia.on_activate(self, staticdata, dtime_s)
		self.trust = mobkit.recall(self, "trust") or {}
		self.trust_cooldown = mobkit.recall(self, "trust_cooldown") or 0
		self.interact_sound_cooldown = 0
	end,
	on_rightclick = function(self, clicker)
		local item = clicker:get_wielded_item():get_name()
		if item == "animalia:net" then return end
		if not self.trust[clicker:get_player_name()] then
			self.trust[clicker:get_player_name()] = 0
			mobkit.remember(self, "trust", self.trust)
		end
		local trust = self.trust[clicker:get_player_name()]
		local pos = self.object:get_pos()
		local prt_pos = vector.new(pos.x, pos.y + 0.5, pos.z)
		local minppos = vector.add(prt_pos, 1)
		local maxppos = vector.subtract(prt_pos, 1)
		if animalia.feed_tame(self, clicker, math.random(3, 5), trust >= 10, trust >= 10) then
			if self.trust_cooldown <= 0
			and trust < 10 then
				self.trust[clicker:get_player_name()] = trust + 1
				self.trust_cooldown = mobkit.remember(self, "trust_cooldown", 60)
				mobkit.remember(self, "trust", self.trust)
				animalia.particle_spawner(prt_pos, "mob_core_green_particle.png", "float", minppos, maxppos)
			end
			return
		end
		mob_core.protect(self, clicker, true)
		mob_core.nametag(self, clicker, true)
		if mobkit.get_queue_priority(self) == 3
		and clicker:get_wielded_item():get_name() == "animalia:cat_toy" then
			if trust < 10 then
				self.trust[clicker:get_player_name()] = trust + 1
				mobkit.remember(self, "trust", self.trust)
				animalia.particle_spawner(prt_pos, "mob_core_green_particle.png", "float", minppos, maxppos)
				if self.interact_sound_cooldown <= 0 then
					self.sounds["purr"].gain = 1
					self.interact_sound_cooldown = 3
					mobkit.make_sound(self, "purr")
				end
			end
		end

		if not self.owner
		or clicker:get_player_name() ~= self.owner then
			return
		end
		if clicker:get_player_control().sneak then
			if self.interact_sound_cooldown <= 0 then
				self.sounds["purr"].gain = 0.15 * self.trust[self.owner]
				self.interact_sound_cooldown = 3
				mobkit.make_sound(self, "purr")
			end
		end
		if trust <= 7 then
			if self.interact_sound_cooldown <= 0 then
				self.interact_sound_cooldown = 3
				mobkit.make_sound(self, "random")
			end
			return
		end
		if self.order == "wander" then
			self.order = "follow"
		elseif self.order == "follow" then
			self.order = "sit"
		else
			self.order = "wander"
		end
		mobkit.remember(self, "order", self.order)
	end,
	on_punch = function(self, puncher, _, tool_capabilities, dir)
		mob_core.on_punch_basic(self, puncher, tool_capabilities, dir)
		animalia.hq_sporadic_flee(self, 10)
		if not self.trust[puncher:get_player_name()] then
			self.trust[puncher:get_player_name()] = 0
		else
			local trust = self.trust[puncher:get_player_name()]
			self.trust[puncher:get_player_name()] = trust - 1
		end
		local pos = self.object:get_pos()
		local prt_pos = vector.new(pos.x, pos.y + 0.5, pos.z)
		local minppos = vector.add(prt_pos, 1)
		local maxppos = vector.subtract(prt_pos, 1)
		animalia.particle_spawner(prt_pos, "mob_core_red_particle.png", "float", minppos, maxppos)
		mobkit.remember(self, "trust", self.trust)
	end
})

mob_core.register_spawn_egg("animalia:cat", "db9764" ,"cf8d5a")