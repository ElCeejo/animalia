----------
-- Wolf --
----------

local clamp_bone_rot = animalia.clamp_bone_rot

local interp = animalia.interp

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

function animalia.bh_attack(self, prty, target)
	if mobkit.is_alive(target) then
		if target:is_player() then
			if not self.tamed
			or target:get_player_name() ~= self.owner then
				animalia.hq_attack(self, prty, target)
			end
		elseif target:get_luaentity() then
			if not self.tamed
			or not mob_core.shared_owner(self, target) then
				animalia.hq_attack(self, prty, target)
			end
		end
	end
end

local function wolf_logic(self)
	
	if self.hp <= 0 then	
		mob_core.on_die(self)
		return
	end

	animalia.head_tracking(self, 0.5, 0.75)

	if mobkit.timer(self, 1) then

		local prty = mobkit.get_queue_priority(self)
		local player = mobkit.get_nearby_player(self)

		mob_core.random_sound(self, 22)
		mob_core.growth(self)

		if self.status ~= "following" then
            if self.attention_span > 1 then
                self.attention_span = self.attention_span - 1
                mobkit.remember(self, "attention_span", self.attention_span)
            end
		else
			self.attention_span = self.attention_span + 1
			mobkit.remember(self, "attention_span", self.attention_span)
		end

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
		and self.owner
		and minetest.get_player_by_name(self.owner) then
			local owner = minetest.get_player_by_name(self.owner)
			animalia.hq_follow_player(self, 20, owner, true)
		end

		if prty < 5
		and self.isinliquid then
			animalia.hq_go_to_land(self, 5)
		end

		if prty < 4
        and self.breeding then
            animalia.hq_breed(self, 4)
		end

		if prty == 3
		and not self.lasso_player
		and (not player
		or not mob_core.follow_holding(self, player)) then
			mobkit.clear_queue_high(self)
		end

        if prty < 3 then
			if self.caught_with_lasso
			and self.lasso_player then
				animalia.hq_follow_player(self, 3, self.lasso_player, true)
			elseif player then
	        	if self.attention_span < 5 then
				    if mob_core.follow_holding(self, player) then
            	        animalia.hq_follow_player(self, 3, player)
            	        self.attention_span = self.attention_span + 3
            	    end
            	end
			end
        end
		
		if prty < 2 then
			local target = mobkit.get_closest_entity(self, "animalia:sheep")
			if target then
				animalia.bh_attack(self, 2, target)
			end
		end

		if mobkit.is_queue_empty_high(self) then
			animalia.hq_wander_group(self, 0, 8)
		end
	end
end

animalia.register_mob("wolf", {
    -- Stats
    health = 25,
    fleshy = 100,
    view_range = 32,
    lung_capacity = 10,
    -- Visual
	collisionbox = {-0.35, -0.375, -0.35, 0.35, 0.4, 0.35},
	visual_size = {x = 9, y = 9},
	scale_stage1 = 0.5,
    scale_stage2 = 0.65,
    scale_stage3 = 0.80,
	mesh = "animalia_wolf.b3d",
	textures = {"animalia_wolf.png"},
	animations = {
		stand = {range = {x = 30, y = 49}, speed = 10, frame_blend = 0.3, loop = true},
		sit = {range = {x = 60, y = 90}, speed = 20, frame_blend = 0.3, loop = true},
		walk = {range = {x = 1, y = 20}, speed = 30, frame_blend = 0.3, loop = true},
		run = {range = {x = 1, y = 20}, speed = 45, frame_blend = 0.3, loop = true},
	},
    -- Physics
    speed = 8,
    max_fall = 4,
    -- Attributes
    sounds = {
        alter_child_pitch = true,
        random = {
            name = "animalia_wolf_idle",
            gain = 1.0,
            distance = 8
        },
        hurt = {
            name = "animalia_wolf_hurt",
			gain = 1.0,
			pitch = 0.5,
            distance = 8
        },
        death = {
            name = "animalia_wolf_death",
            gain = 1.0,
            distance = 8
        }
	},
	reach = 2,
    damage = 3,
    knockback = 2,
    punch_cooldown = 1,
    -- Behavior
    defend_owner = true,
	follow = {
		"bonemeal:bone",
		"animalia:beef_raw",
		"animalia:porkchop_raw",
		"animalia:mutton_raw",
		"animalia:poultry_raw"
	},
    -- Functions
	head_data = {
		offset = {x = 0, y = 0.22, z = 0},
		pitch_correction = -20,
		pivot_h = 0.65,
		pivot_v = 0.65
	},
    logic = wolf_logic,
    get_staticdata = mobkit.statfunc,
	on_step = animalia.on_step,
	on_activate = animalia.on_activate,
	on_rightclick = function(self, clicker)
		if animalia.feed_tame(self, clicker, math.random(3, 5), true, true) then return end
		mob_core.protect(self, clicker, false)
		mob_core.nametag(self, clicker, true)
		if not self.owner
		or clicker:get_player_name() ~= self.owner then return end
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
		animalia.bh_attack(self, 10, puncher)
	end
})

mob_core.register_spawn_egg("animalia:wolf", "a19678" ,"231b13")