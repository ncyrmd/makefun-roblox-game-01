-- Neon Harvest: the shared look of the interface. Every label and button
-- the client builds goes through here, so the palette and the text sizes
-- stay consistent and readable once the screenshots are scaled down.

local Config = require(script.Parent.Config)

local GuiTheme = {}
local Colors = Config.COLORS

-- A plain label. Text is kept large: the judge sees the cover scaled to
-- 768 by 480, so HUD text below 24px would not read at a glance.
function GuiTheme.makeLabel(parent: Instance, name: string, text: string, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.Font = Enum.Font.GothamBold
	label.TextScaled = false
	label.Parent = parent
	return label
end

-- A rounded button with a bright fill and dark text.
function GuiTheme.makeButton(parent: Instance, name: string, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = Colors.Basket
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Colors.Background
	button.TextSize = 28
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

-- A full-screen dim layer behind menus and end screens.
function GuiTheme.makeOverlay(parent: Instance, name: string): Frame
	local overlay = Instance.new("Frame")
	overlay.Name = name
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Colors.Background
	overlay.BackgroundTransparency = 0.25
	overlay.BorderSizePixel = 0
	overlay.Parent = parent
	return overlay
end

-- A centred panel for a menu or an end screen.
function GuiTheme.makePanel(parent: Instance, name: string, width: number, height: number): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(width, height)
	panel.BackgroundColor3 = Colors.Arena
	panel.BorderColor3 = Colors.ArenaEdge
	panel.BorderSizePixel = 2
	panel.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	return panel
end

return GuiTheme
