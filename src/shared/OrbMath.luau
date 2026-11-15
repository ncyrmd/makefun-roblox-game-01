-- Neon Harvest: pure maths for the falling orbs. No services, no state,
-- so the server and the client always agree on the same numbers.

local Config = require(script.Parent.Config)

local OrbMath = {}

-- The centre x of a lane, in pixels from the left of the arena.
function OrbMath.laneCenterX(lane: number): number
	local laneWidth = Config.ARENA_WIDTH / Config.LANE_COUNT
	return (lane - 0.5) * laneWidth
end

-- How far an orb has fallen (pixels from the top) at a given moment.
function OrbMath.orbY(spawnTime: number, speed: number, now: number): number
	local age = now - spawnTime
	if age < 0 then
		return 0
	end
	return speed * age
end

-- When an orb's centre reaches the basket line, on the shared clock.
function OrbMath.arrivalTime(spawnTime: number, speed: number): number
	return spawnTime + Config.BASKET_Y / speed
end

-- Does the basket cover the orb horizontally? Both x values are the
-- left edge of the frame; the orb is treated as a point at its centre.
function OrbMath.basketCoversOrb(basketX: number, orbCenterX: number): boolean
	local basketCentre = basketX + Config.BASKET_WIDTH / 2
	local reach = (Config.BASKET_WIDTH + Config.ORB_SIZE) / 2
	return math.abs(basketCentre - orbCenterX) <= reach
end

-- The score multiplier for a catch streak. Caps at MAX_MULTIPLIER.
function OrbMath.comboMultiplier(combo: number): number
	local mult = 1 + math.floor(combo / Config.COMBO_PER_MULTIPLIER)
	return math.min(mult, Config.MAX_MULTIPLIER)
end

-- Points a catch is worth, before the server adds them to the score.
function OrbMath.pointsFor(kind: string, combo: number): number
	local def = Config.ORBS[kind]
	if def == nil then
		return 0
	end
	return def.Points * OrbMath.comboMultiplier(combo)
end

-- Pick an orb kind from the spawn table, weighted by Config.ORBS.
function OrbMath.pickKind(randomValue: number): string
	local total = 0
	for _, kind in ipairs(Config.ORB_KIND_ORDER) do
		total += Config.ORBS[kind].Weight
	end
	local roll = randomValue * total
	for _, kind in ipairs(Config.ORB_KIND_ORDER) do
		roll -= Config.ORBS[kind].Weight
		if roll <= 0 then
			return kind
		end
	end
	return "Star"
end

-- Level tuning for a level number, clamped to the last level.
function OrbMath.levelTuning(level: number)
	return Config.LEVELS[math.clamp(level, 1, Config.MAX_LEVEL)]
end

return OrbMath
