--!strict
-- Small slide-out panel with one bar per need. Closed by default so the plant
-- stays the focus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local NeedsMath = require(Shared.Util.NeedsMath)
local PlantConfig = require(Shared.Config.PlantConfig)

local Build = require(script.Parent.Parent.Parent.Util.Build)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

export type NeedsPanel = {
	setOpen: (self: NeedsPanel, open: boolean) -> (),
	isOpen: (self: NeedsPanel) -> boolean,
	update: (self: NeedsPanel, plant: Types.PlantState) -> (),
}

local ROWS = {
	{ key = "water", icon = "💧", color = Theme.Colors.Water },
	{ key = "nutrients", icon = "🌱", color = Theme.Colors.Nutrients },
	{ key = "energy", icon = "⚡", color = Theme.Colors.Energy },
	{ key = "cleanliness", icon = "✨", color = Theme.Colors.Cleanliness },
	{ key = "happiness", icon = "😊", color = Theme.Colors.Happiness },
}

local ROW_HEIGHT = 38
local WIDTH = 230
local TOP = 104

local NeedsPanel = {}

function NeedsPanel.new(parent: Instance): NeedsPanel
	local height = #ROWS * ROW_HEIGHT + 24
	local frame = Widgets.panel({
		Name = "NeedsPanel",
		Size = UDim2.fromOffset(WIDTH, height),
		Position = UDim2.fromOffset(-WIDTH - 40, TOP),
		Visible = false,
		Parent = parent,
	})
	Build.new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 14),
		Parent = frame,
	})
	Build.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

	local fills: { [string]: Frame } = {}
	for index, row in ROWS do
		local container = Build.new("Frame", {
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Parent = frame,
		})
		Widgets.label({ Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(0, 4), Text = row.icon, TextScaled = true, Parent = container })
		local bar = Build.new("Frame", {
			Size = UDim2.new(1, -40, 0, 16),
			Position = UDim2.new(0, 40, 0.5, -8),
			BackgroundColor3 = Theme.Colors.BarBackground,
			BorderSizePixel = 0,
			Parent = container,
		})
		Widgets.corner(bar, UDim.new(1, 0))
		local fill = Build.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = row.color,
			BorderSizePixel = 0,
			Parent = bar,
		})
		Widgets.corner(fill, UDim.new(1, 0))
		fills[row.key] = fill
	end

	local open = false
	local panel = {}

	function panel.setOpen(_self: NeedsPanel, value: boolean)
		if value == open then
			return
		end
		open = value
		if value then
			frame.Visible = true
			Widgets.tween(frame, 0.3, { Position = UDim2.fromOffset(Theme.Gap + 4, TOP) }, Enum.EasingStyle.Back)
		else
			local slide = Widgets.tween(frame, 0.2, { Position = UDim2.fromOffset(-WIDTH - 40, TOP) })
			slide.Completed:Once(function()
				if not open then
					frame.Visible = false
				end
			end)
		end
	end

	function panel.isOpen(_self: NeedsPanel): boolean
		return open
	end

	function panel.update(_self: NeedsPanel, plant: Types.PlantState)
		for _, row in ROWS do
			local value = if row.key == "happiness" then NeedsMath.happiness(plant) else plant.needs[row.key] or 0
			local fill = fills[row.key]
			Widgets.tween(fill, 0.4, { Size = UDim2.fromScale(math.max(value / 100, 0.04), 1) })
			fill.BackgroundColor3 = if value < PlantConfig.Needs.LowThreshold then Theme.Colors.Low else row.color
		end
	end

	return (panel :: any) :: NeedsPanel
end

return NeedsPanel
