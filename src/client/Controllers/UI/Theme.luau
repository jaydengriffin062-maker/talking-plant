--!strict
-- Shared look for every HUD element.

local Theme = {}

Theme.Font = Enum.Font.FredokaOne

Theme.Colors = {
	Panel = Color3.fromRGB(255, 252, 244),
	PanelStroke = Color3.fromRGB(110, 165, 95),
	Accent = Color3.fromRGB(120, 200, 95),
	AccentDark = Color3.fromRGB(75, 145, 65),
	Text = Color3.fromRGB(55, 70, 55),
	SubtleText = Color3.fromRGB(120, 135, 120),
	Highlight = Color3.fromRGB(255, 205, 60),
	BarBackground = Color3.fromRGB(230, 232, 222),
	Coin = Color3.fromRGB(255, 200, 60),
	Water = Color3.fromRGB(80, 170, 240),
	Nutrients = Color3.fromRGB(140, 200, 80),
	Energy = Color3.fromRGB(250, 195, 60),
	Cleanliness = Color3.fromRGB(175, 140, 245),
	Happiness = Color3.fromRGB(255, 120, 150),
	Low = Color3.fromRGB(240, 90, 80),
}

Theme.Gap = 12
Theme.NavHeight = 84

return Theme
