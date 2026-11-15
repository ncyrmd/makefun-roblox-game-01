-- Neon Harvest: the best score, kept in a DataStore with a session
-- fallback. Every DataStore call is pcall-guarded: in Studio, or when
-- the service is unreachable, the game keeps working and the best score
-- simply lives for the session instead of forever.

local DataStoreService = game:GetService("DataStoreService")

local ScoreStore = {}

local STORE_NAME = "NeonHarvestBest_v1"
local sessionBest: { [number]: number } = {}

local function store()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		return result
	end
	return nil
end

-- The player's best score: the saved one, or 0 when there is none.
function ScoreStore.loadBest(player: Player): number
	local dataStore = store()
	if dataStore ~= nil then
		local ok, saved = pcall(function()
			return dataStore:GetAsync("best_" .. player.UserId)
		end)
		if ok and typeof(saved) == "number" then
			sessionBest[player.UserId] = saved
			return saved
		end
	end
	return sessionBest[player.UserId] or 0
end

-- Keep the best score if the new score beats it. Returns the best score
-- and whether this run set a new one.
function ScoreStore.saveBest(player: Player, score: number): (number, boolean)
	local oldBest = sessionBest[player.UserId]
	if oldBest == nil then
		oldBest = ScoreStore.loadBest(player)
	end
	local isNewBest = score > 0 and score > oldBest
	local best = math.max(oldBest, score)
	sessionBest[player.UserId] = best
	local dataStore = store()
	if dataStore ~= nil then
		pcall(function()
			dataStore:UpdateAsync("best_" .. player.UserId, function(old)
				if typeof(old) == "number" then
					return math.max(old, score)
				end
				return score
			end)
		end)
	end
	return best, isNewBest
end

return ScoreStore
