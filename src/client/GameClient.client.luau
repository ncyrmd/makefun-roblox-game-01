-- Neon Harvest (client): draws the game and reads the player's hands.
-- The server owns the score, the lives and every orb; this script owns
-- the screen. It moves the basket, draws each orb where the server's
-- clock says it is, and reports a catch the moment an orb reaches the
-- basket line. The server still judges every catch before it pays out.
--
-- Keys: Left/Right arrows or A/D. The kit warns that Roblox's default
-- camera scripts eat the arrow keys before InputBegan sees them, so the
-- movement binds through ContextActionService and polls IsKeyDown, and
-- two on-screen buttons cover touch players.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local OrbMath = require(ReplicatedStorage.Shared.OrbMath)
local GuiTheme = require(ReplicatedStorage.Shared.GuiTheme)
local Effects = require(script.Parent.Effects)

local Colors = Config.COLORS
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NeonHarvestRemotes")
local startGameRemote = remotes:WaitForChild("StartGame")
local catchRemote = remotes:WaitForChild("CatchAttempt")
local orbSpawnedRemote = remotes:WaitForChild("OrbSpawned")
local orbResolvedRemote = remotes:WaitForChild("OrbResolved")
local snapshotRemote = remotes:WaitForChild("StateSnapshot")
local phaseRemote = remotes:WaitForChild("PhaseChanged")

-- ------------------------------------------------------------------ state

local phase = "menu"
local basketX = (Config.ARENA_WIDTH - Config.BASKET_WIDTH) / 2
local bestScore = 0
local levelTarget = Config.LEVELS[1].Target
local moveLeft = false
local moveRight = false
local touchLeft = false
local touchRight = false
local orbs: { [number]: { frame: Frame, kind: string, lane: number, speed: number, spawnTime: number, attempted: boolean } } = {}

-- ------------------------------------------------------------------ gui

local gui = Instance.new("ScreenGui")
gui.Name = "NeonHarvestGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Colors.Background
root.BorderSizePixel = 0
root.Parent = gui

local uiScale = Instance.new("UIScale")
uiScale.Parent = root

-- Shrink the whole layout on small screens so the arena always fits.
local function fitScale()
	local camera = workspace.CurrentCamera
	local viewport = Vector2.new(1280, 720)
	if camera ~= nil then
		viewport = camera.ViewportSize
	end
	local scale = math.min(
		1,
		(viewport.X - 24) / (Config.ARENA_WIDTH + 16),
		(viewport.Y - 180) / (Config.ARENA_HEIGHT + 16)
	)
	uiScale.Scale = math.max(0.45, scale)
end

local title = GuiTheme.makeLabel(root, "Title", "NEON HARVEST", 40, Colors.Basket)
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0.5, -Config.ARENA_HEIGHT / 2 - 96)
title.Size = UDim2.fromOffset(Config.ARENA_WIDTH, 48)

-- HUD: score on the left, level and target in the middle, timer right.
local hud = Instance.new("Frame")
hud.Name = "Hud"
hud.AnchorPoint = Vector2.new(0.5, 0)
hud.Position = UDim2.new(0.5, 0, 0.5, -Config.ARENA_HEIGHT / 2 - 44)
hud.Size = UDim2.fromOffset(Config.ARENA_WIDTH, 36)
hud.BackgroundTransparency = 1
hud.Parent = root

local scoreLabel = GuiTheme.makeLabel(hud, "Score", "SCORE 0", 26, Colors.Text)
scoreLabel.Position = UDim2.fromOffset(0, 0)
scoreLabel.Size = UDim2.fromOffset(200, 36)
scoreLabel.TextXAlignment = Enum.TextXAlignment.Left

local levelLabel = GuiTheme.makeLabel(hud, "Level", "LEVEL 1", 26, Colors.Text)
levelLabel.AnchorPoint = Vector2.new(0.5, 0)
levelLabel.Position = UDim2.fromScale(0.5, 0)
levelLabel.Size = UDim2.fromOffset(160, 36)

local timerLabel = GuiTheme.makeLabel(hud, "Timer", "75s", 26, Colors.Text)
timerLabel.AnchorPoint = Vector2.new(1, 0)
timerLabel.Position = UDim2.fromScale(1, 0)
timerLabel.Size = UDim2.fromOffset(120, 36)
timerLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Target progress bar, just above the arena.
local progressBack = Instance.new("Frame")
progressBack.Name = "TargetBarBack"
progressBack.AnchorPoint = Vector2.new(0.5, 0)
progressBack.Position = UDim2.new(0.5, 0, 0.5, -Config.ARENA_HEIGHT / 2 - 8)
progressBack.Size = UDim2.fromOffset(Config.ARENA_WIDTH, 8)
progressBack.BackgroundColor3 = Colors.ArenaEdge
progressBack.BorderSizePixel = 0
progressBack.Parent = root

local progressFill = Instance.new("Frame")
progressFill.Name = "TargetBarFill"
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = Colors.Good
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBack

-- Lives and combo, under the arena.
local livesLabel = GuiTheme.makeLabel(root, "Lives", "♥♥♥", 26, Colors.Heart)
livesLabel.AnchorPoint = Vector2.new(0, 0)
livesLabel.Position = UDim2.new(0.5, -Config.ARENA_WIDTH / 2, 0.5, Config.ARENA_HEIGHT / 2 + 8)
livesLabel.Size = UDim2.fromOffset(160, 32)
livesLabel.TextXAlignment = Enum.TextXAlignment.Left

local comboLabel = GuiTheme.makeLabel(root, "Combo", "", 26, Colors.Golden)
comboLabel.AnchorPoint = Vector2.new(1, 0)
comboLabel.Position = UDim2.new(0.5, Config.ARENA_WIDTH / 2, 0.5, Config.ARENA_HEIGHT / 2 + 8)
comboLabel.Size = UDim2.fromOffset(200, 32)
comboLabel.TextXAlignment = Enum.TextXAlignment.Right

local arena = Instance.new("Frame")
arena.Name = "Arena"
arena.AnchorPoint = Vector2.new(0.5, 0.5)
arena.Position = UDim2.fromScale(0.5, 0.5)
arena.Size = UDim2.fromOffset(Config.ARENA_WIDTH, Config.ARENA_HEIGHT)
arena.BackgroundColor3 = Colors.Arena
arena.BorderColor3 = Colors.ArenaEdge
arena.BorderSizePixel = 2
arena.ClipsDescendants = true
arena.Parent = root

-- Lane guides, so the falling columns read at a glance.
for lane = 1, Config.LANE_COUNT do
	local guide = Instance.new("Frame")
	guide.Name = "Lane" .. lane
	guide.AnchorPoint = Vector2.new(0.5, 0)
	guide.Position = UDim2.fromOffset(OrbMath.laneCenterX(lane), 0)
	guide.Size = UDim2.fromOffset(2, Config.ARENA_HEIGHT)
	guide.BackgroundColor3 = Colors.ArenaEdge
	guide.BackgroundTransparency = 0.7
	guide.BorderSizePixel = 0
	guide.Parent = arena
end

local basket = Instance.new("Frame")
basket.Name = "Basket"
basket.Size = UDim2.fromOffset(Config.BASKET_WIDTH, Config.BASKET_HEIGHT)
basket.BackgroundColor3 = Colors.Basket
basket.BorderSizePixel = 0
basket.Parent = arena
local basketCorner = Instance.new("UICorner")
basketCorner.CornerRadius = UDim.new(0, 10)
basketCorner.Parent = basket
local basketGlow = Instance.new("TextLabel")
basketGlow.Name = "BasketMark"
basketGlow.Size = UDim2.fromScale(1, 1)
basketGlow.BackgroundTransparency = 1
basketGlow.Text = "▲"
basketGlow.TextColor3 = Colors.Background
basketGlow.TextSize = 18
basketGlow.Font = Enum.Font.GothamBold
basketGlow.Parent = basket

local function placeBasket()
	basket.Position = UDim2.fromOffset(math.floor(basketX + 0.5), Config.BASKET_Y)
end
placeBasket()

-- Touch buttons, bottom corners. They only steer while playing.
local function makeTouchButton(name: string, text: string, anchorX: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(anchorX, 1)
	if anchorX == 0 then
		button.Position = UDim2.new(0, 16, 1, -16)
	else
		button.Position = UDim2.new(1, -16, 1, -16)
	end
	button.Size = UDim2.fromOffset(84, 84)
	button.BackgroundColor3 = Colors.ArenaEdge
	button.BackgroundTransparency = 0.3
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Colors.Text
	button.TextSize = 40
	button.Font = Enum.Font.GothamBold
	button.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 42)
	corner.Parent = button
	return button
end

local leftButton = makeTouchButton("TouchLeft", "◀", 0)
local rightButton = makeTouchButton("TouchRight", "▶", 1)

leftButton.InputBegan:Connect(function()
	touchLeft = true
end)
leftButton.InputEnded:Connect(function()
	touchLeft = false
end)
rightButton.InputBegan:Connect(function()
	touchRight = true
end)
rightButton.InputEnded:Connect(function()
	touchRight = false
end)

-- Big centre text for the countdown and the level banners.
local banner = GuiTheme.makeLabel(root, "Banner", "", 44, Colors.Good)
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.5)
banner.Size = UDim2.fromOffset(Config.ARENA_WIDTH, 60)
banner.Visible = false
banner.ZIndex = 25

-- ------------------------------------------------------------------ screens

local menuOverlay = GuiTheme.makeOverlay(root, "MenuOverlay")
local menuPanel = GuiTheme.makePanel(menuOverlay, "MenuPanel", 520, 380)
local menuTitle = GuiTheme.makeLabel(menuPanel, "MenuTitle", "NEON HARVEST", 40, Colors.Basket)
menuTitle.Position = UDim2.fromOffset(0, 24)
menuTitle.Size = UDim2.fromOffset(520, 48)
local menuHow = GuiTheme.makeLabel(menuPanel, "MenuHow", "Catch the falling stars.\nDodge the bombs. Grab hearts to heal.\nReach the target before time runs out!", 22, Colors.Text)
menuHow.Position = UDim2.fromOffset(20, 88)
menuHow.Size = UDim2.fromOffset(480, 110)
local menuBest = GuiTheme.makeLabel(menuPanel, "MenuBest", "BEST 0", 24, Colors.Golden)
menuBest.Position = UDim2.fromOffset(0, 210)
menuBest.Size = UDim2.fromOffset(520, 32)
local menuControls = GuiTheme.makeLabel(menuPanel, "MenuControls", "Move: ← → or A / D  •  Touch: ◀ ▶", 20, Colors.Muted)
menuControls.Position = UDim2.fromOffset(0, 246)
menuControls.Size = UDim2.fromOffset(520, 28)
local playButton = GuiTheme.makeButton(menuPanel, "PlayButton", "▶  PLAY")
playButton.AnchorPoint = Vector2.new(0.5, 0)
playButton.Position = UDim2.new(0.5, 0, 0, 292)
playButton.Size = UDim2.fromOffset(240, 56)

local endOverlay = GuiTheme.makeOverlay(root, "EndOverlay")
endOverlay.Visible = false
local endPanel = GuiTheme.makePanel(endOverlay, "EndPanel", 520, 360)
local endTitle = GuiTheme.makeLabel(endPanel, "EndTitle", "GAME OVER", 40, Colors.Bad)
endTitle.Position = UDim2.fromOffset(0, 24)
endTitle.Size = UDim2.fromOffset(520, 48)
local endDetail = GuiTheme.makeLabel(endPanel, "EndDetail", "", 22, Colors.Text)
endDetail.Position = UDim2.fromOffset(20, 88)
endDetail.Size = UDim2.fromOffset(480, 100)
local endBest = GuiTheme.makeLabel(endPanel, "EndBest", "", 24, Colors.Golden)
endBest.Position = UDim2.fromOffset(0, 196)
endBest.Size = UDim2.fromOffset(520, 32)
local againButton = GuiTheme.makeButton(endPanel, "AgainButton", "↻  PLAY AGAIN")
againButton.AnchorPoint = Vector2.new(0.5, 0)
againButton.Position = UDim2.new(0.5, 0, 0, 252)
againButton.Size = UDim2.fromOffset(260, 56)

gui.Parent = player:WaitForChild("PlayerGui")
fitScale()
local camera = workspace.CurrentCamera
if camera ~= nil then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)
end

-- ------------------------------------------------------------------ screens

local function showMenu()
	menuOverlay.Visible = true
	endOverlay.Visible = false
	banner.Visible = false
	menuBest.Text = "BEST " .. bestScore
end

local function showEnd(won: boolean, payload: { [string]: any })
	endOverlay.Visible = true
	menuOverlay.Visible = false
	banner.Visible = false
	if won then
		endTitle.Text = "★ YOU WIN! ★"
		endTitle.TextColor3 = Colors.Good
		endDetail.Text = "You cleared all " .. Config.MAX_LEVEL .. " levels!\nFinal score: " .. (payload.score or 0)
	else
		endTitle.Text = "GAME OVER"
		endTitle.TextColor3 = Colors.Bad
		local reason = payload.reason
		local reasonText = "Out of lives!"
		if reason == "time" then
			reasonText = "Time ran out!"
		end
		endDetail.Text = reasonText .. "\nFinal score: " .. (payload.score or 0)
	end
	local bestText = "BEST " .. (payload.best or bestScore)
	if payload.isNewBest then
		bestText = "★ NEW BEST! " .. (payload.best or 0) .. " ★"
	end
	endBest.Text = bestText
end

local function showBanner(text: string, color: Color3, seconds: number)
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	task.delay(seconds, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

playButton.Activated:Connect(function()
	startGameRemote:FireServer()
end)
againButton.Activated:Connect(function()
	startGameRemote:FireServer()
end)

-- ------------------------------------------------------------------ input

-- One action per direction: the handler keys on the action name.
ContextActionService:BindAction("NeonMoveLeft", function(_, inputState: EnumItem)
	if inputState == Enum.UserInputState.Begin then
		moveLeft = true
	elseif inputState == Enum.UserInputState.End then
		moveLeft = false
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Left, Enum.KeyCode.A)
ContextActionService:BindAction("NeonMoveRight", function(_, inputState: EnumItem)
	if inputState == Enum.UserInputState.Begin then
		moveRight = true
	elseif inputState == Enum.UserInputState.End then
		moveRight = false
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Right, Enum.KeyCode.D)

-- ------------------------------------------------------------------ orbs

local function clearOrbs()
	for id, orb in pairs(orbs) do
		orb.frame:Destroy()
		orbs[id] = nil
	end
end

local function spawnOrbFrame(data: { [string]: any })
	local def = Config.ORBS[data.kind]
	if def == nil then
		return
	end
	local frame = Instance.new("Frame")
	frame.Name = "Orb" .. data.id
	frame.Size = UDim2.fromOffset(Config.ORB_SIZE, Config.ORB_SIZE)
	frame.BackgroundColor3 = def.Color
	frame.BorderSizePixel = 0
	frame.Parent = arena
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.BackgroundTransparency = 1
	glyph.Text = def.Symbol
	glyph.TextColor3 = Colors.Background
	glyph.TextSize = 24
	glyph.Font = Enum.Font.GothamBold
	glyph.Parent = frame
	orbs[data.id] = {
		frame = frame,
		kind = data.kind,
		lane = data.lane,
		speed = data.speed,
		spawnTime = data.spawnTime,
		attempted = false,
	}
end

-- ------------------------------------------------------------------ remotes

orbSpawnedRemote.OnClientEvent:Connect(spawnOrbFrame)

orbResolvedRemote.OnClientEvent:Connect(function(id: number, result: string, payload: { [string]: any })
	local orb = orbs[id]
	if orb ~= nil then
		local centre = UDim2.fromOffset(OrbMath.laneCenterX(orb.lane), OrbMath.orbY(orb.spawnTime, orb.speed, workspace:GetServerTimeNow()))
		if result == "caught" then
			Effects.popFrame(orb.frame)
			if payload.points ~= nil and payload.points > 0 then
				Effects.floatText(arena, "+" .. payload.points, centre, Colors.Good)
			elseif payload.kind == "Heart" then
				Effects.floatText(arena, "+1 ♥", centre, Colors.Heart)
			end
			Effects.playPing(payload.combo or 0)
			-- Let the pop tween finish before the frame goes away.
			local frame = orb.frame
			task.delay(0.2, function()
				if frame.Parent ~= nil then
					frame:Destroy()
				end
			end)
		elseif result == "bomb" then
			Effects.flashOverlay(root, Colors.Bad)
			Effects.shakeArena(arena)
			Effects.floatText(arena, "BOOM!", centre, Colors.Bad)
			Effects.playPing(0)
			orb.frame:Destroy()
		else
			orb.frame:Destroy()
		end
		orbs[id] = nil
	end
end)

snapshotRemote.OnClientEvent:Connect(function(state: { [string]: any })
	phase = state.phase
	bestScore = state.best or bestScore
	levelTarget = state.target or levelTarget
	if menuOverlay.Visible then
		menuBest.Text = "BEST " .. bestScore
	end
	scoreLabel.Text = "SCORE " .. (state.score or 0)
	levelLabel.Text = "LEVEL " .. (state.level or 1)
	timerLabel.Text = math.ceil(state.timeLeft or 0) .. "s"
	livesLabel.Text = string.rep("♥", math.max(state.lives or 0, 0))
	if (state.combo or 0) >= 2 then
		comboLabel.Text = "COMBO x" .. (state.combo or 0) .. "  (" .. (state.multiplier or 1) .. "x)"
	else
		comboLabel.Text = ""
	end
	local progress = math.clamp((state.score or 0) / levelTarget, 0, 1)
	progressFill.Size = UDim2.fromScale(progress, 1)
end)

phaseRemote.OnClientEvent:Connect(function(newPhase: string, payload: { [string]: any })
	phase = newPhase
	if newPhase == "menu" then
		bestScore = payload.best or bestScore
		clearOrbs()
		showMenu()
	elseif newPhase == "countdown" then
		menuOverlay.Visible = false
		endOverlay.Visible = false
		clearOrbs()
		basketX = (Config.ARENA_WIDTH - Config.BASKET_WIDTH) / 2
		placeBasket()
		showBanner(tostring(payload.count or 3), Colors.Text, 0.9)
	elseif newPhase == "playing" then
		banner.Visible = false
		if payload.level ~= nil and payload.level > 1 then
			showBanner("LEVEL " .. payload.level .. " — GO!", Colors.Good, 1.2)
		end
	elseif newPhase == "levelclear" then
		showBanner("LEVEL " .. (payload.level or 1) .. " CLEAR!", Colors.Good, 2.2)
	elseif newPhase == "gameover" then
		clearOrbs()
		showEnd(false, payload)
	elseif newPhase == "victory" then
		clearOrbs()
		showEnd(true, payload)
	end
end)

-- ------------------------------------------------------------------ loop

RunService.RenderStepped:Connect(function(dt: number)
	if phase ~= "playing" then
		return
	end
	local dir = 0
	if moveLeft or touchLeft then
		dir -= 1
	end
	if moveRight or touchRight then
		dir += 1
	end
	if dir ~= 0 then
		basketX = math.clamp(basketX + dir * Config.BASKET_SPEED * dt, 0, Config.ARENA_WIDTH - Config.BASKET_WIDTH)
		placeBasket()
	end
	local now = workspace:GetServerTimeNow()
	for id, orb in pairs(orbs) do
		local y = OrbMath.orbY(orb.spawnTime, orb.speed, now)
		local centreX = OrbMath.laneCenterX(orb.lane)
		orb.frame.Position = UDim2.fromOffset(math.floor(centreX - Config.ORB_SIZE / 2 + 0.5), math.floor(y + 0.5))
		if not orb.attempted and y + Config.ORB_SIZE >= Config.BASKET_Y - 6 and y <= Config.BASKET_Y + Config.BASKET_HEIGHT then
			if OrbMath.basketCoversOrb(basketX, centreX) then
				orb.attempted = true
				catchRemote:FireServer(id, basketX)
			end
		end
		if y > Config.ARENA_HEIGHT + 20 then
			orb.frame:Destroy()
			orbs[id] = nil
		end
	end
end)

showMenu()
print("Neon Harvest client ready.")
