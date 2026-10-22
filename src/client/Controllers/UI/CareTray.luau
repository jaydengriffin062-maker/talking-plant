--!strict
-- The care tools row that slides up above the bottom navigation.

local Build = require(script.Parent.Parent.Parent.Util.Build)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

export type CareTray = {
	setOpen: (self: CareTray, open: boolean) -> (),
	isOpen: (self: CareTray) -> boolean,
	setActiveTool: (self: CareTray, kind: string?) -> (),
	setAsleep: (self: CareTray, asleep: boolean) -> (),
	highlight: (self: CareTray, kind: string, on: boolean) -> (),
}

local BUTTONS = {
	{ kind = "Water", icon = "💧", label = "Water" },
	{ kind = "Feed", icon = "🌱", label = "Feed" },
	{ kind = "Clean", icon = "🧽", label = "Clean" },
	{ kind = "Sleep", icon = "🌙", label = "Sleep" },
}

local BUTTON_SIZE = 80
local HEIGHT = BUTTON_SIZE + 20
local OPEN_Y = -(Theme.Gap * 2 + Theme.NavHeight)

local CareTray = {}

function CareTray.new(parent: Instance, onPressed: (kind: string) -> ()): CareTray
	local width = #BUTTONS * (BUTTON_SIZE + 10) + 20
	local frame = Widgets.panel({
		Name = "CareTray",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(width, HEIGHT),
		Position = UDim2.new(0.5, 0, 1, HEIGHT),
		Visible = false,
		Parent = parent,
	})
	Build.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})

	local buttons: { [string]: TextButton } = {}
	local sleepIcon: TextLabel
	local sleepCaption: TextLabel?
	for index, def in BUTTONS do
		local button, icon, caption = Widgets.iconButton({
			icon = def.icon,
			label = def.label,
			size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
			parent = frame,
			layoutOrder = index,
		})
		button.Activated:Connect(function()
			onPressed(def.kind)
		end)
		buttons[def.kind] = button
		if def.kind == "Sleep" then
			sleepIcon, sleepCaption = icon, caption
		end
	end

	local open = false
	local stopPulse: { [string]: () -> () } = {}
	local tray = {}

	function tray.setOpen(_self: CareTray, value: boolean)
		if value == open then
			return
		end
		open = value
		if value then
			frame.Visible = true
			Widgets.tween(frame, 0.3, { Position = UDim2.new(0.5, 0, 1, OPEN_Y) }, Enum.EasingStyle.Back)
		else
			local slide = Widgets.tween(frame, 0.2, { Position = UDim2.new(0.5, 0, 1, HEIGHT) })
			slide.Completed:Once(function()
				if not open then
					frame.Visible = false
				end
			end)
		end
	end

	function tray.isOpen(_self: CareTray): boolean
		return open
	end

	function tray.setActiveTool(_self: CareTray, kind: string?)
		for buttonKind, button in buttons do
			button.BackgroundColor3 = if buttonKind == kind then Theme.Colors.Highlight else Theme.Colors.Panel
		end
	end

	function tray.setAsleep(_self: CareTray, asleep: boolean)
		sleepIcon.Text = if asleep then "☀️" else "🌙"
		if sleepCaption then
			sleepCaption.Text = if asleep then "Wake" else "Sleep"
		end
	end

	function tray.highlight(_self: CareTray, kind: string, on: boolean)
		local stop = stopPulse[kind]
		if stop then
			stop()
			stopPulse[kind] = nil
		end
		if on and buttons[kind] then
			stopPulse[kind] = Widgets.pulse(buttons[kind])
		end
	end

	return (tray :: any) :: CareTray
end

return CareTray
