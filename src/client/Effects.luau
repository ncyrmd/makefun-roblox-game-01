-- Neon Harvest (client): every bit of juice. Small tweens, floating
-- score labels, a red flash and a shake when a bomb lands, and a short
-- built-in ping whose pitch climbs with the combo. No uploaded assets.

local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Parent.Shared.Config)

local Effects = {}

-- A quick grow-and-settle pop on a frame (a caught orb, a button press).
function Effects.popFrame(frame: GuiObject)
	local original = frame.Size
	local grown = UDim2.fromOffset(original.X.Offset + 8, original.Y.Offset + 8)
	local grow = TweenService:Create(frame, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = grown })
	local shrink = TweenService:Create(frame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = original })
	grow:Play()
	grow.Completed:Connect(function()
		shrink:Play()
	end)
end

-- A label that floats up and fades away, then destroys itself.
function Effects.floatText(parent: Instance, text: string, position: UDim2, color: Color3)
	local label = Instance.new("TextLabel")
	label.Name = "FloatText"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = UDim2.fromOffset(120, 32)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = 26
	label.Font = Enum.Font.GothamBold
	label.ZIndex = 20
	label.Parent = parent
	local rise = TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = position + UDim2.fromOffset(0, -44),
		TextTransparency = 1,
	})
	rise:Play()
	rise.Completed:Connect(function()
		label:Destroy()
	end)
end

-- A full-screen colour flash, for the bomb hit.
function Effects.flashOverlay(parent: Instance, color: Color3)
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.55
	flash.BorderSizePixel = 0
	flash.ZIndex = 30
	flash.Parent = parent
	local fade = TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	fade:Play()
	fade.Completed:Connect(function()
		flash:Destroy()
	end)
end

-- Jolt the arena sideways for a moment. The arena's resting position is
-- centre-anchored, so the offsets are small random nudges around it.
function Effects.shakeArena(arena: GuiObject)
	task.spawn(function()
		for _ = 1, 6 do
			arena.Position = UDim2.new(0.5, math.random(-7, 7), 0.5, math.random(-5, 5))
			task.wait(0.04)
		end
		arena.Position = UDim2.fromScale(0.5, 0.5)
	end)
end

-- The built-in ping, pitched up as the combo climbs. Silent when the
-- asset cannot load: a failed sound must never break the game.
function Effects.playPing(combo: number)
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = Config.SOUND_CATCH
		sound.PlaybackSpeed = math.min(1 + combo * 0.06, 1.6)
		sound.Volume = 0.5
		sound.Parent = game:GetService("SoundService")
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		task.delay(2, function()
			if sound.Parent ~= nil then
				sound:Destroy()
			end
		end)
	end)
end

return Effects
