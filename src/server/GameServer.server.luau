-- Neon Harvest (server): the one place that owns the game.
-- Each player gets their own game: score, combo, lives, level, timer and
-- every falling orb. The client only renders what the server says and
-- reports catches; the server checks each catch against the orb's real
-- arrival time and the basket's real position before it pays out.
-- A catch the server cannot verify is ignored, never punished.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Parent.Shared.Config)
local OrbMath = require(script.Parent.Parent.Shared.OrbMath)
local ScoreStore = require(script.Parent.ScoreStore)

local REMOTE_NAMES = { "StartGame", "CatchAttempt", "OrbSpawned", "OrbResolved", "StateSnapshot", "PhaseChanged" }

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "NeonHarvestRemotes"
remotesFolder.Parent = ReplicatedStorage
local remotes: { [string]: RemoteEvent } = {}
for _, name in ipairs(REMOTE_NAMES) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	remotes[name] = remote
end

type Orb = {
	id: number,
	kind: string,
	lane: number,
	speed: number,
	spawnTime: number,
	resolved: boolean,
}

type Game = {
	player: Player,
	phase: string,
	score: number,
	combo: number,
	lives: number,
	level: number,
	timeLeft: number,
	best: number,
	orbs: { [number]: Orb },
	nextOrbId: number,
	lastLane: number,
	runId: number,
	running: boolean,
}

local games: { [Player]: Game } = {}

local function sendSnapshot(game: Game)
	remotes.StateSnapshot:FireClient(game.player, {
		phase = game.phase,
		score = game.score,
		lives = game.lives,
		level = game.level,
		combo = game.combo,
		multiplier = OrbMath.comboMultiplier(game.combo),
		timeLeft = game.timeLeft,
		target = OrbMath.levelTuning(game.level).Target,
		best = game.best,
	})
end

local function sendPhase(game: Game, phase: string, payload: { [string]: any }?)
	remotes.PhaseChanged:FireClient(game.player, phase, payload or {})
end

local function newGame(player: Player): Game
	local game: Game = {
		player = player,
		phase = "menu",
		score = 0,
		combo = 0,
		lives = Config.START_LIVES,
		level = 1,
		timeLeft = Config.LEVEL_TIME,
		best = ScoreStore.loadBest(player),
		orbs = {},
		nextOrbId = 1,
		lastLane = 0,
		runId = 0,
		running = false,
	}
	games[player] = game
	return game
end

local function resolveOrb(game: Game, orb: Orb, result: string, payload: { [string]: any }?)
	if orb.resolved then
		return
	end
	orb.resolved = true
	game.orbs[orb.id] = nil
	remotes.OrbResolved:FireClient(game.player, orb.id, result, payload or {})
end

local function endGame(game: Game, won: boolean, reason: string)
	if not game.running and game.phase ~= "playing" then
		return
	end
	game.running = false
	game.runId += 1
	game.phase = if won then "victory" else "gameover"
	local best, isNewBest = ScoreStore.saveBest(game.player, game.score)
	game.best = best
	sendPhase(game, game.phase, {
		score = game.score,
		best = best,
		isNewBest = isNewBest,
		reason = reason,
	})
	sendSnapshot(game)
end

local function levelClear(game: Game)
	if game.level >= Config.MAX_LEVEL then
		endGame(game, true, "all-levels")
		return
	end
	game.phase = "levelclear"
	game.runId += 1
	sendPhase(game, "levelclear", { level = game.level, score = game.score })
	sendSnapshot(game)
	task.delay(2.5, function()
		if games[game.player] ~= game then
			return
		end
		game.level += 1
		game.timeLeft = Config.LEVEL_TIME
		beginPlaying(game)
	end)
end

local function spawnOrb(game: Game)
	local tuning = OrbMath.levelTuning(game.level)
	local kind = OrbMath.pickKind(math.random())
	local lane = math.random(1, Config.LANE_COUNT)
	if lane == game.lastLane then
		lane = (lane % Config.LANE_COUNT) + 1
	end
	game.lastLane = lane
	local def = Config.ORBS[kind]
	local speed = def.Speed * tuning.SpeedMul * (0.95 + math.random() * 0.1)
	local orb: Orb = {
		id = game.nextOrbId,
		kind = kind,
		lane = lane,
		speed = speed,
		spawnTime = workspace:GetServerTimeNow(),
		resolved = false,
	}
	game.nextOrbId += 1
	game.orbs[orb.id] = orb
	remotes.OrbSpawned:FireClient(game.player, {
		id = orb.id,
		kind = kind,
		lane = lane,
		speed = speed,
		spawnTime = orb.spawnTime,
	})
end

local function spawnLoop(game: Game, runId: number)
	while game.running and game.runId == runId and game.phase == "playing" do
		local tuning = OrbMath.levelTuning(game.level)
		task.wait(tuning.SpawnEvery * (0.9 + math.random() * 0.2))
		if game.running and game.runId == runId and game.phase == "playing" then
			spawnOrb(game)
		end
	end
end

local function tickLoop(game: Game, runId: number)
	while game.running and game.runId == runId and game.phase == "playing" do
		task.wait(0.1)
		if not (game.running and game.runId == runId and game.phase == "playing") then
			break
		end
		game.timeLeft -= 0.1
		local now = workspace:GetServerTimeNow()
		for id, orb in pairs(game.orbs) do
			if now > OrbMath.arrivalTime(orb.spawnTime, orb.speed) + Config.CATCH_WINDOW then
				local kind = orb.kind
				if kind == "Star" or kind == "Golden" then
					game.combo = 0
				end
				resolveOrb(game, orb, "missed", { kind = kind })
			end
		end
		if game.timeLeft <= 0 then
			game.timeLeft = 0
			sendSnapshot(game)
			endGame(game, false, "time")
			break
		end
		sendSnapshot(game)
	end
end

local function beginPlaying(game: Game)
	game.phase = "playing"
	game.runId += 1
	local runId = game.runId
	sendPhase(game, "playing", { level = game.level })
	sendSnapshot(game)
	task.spawn(spawnLoop, game, runId)
	task.spawn(tickLoop, game, runId)
end

local function startGame(player: Player)
	local game = games[player]
	if game == nil then
		game = newGame(player)
	end
	if game.phase == "playing" or game.phase == "countdown" or game.phase == "levelclear" then
		return
	end
	game.score = 0
	game.combo = 0
	game.lives = Config.START_LIVES
	game.level = 1
	game.timeLeft = Config.LEVEL_TIME
	game.orbs = {}
	game.nextOrbId = 1
	game.lastLane = 0
	game.running = true
	game.phase = "countdown"
	game.runId += 1
	sendPhase(game, "countdown", { count = 3 })
	sendSnapshot(game)
	task.spawn(function()
		local runId = game.runId
		for count = 3, 1, -1 do
			task.wait(1)
			if game.runId ~= runId or not game.running then
				return
			end
			if count > 1 then
				sendPhase(game, "countdown", { count = count - 1 })
			end
		end
		if game.runId ~= runId or not game.running then
			return
		end
		beginPlaying(game)
	end)
end

local function onCatchAttempt(player: Player, orbId: number, basketX: number)
	local game = games[player]
	if game == nil or game.phase ~= "playing" then
		return
	end
	local orb = game.orbs[orbId]
	if orb == nil or orb.resolved then
		return
	end
	if typeof(basketX) ~= "number" then
		return
	end
	basketX = math.clamp(basketX, 0, Config.ARENA_WIDTH - Config.BASKET_WIDTH)
	local now = workspace:GetServerTimeNow()
	local arrival = OrbMath.arrivalTime(orb.spawnTime, orb.speed)
	if math.abs(now - arrival) > Config.CATCH_WINDOW then
		return
	end
	if not OrbMath.basketCoversOrb(basketX, OrbMath.laneCenterX(orb.lane)) then
		return
	end
	local def = Config.ORBS[orb.kind]
	if orb.kind == "Star" or orb.kind == "Golden" then
		game.combo += 1
		local points = OrbMath.pointsFor(orb.kind, game.combo)
		game.score += points
		resolveOrb(game, orb, "caught", {
			kind = orb.kind,
			points = points,
			combo = game.combo,
			multiplier = OrbMath.comboMultiplier(game.combo),
		})
	elseif orb.kind == "Heart" then
		game.lives = math.min(Config.MAX_LIVES, game.lives + 1)
		resolveOrb(game, orb, "caught", { kind = orb.kind, points = 0, lives = game.lives })
	elseif orb.kind == "Bomb" then
		game.lives -= 1
		game.combo = 0
		resolveOrb(game, orb, "bomb", { kind = orb.kind, lives = game.lives })
	end
	sendSnapshot(game)
	if game.lives <= 0 then
		endGame(game, false, "lives")
	elseif game.score >= OrbMath.levelTuning(game.level).Target then
		levelClear(game)
	end
end

remotes.StartGame.OnServerEvent:Connect(startGame)
remotes.CatchAttempt.OnServerEvent:Connect(onCatchAttempt)

Players.PlayerAdded:Connect(function(player)
	local game = newGame(player)
	sendPhase(game, "menu", { best = game.best })
	sendSnapshot(game)
end)

Players.PlayerRemoving:Connect(function(player)
	local game = games[player]
	if game ~= nil then
		game.running = false
		game.runId += 1
		games[player] = nil
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	local game = newGame(player)
	sendPhase(game, "menu", { best = game.best })
	sendSnapshot(game)
end

print("Neon Harvest server ready.")
