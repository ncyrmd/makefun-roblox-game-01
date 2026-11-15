-- Neon Harvest: every number the game balances on, in one place.
-- The server and the client both read this module, so a tweak here
-- retunes the whole game without touching any other script.

local Config = {}

Config.GAME_NAME = "Neon Harvest"
Config.VERSION = "1.0.0"

-- The playfield is a fixed-size arena drawn on a ScreenGui, so the game
-- plays the same on any screen size: the arena is centred and scaled.
Config.ARENA_WIDTH = 640
Config.ARENA_HEIGHT = 480
Config.LANE_COUNT = 7

Config.BASKET_WIDTH = 96
Config.BASKET_HEIGHT = 22
-- Top edge of the basket, in pixels from the top of the arena.
Config.BASKET_Y = Config.ARENA_HEIGHT - 44
Config.BASKET_SPEED = 520 -- pixels per second

Config.ORB_SIZE = 34
-- Seconds of slack around an orb's predicted arrival when the server
-- judges a catch. Network jitter makes an exact instant unfair.
Config.CATCH_WINDOW = 0.35
Config.LEVEL_TIME = 75 -- seconds to reach the level target
Config.START_LIVES = 3
Config.MAX_LIVES = 3

-- A catch streak raises the multiplier: every 4 catches in a row add 1x.
Config.COMBO_PER_MULTIPLIER = 4
Config.MAX_MULTIPLIER = 3

-- Palette: a deep indigo night with neon fruit.
Config.COLORS = {
	Background = Color3.fromRGB(16, 14, 40),
	Arena = Color3.fromRGB(28, 24, 64),
	ArenaEdge = Color3.fromRGB(90, 80, 180),
	Basket = Color3.fromRGB(0, 229, 255),
	Star = Color3.fromRGB(255, 214, 64),
	Golden = Color3.fromRGB(255, 170, 0),
	Heart = Color3.fromRGB(255, 77, 141),
	Bomb = Color3.fromRGB(255, 59, 59),
	Text = Color3.fromRGB(240, 244, 255),
	Muted = Color3.fromRGB(160, 170, 210),
	Good = Color3.fromRGB(64, 255, 150),
	Bad = Color3.fromRGB(255, 90, 90),
}

-- Orb kinds. Points are multiplied by the combo multiplier; a Heart heals
-- one life, a Bomb costs one. Weight is the spawn-table share.
Config.ORBS = {
	Star = { Points = 10, Speed = 210, Weight = 62, Symbol = "★", Color = Color3.fromRGB(255, 214, 64), Heals = 0, Hurts = 0 },
	Golden = { Points = 25, Speed = 300, Weight = 10, Symbol = "★", Color = Color3.fromRGB(255, 170, 0), Heals = 0, Hurts = 0 },
	Heart = { Points = 0, Speed = 190, Weight = 6, Symbol = "♥", Color = Color3.fromRGB(255, 77, 141), Heals = 1, Hurts = 0 },
	Bomb = { Points = 0, Speed = 260, Weight = 22, Symbol = "✖", Color = Color3.fromRGB(255, 59, 59), Heals = 0, Hurts = 1 },
}
Config.ORB_KIND_ORDER = { "Star", "Golden", "Heart", "Bomb" }

-- Five levels. Target is the cumulative score that clears the level;
-- SpawnEvery and SpeedMul make each level faster than the last.
Config.LEVELS = {
	{ Target = 150, SpawnEvery = 0.85, SpeedMul = 1.00 },
	{ Target = 300, SpawnEvery = 0.75, SpeedMul = 1.10 },
	{ Target = 500, SpawnEvery = 0.65, SpeedMul = 1.22 },
	{ Target = 750, SpawnEvery = 0.55, SpeedMul = 1.35 },
	{ Target = 1000, SpawnEvery = 0.48, SpeedMul = 1.50 },
}
Config.MAX_LEVEL = #Config.LEVELS

-- Built-in Roblox sound, played at different pitches for feedback.
-- No uploaded audio is used, so the place works with no assets.
Config.SOUND_CATCH = "rbxasset://sounds/electronicpingshort.wav"

return Config
